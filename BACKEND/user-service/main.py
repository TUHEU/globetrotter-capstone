"""
GlobeTrotter - User Service (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

Owns: users.json (identity, credentials, preferences).
Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8001
Docs: http://localhost:8001/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import auth, reviews, favorites, social, messages

app = FastAPI(
    title="GlobeTrotter - User Service",
    version="2.0.0-phase2",
    description="Owns user registration, login, and preferences. Issues JWTs "
                 "that Itinerary Service and Recommendation Service verify.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(reviews.router)
app.include_router(favorites.router)
app.include_router(social.router)
app.include_router(messages.router)


@app.get("/health")
def health():
    return {"service": "user-service", "status": "ok"}
