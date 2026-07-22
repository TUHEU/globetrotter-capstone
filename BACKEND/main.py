"""
GlobeTrotter Travel Assistant - Phase 1: The Monolith
CS 4122 - Distributed Systems (ICT University)

Single server handling ALL requests, data stored in JSON files.
Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8000
Docs: http://localhost:8000/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, destinations, recommendations, itineraries

app = FastAPI(
    title="GlobeTrotter Monolith",
    version="1.0.0-phase1",
    description="Phase 1 monolithic API: auth, destinations, recommendations, itineraries. JSON file storage (no database yet).",
)

# CORS: Flutter web runs on a different origin than the API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(destinations.router)
app.include_router(recommendations.router)
app.include_router(itineraries.router)


@app.get("/", tags=["Health"])
def health():
    return {
        "service": "GlobeTrotter Yaounde Monolith",
        "phase": 1,
        "status": "up",
        "storage": "JSON files (by design — see Phase 1 challenges)",
    }
