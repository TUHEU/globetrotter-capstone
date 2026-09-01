"""Chat Service – JSON-file storage (rolling window, thread-safe)."""
import json
import threading
from pathlib import Path
from typing import Any, Dict, List, Optional

from .config import DATA_DIR, MAX_STORED_MESSAGES

MESSAGES_FILE = DATA_DIR / "messages.json"
_lock = threading.Lock()


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


def append_message(msg: Dict[str, Any]) -> None:
    with _lock:
        msgs = _read()
        msgs.append(msg)
        # Rolling window: keep only the last MAX_STORED_MESSAGES
        if len(msgs) > MAX_STORED_MESSAGES:
            msgs = msgs[-MAX_STORED_MESSAGES:]
        _write(msgs)


def delete_message(message_id: str, requester_id: str) -> bool:
    """Delete a message. Only the author can delete their own message."""
    with _lock:
        msgs = _read()
        new_msgs = []
        found = False
        for m in msgs:
            if m["id"] == message_id and m["user_id"] == requester_id:
                found = True
            else:
                new_msgs.append(m)
        if found:
            _write(new_msgs)
        return found


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
