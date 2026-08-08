"""Likes and comments on itineraries.

Kept as a separate router from itineraries.py (which is already large)
rather than folding these in - same "one file per concern" convention as
the rest of this codebase.
"""
from fastapi import APIRouter, Depends, HTTPException

from .. import storage
from ..models import CommentCreate
from ..security import get_current_user

router = APIRouter(tags=["Social"])


def _visible_to(it: dict, user) -> bool:
    """Same visibility rule as GET /itineraries/{id} - comments/likes only
    make sense on an itinerary the viewer is actually allowed to see."""
    if it["owner_id"] == user["id"]:
        return True
    if it.get("is_public", False):
        return True
    shared = it.get("shared_with", [])
    return user["id"] in shared or user["email"] in shared


def _get_or_404(it_id: str) -> dict:
    it = next((i for i in storage.get_itineraries() if i["id"] == it_id), None)
    if not it:
        raise HTTPException(status_code=404, detail="Itinerary not found")
    return it


@router.post("/itineraries/{it_id}/like")
def like(it_id: str, current=Depends(get_current_user)):
    it = _get_or_404(it_id)
    if not _visible_to(it, current):
        raise HTTPException(status_code=403, detail="Not allowed to view this itinerary")
    return storage.toggle_like(it_id, current["id"])


@router.get("/itineraries/{it_id}/comments")
def list_comments(it_id: str, current=Depends(get_current_user)):
    it = _get_or_404(it_id)
    if not _visible_to(it, current):
        raise HTTPException(status_code=403, detail="Not allowed to view this itinerary")
    comments = storage.get_comments(it_id)
    return {"count": len(comments), "results": comments}


@router.post("/itineraries/{it_id}/comments", status_code=201)
def add_comment(it_id: str, body: CommentCreate, current=Depends(get_current_user)):
    it = _get_or_404(it_id)
    if not _visible_to(it, current):
        raise HTTPException(status_code=403, detail="Not allowed to view this itinerary")
    return storage.add_comment(it_id, current["id"], current["full_name"], body.text)


@router.delete("/itineraries/{it_id}/comments/{comment_id}", status_code=204)
def remove_comment(it_id: str, comment_id: str, current=Depends(get_current_user)):
    ok = storage.delete_comment(comment_id, current["id"])
    if not ok:
        raise HTTPException(status_code=403, detail="Not allowed to delete this comment")
