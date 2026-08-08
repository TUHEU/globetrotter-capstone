"""Tests du routage de l'API Gateway.

Ces tests n'ont besoin d'AUCUN service réel derrière - resolve_target() est
une fonction pure qui décide juste "quel service possède ce chemin ?",
et BLOCKED_PATTERNS est vérifiable sans réseau non plus.
"""
import pytest
from fastapi import HTTPException

from app.proxy import resolve_target, BLOCKED_PATTERNS
from app.config import USER_SERVICE_URL, ITINERARY_SERVICE_URL, RECOMMENDATION_SERVICE_URL, AI_SERVICE_URL


@pytest.mark.parametrize("path,expected", [
    ("/login", USER_SERVICE_URL),
    ("/register", USER_SERVICE_URL),
    ("/me", USER_SERVICE_URL),
    ("/auth/google", USER_SERVICE_URL),
    ("/reviews", USER_SERVICE_URL),
    ("/reviews/summary", USER_SERVICE_URL),
    ("/favorites", USER_SERVICE_URL),
    ("/favorites/y001", USER_SERVICE_URL),
    ("/users/search", USER_SERVICE_URL),
    ("/follow/abc123", USER_SERVICE_URL),
    ("/follow/following", USER_SERVICE_URL),
    ("/follow/followers", USER_SERVICE_URL),
    ("/messages/inbox", USER_SERVICE_URL),
    ("/messages/abc123", USER_SERVICE_URL),
    ("/itineraries", ITINERARY_SERVICE_URL),
    ("/itineraries/abc123", ITINERARY_SERVICE_URL),
    ("/itineraries/feed", ITINERARY_SERVICE_URL),
    ("/itineraries/public/user-1", ITINERARY_SERVICE_URL),
    ("/destinations", RECOMMENDATION_SERVICE_URL),
    ("/destinations/y001", RECOMMENDATION_SERVICE_URL),
    ("/destinations/y001/reviews", RECOMMENDATION_SERVICE_URL),
    ("/destinations/y001/nearby", RECOMMENDATION_SERVICE_URL),
    ("/categories", RECOMMENDATION_SERVICE_URL),
    ("/assistant/chat", AI_SERVICE_URL),
])
def test_routes_to_correct_service(path, expected):
    assert resolve_target(path) == expected


def test_unknown_path_raises_404():
    with pytest.raises(HTTPException) as exc:
        resolve_target("/this-route-does-not-exist")
    assert exc.value.status_code == 404


def test_visit_endpoint_is_blocked_from_public_forwarding():
    """POST /destinations/{id}/visit est un appel INTERNE (service à
    service, utilisé par itinerary-service) - jamais censé être appelable
    directement depuis l'extérieur via la Gateway."""
    assert any(p.match("/destinations/y001/visit") for p in BLOCKED_PATTERNS)


def test_visit_pattern_does_not_accidentally_block_similar_paths():
    # Vérifie que le pattern est assez précis pour ne pas bloquer par erreur
    # des chemins qui se ressemblent mais sont légitimes.
    assert not any(p.match("/destinations/y001/reviews") for p in BLOCKED_PATTERNS)
    assert not any(p.match("/destinations/y001") for p in BLOCKED_PATTERNS)
