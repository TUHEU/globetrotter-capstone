"""Destinations router: GET /destinations (search Yaounde places), GET /destinations/{id},
GET /categories, and POST /destinations/{id}/visit (internal - called by
Itinerary Service to bump popularity when a stop is added to a trip).
"""
import uuid
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, File, Form, HTTPException, Query, UploadFile
from pydantic import BaseModel, Field

from .. import storage, clients
from ..config import BASE_DIR
from ..security import get_current_user, get_raw_token

router = APIRouter(tags=["Destinations"])

CATEGORIES = ["attraction", "museum", "nature", "market", "restaurant", "cafe", "hotel", "entertainment", "education", "sports", "supermarket", "administrative", "travel_agency", "bar", "snack", "gaming", "health", "transport"]

MAX_UPLOAD_BYTES = 5 * 1024 * 1024  # 5 Mo - large-écran mais empêche un upload accidentel de vidéo/fichier énorme
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


class DestinationReviewRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)
    mentions: list[str] = Field(default_factory=list, max_length=20)


class ReviewReplyRequest(BaseModel):
    text: str = Field(min_length=1, max_length=300)
    mentions: list[str] = Field(default_factory=list, max_length=20)


@router.get("/categories")
def categories():
    return {"results": CATEGORIES}


@router.get("/destinations/stats/public")
def public_destination_stats():
    """Voir la note dans user-service/app/routers/social.py:public_user_stats.
    Compte le total RÉEL, pas la page renvoyée par GET /destinations (qui
    est limitée par `limit`, 100 par défaut - actuellement sans incidence
    puisque le catalogue a moins de 100 entrées, mais ce compteur reste
    exact même si le catalogue dépasse un jour cette limite).

    by_category et top_popular sont dérivés des vraies données du
    catalogue (pas de chiffres inventés pour "remplir" un graphique) -
    top_popular expose uniquement nom + score de popularité, jamais de
    donnée sensible (aucune n'existe de toute façon sur une destination)."""
    dests = storage.get_destinations()
    by_category: dict = {}
    for d in dests:
        cat = d.get("category", "autre")
        by_category[cat] = by_category.get(cat, 0) + 1
    top_popular = sorted(dests, key=lambda d: d.get("popularity", 0), reverse=True)[:6]
    return {
        "total_destinations": len(dests),
        "total_categories": len(CATEGORIES),
        "by_category": by_category,
        "top_popular": [
            {"name": d["name"], "popularity": d.get("popularity", 0)} for d in top_popular
        ],
    }


@router.get("/destinations")
def search_destinations(
    q: Optional[str] = Query(None, description="Free-text search (name, quartier, tags)"),
    tag: Optional[str] = Query(None, description="Filter by tag, e.g. food"),
    category: Optional[str] = Query(None, description="attraction | museum | nature | market | restaurant | cafe | hotel | entertainment"),
    quartier: Optional[str] = None,
    # Le max autorisé (100) est aussi la valeur par défaut - avant, le
    # défaut était 50, ce qui coupait silencieusement le catalogue dès
    # qu'un appel sans "limit" explicite dépassait ce chiffre (exactement
    # ce qui s'est produit avec la 51e destination, Stade d'Olembé,
    # ajoutée après ce défaut : elle n'apparaissait jamais dans l'app,
    # pas parce qu'elle manquait côté données, mais parce que l'API la
    # tronquait avant même que le résultat n'atteigne le client).
    limit: int = Query(100, ge=1, le=100),
    min_price: Optional[int] = Query(None, ge=0, description="Minimum avg_price_fcfa (inclusive)"),
    max_price: Optional[int] = Query(None, ge=0, description="Maximum avg_price_fcfa (inclusive)"),
):
    dests = storage.get_destinations()
    if q:
        ql = q.lower()
        dests = [
            d for d in dests
            if ql in d["name"].lower()
            or ql in d.get("quartier", "").lower()
            or ql in d.get("description", "").lower()
            or any(ql in t for t in d.get("tags", []))
        ]
    if tag:
        dests = [d for d in dests if tag.lower() in d.get("tags", [])]
    if category:
        dests = [d for d in dests if d.get("category") == category.lower()]
    if quartier:
        dests = [d for d in dests if quartier.lower() in d.get("quartier", "").lower()]
    if min_price is not None:
        dests = [d for d in dests if d.get("avg_price_fcfa", 0) >= min_price]
    if max_price is not None:
        dests = [d for d in dests if d.get("avg_price_fcfa", 0) <= max_price]
    dests.sort(key=lambda d: d.get("popularity", 0), reverse=True)
    return {"count": len(dests[:limit]), "results": dests[:limit]}


@router.get("/destinations/{dest_id}")
def get_destination(dest_id: str):
    d = storage.find_destination(dest_id)
    if not d:
        raise HTTPException(status_code=404, detail="Destination not found")
    return d


@router.post("/destinations/{dest_id}/visit", status_code=204)
def visit_destination(dest_id: str):
    """Called by Itinerary Service whenever a stop is added to a trip.

    No auth required: this is an internal, service-to-service call, not a
    user-facing endpoint. In a real deployment this would sit behind a
    private network / service mesh rather than being publicly reachable -
    worth flagging to the API Gateway design later (it should NOT expose
    this path to the public internet).
    """
    d = storage.find_destination(dest_id)
    if not d:
        raise HTTPException(status_code=404, detail="Destination not found")
    storage.increment_popularity(dest_id)


# ---------------------------------------------------------------------
# Avis publics sur une destination (indépendants d'un itinéraire),
# adaptés du pattern du monolithe Phase 1.
# ---------------------------------------------------------------------
@router.get("/destinations/{dest_id}/reviews")
def destination_reviews(dest_id: str):
    if not storage.find_destination(dest_id):
        raise HTTPException(status_code=404, detail="Destination not found")
    return {
        "summary": storage.get_review_summary(dest_id),
        "results": storage.get_reviews_for_destination(dest_id),
    }


@router.post("/destinations/{dest_id}/reviews", status_code=201)
def submit_destination_review(
    dest_id: str,
    body: DestinationReviewRequest,
    current=Depends(get_current_user),
    token: str = Depends(get_raw_token),
):
    dest = storage.find_destination(dest_id)
    if not dest:
        raise HTTPException(status_code=404, detail="Destination not found")
    review = storage.add_destination_review({
        "destination_id": dest_id,
        "user_id": current["id"],
        "reviewer_name": current.get("full_name") or "Utilisateur",
        "rating": body.rating,
        "comment": body.comment.strip(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    })
    for mentioned_id in dict.fromkeys(body.mentions):  # de-dupe, keep order
        if mentioned_id != current["id"]:
            clients.notify_mention(token, mentioned_id, dest["name"], body.comment.strip()[:120])
    return review


@router.post("/destinations/{dest_id}/reviews/{review_id}/replies", status_code=201)
def reply_to_review(
    dest_id: str,
    review_id: str,
    body: ReviewReplyRequest,
    current=Depends(get_current_user),
    token: str = Depends(get_raw_token),
):
    """Répondre à l'avis d'un autre utilisateur (fil de discussion sous
    chaque avis) - jusqu'ici les avis étaient une simple liste plate,
    personne ne pouvait réagir à ce que quelqu'un d'autre avait écrit."""
    dest = storage.find_destination(dest_id)
    if not dest:
        raise HTTPException(status_code=404, detail="Destination not found")
    reply = {
        "id": storage.new_reply_id(),
        "user_id": current["id"],
        "author_name": current.get("full_name") or "Utilisateur",
        "text": body.text.strip(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    review = storage.add_reply_to_review(dest_id, review_id, reply)
    if review is None:
        raise HTTPException(status_code=404, detail="Review not found")
    for mentioned_id in dict.fromkeys(body.mentions):
        if mentioned_id != current["id"]:
            clients.notify_mention(token, mentioned_id, dest["name"], body.text.strip()[:120])
    return review


# ---------------------------------------------------------------------
# Lieux à proximité — distance à vol d'oiseau (formule de haversine),
# portée telle quelle depuis le monolithe Phase 1 (business_logic.py).
# ---------------------------------------------------------------------
import math


def _haversine_km(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    """Distance à vol d'oiseau entre deux points, en kilomètres."""
    r = 6371.0
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lng2 - lng1)
    a = math.sin(dphi / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dlambda / 2) ** 2
    return 2 * r * math.asin(math.sqrt(a))


@router.get("/destinations/{dest_id}/nearby")
def nearby_destinations(
    dest_id: str,
    limit: int = Query(5, ge=1, le=20),
    max_km: float = Query(3.0, gt=0),
):
    origin = storage.find_destination(dest_id)
    if not origin:
        raise HTTPException(status_code=404, detail="Destination not found")

    scored = []
    for d in storage.get_destinations():
        if d["id"] == dest_id:
            continue
        dist = _haversine_km(origin["lat"], origin["lng"], d["lat"], d["lng"])
        if dist <= max_km:
            scored.append((dist, d))
    scored.sort(key=lambda pair: pair[0])
    results = [{"distance_km": round(dist, 2), **d} for dist, d in scored[:limit]]
    return {"count": len(results), "results": results}


# ---------------------------------------------------------------------
# Distance depuis la position GPS de l'utilisateur vers UNE destination -
# utilisé par l'app pour afficher "à 2.3 km de vous" sur la carte/fiche lieu.
# ---------------------------------------------------------------------
@router.get("/destinations/{dest_id}/distance")
def distance_from_user(dest_id: str, lat: float = Query(...), lng: float = Query(...)):
    d = storage.find_destination(dest_id)
    if not d:
        raise HTTPException(status_code=404, detail="Destination not found")
    return {"distance_km": round(_haversine_km(lat, lng, d["lat"], d["lng"]), 2)}

@router.post("/destinations/{dest_id}/photos", status_code=201)
async def add_destination_photo(
    dest_id: str,
    photo: UploadFile = File(...),
    current=Depends(get_current_user),
):
    """Lets any user contribute an extra photo to a destination's gallery
    (up to 4, on top of the original cover photo) - same crowdsourced,
    no-moderation-queue spirit as /destinations/submit."""
    dest = storage.find_destination(dest_id)
    if not dest:
        raise HTTPException(status_code=404, detail="Destination not found")
    if photo.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Format d'image non supporté (JPEG, PNG ou WebP uniquement).",
        )
    contents = await photo.read()
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=400, detail="Image trop volumineuse (5 Mo maximum).")

    extension = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}[photo.content_type]
    filename = f"g_{uuid.uuid4().hex[:12]}.{extension}"
    images_dir = BASE_DIR / "static" / "images"
    images_dir.mkdir(parents=True, exist_ok=True)
    (images_dir / filename).write_bytes(contents)

    updated = storage.add_destination_photo(dest_id, f"/static/images/{filename}")
    if updated is None:
        raise HTTPException(
            status_code=400,
            detail=f"Cette destination a déjà {storage.MAX_EXTRA_PHOTOS} photos supplémentaires (maximum).",
        )
    return updated


# ---------------------------------------------------------------------
# Ajout d'un lieu par un utilisateur, photo comprise - visible par tout
# le monde immédiatement, exactement comme demandé ("everyone can see
# the new place uploaded"). Utilise multipart/form-data (pas du JSON)
# puisqu'il faut envoyer un vrai fichier image en même temps que le
# texte, dans la même requête.
# ---------------------------------------------------------------------
@router.post("/destinations/submit", status_code=201)
async def submit_destination(
    name: str = Form(..., min_length=2, max_length=100),
    description: str = Form(..., min_length=10, max_length=800),
    category: str = Form(...),
    quartier: str = Form(..., min_length=2, max_length=80),
    lat: float = Form(...),
    lng: float = Form(...),
    photo: UploadFile = File(...),
    current=Depends(get_current_user),
):
    if category not in CATEGORIES:
        raise HTTPException(
            status_code=400,
            detail=f"Catégorie inconnue. Choisissez parmi : {', '.join(CATEGORIES)}",
        )
    # Yaoundé se situe environ entre 3.7°/4.0° de latitude et 11.4°/11.7°
    # de longitude - un garde-fou simple pour éviter qu'un point saisi par
    # erreur (ou une position GPS non initialisée à 0,0) n'atterrisse à
    # l'autre bout du monde sur la carte de tout le monde.
    if not (3.5 <= lat <= 4.2) or not (11.2 <= lng <= 11.9):
        raise HTTPException(
            status_code=400,
            detail="Cette position ne semble pas se trouver à Yaoundé. Vérifiez le point choisi sur la carte.",
        )
    if photo.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail="Format d'image non supporté (JPEG, PNG ou WebP uniquement).",
        )
    contents = await photo.read()
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=400, detail="Image trop volumineuse (5 Mo maximum).")

    extension = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}[photo.content_type]
    filename = f"u_{uuid.uuid4().hex[:12]}.{extension}"
    images_dir = BASE_DIR / "static" / "images"
    images_dir.mkdir(parents=True, exist_ok=True)
    (images_dir / filename).write_bytes(contents)

    entry = storage.add_user_submitted_destination({
        "name": name.strip(),
        "quartier": quartier.strip(),
        "category": category,
        "description": description.strip(),
        "tags": [],
        "image": f"/static/images/{filename}",
        "avg_price_fcfa": 0,
        "best_time": "",
        "popularity": 1,
        "image_source": "Photo réelle (ajoutée par la communauté)",
        "lat": lat,
        "lng": lng,
        "maps_url": f"https://maps.google.com/?q={lat},{lng}",
        "submitted_by_user_id": current["id"],
        "submitted_by_name": current.get("full_name") or "Un utilisateur",
        "submitted_at": datetime.now(timezone.utc).isoformat(),
    })
    return entry
