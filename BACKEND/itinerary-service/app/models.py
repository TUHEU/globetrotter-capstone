"""Itinerary Service - Pydantic schemas."""
from typing import List, Optional
from pydantic import BaseModel, Field


class ItineraryStop(BaseModel):
    destination_id: str
    day: int = 1
    notes: Optional[str] = None


class ItineraryCreate(BaseModel):
    title: str = Field(min_length=2, max_length=120)
    description: Optional[str] = None
    start_date: Optional[str] = None  # ISO date string
    end_date: Optional[str] = None
    stops: List[ItineraryStop] = []
    shared_with: List[str] = []  # emails of friends/family
    is_public: bool = False  # visible to followers in GET /itineraries/feed
    budget_fcfa: Optional[int] = Field(None, ge=0)  # budget prévu par l'utilisateur


class ItineraryUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    stops: Optional[List[ItineraryStop]] = None
    shared_with: Optional[List[str]] = None
    is_public: Optional[bool] = None
    budget_fcfa: Optional[int] = Field(None, ge=0)


class VisibilityUpdate(BaseModel):
    is_public: bool


class CommentCreate(BaseModel):
    text: str = Field(min_length=1, max_length=1000)
