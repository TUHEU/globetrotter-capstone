"""Tests des itinéraires : création, lecture, mise à jour, suppression,
règles de propriété et de partage."""


def _create(client, headers, **overrides):
    body = {
        "title": "Week-end découverte",
        "description": "Un peu de tout",
        "start_date": "2026-09-01",
        "end_date": "2026-09-02",
        "stops": [{"destination_id": "t001", "day": 1, "notes": None}],
        "shared_with": [],
    }
    body.update(overrides)
    return client.post("/itineraries", json=body, headers=headers)


def test_create_itinerary(client, auth_headers):
    res = _create(client, auth_headers)
    assert res.status_code == 201
    data = res.json()
    assert data["title"] == "Week-end découverte"
    assert data["owner_name"] == "Test User"
    assert len(data["stops"]) == 1


def test_create_rejects_unknown_destination(client, auth_headers):
    res = _create(client, auth_headers,
                   stops=[{"destination_id": "does-not-exist", "day": 1, "notes": None}])
    assert res.status_code == 400


def test_create_requires_auth(client):
    res = _create(client, {})
    assert res.status_code == 401


def test_list_only_shows_my_itineraries(client, auth_headers, other_auth_headers):
    _create(client, auth_headers)
    _create(client, other_auth_headers, title="Sortie de l'autre utilisateur")

    mine = client.get("/itineraries", headers=auth_headers).json()
    assert mine["count"] == 1
    assert mine["results"][0]["title"] == "Week-end découverte"


def test_get_single_itinerary_owner_can_view(client, auth_headers):
    created = _create(client, auth_headers).json()
    res = client.get(f"/itineraries/{created['id']}", headers=auth_headers)
    assert res.status_code == 200


def test_get_single_itinerary_stranger_forbidden(client, auth_headers, other_auth_headers):
    created = _create(client, auth_headers).json()
    res = client.get(f"/itineraries/{created['id']}", headers=other_auth_headers)
    assert res.status_code == 403


def test_shared_user_can_view_via_email(client, auth_headers, other_auth_headers):
    created = _create(client, auth_headers, shared_with=["other@example.com"]).json()
    res = client.get(f"/itineraries/{created['id']}", headers=other_auth_headers)
    assert res.status_code == 200


def test_update_only_by_owner(client, auth_headers, other_auth_headers):
    created = _create(client, auth_headers).json()

    res = client.put(f"/itineraries/{created['id']}", json={"title": "Nouveau titre"},
                      headers=other_auth_headers)
    assert res.status_code == 403

    res = client.put(f"/itineraries/{created['id']}", json={"title": "Nouveau titre"},
                      headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["title"] == "Nouveau titre"


def test_delete_only_by_owner(client, auth_headers, other_auth_headers):
    created = _create(client, auth_headers).json()

    res = client.delete(f"/itineraries/{created['id']}", headers=other_auth_headers)
    assert res.status_code == 403

    res = client.delete(f"/itineraries/{created['id']}", headers=auth_headers)
    assert res.status_code == 204

    res = client.get(f"/itineraries/{created['id']}", headers=auth_headers)
    assert res.status_code == 404


def test_get_unknown_itinerary_404s(client, auth_headers):
    res = client.get("/itineraries/does-not-exist", headers=auth_headers)
    assert res.status_code == 404
