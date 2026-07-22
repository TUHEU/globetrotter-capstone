"""Itineraries router: create, view, manage, share (JWT protected)."""
from fastapi import APIRouter, Depends, HTTPException, status

from .. import storage
from ..models import ItineraryCreate, ItineraryUpdate
from ..security import get_current_user

router = APIRouter(tags=["Itineraries"])


@router.post("/itineraries", status_code=status.HTTP_201_CREATED)
def create_itinerary(body: ItineraryCreate, current=Depends(get_current_user)):
    for stop in body.stops:
        if not storage.find_destination(stop.destination_id):
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
    }
    storage.create_itinerary(it)
    for s in body.stops:
        storage.increment_popularity(s.destination_id)
    return it


@router.get("/itineraries")
def my_itineraries(current=Depends(get_current_user)):
    items = storage.get_itineraries_for_user(current["id"])
    return {"count": len(items), "results": items}


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
