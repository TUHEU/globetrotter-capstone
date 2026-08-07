"""Fixtures partagées pour recommendation-service.

On isole destinations.json, destination_reviews.json et
popularity_overrides.json vers un dossier temporaire, puis on y met un
petit jeu de données de test (3 destinations) - jamais les 36 vraies.
"""
import json
from jose import jwt
import pytest
from fastapi.testclient import TestClient

from app import storage
from app.config import SECRET_KEY, ALGORITHM

TEST_DESTINATIONS = [
    {
        "id": "t001", "name": "Test Monument", "quartier": "Centre-ville",
        "category": "attraction", "description": "Un monument de test.",
        "tags": ["history"], "image": "https://example.com/a.jpg",
        "avg_price_fcfa": 1000, "best_time": "Journée", "popularity": 50,
        "lat": 3.8667, "lng": 11.5167,
    },
    {
        "id": "t002", "name": "Test Café", "quartier": "Bastos",
        "category": "cafe", "description": "Un café de test.",
        "tags": ["food"], "image": "https://example.com/b.jpg",
        "avg_price_fcfa": 2000, "best_time": "Matin", "popularity": 30,
        "lat": 3.8880, "lng": 11.5195,
    },
    {
        "id": "t003", "name": "Test Musée", "quartier": "Nlongkak",
        "category": "museum", "description": "Un musée de test, loin des 2 autres.",
        "tags": ["art"], "image": "https://example.com/c.jpg",
        "avg_price_fcfa": 500, "best_time": "Après-midi", "popularity": 20,
        "lat": 3.95, "lng": 11.60,  # volontairement loin (> 3km) pour tester "nearby"
    },
]


@pytest.fixture(autouse=True)
def isolated_data(tmp_path, monkeypatch):
    dest_file = tmp_path / "destinations.json"
    dest_file.write_text(json.dumps(TEST_DESTINATIONS), encoding="utf-8")

    monkeypatch.setattr(storage, "DESTINATIONS_FILE", dest_file)
    monkeypatch.setattr(storage, "DESTINATION_REVIEWS_FILE", tmp_path / "destination_reviews.json")
    monkeypatch.setattr(storage, "POPULARITY_FILE", tmp_path / "popularity_overrides.json")
    monkeypatch.setattr(storage, "DATA_DIR", tmp_path)
    yield


@pytest.fixture
def client():
    from main import app
    return TestClient(app)


@pytest.fixture
def auth_headers():
    """Un JWT valide, sans passer par user-service (pas besoin pour ces
    tests) - juste un token que ce service saura vérifier lui-même."""
    token = jwt.encode(
        {"sub": "test-user-id", "full_name": "Test User", "email": "test@example.com"},
        SECRET_KEY, algorithm=ALGORITHM,
    )
    return {"Authorization": f"Bearer {token}"}
