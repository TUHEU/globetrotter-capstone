"""Recommendation Service - Data Access Layer. Only ever touches destinations.json."""
import json
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import DESTINATIONS_FILE, DESTINATION_REVIEWS_FILE, POPULARITY_FILE, DATA_DIR

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


def get_destinations() -> List[Dict[str, Any]]:
    dests = _read(DESTINATIONS_FILE)
    overrides = _read_popularity_overrides()
    if overrides:
        for d in dests:
            if d["id"] in overrides:
                d["popularity"] = overrides[d["id"]]
    return dests


def add_user_submitted_destination(entry: Dict[str, Any]) -> Dict[str, Any]:
    """Ajoute un lieu proposé par un utilisateur au catalogue - visible
    immédiatement par tout le monde (pas de file de modération, comme
    demandé). L'id commence par "u_" (au lieu de "y0XX") pour qu'on puisse
    toujours distinguer d'un coup d'œil le catalogue vérifié au départ des
    lieux ajoutés par la communauté, sans que ça change quoi que ce soit
    pour l'utilisateur (mêmes filtres, même recherche, même carte)."""
    with _lock:
        dests = _read(DESTINATIONS_FILE)
        entry["id"] = f"u_{uuid.uuid4().hex[:10]}"
        dests.append(entry)
        _write(DESTINATIONS_FILE, dests)
        return entry


def _read_popularity_overrides() -> Dict[str, int]:
    if not POPULARITY_FILE.exists():
        return {}
    with POPULARITY_FILE.open("r", encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return {}


def find_destination(dest_id: str) -> Optional[Dict[str, Any]]:
    return next((d for d in get_destinations() if d["id"] == dest_id), None)


def increment_popularity(dest_id: str) -> None:
    """Écrit UNIQUEMENT dans popularity_overrides.json (gitignoré) -
    destinations.json (suivi par git) n'est plus jamais modifié au
    runtime, ce qui élimine les conflits `git pull` sur le VPS."""
    with _lock:
        overrides = _read_popularity_overrides()
        base = next((d for d in _read(DESTINATIONS_FILE) if d["id"] == dest_id), None)
        current = overrides.get(dest_id, base.get("popularity", 0) if base else 0)
        overrides[dest_id] = current + 1
        DATA_DIR.mkdir(parents=True, exist_ok=True)
        tmp = POPULARITY_FILE.with_suffix(".tmp")
        with tmp.open("w", encoding="utf-8") as f:
            json.dump(overrides, f, indent=2, ensure_ascii=False)
        tmp.replace(POPULARITY_FILE)


# ---------------- Avis sur une destination (place reviews) -----------------
# Adapté du pattern qui a fait ses preuves dans le monolithe Phase 1 :
# n'importe quel utilisateur connecté peut laisser un avis (note + commentaire)
# sur une destination, indépendamment de son itinéraire.

def get_reviews_for_destination(destination_id: str) -> List[Dict[str, Any]]:
    all_reviews = _read(DESTINATION_REVIEWS_FILE)
    reviews = [r for r in all_reviews if r["destination_id"] == destination_id]
    reviews.sort(key=lambda r: r["created_at"], reverse=True)
    # Rétrocompatibilité : les avis créés AVANT l'ajout des réponses n'ont
    # pas encore de clé "replies" dans le fichier JSON - on la complète à
    # la lecture plutôt que de migrer tout le fichier une bonne fois.
    for r in reviews:
        r.setdefault("replies", [])
    return reviews


def add_destination_review(review: Dict[str, Any]) -> Dict[str, Any]:
    with _lock:
        all_reviews = _read(DESTINATION_REVIEWS_FILE)
        review["id"] = f"{len(all_reviews) + 1:06d}_{review['destination_id']}"
        review["replies"] = []
        all_reviews.append(review)
        _write(DESTINATION_REVIEWS_FILE, all_reviews)
        return review


def new_reply_id() -> str:
    return uuid.uuid4().hex[:10]


def add_reply_to_review(
    destination_id: str, review_id: str, reply: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    """Ajoute une réponse à l'avis d'un autre utilisateur. Retourne l'avis
    mis à jour (avec sa nouvelle réponse), ou None si l'avis n'existe pas
    (ou n'appartient pas à ce lieu - évite de répondre à un avis d'un
    AUTRE lieu en devinant juste son id)."""
    with _lock:
        all_reviews = _read(DESTINATION_REVIEWS_FILE)
        for r in all_reviews:
            if r["id"] == review_id and r["destination_id"] == destination_id:
                r.setdefault("replies", [])
                r["replies"].append(reply)
                _write(DESTINATION_REVIEWS_FILE, all_reviews)
                return r
        return None


def get_review_summary(destination_id: str) -> Dict[str, Any]:
    reviews = get_reviews_for_destination(destination_id)
    if not reviews:
        return {"average_rating": 0.0, "count": 0}
    avg = sum(r["rating"] for r in reviews) / len(reviews)
    return {"average_rating": round(avg, 2), "count": len(reviews)}
