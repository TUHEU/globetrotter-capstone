"""Social: search other users, follow/unfollow, list followers/following.

Kept in User Service rather than a new microservice - "who follows whom"
is just another relationship on top of identity (the same way favorites
and reviews already live here), and it needs zero data that any other
service owns. Itinerary Service is the one that calls OUT to this file
(via GET /follow/following) to build a friends' trips feed - see its
app/clients.py::get_following().
"""
from fastapi import APIRouter, Depends, HTTPException, Query
from datetime import datetime

from .. import storage
from ..security import get_current_user

router = APIRouter(tags=["Social"])


def _public(u: dict) -> dict:
    return {"id": u["id"], "full_name": u["full_name"], "email": u["email"]}


@router.get("/users/search")
def search_users(q: str = Query("", min_length=0), current=Depends(get_current_user)):
    results = storage.search_users(q, exclude_id=current["id"])
    return {"count": len(results), "results": [_public(u) for u in results]}


@router.get("/users/discover")
def discover_users(current=Depends(get_current_user)):
    """Écran 'Découvrir' : liste de personnes à suivre, sans avoir à taper
    une recherche - contrairement à /users/search (qui exige une requête
    non vide), pensé pour être parcouru plutôt que cherché. Exclut les
    personnes déjà suivies, puisque le but est de trouver du NOUVEAU
    monde à suivre."""
    already_following = storage.get_following(current["id"])
    results = storage.discover_users(exclude_id=current["id"], exclude_ids=already_following)
    return {"count": len(results), "results": [_public(u) for u in results]}


@router.post("/follow/{user_id}", status_code=201)
def follow(user_id: str, current=Depends(get_current_user)):
    if user_id == current["id"]:
        raise HTTPException(status_code=400, detail="You cannot follow yourself")
    target = storage.find_user_by_id(user_id)
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    ids = storage.follow_user(current["id"], user_id)
    return {"following_ids": ids}


@router.delete("/follow/{user_id}")
def unfollow(user_id: str, current=Depends(get_current_user)):
    ids = storage.unfollow_user(current["id"], user_id)
    return {"following_ids": ids}


@router.get("/follow/following")
def following(current=Depends(get_current_user)):
    """Who the CURRENT user follows - also called by Itinerary Service
    (with the caller's own forwarded token) to build the friends' trips
    feed, so this must stay a simple GET with no side effects."""
    ids = storage.get_following(current["id"])
    users = [u for u in (storage.find_user_by_id(uid) for uid in ids) if u]
    return {"count": len(users), "results": [_public(u) for u in users]}


@router.get("/follow/followers")
def followers(current=Depends(get_current_user)):
    ids = storage.get_followers(current["id"])
    users = [u for u in (storage.find_user_by_id(uid) for uid in ids) if u]
    return {"count": len(users), "results": [_public(u) for u in users]}


@router.get("/follow/status/{user_id}")
def follow_status(user_id: str, current=Depends(get_current_user)):
    return {"is_following": user_id in storage.get_following(current["id"])}


@router.get("/users/stats/public")
def public_user_stats():
    """Statistiques PUBLIQUES et anonymes, sans authentification - juste des
    compteurs agrégés, jamais une donnée individuelle (aucun nom, email,
    ni identifiant). Destiné au site vitrine (TUHEU/GLOBE) pour afficher
    "X personnes utilisent déjà GlobeTrotter" + un graphique de croissance,
    pas à un usage interne à l'app (qui a déjà /users/discover pour ça,
    lui-même protégé par authentification).
    Nom de route explicite en /public pour qu'il n'y ait jamais de doute
    en le relisant plus tard sur le fait qu'il est volontairement ouvert.

    "weekly_growth" groupe les inscriptions par semaine ISO (ex: "2026-W07")
    à partir du VRAI `created_at` de chaque compte - pas de données
    inventées pour "faire joli" sur un graphique.
    """
    users = storage.get_users()
    weekly: dict = {}
    for u in users:
        created = u.get("created_at", "")
        if not created:
            continue
        try:
            dt = datetime.fromisoformat(created)
        except ValueError:
            continue
        week_key = dt.strftime("%Y-W%V")
        weekly[week_key] = weekly.get(week_key, 0) + 1
    weekly_growth = [{"week": k, "count": v} for k, v in sorted(weekly.items())]
    return {"total_users": len(users), "weekly_growth": weekly_growth}
