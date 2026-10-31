"""Batched analytics validation and AdMob SSV signature handling."""

from __future__ import annotations

import time
import uuid

from app.ssv import sign


async def test_events_batch_is_accepted_and_attached(client, guest):
    player = await guest("Analyst")
    response = await client.post(
        "/v1/events",
        json={
            "events": [
                {"name": "app_open", "props": {"version": "0.8.0"}, "client_ts": 1761800000},
                {"name": "run_start", "props": {"wave": 1}},
                {"name": "screen_view", "props": {"screen": "menu", "flag": True}},
            ]
        },
        headers=player["headers"],
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["accepted"] == 3
    assert body["dropped"] == 0


async def test_events_batch_limits_and_validation(client, guest):
    player = await guest("Spammer")
    too_many = [{"name": "wave_cleared", "props": {"wave": index}} for index in range(101)]
    response = await client.post(
        "/v1/events", json={"events": too_many}, headers=player["headers"]
    )
    assert response.status_code == 422
    assert response.json()["detail"]["code"] == "batch_too_large"

    empty = await client.post("/v1/events", json={"events": []}, headers=player["headers"])
    assert empty.status_code == 422
    assert empty.json()["detail"]["code"] == "empty_batch"

    bad_name = await client.post(
        "/v1/events",
        json={"events": [{"name": "BadName", "props": {}}]},
        headers=player["headers"],
    )
    assert bad_name.status_code == 422
    assert bad_name.json()["detail"]["code"] == "invalid_event_name"

    nested = await client.post(
        "/v1/events",
        json={"events": [{"name": "run_end", "props": {"nested": {"a": 1}}}]},
        headers=player["headers"],
    )
    assert nested.status_code == 422
    assert nested.json()["detail"]["code"] == "invalid_props"


async def test_ssv_callback_is_signed_and_idempotent(client):
    transaction_id = f"txn-{uuid.uuid4()}"
    timestamp = str(int(time.time()))
    user_id = str(uuid.uuid4())
    custom_data = "free_cash"
    reward_amount = "150"
    signature = sign(
        "test-ssv-secret", transaction_id, user_id, custom_data, reward_amount, timestamp
    )
    params = {
        "transaction_id": transaction_id,
        "signature": signature,
        "user_id": user_id,
        "custom_data": custom_data,
        "reward_amount": reward_amount,
        "reward_item": "cash",
        "timestamp": timestamp,
        "ad_unit": "test-rewarded",
        "ad_network": "test",
        "key_id": "1",
    }
    first = await client.post("/v1/ads/ssv", params=params)
    assert first.status_code == 200, first.text
    assert first.json()["ok"] is True
    assert first.json()["duplicate"] is False

    duplicate = await client.post("/v1/ads/ssv", params=params)
    assert duplicate.status_code == 200
    assert duplicate.json()["duplicate"] is True

    bad = await client.post("/v1/ads/ssv", params={**params, "signature": "deadbeef"})
    assert bad.status_code == 403
    assert bad.json()["detail"]["code"] == "invalid_signature"

    stale_timestamp = str(int(time.time()) - 10_000)
    stale_signature = sign(
        "test-ssv-secret",
        transaction_id + "-stale",
        user_id,
        custom_data,
        reward_amount,
        stale_timestamp,
    )
    stale = await client.post(
        "/v1/ads/ssv",
        params={
            **params,
            "transaction_id": transaction_id + "-stale",
            "signature": stale_signature,
            "timestamp": stale_timestamp,
        },
    )
    assert stale.status_code == 403
    assert stale.json()["detail"]["code"] == "stale_callback"

    missing = await client.post("/v1/ads/ssv", params={"transaction_id": transaction_id})
    assert missing.status_code == 422
    assert missing.json()["detail"]["code"] == "missing_ssv_parameters"
