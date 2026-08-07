"""Tests de ai-service.

IMPORTANT : ces tests ne font JAMAIS de vrai appel à Gemini ou OpenRouter -
tout est mocké. On ne veut pas dépendre d'une clé API valide (ni gaspiller
de quota) juste pour lancer la suite de tests.
"""
from unittest.mock import patch

import pytest
from fastapi.testclient import TestClient

from app.routers.assistant import _build_system_instruction
from app.gemini_client import GeminiError
from app.openrouter_client import OpenRouterError
from app.security import get_current_user, get_raw_token


FAKE_USER = {"id": "u1", "full_name": "Test User", "email": "t@example.com"}


@pytest.fixture
def client():
    from main import app
    # Dependency override officielle de FastAPI : on remplace la vérification
    # JWT par un utilisateur factice, pour tester la LOGIQUE du endpoint sans
    # avoir besoin d'un vrai token signé dans ces tests.
    app.dependency_overrides[get_current_user] = lambda: FAKE_USER
    app.dependency_overrides[get_raw_token] = lambda: "fake-token"
    yield TestClient(app)
    app.dependency_overrides.clear()


def test_health_endpoint(client):
    res = client.get("/health")
    assert res.status_code == 200
    assert res.json()["status"] == "ok"


def test_assistant_health_endpoint(client):
    res = client.get("/assistant/health")
    assert res.status_code == 200
    assert res.json()["service"] == "ai-service"


class TestSystemInstructionBuilder:
    """Le prompt système est ce qui empêche l'IA d'halluciner des lieux qui
    n'existent pas dans l'app - ces tests vérifient qu'il contient bien
    toutes les vraies données qu'on lui donne."""

    def test_includes_user_name(self):
        instruction = _build_system_instruction(
            {"full_name": "Fahdil"}, destinations=[], itineraries=[])
        assert "Fahdil" in instruction

    def test_includes_real_destination_names_not_generic_placeholder(self):
        destinations = [{
            "name": "Mont Fébé", "category": "nature", "quartier": "Fébé",
            "avg_price_fcfa": 0, "description": "Un point de vue.",
        }]
        instruction = _build_system_instruction(
            {"full_name": "Test"}, destinations=destinations, itineraries=[])
        assert "Mont Fébé" in instruction
        assert "Fébé" in instruction

    def test_handles_no_destinations_gracefully(self):
        instruction = _build_system_instruction(
            {"full_name": "Test"}, destinations=[], itineraries=[])
        assert "aucune donnée" in instruction.lower()

    def test_includes_user_itinerary_titles(self):
        itineraries = [{"title": "Week-end culture", "stops": [{"destination_id": "y001"}]}]
        instruction = _build_system_instruction(
            {"full_name": "Test"}, destinations=[], itineraries=itineraries)
        assert "Week-end culture" in instruction

    def test_instructs_model_to_stay_on_topic(self):
        """Le prompt doit explicitement dire à l'IA de ne pas halluciner
        de lieux et de rester sur Yaoundé - c'est la garde-fou principale."""
        instruction = _build_system_instruction(
            {"full_name": "Test"}, destinations=[], itineraries=[])
        assert "Yaoundé" in instruction
        assert "invente" in instruction.lower() or "n'existe" in instruction.lower()


class TestGeminiOpenRouterFallback:
    """Vérifie que le repli silencieux fonctionne : si Gemini échoue,
    OpenRouter prend le relai automatiquement, sans que l'appelant ne
    voie de différence dans la réponse."""

    def test_falls_back_to_openrouter_when_gemini_fails(self, client):
        with patch("app.routers.assistant.ask_gemini", side_effect=GeminiError("403 simulé")), \
             patch("app.routers.assistant.ask_openrouter", return_value="Réponse de secours") as mock_or, \
             patch("app.routers.assistant.clients.get_top_destinations", return_value=[]), \
             patch("app.routers.assistant.clients.get_user_itineraries", return_value=[]):
            res = client.post("/assistant/chat", json={"message": "Bonjour", "history": []})

        assert res.status_code == 200
        assert res.json()["reply"] == "Réponse de secours"
        assert mock_or.called

    def test_returns_502_when_both_providers_fail(self, client):
        with patch("app.routers.assistant.ask_gemini", side_effect=GeminiError("Gemini down")), \
             patch("app.routers.assistant.ask_openrouter", side_effect=OpenRouterError("OpenRouter down too")), \
             patch("app.routers.assistant.clients.get_top_destinations", return_value=[]), \
             patch("app.routers.assistant.clients.get_user_itineraries", return_value=[]):
            res = client.post("/assistant/chat", json={"message": "Bonjour", "history": []})

        assert res.status_code == 502

    def test_uses_gemini_directly_when_it_succeeds(self, client):
        with patch("app.routers.assistant.ask_gemini", return_value="Réponse de Gemini") as mock_gemini, \
             patch("app.routers.assistant.ask_openrouter") as mock_or, \
             patch("app.routers.assistant.clients.get_top_destinations", return_value=[]), \
             patch("app.routers.assistant.clients.get_user_itineraries", return_value=[]):
            res = client.post("/assistant/chat", json={"message": "Bonjour", "history": []})

        assert res.status_code == 200
        assert res.json()["reply"] == "Réponse de Gemini"
        assert mock_gemini.called
        assert not mock_or.called  # le repli ne doit PAS être appelé si Gemini marche
