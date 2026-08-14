"""
GlobeTrotter - Recommendation Service (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

Owns: destinations.json (the Yaounde catalog + popularity counters).
Calls out to: User Service (preferences) and Itinerary Service (past trips)
to build a personalized recommendation - see app/clients.py.
Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8003
Docs: http://localhost:8003/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from app.config import BASE_DIR
from app.routers import destinations, recommendations

app = FastAPI(
    title="GlobeTrotter - Recommendation Service",
    version="2.0.0-phase2",
    description="Owns the destinations catalog and generates personalized "
                 "recommendations by calling User Service and Itinerary "
                 "Service over REST.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(destinations.router)
app.include_router(recommendations.router)

# Real destination photos (replaces the old network/unsplash/wikimedia
# "image" URLs in destinations.json). Files live in static/images/<id>.jpg
# and are served at /static/images/<id>.jpg - the API Gateway forwards
# that prefix straight through to this service (see api-gateway/app/config.py).
app.mount("/static", StaticFiles(directory=BASE_DIR / "static"), name="static")


@app.get("/health")
def health():
    return {"service": "recommendation-service", "status": "ok"}
