"""Destinations router: GET /destinations (search Yaounde places), GET /destinations/{id},
GET /categories, and POST /destinations/{id}/visit (internal - called by
Itinerary Service to bump popularity when a stop is added to a trip).
"""
from datetime import datetime, timezone
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from pydantic import BaseModel, Field

from .. import storage
from ..security import get_current_user

router = APIRouter(tags=["Destinations"])

CATEGORIES = ["attraction", "museum", "nature", "market", "restaurant", "cafe", "hotel", "entertainment", "education", "sports", "supermarket", "administrative"]


class DestinationReviewRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


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
):
    if not storage.find_destination(dest_id):
        raise HTTPException(status_code=404, detail="Destination not found")
    review = storage.add_destination_review({
        "destination_id": dest_id,
        "user_id": current["id"],
        "reviewer_name": current.get("full_name") or "Utilisateur",
        "rating": body.rating,
        "comment": body.comment.strip(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    })
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
