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
import httpx

from .config import RECOMMENDATION_SERVICE_URL


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
