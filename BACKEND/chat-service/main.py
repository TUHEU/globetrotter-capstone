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
  • Edit or delete their own text messages within 5 minutes of sending
  • See a "user is typing…" indicator
  • Reply to a specific earlier message (quoted preview)
  • @-mention another user (they get a notification via User Service)

Transport: WebSocket (/ws/chat?token=<JWT>) — types: text/image/audio/video/
           location/delete/edit/react/typing (send, text/image/audio/video
           also accept an optional reply_to=<message_id>) — message/delete/
           edit/reaction/typing/system/online/error (receive)
REST:       POST   /chat/upload            → media upload → returns URL
            GET    /chat/history           → last N messages (auth required)
            GET    /chat/online            → count of live connections
            DELETE /chat/messages/{id}     → delete own message (≤5 min)
            PATCH  /chat/messages/{id}     → edit own text message (≤5 min)

Run: uvicorn main:app --reload --host 0.0.0.0 --port 8005
"""
import asyncio
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

from app.config import (
    SECRET_KEY, ALGORITHM, DATA_DIR, UPLOAD_DIR, MAX_UPLOAD_BYTES,
    GLOBAL_CALL_ROOM,
)
from app.storage import (
    load_messages,
    append_message,
    delete_message,
    edit_message,
    add_reaction,
    find_message,
)
from app.connection_manager import ConnectionManager
from app.clients import notify_mention

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

# ── WebRTC call signalling (mesh) ───────────────────────────────────────────
# room_id -> {user_id: user_name}. Purely in-memory presence for whoever is
# currently "in" a given call room (the fixed GLOBAL_CALL_ROOM, or a
# deterministic per-pair id for DM calls) - NOT the media itself, which goes
# peer-to-peer over WebRTC once signalling has connected two browsers/apps.
# A room simply stops existing once its last member leaves/disconnects.
call_rooms: dict[str, dict[str, str]] = {}
_call_rooms_lock = asyncio.Lock()


async def _call_room_leave(room: str, user_id: str) -> None:
    """Remove user_id from room and tell whoever's left (only them - not a
    global broadcast, since other chat members were never told this room's
    membership in the first place). Safe to call even if the user was never
    in that room (e.g. duplicate leave/disconnect)."""
    async with _call_rooms_lock:
        members = call_rooms.get(room)
        if not members or user_id not in members:
            return
        members.pop(user_id, None)
        remaining = list(members.keys())
        if not members:
            call_rooms.pop(room, None)
    event = json.dumps({"type": "call_peer_left", "room": room, "user_id": user_id})
    for uid in remaining:
        await manager.send_to_user(uid, event)
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="/login", auto_error=False)

# ──────────────────────────────────────────────────────────────────────────────
# Auth helpers
# ──────────────────────────────────────────────────────────────────────────────

def _decode_token(token: str) -> Optional[dict]:
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        user_id = payload.get("sub")
        full_name = payload.get("full_name", "Explorateur")
        avatar = payload.get("avatar")
        if not user_id:
            return None
        return {"id": user_id, "full_name": full_name, "avatar": avatar}
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
    "audio/x-m4a", "audio/aac", "audio/webm",
    # Video
    "video/mp4", "video/quicktime", "video/webm", "video/x-matroska",
}

MIME_TO_KIND = {
    **{m: "image" for m in ("image/jpeg", "image/png", "image/webp", "image/gif")},
    **{m: "audio" for m in ("audio/mpeg", "audio/ogg", "audio/mp4", "audio/wav",
                             "audio/x-m4a", "audio/aac", "audio/webm")},
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


@app.post("/chat/call/token")
def global_call_token(current=Depends(get_current_user)):
    """Everyone joins the SAME room - the Global call is one shared space,
    not a call-per-session ("tap to join whoever's already talking").
    This no longer mints a LiveKit token: calls are peer-to-peer WebRTC,
    signalled over this service's own /ws/chat (see call_join/call_signal/
    call_leave above) - the client just needs the fixed room id to join."""
    return {"room": GLOBAL_CALL_ROOM}


_DELETE_EDIT_ERRORS = {
    "not_found": (404, "Message introuvable"),
    "forbidden": (403, "Vous ne pouvez modifier que vos propres messages"),
    "expired": (403, "Le délai de 5 minutes est dépassé"),
    "not_editable": (400, "Ce type de message ne peut pas être modifié"),
}


@app.delete("/chat/messages/{message_id}")
def remove_message(message_id: str, current=Depends(get_current_user)):
    status = delete_message(message_id, current["id"])
    if status != "ok":
        code, detail = _DELETE_EDIT_ERRORS[status]
        raise HTTPException(status_code=code, detail=detail)
    # Broadcast deletion
    import asyncio
    asyncio.create_task(
        manager.broadcast(json.dumps({"type": "delete", "message_id": message_id}))
    )
    return {"deleted": True}


@app.patch("/chat/messages/{message_id}")
async def edit_message_rest(
    message_id: str,
    text: str = Query(..., min_length=1, max_length=4000),
    current=Depends(get_current_user),
):
    status, updated = edit_message(message_id, current["id"], text.strip())
    if status != "ok":
        code, detail = _DELETE_EDIT_ERRORS[status]
        raise HTTPException(status_code=code, detail=detail)
    await manager.broadcast(json.dumps({"type": "edit", "message": updated}))
    return {"message": updated}


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

            # ── Delete own message (within the edit/delete window) ───────
            if msg_type == "delete":
                mid = payload.get("message_id", "")
                status = delete_message(mid, user["id"])
                if status == "ok":
                    await manager.broadcast(
                        json.dumps({"type": "delete", "message_id": mid})
                    )
                else:
                    _, detail = _DELETE_EDIT_ERRORS[status]
                    await websocket.send_text(json.dumps({
                        "type": "error", "action": "delete",
                        "message_id": mid, "detail": detail,
                    }))
                continue

            # ── Edit own text message (within the edit/delete window) ────
            if msg_type == "edit":
                mid = payload.get("message_id", "")
                new_text = (payload.get("text") or "").strip()
                if not mid or not new_text:
                    continue
                status, updated = edit_message(mid, user["id"], new_text)
                if status == "ok":
                    await manager.broadcast(
                        json.dumps({"type": "edit", "message": updated})
                    )
                else:
                    _, detail = _DELETE_EDIT_ERRORS[status]
                    await websocket.send_text(json.dumps({
                        "type": "error", "action": "edit",
                        "message_id": mid, "detail": detail,
                    }))
                continue

            # ── Typing indicator (ephemeral, not stored) ─────────────────
            if msg_type == "typing":
                await manager.broadcast(json.dumps({
                    "type": "typing",
                    "user_id": user["id"],
                    "user_name": user["full_name"],
                }))
                continue

            # ── Global call presence banner (unrelated to WebRTC signalling
            # below - this is just "someone's in the global call" for the
            # chat UI, e.g. a banner inviting others to join) ─────────────
            if msg_type in ("call_start", "call_end"):
                await manager.broadcast(json.dumps({
                    "type": msg_type,
                    "user_id": user["id"],
                    "user_name": user["full_name"],
                }))
                continue

            # ── WebRTC mesh signalling ────────────────────────────────────
            # No media ever touches this server - only the SDP offer/answer
            # and ICE candidates needed for two browsers/apps to find each
            # other and negotiate a direct peer-to-peer connection. `room`
            # is either GLOBAL_CALL_ROOM or a deterministic per-pair id the
            # client builds for DM calls (sorted "uidA_uidB").

            # Join: register presence in the room, tell the joiner who's
            # already there (so *they* initiate offers to each - standard
            # "new peer offers to existing peers" mesh convention, avoids
            # both sides racing to offer each other), then tell existing
            # members someone new arrived (they just wait for an offer).
            if msg_type == "call_join":
                room = (payload.get("room") or "").strip()
                if not room:
                    continue
                async with _call_rooms_lock:
                    members = call_rooms.setdefault(room, {})
                    existing = [
                        {"user_id": uid, "user_name": name}
                        for uid, name in members.items() if uid != user["id"]
                    ]
                    members[user["id"]] = user["full_name"]
                await websocket.send_text(json.dumps({
                    "type": "call_room_state", "room": room, "peers": existing,
                }))
                joined_event = json.dumps({
                    "type": "call_peer_joined", "room": room,
                    "user_id": user["id"], "user_name": user["full_name"],
                })
                for peer in existing:
                    await manager.send_to_user(peer["user_id"], joined_event)
                continue

            # Relay: forward an SDP offer/answer or ICE candidate to exactly
            # one target peer, untouched, just stamped with who it's from.
            if msg_type == "call_signal":
                room = (payload.get("room") or "").strip()
                target_id = payload.get("target_user_id")
                data = payload.get("data")
                if not room or not target_id or data is None:
                    continue
                await manager.send_to_user(target_id, json.dumps({
                    "type": "call_signal", "room": room,
                    "from_user_id": user["id"], "from_user_name": user["full_name"],
                    "data": data,
                }))
                continue

            # Leave: explicit hang-up (in addition to the disconnect cleanup
            # below, for when the socket itself stays open but the user just
            # backs out of the call screen).
            if msg_type == "call_leave":
                room = (payload.get("room") or "").strip()
                if room:
                    await _call_room_leave(room, user["id"])
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

            reply_preview = None
            reply_to_id = payload.get("reply_to")
            if reply_to_id:
                original = find_message(reply_to_id)
                if original is not None:
                    # Snapshot at send-time so the quote still makes sense
                    # even if the original is edited/deleted afterwards.
                    reply_preview = {
                        "id": original["id"],
                        "user_name": original["user_name"],
                        "type": original["type"],
                        "text": original.get("text", ""),
                    }

            # Client sends the exact user ids it tagged via the @-mention
            # picker (see chat_hub_screen mention autocomplete) rather than
            # us trying to regex-parse "@Full Name" back out of free text,
            # which is ambiguous the moment two people's names overlap or a
            # name contains spaces.
            mentions = [m for m in (payload.get("mentions") or []) if isinstance(m, str)][:20]

            message = {
                "id": uuid.uuid4().hex,
                "user_id": user["id"],
                "user_name": user["full_name"],
                "avatar": user.get("avatar"),
                "type": msg_type,
                "text": payload.get("text", ""),
                "media_url": payload.get("media_url"),         # image/audio/video
                "media_content_type": payload.get("media_content_type"),
                "location": payload.get("location"),           # {lat, lng, label?}
                "reply_to": reply_preview,
                "mentions": mentions,
                "reactions": {},
                "ts": _now(),
            }

            append_message(message)

            envelope = {"type": "message", "message": message}
            await manager.broadcast(json.dumps(envelope))

            if mentions:
                preview = message["text"][:120] or "vous a mentionné dans le chat"
                for mentioned_id in mentions:
                    if mentioned_id != user["id"]:
                        asyncio.create_task(
                            asyncio.to_thread(notify_mention, token, mentioned_id, preview)
                        )

    except WebSocketDisconnect:
        manager.disconnect(websocket)
        leave_event = json.dumps({
            "type": "system",
            "text": f"👋 {user['full_name']} a quitté le chat",
            "ts": _now(),
        })
        await manager.broadcast(leave_event)
        await manager.broadcast(json.dumps({"type": "online", "count": manager.count()}))
        # Also drop them from any call room(s) they were in - a dropped
        # connection is a dropped call, same as an explicit call_leave.
        rooms_to_check = [r for r, members in call_rooms.items() if user["id"] in members]
        for room in rooms_to_check:
            await _call_room_leave(room, user["id"])


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()
