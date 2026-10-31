"""Remote config, health, purchases and URL normalisation."""

from __future__ import annotations

import ssl
import uuid

from app.config import deep_merge, prepare_database_url


async def test_config_requires_auth_and_returns_defaults(client, guest):
    anonymous = await client.get("/v1/config")
    assert anonymous.status_code == 401

    player = await guest("Config")
    response = await client.get("/v1/config", headers=player["headers"])
    assert response.status_code == 200, response.text
    body = response.json()
    assert body["version"] >= 1
    assert body["feature_flags"]["tournaments"] is True
    assert body["ad_frequency"]["interstitial_every_runs"] == 3
    assert body["shop_catalog_version"] == 1
    assert body["week_id"].startswith("20")
    assert body["week_resets_at"]
    assert body["tournament"]["cohort_size"] == 50


async def test_healthz_and_root(client):
    health = await client.get("/healthz")
    assert health.status_code == 200
    assert health.json()["status"] == "ok"
    assert health.json()["database"] == "sqlite"
    root = await client.get("/")
    assert root.status_code == 200
    assert root.json()["docs"] == "/docs"


async def test_purchase_verify_is_idempotent(client, guest):
    player = await guest("Buyer")
    token = f"stub-token-{uuid.uuid4()}"
    body = {"product_id": "thetree.gems_100", "purchase_token": token, "platform": "google"}
    first = await client.post("/v1/purchases/verify", json=body, headers=player["headers"])
    assert first.status_code == 200, first.text
    assert first.json()["status"] == "granted"
    assert first.json()["verified_by"] == "stub"

    second = await client.post("/v1/purchases/verify", json=body, headers=player["headers"])
    assert second.status_code == 200
    assert second.json()["status"] == "already_granted"
    assert second.json()["grant_id"] == first.json()["grant_id"]

    unknown = await client.post(
        "/v1/purchases/verify",
        json={"product_id": "thetree.unknown", "purchase_token": token + "-2"},
        headers=player["headers"],
    )
    assert unknown.status_code == 422

    other = await guest("OtherBuyer")
    conflict = await client.post("/v1/purchases/verify", json=body, headers=other["headers"])
    assert conflict.status_code == 409


def test_deep_merge_does_not_mutate_inputs():
    defaults = {"a": 1, "nested": {"x": 1, "y": 2}, "list": [1, 2]}
    override = {"nested": {"y": 9, "z": 3}, "list": [3]}
    merged = deep_merge(defaults, override)
    assert merged == {"a": 1, "nested": {"x": 1, "y": 9, "z": 3}, "list": [3]}
    assert defaults["nested"] == {"x": 1, "y": 2}
    assert defaults["list"] == [1, 2]


def test_database_url_normalisation():
    url, connect_args = prepare_database_url(
        "postgresql://user:pass@ep-1-pooler.eu-central-1.aws.neon.tech/thetree?ssl=require"
    )
    assert url == "postgresql+asyncpg://user:pass@ep-1-pooler.eu-central-1.aws.neon.tech/thetree"
    assert isinstance(connect_args["ssl"], ssl.SSLContext)

    url, connect_args = prepare_database_url(
        "postgres://user:pass@db.example.com:5432/thetree?sslmode=verify-full"
    )
    assert url.startswith("postgresql+asyncpg://")
    assert isinstance(connect_args["ssl"], ssl.SSLContext)
    assert connect_args["ssl"].verify_mode == ssl.CERT_REQUIRED

    url, connect_args = prepare_database_url("sqlite+aiosqlite:///./local.db")
    assert url == "sqlite+aiosqlite:///./local.db"
    assert connect_args == {}
