"""Shared test setup: a throwaway SQLite database and an ASGI httpx client.

The environment is configured before app modules are imported, because settings
and the async engine are cached per process.
"""

from __future__ import annotations

import os
import tempfile
import uuid

TEST_DB_PATH = os.path.join(tempfile.gettempdir(), f"thetree_test_{os.getpid()}.db")

os.environ["DATABASE_URL"] = f"sqlite+aiosqlite:///{TEST_DB_PATH}"
os.environ["JWT_SECRET"] = "test-secret-do-not-use-in-production"
os.environ["RATE_LIMIT_ENABLED"] = "false"
os.environ["RUN_HMAC_SECRET"] = ""
os.environ["ADMOB_SSV_SECRET"] = "test-ssv-secret"
os.environ["SSV_MAX_SKEW_SECONDS"] = "600"
os.environ["PURCHASES_MODE"] = "stub"
os.environ["AUTO_CREATE_TABLES"] = "true"

import httpx  # noqa: E402
import pytest_asyncio  # noqa: E402

from app.config import reset_settings  # noqa: E402
from app.db import get_session_factory, init_db, reset_db  # noqa: E402


@pytest_asyncio.fixture(scope="session", loop_scope="session", autouse=True)
async def _database():
    reset_settings()
    await reset_db()
    await init_db()
    yield
    await reset_db()
    for suffix in ("", "-journal", "-wal", "-shm"):
        try:
            os.remove(TEST_DB_PATH + suffix)
        except OSError:
            pass


@pytest_asyncio.fixture(scope="session", loop_scope="session")
async def client():
    from app.main import app

    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as http_client:
        yield http_client


@pytest_asyncio.fixture(loop_scope="session")
async def guest(client):
    """Factory: creates a fresh guest and returns tokens + auth headers."""

    async def _make(nickname: str = "Tester", level: int | None = None, avatar: str = "avatar_01"):
        device_id = f"device-{uuid.uuid4()}"
        response = await client.post(
            "/v1/auth/guest",
            json={"device_id": device_id, "nickname": nickname, "avatar_id": avatar},
        )
        assert response.status_code == 200, response.text
        data = response.json()
        headers = {"Authorization": f"Bearer {data['access_token']}"}
        if level is not None:
            saved = await client.put(
                "/v1/save",
                json={
                    "revision": 0,
                    "payload": {
                        "player": {
                            "nickname": nickname,
                            "avatar_id": avatar,
                            "level": level,
                            "xp": 0,
                        },
                        "stats": {"best_wave": 0},
                    },
                },
                headers={**headers, "Idempotency-Key": str(uuid.uuid4())},
            )
            assert saved.status_code == 200, saved.text
        return {"device_id": device_id, **data, "headers": headers}

    return _make


@pytest_asyncio.fixture(loop_scope="session")
async def db():
    async with get_session_factory()() as session:
        yield session
