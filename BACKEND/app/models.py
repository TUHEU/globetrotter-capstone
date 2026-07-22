"""GlobeTrotter Monolith - Pydantic schemas."""
from typing import List, Optional
from pydantic import BaseModel, EmailStr, Field


# ---------- Auth ----------
class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=80)
    email: EmailStr
    password: str = Field(min_length=6)
    preferences: List[str] = []  # e.g. ["beach", "culture", "adventure"]


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict


class UserPublic(BaseModel):
    id: str
    full_name: str
    email: EmailStr
    preferences: List[str] = []


# ---------- Itineraries ----------
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


class ItineraryUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    stops: Optional[List[ItineraryStop]] = None
    shared_with: Optional[List[str]] = None
