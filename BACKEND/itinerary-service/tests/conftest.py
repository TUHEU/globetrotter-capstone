"""Fixtures pour itinerary-service.

On isole itineraries.json vers un dossier temporaire, ET on mocke
clients.destination_exists / clients.bump_popularity pour ne jamais faire
de vrai appel réseau vers recommendation-service pendant les tests.
"""
from jose import jwt
import pytest
from fastapi.testclient import TestClient

from app import storage, clients
from app.config import SECRET_KEY, ALGORITHM


@pytest.fixture(autouse=True)
def isolated_data(tmp_path, monkeypatch):
    monkeypatch.setattr(storage, "ITINERARIES_FILE", tmp_path / "itineraries.json")
    monkeypatch.setattr(storage, "COMMENTS_FILE", tmp_path / "comments.json")
    monkeypatch.setattr(storage, "LIKES_FILE", tmp_path / "likes.json")
    monkeypatch.setattr(storage, "DATA_DIR", tmp_path)
    # On simule que toute destination "t00x" existe (pas de vrai appel réseau
    # vers recommendation-service dans ces tests unitaires).
    monkeypatch.setattr(clients, "destination_exists", lambda dest_id: dest_id.startswith("t"))
    monkeypatch.setattr(clients, "bump_popularity", lambda dest_id: None)
    # Par défaut "ne suit personne" - les tests du fil d'amis remplacent ce
    # mock pour simuler une vraie réponse de User Service sans appel réseau.
    monkeypatch.setattr(clients, "get_following", lambda token: [])
    yield


@pytest.fixture
def client():
    from main import app
    return TestClient(app)


def _token(user_id, name="Test User", email="test@example.com"):
    return jwt.encode({"sub": user_id, "full_name": name, "email": email}, SECRET_KEY, algorithm=ALGORITHM)


@pytest.fixture
def auth_headers():
    return {"Authorization": f"Bearer {_token('user-1')}"}


@pytest.fixture
def other_auth_headers():
    return {"Authorization": f"Bearer {_token('user-2', 'Other User', 'other@example.com')}"}
