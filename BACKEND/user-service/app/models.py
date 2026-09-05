"""User Service - Pydantic schemas."""
from typing import List
from pydantic import BaseModel, EmailStr, Field


class RegisterRequest(BaseModel):
    full_name: str = Field(min_length=2, max_length=80)
    email: EmailStr
    password: str = Field(min_length=6)
    preferences: List[str] = []  # e.g. ["beach", "culture", "adventure"]


class LoginRequest(BaseModel):
    email: EmailStr
    password: str


class GoogleAuthRequest(BaseModel):
    id_token: str  # le jeton fourni par le SDK Google Sign-In côté client


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: dict


class UserPublic(BaseModel):
    id: str
    full_name: str
    email: EmailStr
    preferences: List[str] = []
    avatar: str | None = None
