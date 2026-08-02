"""Recommendations router: GET /recommendations (personalized, JWT protected).

Compare to the Phase 1 monolith version: `current.get("preferences")` and
`storage.get_itineraries_for_user(...)` are gone. In their place: two real
HTTP calls to the services that actually own that data. Scoring logic
itself (preference matches + past-trip affinity + popularity) is unchanged -
decomposition changed WHERE the data comes from, not the recommendation
algorithm.
"""
from fastapi import APIRouter, Depends, Query

from .. import storage, clients
from ..security import get_current_user, get_raw_token

router = APIRouter(tags=["Recommendations"])


@router.get("/recommendations")
def recommendations(
    limit: int = Query(10, ge=1, le=50),
    current=Depends(get_current_user),
    token: str = Depends(get_raw_token),
):
    prefs = set(clients.get_user_preferences(token))

    # Tags from user's past trips (itinerary stops) - fetched over REST now.
    visited_ids = set()
    trip_tags = set()
    for it in clients.get_user_itineraries(token):
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
