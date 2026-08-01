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

from .config import USERS_FILE, DATA_DIR

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
