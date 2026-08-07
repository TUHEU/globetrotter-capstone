"""Tests d'authentification : register, login, /me.

Ce sont les tests les plus critiques du service - un bug ici bloque
littéralement tout le monde hors de l'app.
"""


def test_register_creates_account_and_returns_token(client):
    res = client.post("/register", json={
        "full_name": "Alice",
        "email": "alice@example.com",
        "password": "secret123",
        "preferences": ["nature", "food"],
    })
    assert res.status_code == 201
    data = res.json()
    assert data["access_token"]
    assert data["user"]["email"] == "alice@example.com"
    assert data["user"]["full_name"] == "Alice"
    # Le mot de passe ou son hash ne doivent JAMAIS revenir dans la réponse.
    assert "password" not in data["user"]
    assert "password_hash" not in data["user"]


def test_register_rejects_duplicate_email(client, registered_user):
    res = client.post("/register", json={
        "full_name": "Someone Else",
        "email": registered_user["email"],
        "password": "anotherpass",
        "preferences": [],
    })
    assert res.status_code == 409


def test_login_with_correct_password_succeeds(client, registered_user):
    res = client.post("/login", json={
        "email": registered_user["email"],
        "password": "password123",
    })
    assert res.status_code == 200
    assert res.json()["access_token"]


def test_login_with_wrong_password_fails(client, registered_user):
    res = client.post("/login", json={
        "email": registered_user["email"],
        "password": "wrong-password",
    })
    assert res.status_code == 401


def test_login_with_unknown_email_fails(client):
    res = client.post("/login", json={
        "email": "nobody@example.com",
        "password": "whatever123",
    })
    assert res.status_code == 401


def test_me_requires_valid_token(client):
    res = client.get("/me")
    assert res.status_code == 401


def test_me_returns_current_user(client, registered_user):
    res = client.get("/me", headers=registered_user["headers"])
    assert res.status_code == 200
    assert res.json()["email"] == registered_user["email"]
