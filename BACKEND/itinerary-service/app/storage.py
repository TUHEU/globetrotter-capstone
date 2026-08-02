"""Itinerary Service - Data Access Layer. Only ever touches itineraries.json."""
import json
import threading
import uuid
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import ITINERARIES_FILE, DATA_DIR

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
