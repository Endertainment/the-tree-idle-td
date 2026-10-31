"""Async SQLAlchemy engine and session plumbing.

One engine per process, created lazily from the current Settings so tests can
point DATABASE_URL at a temporary SQLite file before the first request.
"""

from __future__ import annotations

from collections.abc import AsyncIterator

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase
from sqlalchemy.pool import StaticPool

from .config import get_settings, prepare_database_url


class Base(DeclarativeBase):
    pass


_engine = None
_session_factory: async_sessionmaker[AsyncSession] | None = None


def get_engine():
    global _engine
    if _engine is None:
        settings = get_settings()
        url, connect_args = prepare_database_url(settings.database_url)
        kwargs: dict = {"echo": False, "future": True, "pool_pre_ping": True}
        if url.startswith("sqlite"):
            kwargs["connect_args"] = {"check_same_thread": False}
            if ":memory:" in url:
                kwargs["poolclass"] = StaticPool
        else:
            kwargs["connect_args"] = connect_args
        _engine = create_async_engine(url, **kwargs)
    return _engine


def get_session_factory() -> async_sessionmaker[AsyncSession]:
    global _session_factory
    if _session_factory is None:
        _session_factory = async_sessionmaker(get_engine(), expire_on_commit=False)
    return _session_factory


async def get_session() -> AsyncIterator[AsyncSession]:
    factory = get_session_factory()
    async with factory() as session:
        yield session


async def init_db() -> None:
    """Creates all tables (the create_all bootstrap, Alembic is the formal path)."""
    from . import models  # noqa: F401  (registers metadata)

    async with get_engine().begin() as connection:
        await connection.run_sync(Base.metadata.create_all)


async def reset_db() -> None:
    """Test hook: dispose the engine and forget the session factory."""
    global _engine, _session_factory
    if _engine is not None:
        await _engine.dispose()
    _engine = None
    _session_factory = None
