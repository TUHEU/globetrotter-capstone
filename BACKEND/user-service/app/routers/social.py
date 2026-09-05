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
    return {"id": u["id"], "full_name": u["full_name"], "email": u["email"], "avatar": u.get("avatar")}


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
    already_following = user_id in storage.get_following(current["id"])
    ids = storage.follow_user(current["id"], user_id)
    if not already_following:
        storage.add_notification(
            user_id=user_id,
            type_="follow",
            title="New follower",
            body=f"{current.get('full_name', 'Someone')} started following you.",
            actor_id=current["id"],
            actor_name=current.get("full_name", "Someone"),
        )
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
    """Anonymous public community metrics for the website.

    - total_users: all registered accounts
    - weekly_growth: newly-created accounts by ISO week
    - total_login_events: successful logins recorded since tracking began
    - unique_logged_in_users: distinct accounts with a recorded successful login
    - weekly_logins: distinct logged-in accounts per ISO week

    No names, emails, passwords, or user ids are exposed here. The existing
    users.json does not contain login timestamps, so historical login activity
    is not invented; new successful logins are recorded from this version onward.
    """
    users = storage.get_users()
    weekly_signups: dict = {}
    for u in users:
        created = u.get("created_at", "")
        if not created:
            continue
        try:
            dt = datetime.fromisoformat(created)
        except ValueError:
            continue
        week_key = dt.strftime("%Y-W%V")
        weekly_signups[week_key] = weekly_signups.get(week_key, 0) + 1

    events = storage.get_login_events()
    weekly_login_users: dict[str, set[str]] = {}
    unique_users: set[str] = set()
    for event in events:
        user_id = event.get("user_id")
        created = event.get("created_at", "")
        if not user_id or not created:
            continue
        try:
            dt = datetime.fromisoformat(created)
        except ValueError:
            continue
        week_key = dt.strftime("%Y-W%V")
        unique_users.add(user_id)
        weekly_login_users.setdefault(week_key, set()).add(user_id)

    weekly_logins = [
        {"week": week, "count": len(ids)}
        for week, ids in sorted(weekly_login_users.items())
    ]

    return {
        "total_users": len(users),
        "weekly_growth": [
            {"week": k, "count": v} for k, v in sorted(weekly_signups.items())
        ],
        "total_login_events": len(events),
        "unique_logged_in_users": len(unique_users),
        "weekly_logins": weekly_logins,
    }
