"""User Service - Pydantic schemas for the social/follow feature."""
from typing import List
from pydantic import BaseModel


class UserPublicMini(BaseModel):
    """Just enough to show someone in a search result / follower list -
    never the password hash or preferences (those stay private)."""
    id: str
    full_name: str
    email: str


class UserListResponse(BaseModel):
    count: int
    results: List[UserPublicMini]


class FollowStatus(BaseModel):
    is_following: bool
