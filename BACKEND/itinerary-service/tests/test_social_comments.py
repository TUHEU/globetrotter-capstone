"""Tests for likes and comments on itineraries."""


def _create(client, headers, **overrides):
    body = {
        "title": "Week-end découverte",
        "stops": [{"destination_id": "t001", "day": 1, "notes": None}],
        "is_public": True,
    }
    body.update(overrides)
    return client.post("/itineraries", json=body, headers=headers).json()


def test_like_toggles_on_and_off(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers)

    res = client.post(f"/itineraries/{it['id']}/like", headers=other_auth_headers)
    assert res.status_code == 200
    assert res.json() == {"liked": True, "like_count": 1}

    res = client.post(f"/itineraries/{it['id']}/like", headers=other_auth_headers)
    assert res.json() == {"liked": False, "like_count": 0}


def test_like_count_reflected_in_itinerary_response(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers)
    client.post(f"/itineraries/{it['id']}/like", headers=other_auth_headers)

    res = client.get(f"/itineraries/{it['id']}", headers=auth_headers)
    body = res.json()
    assert body["like_count"] == 1
    # L'auteur n'a pas liké lui-même son propre post.
    assert body["liked_by_me"] is False

    res2 = client.get(f"/itineraries/{it['id']}", headers=other_auth_headers)
    assert res2.json()["liked_by_me"] is True


def test_cannot_like_private_itinerary_of_someone_else(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers, is_public=False)
    res = client.post(f"/itineraries/{it['id']}/like", headers=other_auth_headers)
    assert res.status_code == 403


def test_add_and_list_comments(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers)
    res = client.post(f"/itineraries/{it['id']}/comments", json={"text": "Superbe itinéraire !"},
                       headers=other_auth_headers)
    assert res.status_code == 201
    assert res.json()["user_name"] == "Other User"

    res = client.get(f"/itineraries/{it['id']}/comments", headers=auth_headers)
    assert res.status_code == 200
    assert res.json()["count"] == 1
    assert res.json()["results"][0]["text"] == "Superbe itinéraire !"


def test_comment_count_reflected_in_itinerary_response(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers)
    client.post(f"/itineraries/{it['id']}/comments", json={"text": "un"}, headers=other_auth_headers)
    client.post(f"/itineraries/{it['id']}/comments", json={"text": "deux"}, headers=auth_headers)

    res = client.get(f"/itineraries/{it['id']}", headers=auth_headers)
    assert res.json()["comment_count"] == 2


def test_cannot_comment_on_private_itinerary_of_someone_else(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers, is_public=False)
    res = client.post(f"/itineraries/{it['id']}/comments", json={"text": "hi"}, headers=other_auth_headers)
    assert res.status_code == 403


def test_only_author_can_delete_own_comment(client, auth_headers, other_auth_headers):
    it = _create(client, auth_headers)
    comment = client.post(f"/itineraries/{it['id']}/comments", json={"text": "un"},
                           headers=other_auth_headers).json()

    res = client.delete(f"/itineraries/{it['id']}/comments/{comment['id']}", headers=auth_headers)
    assert res.status_code == 403

    res = client.delete(f"/itineraries/{it['id']}/comments/{comment['id']}", headers=other_auth_headers)
    assert res.status_code == 204
