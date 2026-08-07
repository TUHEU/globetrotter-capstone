"""Tests des destinations, avis de destination, et lieux à proximité."""


def test_list_destinations(client):
    res = client.get("/destinations")
    assert res.status_code == 200
    data = res.json()
    assert data["count"] == 3
    # Triées par popularité décroissante.
    assert data["results"][0]["id"] == "t001"


def test_search_by_free_text(client):
    res = client.get("/destinations", params={"q": "café"})
    assert res.json()["count"] == 1
    assert res.json()["results"][0]["id"] == "t002"


def test_filter_by_category(client):
    res = client.get("/destinations", params={"category": "museum"})
    assert res.json()["count"] == 1
    assert res.json()["results"][0]["id"] == "t003"


def test_get_single_destination(client):
    res = client.get("/destinations/t001")
    assert res.status_code == 200
    assert res.json()["name"] == "Test Monument"


def test_get_unknown_destination_404s(client):
    res = client.get("/destinations/does-not-exist")
    assert res.status_code == 404


def test_categories_endpoint_lists_all_known_categories(client):
    res = client.get("/categories")
    assert res.status_code == 200
    cats = res.json()["results"]
    for expected in ["attraction", "museum", "education", "sports", "supermarket", "administrative"]:
        assert expected in cats


# ---------------- Avis sur une destination ----------------

def test_destination_review_requires_auth(client):
    res = client.post("/destinations/t001/reviews", json={"rating": 5, "comment": "Top"})
    assert res.status_code == 401


def test_submit_and_read_destination_review(client, auth_headers):
    res = client.post("/destinations/t001/reviews", json={"rating": 4, "comment": "Sympa"},
                       headers=auth_headers)
    assert res.status_code == 201

    res = client.get("/destinations/t001/reviews")
    assert res.status_code == 200
    data = res.json()
    assert data["summary"]["count"] == 1
    assert data["summary"]["average_rating"] == 4.0
    assert data["results"][0]["comment"] == "Sympa"


def test_review_on_unknown_destination_404s(client, auth_headers):
    res = client.post("/destinations/nope/reviews", json={"rating": 5, "comment": ""},
                       headers=auth_headers)
    assert res.status_code == 404


# ---------------- Lieux à proximité (haversine) ----------------

def test_nearby_excludes_far_destination(client):
    """t001 et t002 sont à Yaoundé centre (proches) ; t003 est délibérément
    loin (>3km) dans le jeu de données de test - il ne doit PAS apparaître."""
    res = client.get("/destinations/t001/nearby")
    assert res.status_code == 200
    data = res.json()
    ids = [d["id"] for d in data["results"]]
    assert "t002" in ids
    assert "t003" not in ids
    assert "distance_km" in data["results"][0]


def test_nearby_respects_max_km_override(client):
    res = client.get("/destinations/t001/nearby", params={"max_km": 500})
    ids = [d["id"] for d in res.json()["results"]]
    assert "t003" in ids  # avec un rayon élargi, il devient inclus


def test_distance_from_arbitrary_point(client):
    res = client.get("/destinations/t001/distance", params={"lat": 3.8667, "lng": 11.5167})
    assert res.status_code == 200
    # Même point que t001 -> distance ~0
    assert res.json()["distance_km"] < 0.01
