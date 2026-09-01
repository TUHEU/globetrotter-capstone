"""
GlobeTrotter - API Gateway (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

Routes:
  /register, /login, /me, /users, /follow, /messages  -> User Service    (:8001)
  /itineraries*                                         -> Itinerary      (:8002)
  /recommendations, /destinations*, /categories        -> Recommendation (:8003)
  /assistant                                            -> AI Service     (:8004)
  /chat, /ws/chat, /static/chat_uploads                -> Chat Service   (:8005)

Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
"""
import asyncio
import logging

import httpx
import websockets
from fastapi import FastAPI, Request, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from app.proxy import forward
from app.config import (
    USER_SERVICE_URL, ITINERARY_SERVICE_URL,
    RECOMMENDATION_SERVICE_URL, AI_SERVICE_URL, CHAT_SERVICE_URL,
)

logger = logging.getLogger("api-gateway")

app = FastAPI(
    title="GlobeTrotter - API Gateway",
    version="2.1.0",
    description="Single entry point routing to all backend services.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health():
    return {
        "service": "api-gateway",
        "status": "ok",
        "routes_to": {
            "user-service": USER_SERVICE_URL,
            "itinerary-service": ITINERARY_SERVICE_URL,
            "recommendation-service": RECOMMENDATION_SERVICE_URL,
            "ai-service": AI_SERVICE_URL,
            "chat-service": CHAT_SERVICE_URL,
        },
    }


# ── WebSocket proxy for /ws/chat ──────────────────────────────────────────────
@app.websocket("/ws/chat")
async def ws_chat_proxy(client_ws: WebSocket, token: str = ""):
    """
    Transparent WebSocket proxy: bridges the Flutter client <-> chat-service.
    Appends ?token=... to the upstream URL so chat-service can authenticate.
    """
    # Build upstream WS URL
    upstream_base = CHAT_SERVICE_URL.replace("http://", "ws://").replace("https://", "wss://")
    upstream_url = f"{upstream_base}/ws/chat?token={token}"

    await client_ws.accept()
    try:
        async with websockets.connect(upstream_url) as upstream_ws:

            async def client_to_upstream():
                async for msg in client_ws.iter_text():
                    await upstream_ws.send(msg)

            async def upstream_to_client():
                async for msg in upstream_ws:
                    await client_ws.send_text(msg)

            done, pending = await asyncio.wait(
                [
                    asyncio.create_task(client_to_upstream()),
                    asyncio.create_task(upstream_to_client()),
                ],
                return_when=asyncio.FIRST_COMPLETED,
            )
            for task in pending:
                task.cancel()
    except WebSocketDisconnect:
        pass
    except Exception as exc:
        logger.warning("WS proxy error: %s", exc)
    finally:
        try:
            await client_ws.close()
        except Exception:
            pass


# ── All other HTTP routes ─────────────────────────────────────────────────────
@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def gateway(request: Request, path: str):
    return await forward(request, path)
