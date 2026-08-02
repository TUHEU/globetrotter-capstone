"""
GlobeTrotter - API Gateway (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

The single public entry point. Clients (the Flutter app, the download
website's "app/" web build) only ever talk to THIS service. It doesn't own
any data itself - it just routes:

  /register, /login, /me            -> User Service          (:8001)
  /itineraries*                     -> Itinerary Service      (:8002)
  /recommendations, /destinations*,
  /categories                       -> Recommendation Service (:8003)

Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
Docs: http://localhost:8000/docs   (routes through to each service's own
                                     OpenAPI schema is NOT included here -
                                     see README for hitting :8001/:8002/:8003
                                     /docs directly during development)
"""
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware

from app.proxy import forward
from app.config import USER_SERVICE_URL, ITINERARY_SERVICE_URL, RECOMMENDATION_SERVICE_URL, AI_SERVICE_URL

app = FastAPI(
    title="GlobeTrotter - API Gateway",
    version="2.0.0-phase2",
    description="Single entry point routing to User, Itinerary, and "
                 "Recommendation services.",
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
        },
    }


@app.api_route("/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def gateway(request: Request, path: str):
    return await forward(request, path)
