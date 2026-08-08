"""
GlobeTrotter - Itinerary Service (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

Owns: itineraries.json (trips, schedules, sharing).
Calls out to: Recommendation Service (to validate destination IDs and bump
popularity) - see app/clients.py.
Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8002
Docs: http://localhost:8002/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import itineraries, social

app = FastAPI(
    title="GlobeTrotter - Itinerary Service",
    version="2.0.0-phase2",
    description="Owns trip itineraries, schedules, and sharing. Validates "
                 "destinations by calling Recommendation Service over REST.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(itineraries.router)
app.include_router(social.router)


@app.get("/health")
def health():
    return {"service": "itinerary-service", "status": "ok"}
