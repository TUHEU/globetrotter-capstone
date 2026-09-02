"""Fixtures partagées pour les tests de user-service.

Le principe : on redirige TOUS les fichiers de données (USERS_FILE,
REVIEWS_FILE, FAVORITES_FILE) vers un dossier temporaire propre à chaque
test, pour ne JAMAIS toucher aux vraies données de production pendant les
tests - un test qui écrirait dans data/users.json serait un vrai danger.
"""
import pytest
from fastapi.testclient import TestClient

from app import storage


@pytest.fixture(autouse=True)
def isolated_data(tmp_path, monkeypatch):
    monkeypatch.setattr(storage, "USERS_FILE", tmp_path / "users.json")
    monkeypatch.setattr(storage, "REVIEWS_FILE", tmp_path / "reviews.json")
    monkeypatch.setattr(storage, "FAVORITES_FILE", tmp_path / "favorites.json")
    monkeypatch.setattr(storage, "FOLLOWS_FILE", tmp_path / "follows.json")
    monkeypatch.setattr(storage, "MESSAGES_FILE", tmp_path / "messages.json")
    monkeypatch.setattr(storage, "LOGIN_EVENTS_FILE", tmp_path / "login_events.json")
    monkeypatch.setattr(storage, "DATA_DIR", tmp_path)
    yield


@pytest.fixture
def client():
    from main import app
    return TestClient(app)


@pytest.fixture
def registered_user(client):
    """Crée un compte de test et renvoie (headers_auth, user_id, email)."""
    res = client.post("/register", json={
        "full_name": "Test User",
        "email": "test@example.com",
        "password": "password123",
        "preferences": ["food", "culture"],
    })
    assert res.status_code == 201, res.text
    data = res.json()
    token = data["access_token"]
    return {
        "headers": {"Authorization": f"Bearer {token}"},
        "user_id": data["user"]["id"],
        "email": "test@example.com",
    }
