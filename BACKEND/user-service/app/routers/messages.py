"""Messagerie directe (DM) entre utilisateurs.

Règle d'accès : on ne peut envoyer un message qu'à quelqu'un qu'on suit, OU
qui nous suit - pas à n'importe quel inconnu trouvé via /users/search. Ça
évite le spam tout en gardant les conversations naturelles (répondre à
quelqu'un qui vous a suivi en premier reste possible).
"""
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from .. import storage
from ..config import BASE_DIR
from ..models_messages import MessageCreate, MessageEdit
from ..security import get_current_user

router = APIRouter(tags=["Messages"])

MAX_UPLOAD_BYTES = 5 * 1024 * 1024
ALLOWED_CONTENT_TYPES = {"image/jpeg", "image/png", "image/webp"}


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


@router.post("/messages/{other_user_id}/photo")
async def upload_message_photo(other_user_id: str, photo: UploadFile = File(...), current=Depends(get_current_user)):
    """Étape 1 d'un message-photo : uploade juste l'image et renvoie son
    URL - le texte (éventuel) et le vrai POST /messages/{id} qui crée le
    message se font ensuite en JSON normal avec cette URL dedans. Deux
    requêtes plutôt qu'une pour rester cohérent avec le reste de l'API
    (JSON partout, sauf ici où un fichier binaire l'impose)."""
    if not _can_message(current["id"], other_user_id):
        raise HTTPException(
            status_code=403,
            detail="You can only message users you follow or who follow you",
        )
    if photo.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(status_code=400, detail="Format d'image non supporté (JPEG, PNG ou WebP).")
    contents = await photo.read()
    if len(contents) > MAX_UPLOAD_BYTES:
        raise HTTPException(status_code=400, detail="Image trop volumineuse (5 Mo maximum).")

    extension = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}[photo.content_type]
    filename = f"msg_{uuid.uuid4().hex[:12]}.{extension}"
    images_dir = BASE_DIR / "static" / "message_images"
    images_dir.mkdir(parents=True, exist_ok=True)
    (images_dir / filename).write_bytes(contents)
    return {"image_url": f"/static/message_images/{filename}"}


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
    if not body.text.strip() and not body.image_url:
        raise HTTPException(status_code=400, detail="Message vide : ajoutez du texte ou une photo.")
    msg = storage.send_message(current["id"], other_user_id, body.text.strip(), body.image_url)
    return msg


@router.delete("/messages/{other_user_id}/{message_id}")
def delete(other_user_id: str, message_id: str, current=Depends(get_current_user)):
    ok = storage.delete_message(message_id, current["id"])
    if not ok:
        raise HTTPException(
            status_code=404,
            detail="Message introuvable, ou vous n'êtes pas son auteur",
        )
    return {"deleted": True}


@router.patch("/messages/{other_user_id}/{message_id}")
def edit(other_user_id: str, message_id: str, body: MessageEdit, current=Depends(get_current_user)):
    msg = storage.edit_message(message_id, current["id"], body.text.strip())
    if msg is None:
        raise HTTPException(
            status_code=404,
            detail="Message introuvable, ou vous n'êtes pas son auteur",
        )
    return msg
