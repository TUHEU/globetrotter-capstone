"""WebSocket connection manager – tracks all live sessions."""
import asyncio
import logging
from typing import Dict, List

from fastapi import WebSocket

logger = logging.getLogger("chat-service.manager")


class ConnectionManager:
    def __init__(self):
        # websocket -> user dict
        self._connections: Dict[WebSocket, dict] = {}
        self._lock = asyncio.Lock()

    async def connect(self, websocket: WebSocket, user: dict):
        await websocket.accept()
        async with self._lock:
            self._connections[websocket] = user
        logger.info("+ %s connected  (total=%d)", user["full_name"], self.count())

    def disconnect(self, websocket: WebSocket):
        user = self._connections.pop(websocket, {})
        logger.info("- %s disconnected (total=%d)", user.get("full_name", "?"), self.count())

    def count(self) -> int:
        return len(self._connections)

    def online_users(self) -> List[dict]:
        return [
            {"id": u["id"], "name": u["full_name"]}
            for u in self._connections.values()
        ]

    async def broadcast(self, text: str):
        """Send to all connected clients; silently drop broken sockets."""
        dead = []
        for ws in list(self._connections):
            try:
                await ws.send_text(text)
            except Exception:
                dead.append(ws)
        for ws in dead:
            self._connections.pop(ws, None)

    async def send_to_user(self, user_id: str, text: str) -> bool:
        """Send to every live connection belonging to this user_id (usually
        one, but a user could have the app open on >1 device/tab). Used for
        WebRTC call signalling, which is point-to-point rather than
        broadcast. Returns True if at least one connection received it."""
        sent = False
        dead = []
        for ws, u in list(self._connections.items()):
            if u.get("id") == user_id:
                try:
                    await ws.send_text(text)
                    sent = True
                except Exception:
                    dead.append(ws)
        for ws in dead:
            self._connections.pop(ws, None)
        return sent
