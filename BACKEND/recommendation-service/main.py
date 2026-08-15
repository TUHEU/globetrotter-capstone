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
from fastapi.responses import FileResponse
from fastapi import HTTPException

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
#
# ROUTE EXPLICITE plutôt qu'un app.mount(StaticFiles) : ce dernier a été
# vérifié correctement enregistré dans app.routes lui-même (confirmé par
# introspection directe : `Mount /static` apparaît bien dans la liste),
# et le fichier existe bien exactement là où le code l'attend (confirmé
# aussi) - pourtant chaque requête HTTP réelle vers /static/images/*.jpg
# retournait quand même une 404 générique de FastAPI, y compris en
# testant EN DIRECT sur le port du service (8003), sans passerelle ni
# Nginx dans l'équation. Cause exacte non identifiée malgré vérification
# complète (fichier, chemin, mount enregistré, aucune route concurrente,
# versions FastAPI/Starlette). Plutôt que de continuer à chercher dans
# le mécanisme de "Mount" de Starlette (un sous-composant ASGI séparé,
# avec sa propre logique de correspondance distincte du routeur normal),
# cette route passe par le MÊME mécanisme qu'utilisent déjà /destinations,
# /recommendations etc. - dont on sait avec certitude qu'ils fonctionnent.
@app.get("/static/images/{filename}")
def get_image(filename: str):
    # Double sécurité anti-traversal : un nom de fichier attendu ressemble
    # à "y001.jpg", jamais à quelque chose contenant "/" ou "..".
    if "/" in filename or ".." in filename:
        raise HTTPException(status_code=400, detail="Invalid filename")
    path = BASE_DIR / "static" / "images" / filename
    if not path.is_file():
        raise HTTPException(status_code=404, detail="Image not found")
    return FileResponse(path)


@app.get("/health")
def health():
    return {"service": "recommendation-service", "status": "ok"}
