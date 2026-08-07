"""Vérifie le correctif de popularité : /visit ne doit JAMAIS modifier
destinations.json directement (sinon ça recrée le conflit git qu'on a eu
sur le VPS) - seulement popularity_overrides.json."""


def test_visit_increments_popularity_without_touching_destinations_file(client):
    original = client.get("/destinations/t001").json()["popularity"]

    res = client.post("/destinations/t001/visit")
    assert res.status_code == 204

    updated = client.get("/destinations/t001").json()["popularity"]
    assert updated == original + 1


def test_visit_on_unknown_destination_404s(client):
    res = client.post("/destinations/nope/visit")
    assert res.status_code == 404


def test_multiple_visits_accumulate(client):
    for _ in range(3):
        client.post("/destinations/t002/visit")
    assert client.get("/destinations/t002").json()["popularity"] == 30 + 3
