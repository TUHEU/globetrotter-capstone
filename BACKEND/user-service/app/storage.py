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

from .config import USERS_FILE, REVIEWS_FILE, FAVORITES_FILE, DATA_DIR

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
