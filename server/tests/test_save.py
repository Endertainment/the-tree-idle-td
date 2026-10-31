"""Cloud save: revision conflicts (409), idempotency and profile sync."""

from __future__ import annotations

import uuid


def _payload(level: int, nickname: str = "Tester") -> dict:
    return {
        "player": {"nickname": nickname, "avatar_id": "avatar_02", "level": level},
        "stats": {"best_wave": level, "runs_played": 1},
        "wallet": {"coins": 100, "gems": 5, "stones": 0},
    }


def _key() -> dict:
    return {"Idempotency-Key": str(uuid.uuid4())}


async def test_save_lifecycle_conflict_and_idempotency(client, guest):
    player = await guest("Saver")
    headers = player["headers"]

    empty = await client.get("/v1/save", headers=headers)
    assert empty.status_code == 404
    assert empty.json()["detail"]["code"] == "save_not_found"

    created = await client.put(
        "/v1/save", json={"revision": 0, "payload": _payload(2), "checksum": "sha256:abc"}, headers=headers
    )
    assert created.status_code == 200, created.text
    assert created.json()["revision"] == 1

    fetched = await client.get("/v1/save", headers=headers)
    assert fetched.status_code == 200
    assert fetched.json()["payload"] == _payload(2)
    assert fetched.json()["revision"] == 1

    updated = await client.put(
        "/v1/save", json={"revision": 1, "payload": _payload(3)}, headers=headers
    )
    assert updated.status_code == 200
    assert updated.json()["revision"] == 2

    stale = await client.put(
        "/v1/save", json={"revision": 1, "payload": _payload(99)}, headers=headers
    )
    assert stale.status_code == 409
    detail = stale.json()["detail"]
    assert detail["code"] == "stale_revision"
    assert detail["server_revision"] == 2
    assert detail["server"]["payload"] == _payload(3)

    key_headers = {**headers, **_key()}
    body = {"revision": 2, "payload": _payload(4), "checksum": "sha256:def"}
    first = await client.put("/v1/save", json=body, headers=key_headers)
    assert first.status_code == 200
    assert first.json()["revision"] == 3

    replay = await client.put("/v1/save", json=body, headers=key_headers)
    assert replay.status_code == 200
    assert replay.json()["revision"] == 3

    after_replay = await client.get("/v1/save", headers=headers)
    assert after_replay.json()["revision"] == 3

    reused_key = await client.put(
        "/v1/save", json={"revision": 3, "payload": _payload(5)}, headers=key_headers
    )
    assert reused_key.status_code == 409
    assert reused_key.json()["detail"]["code"] == "idempotency_key_reused"


async def test_save_syncs_the_display_profile(client, guest):
    player = await guest("Leveler")
    headers = player["headers"]
    saved = await client.put(
        "/v1/save", json={"revision": 0, "payload": _payload(9, "Leveler")}, headers=headers
    )
    assert saved.status_code == 200
    profile = await client.get("/v1/profile", headers=headers)
    assert profile.status_code == 200
    data = profile.json()
    assert data["level"] == 9
    assert data["nickname"] == "Leveler"
    assert data["save_revision"] == 1
    assert data["wallet"]["coins"] == 100


async def test_revision_zero_when_server_has_no_save_is_required(client, guest):
    player = await guest("Fresh")
    headers = player["headers"]
    conflict = await client.put(
        "/v1/save", json={"revision": 5, "payload": _payload(1)}, headers=headers
    )
    assert conflict.status_code == 409
    detail = conflict.json()["detail"]
    assert detail["code"] == "save_missing"
    assert detail["server_revision"] == 0
