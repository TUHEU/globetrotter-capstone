"""
Itinerary Service - outbound calls to OTHER services.

This is the file that makes Phase 2 different from Phase 1: instead of
`storage.find_destination(...)`, we make a real HTTP call across the
network to whichever service owns that data. This is exactly the
"synchronous REST for request-response" pattern from the course slides,
and it's also where Phase 2's new failure modes live (network latency,
the other service being down, etc. — Phase 4 problems, but you'll feel
the seam here first).
"""
from typing import List

import httpx

from .config import RECOMMENDATION_SERVICE_URL, USER_SERVICE_URL


def destination_exists(destination_id: str) -> bool:
    try:
        r = httpx.get(
            f"{RECOMMENDATION_SERVICE_URL}/destinations/{destination_id}",
            timeout=5.0,
        )
        return r.status_code == 200
    except httpx.RequestError:
        # Recommendation Service is unreachable. In Phase 1 this couldn't
        # happen (one process, one file). In Phase 2 it's a real possibility
        # you must handle explicitly - we fail closed (reject the stop)
        # rather than silently accepting an unverified destination_id.
        return False


def bump_popularity(destination_id: str) -> None:
    try:
        httpx.post(
            f"{RECOMMENDATION_SERVICE_URL}/destinations/{destination_id}/visit",
            timeout=5.0,
        )
    except httpx.RequestError:
        # Non-critical: if this call fails, the itinerary is still created
        # successfully. We just log and move on rather than failing the
        # whole request over a "nice to have" popularity counter.
        pass


def get_following(token: str) -> List[str]:
    """Ask User Service who the caller follows, forwarding their own bearer
    token (same "token propagation" pattern as Recommendation Service ->
    User Service). Used to build GET /itineraries/feed: we never store a
    copy of the follow graph here - Itinerary Service still only owns
    itineraries.json, exactly like the README's service-split diagram says.
    """
    try:
        r = httpx.get(
            f"{USER_SERVICE_URL}/follow/following",
            headers={"Authorization": f"Bearer {token}"},
            timeout=5.0,
        )
        if r.status_code == 200:
            return [u["id"] for u in r.json().get("results", [])]
    except httpx.RequestError:
        pass
    # User Service down/unreachable: degrade to an empty feed rather than
    # failing the whole request.
    return []
