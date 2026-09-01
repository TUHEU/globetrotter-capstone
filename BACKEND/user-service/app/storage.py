"""
User Service - Data Access Layer.

Still JSON file storage for now (Phase 2 decomposes SERVICES, not storage —
that upgrade to a real database is a later-course concern). The key
difference from Phase 1: this file ONLY ever touches users.json. No other
service's data lives here, and no other service's code imports this module.
"""
import json
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from datetime import datetime, timezone

from .config import USERS_FILE, REVIEWS_FILE, FAVORITES_FILE, FOLLOWS_FILE, MESSAGES_FILE, DATA_DIR

_lock = threading.Lock()


def _read(path: Path) -> List[Dict[str, Any]]:
    if not path.exists():
        return []
    with path.open("r", encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return []


def _write(path: Path, data: List[Dict[str, Any]]) -> None:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    tmp.replace(path)


def new_id() -> str:
    return uuid.uuid4().hex[:12]


def get_users() -> List[Dict[str, Any]]:
    return _read(USERS_FILE)


def find_user_by_email(email: str) -> Optional[Dict[str, Any]]:
    email = email.lower().strip()
    return next((u for u in get_users() if u["email"] == email), None)


def find_user_by_id(user_id: str) -> Optional[Dict[str, Any]]:
    return next((u for u in get_users() if u["id"] == user_id), None)


def create_user(user: Dict[str, Any]) -> Dict[str, Any]:
    with _lock:
        users = get_users()
        users.append(user)
        _write(USERS_FILE, users)
    return user


def find_or_create_google_user(email: str, full_name: str, google_sub: str) -> Dict[str, Any]:
    """Retourne l'utilisateur existant (créé au préalable via email/mdp OU
    déjà via Google), ou en crée un nouveau la première fois qu'il se
    connecte avec ce compte Google. Aucun mot de passe utilisable n'est
    stocké pour un compte créé ainsi (juste un hash aléatoire, pour que
    la structure de données reste uniforme sans jamais servir de mot de passe)."""
    import secrets
    existing = find_user_by_email(email)
    if existing:
        # Compte déjà existant (créé via email/mdp ou Google précédemment) :
        # on le relie à ce compte Google s'il ne l'était pas encore.
        if not existing.get("google_sub"):
            with _lock:
                users = get_users()
                for u in users:
                    if u["id"] == existing["id"]:
                        u["google_sub"] = google_sub
                _write(USERS_FILE, users)
            existing["google_sub"] = google_sub
        return existing

    from .security import hash_password  # import local pour éviter un cycle
    user = {
        "id": new_id(),
        "full_name": full_name.strip(),
        "email": email.lower().strip(),
        "password_hash": hash_password(secrets.token_urlsafe(32)),
        "preferences": [],
        "google_sub": google_sub,
    }
    create_user(user)
    return user


# ---------------- Reviews (avis sur l'application elle-même) ----------------

def get_reviews() -> List[Dict[str, Any]]:
    return _read(REVIEWS_FILE)


def find_review_by_user(user_id: str) -> Optional[Dict[str, Any]]:
    return next((r for r in get_reviews() if r["user_id"] == user_id), None)


def upsert_review(user_id: str, full_name: str, rating: int, comment: str) -> Dict[str, Any]:
    """Un seul avis par utilisateur : un nouvel envoi MET À JOUR l'avis
    existant plutôt que d'en empiler un deuxième (comme la plupart des
    stores d'applications - Play Store, App Store)."""
    with _lock:
        reviews = get_reviews()
        existing = next((r for r in reviews if r["user_id"] == user_id), None)
        now = datetime.now(timezone.utc).isoformat()
        if existing:
            existing["rating"] = rating
            existing["comment"] = comment
            existing["full_name"] = full_name
            existing["updated_at"] = now
            _write(REVIEWS_FILE, reviews)
            return existing
        review = {
            "id": new_id(),
            "user_id": user_id,
            "full_name": full_name,
            "rating": rating,
            "comment": comment,
            "created_at": now,
            "updated_at": now,
        }
        reviews.append(review)
        _write(REVIEWS_FILE, reviews)
        return review


def delete_review(user_id: str) -> bool:
    with _lock:
        reviews = get_reviews()
        remaining = [r for r in reviews if r["user_id"] != user_id]
        if len(remaining) == len(reviews):
            return False
        _write(REVIEWS_FILE, remaining)
        return True


# ---------------- Favoris (destinations sauvegardées par l'utilisateur) ----

def get_favorites(user_id: str) -> List[str]:
    """Liste des destination_id favoris d'un utilisateur, stockés comme
    {"user_id": [...destination_ids]} pour un accès O(1) par utilisateur."""
    all_favs = _read(FAVORITES_FILE)
    if isinstance(all_favs, list):
        # fichier vide/neuf initialisé comme [] par erreur -> normaliser
        return []
    return all_favs.get(user_id, [])


def add_favorite(user_id: str, destination_id: str) -> List[str]:
    with _lock:
        raw = _read(FAVORITES_FILE)
        all_favs = raw if isinstance(raw, dict) else {}
        current = all_favs.get(user_id, [])
        if destination_id not in current:
            current.append(destination_id)
        all_favs[user_id] = current
        _write(FAVORITES_FILE, all_favs)
        return current


def remove_favorite(user_id: str, destination_id: str) -> List[str]:
    with _lock:
        raw = _read(FAVORITES_FILE)
        all_favs = raw if isinstance(raw, dict) else {}
        current = [d for d in all_favs.get(user_id, []) if d != destination_id]
        all_favs[user_id] = current
        _write(FAVORITES_FILE, all_favs)
        return current


# ---------------- Social (follow / unfollow / search) ----------------
# Stored as {"follower_id": ["followee_id", ...]} - same shape as favorites,
# for the same reason (O(1) lookup of "who does THIS user follow").
# "Who follows me" (followers) is derived by scanning this map rather than
# kept as a second copy, so the two directions can never drift apart.

def _read_follows() -> Dict[str, List[str]]:
    raw = _read(FOLLOWS_FILE)
    return raw if isinstance(raw, dict) else {}


def get_following(user_id: str) -> List[str]:
    return _read_follows().get(user_id, [])


def get_followers(user_id: str) -> List[str]:
    return [uid for uid, following in _read_follows().items() if user_id in following]


def follow_user(follower_id: str, followee_id: str) -> List[str]:
    with _lock:
        all_follows = _read_follows()
        current = all_follows.get(follower_id, [])
        if followee_id not in current:
            current.append(followee_id)
        all_follows[follower_id] = current
        _write(FOLLOWS_FILE, all_follows)
        return current


def unfollow_user(follower_id: str, followee_id: str) -> List[str]:
    with _lock:
        all_follows = _read_follows()
        current = [u for u in all_follows.get(follower_id, []) if u != followee_id]
        all_follows[follower_id] = current
        _write(FOLLOWS_FILE, all_follows)
        return current


def search_users(query: str, exclude_id: str, limit: int = 20) -> List[Dict[str, Any]]:
    """Simple substring match on name/email - good enough for a class
    project's friend list; a real product would use a proper search index."""
    q = query.lower().strip()
    if not q:
        return []
    results = []
    for u in get_users():
        if u["id"] == exclude_id:
            continue
        if q in u["full_name"].lower() or q in u["email"].lower():
            results.append(u)
        if len(results) >= limit:
            break
    return results


def discover_users(exclude_id: str, exclude_ids: List[str], limit: int = 50) -> List[Dict[str, Any]]:
    """Tout le monde SAUF soi-même et les gens déjà suivis (pas d'intérêt à
    les revoir dans un écran de découverte) - les plus récemment inscrits
    en premier, pour que les nouveaux venus soient visibles rapidement
    plutôt que noyés en fin de liste."""
    excluded = set(exclude_ids) | {exclude_id}
    users = [u for u in get_users() if u["id"] not in excluded]
    users.sort(key=lambda u: u.get("created_at", ""), reverse=True)
    return users[:limit]


# ---------------- Messages (messagerie directe) ----------------
# Stockées à plat dans messages.json (une liste, comme reviews.json) plutôt
# qu'indexées par conversation - un utilisateur peut avoir des dizaines de
# conversations, mais chacune reste petite ; filtrer une liste plate à la
# lecture est largement assez rapide à cette échelle, et ça évite de
# dupliquer chaque message dans deux "boîtes" (risque de désynchronisation).

def _conversation_key(a: str, b: str) -> str:
    """Clé stable pour une paire d'utilisateurs, indépendante de l'ordre
    (A→B et B→A sont la MÊME conversation)."""
    return "|".join(sorted([a, b]))


def get_conversation(user_a: str, user_b: str) -> List[Dict[str, Any]]:
    key = _conversation_key(user_a, user_b)
    msgs = [m for m in _read(MESSAGES_FILE) if _conversation_key(m["from_id"], m["to_id"]) == key]
    msgs.sort(key=lambda m: m["created_at"])
    return msgs


def send_message(from_id: str, to_id: str, text: str, image_url: Optional[str] = None) -> Dict[str, Any]:
    with _lock:
        msgs = _read(MESSAGES_FILE)
        msg = {
            "id": new_id(),
            "from_id": from_id,
            "to_id": to_id,
            "text": text,
            "image_url": image_url,
            "created_at": datetime.now(timezone.utc).isoformat(),
            "read": False,
            "edited": False,
        }
        msgs.append(msg)
        _write(MESSAGES_FILE, msgs)
        return msg


def delete_message(message_id: str, requester_id: str) -> bool:
    """Seul l'AUTEUR d'un message peut le supprimer (pas le destinataire -
    sinon n'importe qui pourrait effacer ce que quelqu'un d'autre lui a
    écrit). Supprime pour les deux côtés de la conversation, comme la
    plupart des applis de messagerie ("supprimer pour tout le monde")."""
    with _lock:
        msgs = _read(MESSAGES_FILE)
        for m in msgs:
            if m["id"] == message_id:
                if m["from_id"] != requester_id:
                    return False
                msgs.remove(m)
                _write(MESSAGES_FILE, msgs)
                return True
        return False


def edit_message(message_id: str, requester_id: str, new_text: str) -> Optional[Dict[str, Any]]:
    """Seul l'auteur peut modifier son propre message. Marque `edited` à
    True pour que l'app puisse afficher un petit "(modifié)" - pratique
    courante de transparence dans les applis de messagerie."""
    with _lock:
        msgs = _read(MESSAGES_FILE)
        for m in msgs:
            if m["id"] == message_id:
                if m["from_id"] != requester_id:
                    return None
                m["text"] = new_text
                m["edited"] = True
                _write(MESSAGES_FILE, msgs)
                return m
        return None


def mark_conversation_read(reader_id: str, other_id: str) -> None:
    """Marque comme lus tous les messages que reader_id a REÇUS de other_id
    (jamais ceux qu'il a envoyés - on ne modifie que sa propre boîte de
    réception)."""
    with _lock:
        msgs = _read(MESSAGES_FILE)
        changed = False
        for m in msgs:
            if m["to_id"] == reader_id and m["from_id"] == other_id and not m["read"]:
                m["read"] = True
                changed = True
        if changed:
            _write(MESSAGES_FILE, msgs)


def get_inbox(user_id: str) -> List[Dict[str, Any]]:
    """Une ligne par conversation (dernier message + nombre de non-lus),
    triée par activité récente - la vue "liste des discussions" classique."""
    msgs = _read(MESSAGES_FILE)
    by_partner: Dict[str, Dict[str, Any]] = {}
    for m in msgs:
        if m["from_id"] == user_id:
            partner = m["to_id"]
        elif m["to_id"] == user_id:
            partner = m["from_id"]
        else:
            continue
        entry = by_partner.setdefault(partner, {"last": None, "unread": 0})
        if entry["last"] is None or m["created_at"] > entry["last"]["created_at"]:
            entry["last"] = m
        if m["to_id"] == user_id and not m["read"]:
            entry["unread"] += 1
    results = [
        {"partner_id": pid, "last_message": e["last"], "unread_count": e["unread"]}
        for pid, e in by_partner.items()
    ]
    results.sort(key=lambda r: r["last_message"]["created_at"], reverse=True)
    return results
