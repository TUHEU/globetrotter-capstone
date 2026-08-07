"""Tests des avis sur l'application (reviews) et des favoris (favorites)."""


def test_submit_review_requires_auth(client):
    res = client.post("/reviews", json={"rating": 5, "comment": "Top"})
    assert res.status_code == 401


def test_submit_and_list_review(client, registered_user):
    res = client.post("/reviews", json={"rating": 5, "comment": "Génial !"},
                       headers=registered_user["headers"])
    assert res.status_code == 201

    res = client.get("/reviews")
    assert res.status_code == 200
    data = res.json()
    assert data["count"] == 1
    assert data["results"][0]["rating"] == 5
    assert data["results"][0]["comment"] == "Génial !"


def test_resubmitting_review_updates_instead_of_duplicating(client, registered_user):
    """Un utilisateur ne doit avoir qu'UN SEUL avis - un second envoi
    remplace le premier plutôt que d'en empiler un deuxième."""
    client.post("/reviews", json={"rating": 3, "comment": "Moyen"},
                headers=registered_user["headers"])
    client.post("/reviews", json={"rating": 5, "comment": "En fait, super"},
                headers=registered_user["headers"])

    data = client.get("/reviews").json()
    assert data["count"] == 1
    assert data["results"][0]["rating"] == 5


def test_review_summary_averages_correctly(client, registered_user):
    client.post("/reviews", json={"rating": 4, "comment": ""},
                headers=registered_user["headers"])
    summary = client.get("/reviews/summary").json()
    assert summary["count"] == 1
    assert summary["average_rating"] == 4.0


def test_rating_out_of_range_is_rejected(client, registered_user):
    res = client.post("/reviews", json={"rating": 7, "comment": "trop"},
                       headers=registered_user["headers"])
    assert res.status_code == 422


def test_favorites_start_empty(client, registered_user):
    res = client.get("/favorites", headers=registered_user["headers"])
    assert res.status_code == 200
    assert res.json()["destination_ids"] == []


def test_add_and_remove_favorite(client, registered_user):
    headers = registered_user["headers"]
    res = client.post("/favorites/y001", headers=headers)
    assert res.status_code == 201
    assert "y001" in res.json()["destination_ids"]

    res = client.get("/favorites", headers=headers)
    assert res.json()["destination_ids"] == ["y001"]

    res = client.delete("/favorites/y001", headers=headers)
    assert res.status_code == 200
    assert res.json()["destination_ids"] == []


def test_favorites_are_isolated_per_user(client, registered_user):
    client.post("/favorites/y001", headers=registered_user["headers"])

    other = client.post("/register", json={
        "full_name": "Bob", "email": "bob@example.com",
        "password": "password123", "preferences": [],
    }).json()
    other_headers = {"Authorization": f"Bearer {other['access_token']}"}

    res = client.get("/favorites", headers=other_headers)
    assert res.json()["destination_ids"] == []
