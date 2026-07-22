"""
GlobeTrotter Monolith - Data Access Layer (Phase 1: JSON file storage).

This is the ONLY file that touches the storage medium.
In Phase 2+, replace this module with a MySQL implementation
without changing any router or business logic.

NOTE (course insight): JSON files have no transactions, no indexing,
and are not designed for concurrent access. We use a process-level
lock as a band-aid — this is exactly the limitation Phase 1 is
designed to expose.
"""
import json
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import USERS_FILE, DESTINATIONS_FILE, ITINERARIES_FILE, DATA_DIR

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


# ---------------- Users ----------------
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


# ------------- Destinations -------------
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


# ------------- Itineraries -------------
def get_itineraries() -> List[Dict[str, Any]]:
    return _read(ITINERARIES_FILE)


def get_itineraries_for_user(user_id: str) -> List[Dict[str, Any]]:
    return [i for i in get_itineraries() if i["owner_id"] == user_id or user_id in i.get("shared_with", [])]


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
