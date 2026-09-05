"""Chat Service – JSON-file storage (rolling window, thread-safe)."""
import json
import threading
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import DATA_DIR, MAX_STORED_MESSAGES, EDIT_DELETE_WINDOW_SECONDS

MESSAGES_FILE = DATA_DIR / "messages.json"
_lock = threading.Lock()


def _within_edit_window(ts: str) -> bool:
    """True if the message's `ts` (ISO 8601, UTC) is still inside the
    edit/delete window (default 5 minutes)."""
    try:
        sent = datetime.fromisoformat(ts)
        if sent.tzinfo is None:
            sent = sent.replace(tzinfo=timezone.utc)
    except (ValueError, TypeError):
        return False
    age = (datetime.now(timezone.utc) - sent).total_seconds()
    return 0 <= age <= EDIT_DELETE_WINDOW_SECONDS


def _read() -> List[Dict[str, Any]]:
    if not MESSAGES_FILE.exists():
        return []
    with MESSAGES_FILE.open("r", encoding="utf-8") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return []


def _write(data: List[Dict[str, Any]]) -> None:
    tmp = MESSAGES_FILE.with_suffix(".tmp")
    with tmp.open("w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    tmp.replace(MESSAGES_FILE)


def load_messages() -> List[Dict[str, Any]]:
    with _lock:
        return _read()


def find_message(message_id: str) -> Optional[Dict[str, Any]]:
    with _lock:
        return next((m for m in _read() if m["id"] == message_id), None)


def append_message(msg: Dict[str, Any]) -> None:
    with _lock:
        msgs = _read()
        msgs.append(msg)
        # Rolling window: keep only the last MAX_STORED_MESSAGES
        if len(msgs) > MAX_STORED_MESSAGES:
            msgs = msgs[-MAX_STORED_MESSAGES:]
        _write(msgs)


def delete_message(message_id: str, requester_id: str) -> str:
    """Delete a message. Only the author can delete their own message, and
    only within EDIT_DELETE_WINDOW_SECONDS of sending it.

    Returns one of: "ok", "not_found", "forbidden", "expired".
    """
    with _lock:
        msgs = _read()
        target = None
        for m in msgs:
            if m["id"] == message_id:
                target = m
                break
        if target is None:
            return "not_found"
        if target["user_id"] != requester_id:
            return "forbidden"
        if not _within_edit_window(target.get("ts", "")):
            return "expired"
        new_msgs = [m for m in msgs if m["id"] != message_id]
        _write(new_msgs)
        return "ok"


def edit_message(
    message_id: str, requester_id: str, new_text: str
) -> tuple[str, Optional[Dict[str, Any]]]:
    """Edit the text of a text message. Only the author can edit their own
    message, only within EDIT_DELETE_WINDOW_SECONDS, and only for text
    messages (editing captions on media isn't supported).

    Returns (status, updated_message_or_None) where status is one of:
    "ok", "not_found", "forbidden", "expired", "not_editable".
    """
    with _lock:
        msgs = _read()
        for m in msgs:
            if m["id"] == message_id:
                if m["user_id"] != requester_id:
                    return "forbidden", None
                if m.get("type") != "text":
                    return "not_editable", None
                if not _within_edit_window(m.get("ts", "")):
                    return "expired", None
                m["text"] = new_text
                m["edited"] = True
                _write(msgs)
                return "ok", dict(m)
        return "not_found", None


def add_reaction(
    message_id: str, user_id: str, emoji: str
) -> Optional[Dict[str, List[str]]]:
    """
    Toggle a reaction. Returns the updated reactions dict, or None if not found.
    reactions shape: { "👍": ["user1", "user2"], "❤️": ["user3"] }
    """
    with _lock:
        msgs = _read()
        for m in msgs:
            if m["id"] == message_id:
                reactions: Dict[str, List[str]] = m.setdefault("reactions", {})
                users = reactions.setdefault(emoji, [])
                if user_id in users:
                    users.remove(user_id)       # toggle off
                else:
                    users.append(user_id)       # toggle on
                if not users:
                    del reactions[emoji]
                _write(msgs)
                return dict(reactions)
        return None
