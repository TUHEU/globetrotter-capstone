"""Chat Service - outbound call to User Service.

Same token-propagation pattern used everywhere else in this project
(Itinerary/Recommendation Service -> User Service): we forward the
tagging user's own bearer token rather than inventing a service-to-service
credential, since creating a "you were mentioned" notification doesn't
need any elevated permission beyond "I am an authenticated user".
"""
import httpx

from .config import USER_SERVICE_URL


def notify_mention(token: str, user_id: str, preview: str) -> None:
    try:
        httpx.post(
            f"{USER_SERVICE_URL}/notifications/mention",
            headers={"Authorization": f"Bearer {token}"},
            json={"user_id": user_id, "context": "Chat Global", "preview": preview},
            timeout=5.0,
        )
    except httpx.RequestError:
        # Non-critical: the message itself already sent successfully. A
        # missed mention notification shouldn't fail (or even slow down)
        # the chat for everyone else.
        pass
