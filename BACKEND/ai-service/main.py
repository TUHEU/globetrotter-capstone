"""
GlobeTrotter - AI Service (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

Owns: rien en stockage - c'est un service "sans état" (stateless) qui
appelle l'API Gemini (gratuite) pour l'assistant conversationnel, en
s'appuyant sur Recommendation Service et Itinerary Service pour ancrer
ses réponses dans les vraies données de l'app plutôt que d'halluciner.

Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8004
Docs: http://localhost:8004/docs
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.routers import assistant

app = FastAPI(
    title="GlobeTrotter - AI Service",
    version="2.0.0-phase2",
    description="Assistant conversationnel (Gemini API) pour recommandations "
                 "de voyage à Yaoundé, ancré sur les données réelles de "
                 "Recommendation Service et Itinerary Service.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(assistant.router)


@app.get("/health")
def health():
    return {"service": "ai-service", "status": "ok"}
