"""Alembic environment: async engine from DATABASE_URL (SQLite or PostgreSQL).

The URL comes from the same Settings object as the app, so ``alembic upgrade
head`` works identically against local SQLite and Neon.
"""

from __future__ import annotations

import asyncio
from logging.config import fileConfig

from alembic import context
from sqlalchemy import pool
from sqlalchemy.ext.asyncio import create_async_engine

from app import models  # noqa: F401  (registers metadata)
from app.config import get_settings, prepare_database_url
from app.db import Base

config = context.config
if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _url_and_args() -> tuple[str, dict]:
    return prepare_database_url(get_settings().database_url)


def run_migrations_offline() -> None:
    url, _ = _url_and_args()
    context.configure(
        url=url,
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
        compare_type=True,
    )
    with context.begin_transaction():
        context.run_migrations()


def _do_run_migrations(connection) -> None:
    context.configure(connection=connection, target_metadata=target_metadata, compare_type=True)
    with context.begin_transaction():
        context.run_migrations()


async def _run_async_migrations() -> None:
    url, connect_args = _url_and_args()
    engine = create_async_engine(url, connect_args=connect_args, poolclass=pool.NullPool)
    async with engine.connect() as connection:
        await connection.run_sync(_do_run_migrations)
    await engine.dispose()


def run_migrations_online() -> None:
    asyncio.run(_run_async_migrations())


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
