"""Recommendation Service - Data Access Layer. Only ever touches destinations.json."""
import json
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import DESTINATIONS_FILE, DESTINATION_REVIEWS_FILE, DATA_DIR

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
    return _read(DESTINATIONS_FILE)


def find_destination(dest_id: str) -> Optional[Dict[str, Any]]:
    return next((d for d in get_destinations() if d["id"] == dest_id), None)


def increment_popularity(dest_id: str) -> None:
    with _lock:
        dests = get_destinations()
        for d in dests:
            if d["id"] == dest_id:
                d["popularity"] = d.get("popularity", 0) + 1
        _write(DESTINATIONS_FILE, dests)


# ---------------- Avis sur une destination (place reviews) -----------------
# Adapté du pattern qui a fait ses preuves dans le monolithe Phase 1 :
# n'importe quel utilisateur connecté peut laisser un avis (note + commentaire)
# sur une destination, indépendamment de son itinéraire.

def get_reviews_for_destination(destination_id: str) -> List[Dict[str, Any]]:
    all_reviews = _read(DESTINATION_REVIEWS_FILE)
    reviews = [r for r in all_reviews if r["destination_id"] == destination_id]
    reviews.sort(key=lambda r: r["created_at"], reverse=True)
    return reviews


def add_destination_review(review: Dict[str, Any]) -> Dict[str, Any]:
    with _lock:
        all_reviews = _read(DESTINATION_REVIEWS_FILE)
        review["id"] = f"{len(all_reviews) + 1:06d}_{review['destination_id']}"
        all_reviews.append(review)
        _write(DESTINATION_REVIEWS_FILE, all_reviews)
        return review


def get_review_summary(destination_id: str) -> Dict[str, Any]:
    reviews = get_reviews_for_destination(destination_id)
    if not reviews:
        return {"average_rating": 0.0, "count": 0}
    avg = sum(r["rating"] for r in reviews) / len(reviews)
    return {"average_rating": round(avg, 2), "count": len(reviews)}
