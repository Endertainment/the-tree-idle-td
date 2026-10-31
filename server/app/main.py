"""FastAPI application factory.

Run locally: ``uvicorn app.main:app --reload`` from ``server/``.
OpenAPI: ``/docs`` (Swagger), ``/openapi.json``.
"""

from __future__ import annotations

from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from .config import get_settings
from .db import init_db, reset_db
from .routers import ads, auth, config, events, leaderboard, profile, purchases, runs, saves, tournaments

VERSION = "0.8.0"


@asynccontextmanager
async def lifespan(_app: FastAPI):
    settings = get_settings()
    if settings.auto_create_tables:
        await init_db()
    yield
    await reset_db()


def create_app() -> FastAPI:
    app = FastAPI(
        title="The Tree: Idle Tower Defense API",
        version=VERSION,
        description=(
            "Backend for The Tree: Idle Tower Defense. SQLite by default; set "
            "DATABASE_URL to a PostgreSQL/Neon asyncpg URL for production. "
            "The server is authoritative for leaderboard and tournament placement."
        ),
        lifespan=lifespan,
    )
    # The Godot client is a native app; permissive CORS keeps browser tools and
    # the generated docs usable without shipping a second origin allowlist.
    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_methods=["*"],
        allow_headers=["*"],
        expose_headers=["Idempotency-Key"],
    )

    for module in (auth, profile, saves, config, leaderboard, tournaments, runs, purchases, ads, events):
        app.include_router(module.router, prefix="/v1")

    @app.get("/healthz", tags=["meta"])
    async def healthz() -> dict:
        url = get_settings().database_url
        backend = "sqlite" if url.startswith("sqlite") else "postgresql"
        return {"status": "ok", "version": VERSION, "database": backend}

    @app.get("/", tags=["meta"])
    async def root() -> dict:
        return {
            "service": "the-tree-api",
            "version": VERSION,
            "docs": "/docs",
            "openapi": "/openapi.json",
            "health": "/healthz",
        }

    return app


app = create_app()
