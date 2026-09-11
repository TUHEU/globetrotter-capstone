"""In-app rating/feedback prompt: lets a user leave a 1-5 star rating with
an optional comment about the app itself (not a destination review - see
recommendation-service for those). Deliberately minimal: no edit/delete,
no moderation - this is sentiment data for the developer, not
user-visible content.
"""
from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field
from datetime import datetime, timezone

from .. import storage
from ..security import get_current_user

router = APIRouter(prefix="/feedback", tags=["Feedback"])


class FeedbackRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


@router.post("", status_code=201)
def submit_feedback(body: FeedbackRequest, current=Depends(get_current_user)):
    entry = storage.add_feedback({
        "user_id": current["id"],
        "user_name": current.get("full_name") or "Utilisateur",
        "rating": body.rating,
        "comment": body.comment.strip(),
        "created_at": datetime.now(timezone.utc).isoformat(),
    })
    return entry


@router.get("/summary")
def feedback_summary():
    """Public aggregate only (count + average) - never lists individual
    comments here, same spirit as /destinations/stats/public."""
    return storage.get_feedback_summary()
