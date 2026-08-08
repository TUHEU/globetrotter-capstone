"""Tests for the direct-messaging feature: send/receive, inbox, unread
counts, and the "must follow or be followed" access rule.
"""
import pytest


@pytest.fixture
def second_user(client):
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
    }


def test_cannot_message_a_stranger(client, registered_user, second_user):
    res = client.post(f"/messages/{second_user['user_id']}", json={"text": "hi"},
                       headers=registered_user["headers"])
    assert res.status_code == 403


def test_can_message_after_following(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    res = client.post(f"/messages/{second_user['user_id']}", json={"text": "Salut !"},
                       headers=registered_user["headers"])
    assert res.status_code == 201
    assert res.json()["text"] == "Salut !"


def test_recipient_can_reply_without_following_back(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    client.post(f"/messages/{second_user['user_id']}", json={"text": "Salut !"},
                headers=registered_user["headers"])
    # second_user ne suit PAS registered_user, mais peut quand même répondre
    # puisque registered_user le suit (relation dans un sens = accès aux deux).
    res = client.post(f"/messages/{registered_user['user_id']}", json={"text": "Salut toi !"},
                       headers=second_user["headers"])
    assert res.status_code == 201


def test_conversation_returns_messages_in_order(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    client.post(f"/messages/{second_user['user_id']}", json={"text": "un"},
                headers=registered_user["headers"])
    client.post(f"/messages/{registered_user['user_id']}", json={"text": "deux"},
                headers=second_user["headers"])
    client.post(f"/messages/{second_user['user_id']}", json={"text": "trois"},
                headers=registered_user["headers"])

    res = client.get(f"/messages/{second_user['user_id']}", headers=registered_user["headers"])
    assert res.status_code == 200
    texts = [m["text"] for m in res.json()["messages"]]
    assert texts == ["un", "deux", "trois"]


def test_opening_conversation_marks_messages_read(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    client.post(f"/messages/{registered_user['user_id']}", json={"text": "hey"},
                headers=second_user["headers"])

    inbox_before = client.get("/messages/inbox", headers=registered_user["headers"]).json()
    assert inbox_before["results"][0]["unread_count"] == 1

    client.get(f"/messages/{second_user['user_id']}", headers=registered_user["headers"])

    inbox_after = client.get("/messages/inbox", headers=registered_user["headers"]).json()
    assert inbox_after["results"][0]["unread_count"] == 0


def test_inbox_shows_last_message_and_partner_name(client, registered_user, second_user):
    client.post(f"/follow/{second_user['user_id']}", headers=registered_user["headers"])
    client.post(f"/messages/{second_user['user_id']}", json={"text": "premier"},
                headers=registered_user["headers"])
    client.post(f"/messages/{second_user['user_id']}", json={"text": "dernier"},
                headers=registered_user["headers"])

    res = client.get("/messages/inbox", headers=registered_user["headers"])
    entry = res.json()["results"][0]
    assert entry["partner_name"] == "Bob Traveler"
    assert entry["last_message"]["text"] == "dernier"


def test_cannot_message_self(client, registered_user):
    res = client.post(f"/messages/{registered_user['user_id']}", json={"text": "hi"},
                       headers=registered_user["headers"])
    assert res.status_code == 400
