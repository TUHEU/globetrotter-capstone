"""Tests for the sharing/social layer on top of itineraries: is_public,
GET /itineraries/public/{owner_id}, and GET /itineraries/feed.
"""
from app import clients


def _create(client, headers, **overrides):
    body = {
        "title": "Week-end découverte",
        "description": "Un peu de tout",
        "start_date": "2026-09-01",
        "end_date": "2026-09-02",
        "stops": [{"destination_id": "t001", "day": 1, "notes": None}],
        "shared_with": [],
        "is_public": False,
    }
    body.update(overrides)
    return client.post("/itineraries", json=body, headers=headers)


def test_new_itinerary_is_private_by_default(client, auth_headers):
    created = _create(client, auth_headers).json()
    assert created["is_public"] is False


def test_public_itineraries_hidden_when_private(client, auth_headers, other_auth_headers):
    _create(client, auth_headers, title="Trip privé")
    res = client.get("/itineraries/public/user-1", headers=other_auth_headers)
    assert res.status_code == 200
    assert res.json()["count"] == 0


def test_public_itineraries_visible_to_anyone(client, auth_headers, other_auth_headers):
    _create(client, auth_headers, title="Trip public", is_public=True)
    res = client.get("/itineraries/public/user-1", headers=other_auth_headers)
    assert res.status_code == 200
    assert res.json()["count"] == 1
    assert res.json()["results"][0]["title"] == "Trip public"


def test_visibility_toggle_only_by_owner(client, auth_headers, other_auth_headers):
    created = _create(client, auth_headers).json()

    res = client.patch(f"/itineraries/{created['id']}/visibility", json={"is_public": True},
                        headers=other_auth_headers)
    assert res.status_code == 403

    res = client.patch(f"/itineraries/{created['id']}/visibility", json={"is_public": True},
                        headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["is_public"] is True


def test_feed_only_includes_public_trips_from_followed_users(client, auth_headers, other_auth_headers,
                                                               monkeypatch):
    # user-1 follows user-2 (mocked - no real call to User Service).
    monkeypatch.setattr(clients, "get_following", lambda token: ["user-2"])

    _create(client, other_auth_headers, title="Trip public de user-2", is_public=True)
    _create(client, other_auth_headers, title="Trip privé de user-2", is_public=False)

    res = client.get("/itineraries/feed", headers=auth_headers)
    assert res.status_code == 200
    titles = [i["title"] for i in res.json()["results"]]
    assert titles == ["Trip public de user-2"]


def test_feed_empty_when_following_nobody(client, auth_headers, other_auth_headers):
    _create(client, other_auth_headers, title="Trip public de user-2", is_public=True)
    res = client.get("/itineraries/feed", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["count"] == 0
