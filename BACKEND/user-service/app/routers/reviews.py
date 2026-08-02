"""Reviews router: avis des utilisateurs sur l'application elle-même
(note 1-5 étoiles + commentaire) - PAS des avis sur une destination.

POST   /reviews          (auth) crée ou met à jour l'avis de l'utilisateur
GET    /reviews                 liste tous les avis (le plus récent d'abord)
GET    /reviews/summary         note moyenne + nombre total d'avis
DELETE /reviews/me        (auth) supprime son propre avis
"""
from fastapi import APIRouter, Depends, HTTPException

from .. import storage
from ..models_reviews import ReviewRequest, ReviewPublic, ReviewSummary
from ..security import get_current_user

router = APIRouter(tags=["Reviews"])


@router.post("/reviews", response_model=ReviewPublic, status_code=201)
def submit_review(body: ReviewRequest, current=Depends(get_current_user)):
    review = storage.upsert_review(
        user_id=current["id"],
        full_name=current["full_name"],
        rating=body.rating,
        comment=body.comment.strip(),
    )
    return review


@router.get("/reviews")
def list_reviews(limit: int = 50):
    reviews = sorted(storage.get_reviews(), key=lambda r: r["created_at"], reverse=True)
    return {"count": len(reviews[:limit]), "results": reviews[:limit]}


@router.get("/reviews/summary", response_model=ReviewSummary)
def reviews_summary():
    reviews = storage.get_reviews()
    if not reviews:
        return {"average_rating": 0.0, "count": 0}
    avg = sum(r["rating"] for r in reviews) / len(reviews)
    return {"average_rating": round(avg, 2), "count": len(reviews)}


@router.delete("/reviews/me", status_code=204)
def delete_my_review(current=Depends(get_current_user)):
    deleted = storage.delete_review(current["id"])
    if not deleted:
        raise HTTPException(status_code=404, detail="No review to delete")
