"""Recommendations router: GET /recommendations (personalized, JWT protected).

Scoring = preference-tag matches + past-trip tag affinity + global popularity.
"""
from fastapi import APIRouter, Depends, Query

from .. import storage
from ..security import get_current_user

router = APIRouter(tags=["Recommendations"])


@router.get("/recommendations")
def recommendations(limit: int = Query(10, ge=1, le=50), current=Depends(get_current_user)):
    prefs = set(current.get("preferences", []))

    # Tags from user's past trips (itinerary stops)
    visited_ids = set()
    trip_tags = set()
    for it in storage.get_itineraries_for_user(current["id"]):
        for stop in it.get("stops", []):
            visited_ids.add(stop["destination_id"])
            d = storage.find_destination(stop["destination_id"])
            if d:
                trip_tags.update(d.get("tags", []))

    scored = []
    max_pop = max((d.get("popularity", 0) for d in storage.get_destinations()), default=1) or 1
    for d in storage.get_destinations():
        if d["id"] in visited_ids:
            continue  # don't recommend places already in their trips
        tags = set(d.get("tags", []))
        score = (
            3.0 * len(tags & prefs)          # explicit preferences
            + 1.5 * len(tags & trip_tags)    # past trips affinity
            + 1.0 * d.get("popularity", 0) / max_pop  # popular destinations
        )
        reasons = []
        if tags & prefs:
            reasons.append("Matches your interests: " + ", ".join(sorted(tags & prefs)))
        if tags & trip_tags:
            reasons.append("Similar to your past trips")
        if d.get("popularity", 0) >= 0.6 * max_pop:
            reasons.append("Popular with travelers")
        scored.append({**d, "score": round(score, 2), "reasons": reasons or ["Discover something new"]})

    scored.sort(key=lambda x: x["score"], reverse=True)
    return {"count": len(scored[:limit]), "results": scored[:limit]}
