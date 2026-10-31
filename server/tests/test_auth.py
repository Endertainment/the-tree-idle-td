"""Guest auth, access tokens and refresh rotation."""

from __future__ import annotations

import uuid


async def test_guest_login_and_profile(client):
    device_id = f"device-{uuid.uuid4()}"
    response = await client.post(
        "/v1/auth/guest",
        json={"device_id": device_id, "nickname": "  Elandra ", "avatar_id": "avatar_03"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["is_new"] is True
    assert body["token_type"] == "bearer"
    assert body["expires_in"] == 900
    assert body["refresh_expires_in"] == 2_592_000
    assert body["nickname"] == "Elandra"
    assert len(body["access_token"].split(".")) == 3

    profile = await client.get(
        "/v1/profile", headers={"Authorization": f"Bearer {body['access_token']}"}
    )
    assert profile.status_code == 200, profile.text
    data = profile.json()
    assert data["player_id"] == body["player_id"]
    assert data["nickname"] == "Elandra"
    assert data["save_revision"] == 0
    assert data["wallet"] == {"coins": 0, "gems": 0, "stones": 0}


async def test_same_device_returns_same_player(client):
    device_id = f"device-{uuid.uuid4()}"
    first = await client.post("/v1/auth/guest", json={"device_id": device_id, "nickname": "Ash"})
    second = await client.post("/v1/auth/guest", json={"device_id": device_id, "nickname": "Ash"})
    assert first.status_code == 200 and second.status_code == 200
    assert first.json()["player_id"] == second.json()["player_id"]
    assert first.json()["is_new"] is True
    assert second.json()["is_new"] is False


async def test_profile_requires_a_token(client):
    missing = await client.get("/v1/profile")
    assert missing.status_code == 401
    assert missing.json()["detail"]["code"] == "missing_token"
    invalid = await client.get("/v1/profile", headers={"Authorization": "Bearer not-a-jwt"})
    assert invalid.status_code == 401
    assert invalid.json()["detail"]["code"] == "malformed_token"


async def test_refresh_rotates_and_revokes_the_old_token(client):
    guest = await client.post(
        "/v1/auth/guest", json={"device_id": f"device-{uuid.uuid4()}", "nickname": "Rowan"}
    )
    tokens = guest.json()
    refreshed = await client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert refreshed.status_code == 200, refreshed.text
    rotated = refreshed.json()
    assert rotated["refresh_token"] != tokens["refresh_token"]
    assert rotated["player_id"] == tokens["player_id"]

    reused = await client.post("/v1/auth/refresh", json={"refresh_token": tokens["refresh_token"]})
    assert reused.status_code == 401
    assert reused.json()["detail"]["code"] == "refresh_revoked"

    # The rotated token still works and the new access token authenticates.
    again = await client.post("/v1/auth/refresh", json={"refresh_token": rotated["refresh_token"]})
    assert again.status_code == 200
    profile = await client.get(
        "/v1/profile", headers={"Authorization": f"Bearer {again.json()['access_token']}"}
    )
    assert profile.status_code == 200
