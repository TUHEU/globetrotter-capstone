# GlobeTrotter – Global Chat Service

Real-time public group chat for GlobeTrotter Yaoundé.

## Features
- ✅ Text messages + emoji (full picker)
- ✅ Image sharing (JPEG / PNG / WebP / GIF)
- ✅ Audio messages / voice notes (M4A / MP3 / OGG / WAV)
- ✅ Video sharing (MP4 / MOV / WebM)
- ✅ GPS location sharing
- ✅ Emoji reactions (toggle, per message)
- ✅ Delete own messages (live broadcast to all)
- ✅ Online user count (live)
- ✅ Scroll-based message history (last 500)
- ✅ Auto-reconnect on disconnect

## Run locally
```bash
cd backend/chat-service
pip install -r requirements.txt
uvicorn main:app --reload --host 0.0.0.0 --port 8005
```

## Docker
```bash
docker build -t globetrotter-chat .
docker run -p 8005:8005 -e SECRET_KEY=your_secret globetrotter-chat
```

## API

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| WS | `/ws/chat?token=<JWT>` | JWT | Main chat WebSocket |
| GET | `/chat/history?limit=80` | JWT | Load recent messages |
| POST | `/chat/upload` | JWT | Upload media (image/audio/video) |
| GET | `/chat/online` | None | Online user count |
| DELETE | `/chat/messages/{id}` | JWT (own) | Delete a message |
| POST | `/chat/messages/{id}/react?emoji=👍` | JWT | Toggle reaction |
| GET | `/static/chat_uploads/{filename}` | None | Serve uploaded media |
| GET | `/health` | None | Health check |

## WebSocket message format

### Client → Server
```json
// Text
{"type": "text", "text": "Bonjour !"}

// Media (after uploading via /chat/upload)
{"type": "image", "text": "", "media_url": "/static/chat_uploads/abc.jpg", "media_content_type": "image/jpeg"}
{"type": "audio", "text": "", "media_url": "/static/chat_uploads/abc.m4a", "media_content_type": "audio/x-m4a"}
{"type": "video", "text": "", "media_url": "/static/chat_uploads/abc.mp4", "media_content_type": "video/mp4"}

// Location
{"type": "location", "text": "", "location": {"lat": 3.848, "lng": 11.502, "label": "Ma position"}}

// React
{"type": "react", "message_id": "abc123", "emoji": "👍"}

// Delete own message
{"type": "delete", "message_id": "abc123"}
```

### Server → Client
```json
// New message
{"type": "message", "message": {...}}

// System event
{"type": "system", "text": "🌍 Jean a rejoint le chat", "ts": "..."}

// Message deleted
{"type": "delete", "message_id": "abc123"}

// Reaction updated
{"type": "reaction", "message_id": "abc123", "reactions": {"👍": ["user1"]}}

// Online count
{"type": "online", "count": 12}
```

## nginx config (add to your VPS nginx)
```nginx
# WebSocket upgrade for chat
location /ws/chat {
    proxy_pass http://localhost:8005;
    proxy_http_version 1.1;
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_set_header Host $host;
    proxy_read_timeout 86400;
}

location /chat/ {
    proxy_pass http://localhost:8005;
}

location /static/chat_uploads/ {
    proxy_pass http://localhost:8005;
}
```

Or route through the API gateway (port 4200) which already handles WebSocket proxying.
