"""User Service - Pydantic schemas for direct messages (messagerie)."""
from typing import List, Optional
from pydantic import BaseModel, Field


class MessageCreate(BaseModel):
    text: str = Field(default="", max_length=2000)
    image_url: Optional[str] = None


class MessageEdit(BaseModel):
    text: str = Field(min_length=1, max_length=2000)


class MessageOut(BaseModel):
    id: str
    from_id: str
    to_id: str
    text: str
    image_url: Optional[str] = None
    created_at: str
    read: bool
    edited: bool = False


class InboxEntry(BaseModel):
    partner_id: str
    partner_name: str
    last_message: MessageOut
    unread_count: int


class ConversationResponse(BaseModel):
    partner_id: str
    partner_name: str
    messages: List[MessageOut]
