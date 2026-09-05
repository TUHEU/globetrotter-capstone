"""1-on-1 audio/video calls, riding on LiveKit Cloud - this service only
ever mints short-lived join tokens; the actual media never touches our
VPS at all, LiveKit Cloud's infrastructure handles that entirely.
"""
import os
from datetime import timedelta

from fastapi import APIRouter, Depends, HTTPException
from livekit import api
from pydantic import BaseModel

from ..security import get_current_user
from .messages import _can_message
from .. import storage

router = APIRouter(prefix="/calls", tags=["calls"])

LIVEKIT_URL = os.getenv("LIVEKIT_URL", "")
LIVEKIT_API_KEY = os.getenv("LIVEKIT_API_KEY", "")
LIVEKIT_API_SECRET = os.getenv("LIVEKIT_API_SECRET", "")


class DmCallTokenRequest(BaseModel):
    other_user_id: str


def _dm_room_name(user_a: str, user_b: str) -> str:
    # Deterministic regardless of who initiates, so both participants'
    # tokens resolve to the exact same LiveKit room.
    a, b = sorted([user_a, user_b])
    return f"dm-{a}-{b}"


@router.post("/dm-token")
def dm_call_token(body: DmCallTokenRequest, current=Depends(get_current_user)):
    if not LIVEKIT_API_KEY or not LIVEKIT_API_SECRET or not LIVEKIT_URL:
        raise HTTPException(
            status_code=503,
            detail="Les appels ne sont pas configurés sur ce serveur (LIVEKIT_* manquant).",
        )
    if body.other_user_id == current["id"]:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous appeler vous-même.")
    other = storage.find_user_by_id(body.other_user_id)
    if not other:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    # Same rule as DMs themselves: you can call someone you follow or who
    # follows you - a call is a more intrusive version of a message, so it
    # shouldn't be allowed where a message wouldn't be either.
    if not _can_message(current["id"], body.other_user_id):
        raise HTTPException(
            status_code=403,
            detail="Vous devez suivre cette personne (ou être suivi par elle) pour l'appeler.",
        )

    room = _dm_room_name(current["id"], body.other_user_id)
    token = (
        api.AccessToken(LIVEKIT_API_KEY, LIVEKIT_API_SECRET)
        .with_identity(current["id"])
        .with_name(current.get("full_name") or "Utilisateur")
        .with_grants(api.VideoGrants(
            room_join=True,
            room=room,
            can_publish=True,
            can_subscribe=True,
            can_publish_data=True,
        ))
        .with_ttl(timedelta(hours=2))
        .to_jwt()
    )
    return {"url": LIVEKIT_URL, "token": token, "room": room}
