"""Tests for the social feature: search users, follow/unfollow, list
followers/following. Mirrors the style of test_reviews_and_favorites.py.
"""
import pytest


@pytest.fixture
def second_user(client):
    """A second account to follow/search for, distinct from `registered_user`."""
    res = client.post("/register", json={
        "full_name": "Bob Traveler",
        "email": "bob@example.com",
        "password": "password123",
        "preferences": ["nature"],
    })
    assert res.status_code == 201, res.text
    data = res.json()
    return {
        "headers": {"Authorization": f"Bearer {data['access_token']}"},
        "user_id": data["user"]["id"],
        "email": "bob@example.com",
    }


def test_search_users_requires_auth(client):
    res = client.get("/users/search", params={"q": "bob"})
    assert res.status_code == 401


def test_search_users_finds_by_name(client, registered_user, second_user):
    res = client.get("/users/search", params={"q": "Bob"}, headers=registered_user["headers"])
    assert res.status_code == 200
    names = [u["full_name"] for u in res.json()["results"]]
    assert "Bob Traveler" in names


def test_search_users_excludes_self(client, registered_user):
    res = client.get("/users/search", params={"q": "Test"}, headers=registered_user["headers"])
    assert res.status_code == 200
    ids = [u["id"] for u in res.json()["results"]]
    assert registered_user["user_id"] not in ids


def test_search_users_empty_query_returns_nothing(client, registered_user, second_user):
    res = client.get("/users/search", params={"q": ""}, headers=registered_user["headers"])
    assert res.status_code == 200
    assert res.json()["results"] == []


def test_follow_then_appears_in_following(client, registered_user, second_user):
    res = client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    assert res.status_code == 201

    res = client.get("/follow/following", headers=registered_user["headers"])
    assert res.status_code == 200
    ids = [u["id"] for u in res.json()["results"]]
    assert second_user["user_id"] in ids


def test_followed_user_sees_follower(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])

    res = client.get("/follow/followers", headers=second_user["headers"])
    assert res.status_code == 200
    ids = [u["id"] for u in res.json()["results"]]
    assert registered_user["user_id"] in ids


def test_unfollow_removes_relationship(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    res = client.delete(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    assert res.status_code == 200
    assert second_user["user_id"] not in res.json()["following_ids"]


def test_cannot_follow_self(client, registered_user):
    res = client.post(f"/follow/{registered_user['user_id']}", headers=registered_user["headers"])
    assert res.status_code == 400


def test_cannot_follow_unknown_user(client, registered_user):
    res = client.post("/follow/does-not-exist", headers=registered_user["headers"])
    assert res.status_code == 404


def test_follow_status_reflects_current_state(client, registered_user, second_user):
    res = client.get(f"/follow/status/{second_user['user_id']}", headers=registered_user["headers"])
    assert res.json()["is_following"] is False

    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    res = client.get(f"/follow/status/{second_user['user_id']}", headers=registered_user["headers"])
    assert res.json()["is_following"] is True


def test_discover_excludes_self_and_already_followed(client, registered_user, second_user):
    res = client.get("/users/discover", headers=registered_user["headers"])
    assert res.status_code == 200
    ids = [u["id"] for u in res.json()["results"]]
    assert registered_user["user_id"] not in ids
    assert second_user["user_id"] in ids

    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    res = client.get("/users/discover", headers=registered_user["headers"])
    ids = [u["id"] for u in res.json()["results"]]
    assert second_user["user_id"] not in ids
