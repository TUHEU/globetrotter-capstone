"""
GlobeTrotter – Global Chat Service
===================================
Public group chat room where every registered user can:
  • Send text + emoji messages
  • Share images (JPEG/PNG/WEBP/GIF)
  • Share audio recordings (MP3/OGG/M4A/WAV)
  • Share video clips (MP4/MOV/WEBM)
  • Share their GPS location (lat/lng)
  • React with emoji to any message
  • Delete their own messages

Transport: WebSocket (/ws/chat?token=<JWT>)
REST:       POST /chat/upload   → media upload → returns URL
            GET  /chat/history  → last N messages (auth required)
            GET  /chat/online   → count of live connections

Run: uvicorn main:app --reload --host 0.0.0.0 --port 8005
"""
import json
import logging
import mimetypes
import uuid
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

from fastapi import (
    Depends,
    FastAPI,
    File,
    HTTPException,
    Query,
    UploadFile,
    WebSocket,
    WebSocketDisconnect,
)
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse
from fastapi.security import OAuth2PasswordBearer
from jose import JWTError, jwt

from app.config import SECRET_KEY, ALGORITHM, DATA_DIR, UPLOAD_DIR, MAX_UPLOAD_BYTES
from app.storage import load_messages, append_message, delete_message, add_reaction
from app.connection_manager import ConnectionManager

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("chat-service")

app = FastAPI(
    title="GlobeTrotter – Global Chat",
    version="1.0.0",
    description="Real-time public group chat for GlobeTrotter Yaoundé",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

manager = ConnectionManager()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login", auto_error=False)

# ──────────────────────────────────────────────────────────────────────────────
# Auth helpers
# ──────────────────────────────────────────────────────────────────────────────

def _decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        full_name = payload.get("full_name", "Explorateur")
        if not user_id:
            return None
        return {"id": user_id, "full_name": full_name}
    except JWTError:
        return None


def get_current_user(token: str = Depends(oauth2_scheme)):
    if not token:
        raise HTTPException(status_code=401, detail="Not authenticated")
    user = _decode_token(token)
    if not user:
        raise HTTPException(status_code=401, detail="Invalid or expired token")
    return user


# ──────────────────────────────────────────────────────────────────────────────
# Static media files
# ──────────────────────────────────────────────────────────────────────────────

@app.get("/static/chat_uploads/{filename}")
def serve_upload(filename: str):
    if "/" in filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    path = UPLOAD_DIR / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="File not found")
    media_type, _ = mimetypes.guess_type(str(path))
    return FileResponse(path, media_type=media_type or "application/octet-stream")


# ──────────────────────────────────────────────────────────────────────────────
# REST endpoints
# ──────────────────────────────────────────────────────────────────────────────

ALLOWED_MIME = {
    # Images
    "image/jpeg", "image/png", "image/webp", "image/gif",
    # Audio
    "audio/mpeg", "audio/ogg", "audio/mp4", "audio/wav",
    "audio/x-m4a", "audio/aac",
    # Video
    "video/mp4", "video/quicktime", "video/webm", "video/x-matroska",
}

MIME_TO_KIND = {
    **{m: "image" for m in ("image/jpeg", "image/png", "image/webp", "image/gif")},
    **{m: "audio" for m in ("audio/mpeg", "audio/ogg", "audio/mp4", "audio/wav",
                             "audio/x-m4a", "audio/aac")},
    **{m: "video" for m in ("video/mp4", "video/quicktime", "video/webm",
                              "video/x-matroska")},
}


@app.post("/chat/upload")
async def upload_media(
    file: UploadFile = File(...),
    current=Depends(get_current_user),
):
    """Upload image / audio / video. Returns the public URL to embed in a message."""
    content_type = file.content_type or ""
    if content_type not in ALLOWED_MIME:
        raise HTTPException(
            status_code=415,
            detail=f"Unsupported media type: {content_type}. "
                   f"Allowed: {', '.join(sorted(ALLOWED_MIME))}",
        )

    data = await file.read()
    if len(data) > MAX_UPLOAD_BYTES:
        mb = MAX_UPLOAD_BYTES // (1024 * 1024)
        raise HTTPException(status_code=413, detail=f"File too large (max {mb} MB)")

    ext = Path(file.filename or "upload").suffix or mimetypes.guess_extension(content_type) or ""
    filename = f"{uuid.uuid4().hex}{ext}"
    dest = UPLOAD_DIR / filename
    dest.write_bytes(data)

    kind = MIME_TO_KIND.get(content_type, "image")
    return {
        "url": f"/static/chat_uploads/{filename}",
        "kind": kind,
        "content_type": content_type,
        "size": len(data),
    }


@app.get("/chat/history")
def chat_history(
    limit: int = Query(default=80, ge=1, le=300),
    current=Depends(get_current_user),
):
    msgs = load_messages()
    return {"messages": msgs[-limit:], "total": len(msgs)}


@app.get("/chat/online")
def online_count():
    return {"online": manager.count()}


@app.delete("/chat/messages/{message_id}")
def remove_message(message_id: str, current=Depends(get_current_user)):
    ok = delete_message(message_id, current["id"])
    if not ok:
        raise HTTPException(status_code=404, detail="Message not found or not yours")
    # Broadcast deletion
    import asyncio
    asyncio.create_task(
        manager.broadcast(json.dumps({"type": "delete", "message_id": message_id}))
    )
    return {"deleted": True}


@app.post("/chat/messages/{message_id}/react")
async def react(
    message_id: str,
    emoji: str = Query(..., min_length=1, max_length=8),
    current=Depends(get_current_user),
):
    updated = add_reaction(message_id, current["id"], emoji)
    if updated is None:
        raise HTTPException(status_code=404, detail="Message not found")
    await manager.broadcast(
        json.dumps({"type": "reaction", "message_id": message_id, "reactions": updated})
    )
    return {"reactions": updated}


@app.get("/health")
def health():
    return {"service": "chat-service", "status": "ok", "online": manager.count()}


# ──────────────────────────────────────────────────────────────────────────────
# WebSocket endpoint
# ──────────────────────────────────────────────────────────────────────────────

@app.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket, token: str = Query(...)):
    user = _decode_token(token)
    if not user:
        await websocket.close(code=4001, reason="Unauthorized")
        return

    await manager.connect(websocket, user)

    # Announce join
    join_event = json.dumps({
        "type": "system",
        "text": f"🌍 {user['full_name']} a rejoint le chat",
        "ts": _now(),
    })
    await manager.broadcast(join_event)
    # Send online count to all
    await manager.broadcast(json.dumps({"type": "online", "count": manager.count()}))

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                payload = json.loads(raw)
            except json.JSONDecodeError:
                continue

            msg_type = payload.get("type", "text")

            # ── Delete own message ──────────────────────────────────────
            if msg_type == "delete":
                mid = payload.get("message_id", "")
                ok = delete_message(mid, user["id"])
                if ok:
                    await manager.broadcast(
                        json.dumps({"type": "delete", "message_id": mid})
                    )
                continue

            # ── Emoji reaction ──────────────────────────────────────────
            if msg_type == "react":
                mid = payload.get("message_id", "")
                emoji = payload.get("emoji", "")
                if mid and emoji:
                    updated = add_reaction(mid, user["id"], emoji)
                    if updated is not None:
                        await manager.broadcast(json.dumps({
                            "type": "reaction",
                            "message_id": mid,
                            "reactions": updated,
                        }))
                continue

            # ── Regular message (text / image / audio / video / location) ─
            allowed_kinds = {"text", "image", "audio", "video", "location"}
            if msg_type not in allowed_kinds:
                continue

            message = {
                "id": uuid.uuid4().hex,
                "user_id": user["id"],
                "user_name": user["full_name"],
                "type": msg_type,
                "text": payload.get("text", ""),
                "media_url": payload.get("media_url"),         # image/audio/video
                "media_content_type": payload.get("media_content_type"),
                "location": payload.get("location"),           # {lat, lng, label?}
                "reactions": {},
                "ts": _now(),
            }

            append_message(message)

            envelope = {"type": "message", "message": message}
            await manager.broadcast(json.dumps(envelope))

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        leave_event = json.dumps({
            "type": "system",
            "text": f"👋 {user['full_name']} a quitté le chat",
            "ts": _now(),
        })
        await manager.broadcast(leave_event)
        await manager.broadcast(json.dumps({"type": "online", "count": manager.count()}))


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
