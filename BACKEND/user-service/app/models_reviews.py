"""User Service - Pydantic schemas for in-app reviews (avis sur l'app,
distinct des avis sur une destination - ceux-ci n'existent pas encore
dans cette Phase 2)."""
from pydantic import BaseModel, Field


class ReviewRequest(BaseModel):
    rating: int = Field(ge=1, le=5)
    comment: str = Field(default="", max_length=500)


class ReviewPublic(BaseModel):
    id: str
    user_id: str
    full_name: str
    rating: int
    comment: str
    created_at: str
    updated_at: str


class ReviewSummary(BaseModel):
    average_rating: float
    count: int
