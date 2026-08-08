"""Messagerie directe (DM) entre utilisateurs.

Règle d'accès : on ne peut envoyer un message qu'à quelqu'un qu'on suit, OU
qui nous suit - pas à n'importe quel inconnu trouvé via /users/search. Ça
évite le spam tout en gardant les conversations naturelles (répondre à
quelqu'un qui vous a suivi en premier reste possible).
"""
from fastapi import APIRouter, Depends, HTTPException

from .. import storage
from ..models_messages import MessageCreate
from ..security import get_current_user

router = APIRouter(tags=["Messages"])


def _can_message(user_a: str, user_b: str) -> bool:
    return user_b in storage.get_following(user_a) or user_a in storage.get_following(user_b)


def _public_name(user_id: str) -> str:
    u = storage.find_user_by_id(user_id)
    return u["full_name"] if u else "Utilisateur supprimé"


@router.get("/messages/inbox")
def inbox(current=Depends(get_current_user)):
    entries = storage.get_inbox(current["id"])
    return {
        "count": len(entries),
        "results": [
            {
                "partner_id": e["partner_id"],
                "partner_name": _public_name(e["partner_id"]),
                "last_message": e["last_message"],
                "unread_count": e["unread_count"],
            }
            for e in entries
        ],
    }


@router.get("/messages/{other_user_id}")
def conversation(other_user_id: str, current=Depends(get_current_user)):
    target = storage.find_user_by_id(other_user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    # Consulter la conversation marque automatiquement les messages reçus
    # comme lus - comportement standard de n'importe quelle appli de
    # messagerie (ouvrir la discussion = les avoir vus).
    storage.mark_conversation_read(current["id"], other_user_id)
    msgs = storage.get_conversation(current["id"], other_user_id)
    return {
        "partner_id": other_user_id,
        "partner_name": target["full_name"],
        "messages": msgs,
    }


@router.post("/messages/{other_user_id}", status_code=201)
def send(other_user_id: str, body: MessageCreate, current=Depends(get_current_user)):
    if other_user_id == current["id"]:
        raise HTTPException(status_code=400, detail="You cannot message yourself")
    target = storage.find_user_by_id(other_user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if not _can_message(current["id"], other_user_id):
        raise HTTPException(
            status_code=403,
            detail="You can only message users you follow or who follow you",
        )
    msg = storage.send_message(current["id"], other_user_id, body.text)
    return msg
