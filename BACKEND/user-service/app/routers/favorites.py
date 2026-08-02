"""Favoris : destinations sauvegardées par l'utilisateur.

On ne stocke ici que les destination_id (pas les données complètes de la
destination) - Recommendation Service reste la seule source de vérité pour
le contenu d'une destination. Le frontend récupère les détails via
GET /destinations/{id} pour chaque favori.
"""
from fastapi import APIRouter, Depends

from .. import storage
from ..security import get_current_user

router = APIRouter(prefix="/favorites", tags=["Favorites"])


@router.get("")
def list_favorites(current=Depends(get_current_user)):
    return {"destination_ids": storage.get_favorites(current["id"])}


@router.post("/{destination_id}", status_code=201)
def add_favorite(destination_id: str, current=Depends(get_current_user)):
    ids = storage.add_favorite(current["id"], destination_id)
    return {"destination_ids": ids}


@router.delete("/{destination_id}")
def remove_favorite(destination_id: str, current=Depends(get_current_user)):
    ids = storage.remove_favorite(current["id"], destination_id)
    return {"destination_ids": ids}
