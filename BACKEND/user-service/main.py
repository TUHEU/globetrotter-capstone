"""
GlobeTrotter - User Service (Phase 2: Microservices)
CS 4122 - Distributed Systems (ICT University)

Owns: users.json (identity, credentials, preferences).
Run:  uvicorn main:app --reload --host 0.0.0.0 --port 8001
Docs: http://localhost:8001/docs
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse

from app.config import BASE_DIR
from app.routers import auth, reviews, favorites, social, messages, notifications, calls

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
app.include_router(notifications.router)
app.include_router(calls.router)


# Photos envoyées dans les messages (POST /messages/{id}/photo) - même
# route EXPLICITE que recommendation-service utilise pour ses photos de
# destination (pas app.mount(StaticFiles), voir le commentaire détaillé
# là-bas : ce mécanisme-là a un souci non résolu avec cette version de
# FastAPI/Starlette, alors qu'une route @app.get() normale fonctionne).
@app.get("/static/message_images/{filename}")
def get_message_image(filename: str):
    if "/" in filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    path = BASE_DIR / "static" / "message_images" / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(path)


@app.get("/health")
def health():
    return {"service": "user-service", "status": "ok"}
