"""
Recommendation Service - outbound calls to OTHER services.

This is the service the slide's diagram calls out by name: "Recommendation
Service calling User Service" is the textbook example of synchronous,
request-response inter-service communication. We forward the SAME bearer
token the client sent us - the user already proved who they are once, to
User Service at login; we don't make them prove it again, we just pass
their credential along (this is the standard "token propagation" pattern).
"""
from typing import Any, Dict, List

import httpx

from .config import USER_SERVICE_URL, ITINERARY_SERVICE_URL


def get_user_preferences(token: str) -> List[str]:
    """Ask User Service for this user's up-to-date preferences.

    We deliberately do NOT trust a 'preferences' claim in the JWT for this -
    preferences change far more often than a name, so stale claims would
    visibly hurt recommendation quality. This is exactly the kind of
    "which data do I trust locally vs. re-fetch" decision microservices
    force you to make explicitly.
    """
    try:
        r = httpx.get(
            f"{USER_SERVICE_URL}/me",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5.0,
        )
        if r.status_code == 200:
            return [p.lower() for p in r.json().get("preferences", [])]
    except httpx.RequestError:
        pass
    # User Service down or errored: degrade gracefully to "no known
    # preferences" rather than failing the whole recommendation request.
    return []


def get_user_itineraries(token: str) -> List[Dict[str, Any]]:
    """Ask Itinerary Service for this user's past trips, to derive taste
    signals (tags of places they've already visited)."""
    try:
        r = httpx.get(
            f"{ITINERARY_SERVICE_URL}/itineraries",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5.0,
        )
        if r.status_code == 200:
            return r.json().get("results", [])
    except httpx.RequestError:
        pass
    return []


def notify_mention(token: str, user_id: str, context: str, preview: str) -> None:
    """Tell User Service to create a "you were mentioned" notification -
    called when someone @-mentions another user in a destination review or
    reply. Same token-propagation pattern as the two functions above."""
    try:
        httpx.post(
            f"{USER_SERVICE_URL}/notifications/mention",
            headers={"Authorization": f"Bearer {token}"},
            json={"user_id": user_id, "context": context, "preview": preview},
            timeout=5.0,
        )
    except httpx.RequestError:
        # Non-critical: the review/reply itself already saved successfully.
        pass
