"""AI Service - outbound calls to other services, to ground the assistant's
answers in REAL data instead of letting Gemini invent Yaoundé places that
don't exist in our own database."""
from typing import Any, Dict, List

import httpx

from .config import RECOMMENDATION_SERVICE_URL, ITINERARY_SERVICE_URL


def get_top_destinations(limit: int = 20) -> List[Dict[str, Any]]:
    """Un échantillon des destinations les plus populaires - assez pour que
    Gemini ait de quoi recommander sans qu'on lui envoie les 26 en entier
    à chaque message (coût de tokens inutile)."""
    try:
        r = httpx.get(
            f"{RECOMMENDATION_SERVICE_URL}/destinations",
            params={"limit": limit},
            timeout=5.0,
        )
        if r.status_code == 200:
            return r.json().get("results", [])
    except httpx.RequestError:
        pass
    return []


def get_user_itineraries(token: str) -> List[Dict[str, Any]]:
    """Pour que l'assistant puisse dire des choses comme 'vu que vous avez déjà
    prévu le Monument dans votre sortie Week-end Culture, vous pourriez
    aussi...' plutôt que de recommander à l'aveugle."""
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
