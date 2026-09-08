"""
Chat Service with WebRTC P2P Signalling (replaces LiveKit)
"""

import os
import json
from datetime import datetime
from typing import Dict, Set
from fastapi import FastAPI, Depends
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
import socketio
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

CHAT_SERVICE_URL = os.getenv('CHAT_SERVICE_URL', 'http://localhost:8002')
USER_SERVICE_URL = os.getenv('USER_SERVICE_URL', 'http://localhost:8001')

sio = socketio.AsyncServer(
    async_mode='asgi',
    cors_allowed_origins=['*'],
    ping_timeout=60,
    ping_interval=30,
    max_http_buffer_size=1e6,
)

call_rooms: Dict[str, Set[str]] = {}
user_sockets: Dict[str, str] = {}
call_timers: Dict[str, dict] = {}


@sio.event
async def connect(sid, environ):
    logger.info(f"[WebRTC] Client connected: {sid}")


@sio.event
async def disconnect(sid):
    user_id = next((uid for uid, session in user_sockets.items() if session == sid), None)
    if user_id:
        del user_sockets[user_id]
        logger.info(f"[WebRTC] User disconnected: {user_id}")
    
    rooms_to_check = list(call_rooms.keys())
    for room_id in rooms_to_check:
        if sid in call_rooms.get(room_id, set()):
            call_rooms[room_id].discard(sid)
            
            await sio.emit('call:participant_left', {
                'userId': user_id or 'unknown',
                'roomId': room_id,
            }, to=room_id)
            
            if not call_rooms[room_id]:
                del call_rooms[room_id]
                if room_id in call_timers:
                    del call_timers[room_id]


@sio.event
async def call_join(sid, data):
    try:
        room_id = data.get('roomId')
        user_id = data.get('userId')
        user_name = data.get('userName')
        
        if not room_id or not user_id:
            await sio.emit('error', {'message': 'Missing roomId or userId'}, to=sid)
            return
        
        user_sockets[user_id] = sid
        sio.enter_room(sid, room_id)
        
        if room_id not in call_rooms:
            call_rooms[room_id] = set()
            call_timers[room_id] = {
                'start': datetime.now().isoformat(),
                'participants': [user_id],
            }
        else:
            call_timers[room_id]['participants'].append(user_id)
        
        call_rooms[room_id].add(sid)
        
        logger.info(f"[WebRTC] User {user_id} ({user_name}) joined room {room_id}")
        
        participants = list(call_timers[room_id]['participants'])
        participants.remove(user_id)
        
        await sio.emit('call:participants_list', {
            'participants': participants,
            'roomId': room_id,
        }, to=sid)
        
        await sio.emit('call:participant_joined', {
            'userId': user_id,
            'userName': user_name,
            'roomId': room_id,
        }, to=room_id, skip_sid=sid)
        
    except Exception as e:
        logger.error(f"[WebRTC] Error in call_join: {str(e)}")
        await sio.emit('error', {'message': f'Failed to join room: {str(e)}'}, to=sid)


@sio.event
async def call_signal(sid, data):
    try:
        signal_type = data.get('type')
        from_user_id = data.get('from')
        to_user_id = data.get('to')
        
        if not signal_type or not from_user_id:
            logger.warning(f"[WebRTC] Invalid signal message: {data}")
            return
        
        if to_user_id and to_user_id in user_sockets:
            recipient_sid = user_sockets[to_user_id]
            
            message = {
                'type': signal_type,
                'from': from_user_id,
                'fromSid': sid,
            }
            
            if signal_type == 'offer':
                message['offer'] = data.get('offer')
            elif signal_type == 'answer':
                message['answer'] = data.get('answer')
            elif signal_type == 'ice':
                message['candidate'] = data.get('candidate')
            
            await sio.emit('call:signal', message, to=recipient_sid)
            logger.info(f"[WebRTC] Relayed {signal_type} from {from_user_id} to {to_user_id}")
        
        room_id = data.get('roomId')
        if room_id:
            await sio.emit('call:signal', {
                'type': signal_type,
                'from': from_user_id,
                ('offer' if signal_type == 'offer' else 
                 'answer' if signal_type == 'answer' else 
                 'candidate'): data.get(signal_type),
            }, to=room_id, skip_sid=sid)
            
    except Exception as e:
        logger.error(f"[WebRTC] Error in call_signal: {str(e)}")


@sio.event
async def call_hang_up(sid, data):
    try:
        room_id = data.get('roomId')
        user_id = data.get('userId')
        
        if room_id and room_id in call_rooms:
            await sio.emit('call:participant_left', {
                'userId': user_id,
                'roomId': room_id,
            }, to=room_id, skip_sid=sid)
            
            sio.leave_room(sid, room_id)
            if sid in call_rooms[room_id]:
                call_rooms[room_id].discard(sid)
            
            if not call_rooms[room_id]:
                del call_rooms[room_id]
                if room_id in call_timers:
                    del call_timers[room_id]
            else:
                if room_id in call_timers:
                    call_timers[room_id]['participants'].remove(user_id)
            
            logger.info(f"[WebRTC] User {user_id} hung up from room {room_id}")
        
    except Exception as e:
        logger.error(f"[WebRTC] Error in call_hang_up: {str(e)}")


@sio.event
async def chat_send_message(sid, data):
    try:
        room_id = data.get('roomId')
        
        if not room_id:
            await sio.emit('error', {'message': 'Missing roomId'}, to=sid)
            return
        
        message_data = {
            'userId': data.get('userId'),
            'userName': data.get('userName'),
            'message': data.get('message'),
            'timestamp': data.get('timestamp', datetime.now().isoformat()),
            'type': 'text'
        }
        
        await sio.emit('chat:message_received', message_data, to=room_id)
        
        logger.info(f"[Chat] Message from {data.get('userId')} in room {room_id}")
        
    except Exception as e:
        logger.error(f"[Chat] Error sending message: {str(e)}")


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("[Chat Service] Starting with WebRTC support...")
    yield
    logger.info("[Chat Service] Shutting down...")
    

app = FastAPI(title="Chat Service with WebRTC", lifespan=lifespan)

app.mount('/socket.io', socketio.ASGIApp(sio, static_files={
    '/': {'filename': 'index.html'}
}))

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=True,
    allow_methods=['*'],
    allow_headers=['*'],
)


@app.get("/health")
async def health_check():
    return {
        "status": "ok",
        "service": "chat-service",
        "features": ["websocket", "webrtc-signalling", "chat-messaging"],
        "active_rooms": len(call_rooms),
        "connected_users": len(user_sockets)
    }


@app.get("/stats")
async def get_stats():
    return {
        "active_call_rooms": len(call_rooms),
        "connected_users": len(user_sockets),
        "rooms": {
            room_id: {
                'participants': list(call_timers.get(room_id, {}).get('participants', [])),
                'started': call_timers.get(room_id, {}).get('start'),
            }
            for room_id in call_rooms.keys()
        }
    }


@app.get("/call/token")
async def get_call_token(room_id: str, user_id: str):
    return {
        "token": "",
        "url": "",
        "room": room_id,
        "protocol": "webrtc-p2p",
        "message": "Use Socket.IO signalling for WebRTC calls"
    }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv('CHAT_SERVICE_PORT', '8002'))
    uvicorn.run(app, host="0.0.0.0", port=port, workers=1)
