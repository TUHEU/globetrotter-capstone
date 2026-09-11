"""1-on-1 audio/video calls - peer-to-peer WebRTC, signalled over
chat-service's /ws/chat (see call_join/call_signal/call_leave there).
This endpoint no longer mints a LiveKit token; it only does the one thing
that still has to happen on a trusted server: check the caller is actually
allowed to call this person, then hand back the deterministic room id both
sides' WebRTC signalling will join. The media itself goes device-to-device
directly, never touching this VPS.
"""
from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel

from ..security import get_current_user
from .messages import _can_message
from .. import storage

router = APIRouter(prefix="/calls", tags=["calls"])


class DmCallTokenRequest(BaseModel):
    other_user_id: str


def _dm_room_name(user_a: str, user_b: str) -> str:
    # Deterministic regardless of who initiates, so both participants'
    # call_join lands in the exact same signalling room.
    a, b = sorted([user_a, user_b])
    return f"dm-{a}-{b}"


@router.post("/dm-token")
def dm_call_room(body: DmCallTokenRequest, current=Depends(get_current_user)):
    if body.other_user_id == current["id"]:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas vous appeler vous-même.")
    other = storage.find_user_by_id(body.other_user_id)
    if not other:
        raise HTTPException(status_code=404, detail="Utilisateur introuvable")
    # Same rule as DMs themselves: you can call someone you follow or who
    # follows you - a call is a more intrusive version of a message, so it
    # shouldn't be allowed where a message wouldn't be either. This is the
    # one check that has to happen server-side (Flutter could compute the
    # same room name locally, but must not be trusted to enforce this).
    if not _can_message(current["id"], body.other_user_id):
        raise HTTPException(
            status_code=403,
            detail="Vous devez suivre cette personne (ou être suivi par elle) pour l'appeler.",
        )

    room = _dm_room_name(current["id"], body.other_user_id)
    return {"room": room}
