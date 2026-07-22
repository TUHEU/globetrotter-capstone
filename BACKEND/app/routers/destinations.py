"""Destinations router: GET /destinations (search Yaounde places), GET /destinations/{id}, GET /categories."""
from typing import Optional
from fastapi import APIRouter, HTTPException, Query

from .. import storage

router = APIRouter(tags=["Destinations"])

CATEGORIES = ["attraction", "museum", "nature", "market", "restaurant", "cafe", "hotel", "entertainment"]


@router.get("/categories")
def categories():
    return {"results": CATEGORIES}


@router.get("/destinations")
def search_destinations(
    q: Optional[str] = Query(None, description="Free-text search (name, quartier, tags)"),
    tag: Optional[str] = Query(None, description="Filter by tag, e.g. food"),
    category: Optional[str] = Query(None, description="attraction | museum | nature | market | restaurant | cafe | hotel | entertainment"),
    quartier: Optional[str] = None,
    limit: int = Query(50, ge=1, le=100),
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
    dests.sort(key=lambda d: d.get("popularity", 0), reverse=True)
    return {"count": len(dests[:limit]), "results": dests[:limit]}


@router.get("/destinations/{dest_id}")
def get_destination(dest_id: str):
    d = storage.find_destination(dest_id)
    if not d:
        raise HTTPException(status_code=404, detail="Destination not found")
    return d
