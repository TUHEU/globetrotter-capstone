"""Recommendation Service - Data Access Layer. Only ever touches destinations.json."""
import json
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import DESTINATIONS_FILE, DATA_DIR

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
