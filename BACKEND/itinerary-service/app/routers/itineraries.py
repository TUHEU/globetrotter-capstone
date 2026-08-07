"""Itineraries router: create, view, manage, share (JWT protected).

Compare create_itinerary() to the Phase 1 version: every place that used to
say `storage.find_destination(...)` or `storage.increment_popularity(...)`
now goes through `clients.py` instead - a real network call to
Recommendation Service, because THIS service no longer has that data.
"""
from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status

from .. import storage, clients
from ..models import ItineraryCreate, ItineraryUpdate, VisibilityUpdate
from ..security import get_current_user, get_raw_token

router = APIRouter(tags=["Itineraries"])


@router.post("/itineraries", status_code=status.HTTP_201_CREATED)
def create_itinerary(body: ItineraryCreate, current=Depends(get_current_user)):
    for stop in body.stops:
        if not clients.destination_exists(stop.destination_id):
            raise HTTPException(status_code=400, detail=f"Unknown destination: {stop.destination_id}")
    it = {
        "id": storage.new_id(),
        "owner_id": current["id"],
        "owner_name": current["full_name"],
        "title": body.title,
        "description": body.description,
        "start_date": body.start_date,
        "end_date": body.end_date,
        "stops": [s.model_dump() for s in body.stops],
        "shared_with": body.shared_with,
        "is_public": body.is_public,
        "created_at": datetime.now(timezone.utc).isoformat(),
    }
    storage.create_itinerary(it)
    for s in body.stops:
        clients.bump_popularity(s.destination_id)
    return it


@router.get("/itineraries")
def my_itineraries(current=Depends(get_current_user)):
    items = storage.get_itineraries_for_user(current["id"])
    return {"count": len(items), "results": items}


@router.get("/itineraries/feed")
def friends_feed(current=Depends(get_current_user), token: str = Depends(get_raw_token)):
    """Public trips from people the caller follows - the 'Friends' Trips'
    feed. Registered BEFORE /itineraries/{it_id} so FastAPI doesn't match
    the literal word 'feed' as an itinerary id.
    """
    following_ids = clients.get_following(token)
    items = storage.get_public_itineraries_for_owners(following_ids)
    return {"count": len(items), "results": items}


@router.get("/itineraries/public/{owner_id}")
def public_itineraries_for_user(owner_id: str, current=Depends(get_current_user)):
    """A specific friend's public trips - e.g. when viewing their profile,
    regardless of whether the caller follows them yet."""
    items = storage.get_public_itineraries_for_owner(owner_id)
    return {"count": len(items), "results": items}


@router.patch("/itineraries/{it_id}/visibility")
def set_visibility(it_id: str, body: VisibilityUpdate, current=Depends(get_current_user)):
    it = next((i for i in storage.get_itineraries() if i["id"] == it_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Itinerary not found")
    if it["owner_id"] != current["id"]:
        raise HTTPException(status_code=403, detail="Only the owner can change visibility")
    return storage.update_itinerary(it_id, {"is_public": body.is_public})


@router.get("/itineraries/{it_id}")
def get_itinerary(it_id: str, current=Depends(get_current_user)):
    it = next((i for i in storage.get_itineraries() if i["id"] == it_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Itinerary not found")
    if it["owner_id"] != current["id"] and current["id"] not in it.get("shared_with", []) \
            and current["email"] not in it.get("shared_with", []):
        raise HTTPException(status_code=403, detail="Not allowed to view this itinerary")
    return it


@router.put("/itineraries/{it_id}")
def update_itinerary(it_id: str, body: ItineraryUpdate, current=Depends(get_current_user)):
    it = next((i for i in storage.get_itineraries() if i["id"] == it_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Itinerary not found")
    if it["owner_id"] != current["id"]:
        raise HTTPException(status_code=403, detail="Only the owner can edit")
    patch = {k: v for k, v in body.model_dump(exclude_none=True).items()}
    if "stops" in patch:
        patch["stops"] = [dict(s) for s in patch["stops"]]
    return storage.update_itinerary(it_id, patch)


@router.delete("/itineraries/{it_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_itinerary(it_id: str, current=Depends(get_current_user)):
    it = next((i for i in storage.get_itineraries() if i["id"] == it_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Itinerary not found")
    if it["owner_id"] != current["id"]:
        raise HTTPException(status_code=403, detail="Only the owner can delete")
    storage.delete_itinerary(it_id)
