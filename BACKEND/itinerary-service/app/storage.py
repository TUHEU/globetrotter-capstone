"""Itinerary Service - Data Access Layer. Only ever touches itineraries.json."""
import json
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import ITINERARIES_FILE, COMMENTS_FILE, LIKES_FILE, DATA_DIR
from datetime import date, datetime, timedelta, timezone

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


def get_itineraries() -> List[Dict[str, Any]]:
    return _read(ITINERARIES_FILE)


def get_itineraries_for_user(user_id: str) -> List[Dict[str, Any]]:
    return [i for i in get_itineraries() if i["owner_id"] == user_id or user_id in i.get("shared_with", [])]


def get_public_itineraries_for_owner(owner_id: str) -> List[Dict[str, Any]]:
    """A single user's PUBLIC trips only - what a friend/follower is allowed
    to see, as opposed to get_itineraries_for_user() which also includes
    private ones the caller was explicitly invited to via shared_with."""
    return [i for i in get_itineraries() if i["owner_id"] == owner_id and i.get("is_public", False)]


def get_public_itineraries_for_owners(owner_ids: List[str]) -> List[Dict[str, Any]]:
    """Feed helper: public trips belonging to ANY of these owners (typically
    'everyone the current user follows'), newest-first."""
    owner_set = set(owner_ids)
    results = [i for i in get_itineraries() if i["owner_id"] in owner_set and i.get("is_public", False)]
    results.sort(key=lambda i: i.get("created_at", ""), reverse=True)
    return results


def destination_activity(destination_id: str) -> Dict[str, int]:
    """How many (public) itineraries have this destination scheduled for
    today, tomorrow, or sometime in the next 7 days - computed from
    start_date + each stop's day offset, not stored separately, so it's
    always in sync with whatever trips people actually plan/edit.

    Only PUBLIC itineraries count - a private trip shouldn't leak "N
    people are visiting this place today" to random visitors of the
    destination page.
    """
    today = date.today()
    counts = {"today": 0, "tomorrow": 0, "this_week": 0}
    for it in get_itineraries():
        if not it.get("is_public", False):
            continue
        start_raw = it.get("start_date")
        if not start_raw:
            continue
        try:
            start = date.fromisoformat(start_raw[:10])
        except ValueError:
            continue
        for stop in it.get("stops", []):
            if stop.get("destination_id") != destination_id:
                continue
            day_offset = max(int(stop.get("day", 1)), 1) - 1
            visit_date = start + timedelta(days=day_offset)
            delta_days = (visit_date - today).days
            if delta_days == 0:
                counts["today"] += 1
            elif delta_days == 1:
                counts["tomorrow"] += 1
            if 0 <= delta_days <= 7:
                counts["this_week"] += 1
    return counts


def create_itinerary(it: Dict[str, Any]) -> Dict[str, Any]:
    with _lock:
        items = get_itineraries()
        items.append(it)
        _write(ITINERARIES_FILE, items)
    return it


def update_itinerary(it_id: str, patch: Dict[str, Any]) -> Optional[Dict[str, Any]]:
    with _lock:
        items = get_itineraries()
        for it in items:
            if it["id"] == it_id:
                it.update(patch)
                _write(ITINERARIES_FILE, items)
                return it
    return None


def delete_itinerary(it_id: str) -> bool:
    with _lock:
        items = get_itineraries()
        new_items = [i for i in items if i["id"] != it_id]
        if len(new_items) == len(items):
            return False
        _write(ITINERARIES_FILE, new_items)
        return True


# ---------------- Likes ----------------
# Stockés comme {"itinerary_id": ["user_id", ...]} - juste assez pour
# compter ET savoir si LE viewer courant a déjà aimé (liked_by_me), sans
# avoir besoin d'une seconde structure inversée.

def _read_likes() -> Dict[str, List[str]]:
    raw = _read(LIKES_FILE)
    return raw if isinstance(raw, dict) else {}


def toggle_like(it_id: str, user_id: str) -> Dict[str, Any]:
    with _lock:
        likes = _read_likes()
        current = likes.get(it_id, [])
        if user_id in current:
            current.remove(user_id)
            liked = False
        else:
            current.append(user_id)
            liked = True
        likes[it_id] = current
        _write(LIKES_FILE, likes)
        return {"liked": liked, "like_count": len(current)}


def like_info(it_id: str, viewer_id: Optional[str]) -> Dict[str, Any]:
    likers = _read_likes().get(it_id, [])
    return {"like_count": len(likers), "liked_by_me": viewer_id in likers if viewer_id else False}


def enrich_with_social(it: Dict[str, Any], viewer_id: Optional[str]) -> Dict[str, Any]:
    """Ajoute like_count/liked_by_me/comment_count à un itinéraire avant de
    le renvoyer au client - centralisé ici pour que /itineraries,
    /itineraries/feed, /itineraries/public/{id} et /itineraries/{id} restent
    tous cohérents entre eux plutôt que de dupliquer cette logique dans
    chaque route."""
    info = like_info(it["id"], viewer_id)
    return {
        **it,
        "like_count": info["like_count"],
        "liked_by_me": info["liked_by_me"],
        "comment_count": len(get_comments(it["id"])),
    }


# ---------------- Comments ----------------
# À plat dans comments.json (comme messages.json côté User Service) -
# chaque commentaire porte déjà son itinerary_id, donc filtrer une liste
# plate à la lecture suffit largement à cette échelle.

def get_comments(it_id: str) -> List[Dict[str, Any]]:
    comments = [c for c in _read(COMMENTS_FILE) if c["itinerary_id"] == it_id]
    comments.sort(key=lambda c: c["created_at"])
    return comments


def add_comment(it_id: str, user_id: str, user_name: str, text: str) -> Dict[str, Any]:
    with _lock:
        comments = _read(COMMENTS_FILE)
        comment = {
            "id": new_id(),
            "itinerary_id": it_id,
            "user_id": user_id,
            "user_name": user_name,
            "text": text,
            "created_at": datetime.now(timezone.utc).isoformat(),
        }
        comments.append(comment)
        _write(COMMENTS_FILE, comments)
        return comment


def delete_comment(comment_id: str, user_id: str) -> bool:
    """Only the comment's own author can delete it - checked here, not just
    in the router, so this invariant holds no matter which route calls it."""
    with _lock:
        comments = _read(COMMENTS_FILE)
        target = next((c for c in comments if c["id"] == comment_id), None)
        if not target or target["user_id"] != user_id:
            return False
        _write(COMMENTS_FILE, [c for c in comments if c["id"] != comment_id])
        return True
