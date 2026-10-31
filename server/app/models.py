"""SQLAlchemy models: the §8.5 contract.

PostgreSQL stores JSONB, SQLite stores JSON through one type alias, so the same
metadata creates the schema on both backends.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timezone

from sqlalchemy import (
    BigInteger,
    Boolean,
    DateTime,
    Float,
    ForeignKey,
    Index,
    Integer,
    JSON,
    String,
    UniqueConstraint,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.orm import Mapped, mapped_column

from .db import Base

JSONType = JSON().with_variant(JSONB, "postgresql")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def new_id() -> str:
    return str(uuid.uuid4())


class Player(Base):
    __tablename__ = "players"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    device_id: Mapped[str] = mapped_column(String(128), unique=True, index=True)
    nickname: Mapped[str] = mapped_column(String(32), default="")
    avatar_id: Mapped[str] = mapped_column(String(32), default="avatar_01")
    level: Mapped[int] = mapped_column(Integer, default=1)
    xp: Mapped[int] = mapped_column(Integer, default=0)
    provider: Mapped[str | None] = mapped_column(String(32), nullable=True)
    provider_uid: Mapped[str | None] = mapped_column(String(128), nullable=True)
    refresh_token_hash: Mapped[str | None] = mapped_column(String(128), nullable=True)
    refresh_expires_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
    last_seen_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Save(Base):
    __tablename__ = "saves"

    player_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("players.id", ondelete="CASCADE"), primary_key=True
    )
    revision: Mapped[int] = mapped_column(Integer, default=1)
    payload: Mapped[dict] = mapped_column(JSONType, default=dict)
    checksum: Mapped[str | None] = mapped_column(String(128), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class IdempotencyKey(Base):
    """Stored responses for mutating calls that carry Idempotency-Key."""

    __tablename__ = "idempotency_keys"
    __table_args__ = (UniqueConstraint("scope", "player_id", "key", name="uq_idempotency"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    scope: Mapped[str] = mapped_column(String(64))
    player_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    key: Mapped[str] = mapped_column(String(80))
    request_hash: Mapped[str] = mapped_column(String(80))
    status_code: Mapped[int] = mapped_column(Integer, default=200)
    response: Mapped[dict] = mapped_column(JSONType, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Run(Base):
    __tablename__ = "runs"
    __table_args__ = (Index("ix_runs_player_created", "player_id", "created_at"),)

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(String(36), ForeignKey("players.id", ondelete="CASCADE"))
    run_seed: Mapped[str] = mapped_column(String(128), default="")
    waves: Mapped[int] = mapped_column(Integer, default=0)
    duration_s: Mapped[float] = mapped_column(Float, default=0.0)
    damage: Mapped[int] = mapped_column(BigInteger, default=0)
    cash: Mapped[int] = mapped_column(BigInteger, default=0)
    playtime_s: Mapped[int] = mapped_column(Integer, default=0)
    signature: Mapped[str | None] = mapped_column(String(256), nullable=True)
    accepted: Mapped[bool] = mapped_column(Boolean, default=False)
    rejection_reason: Mapped[str | None] = mapped_column(String(64), nullable=True)
    week_id: Mapped[str] = mapped_column(String(16), default="")
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class LeaderboardEntry(Base):
    __tablename__ = "leaderboard_entries"
    __table_args__ = (UniqueConstraint("week_id", "player_id", name="uq_leaderboard_week_player"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    week_id: Mapped[str] = mapped_column(String(16), index=True)
    player_id: Mapped[str] = mapped_column(String(36), ForeignKey("players.id", ondelete="CASCADE"))
    max_wave: Mapped[int] = mapped_column(Integer, default=0)
    playtime_s: Mapped[int] = mapped_column(Integer, default=0)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    run_id: Mapped[str | None] = mapped_column(String(36), nullable=True)


class Tournament(Base):
    __tablename__ = "tournaments"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    week_id: Mapped[str] = mapped_column(String(16), unique=True, index=True)
    starts_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    ends_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    cohort_size: Mapped[int] = mapped_column(Integer, default=50)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class TournamentEntry(Base):
    __tablename__ = "tournament_entries"
    __table_args__ = (
        UniqueConstraint("tournament_id", "player_id", name="uq_tournament_player"),
        Index("ix_tournament_cohort", "tournament_id", "cohort_id"),
    )

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    tournament_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("tournaments.id", ondelete="CASCADE")
    )
    player_id: Mapped[str] = mapped_column(String(36), ForeignKey("players.id", ondelete="CASCADE"))
    cohort_id: Mapped[str] = mapped_column(String(64))
    max_wave: Mapped[int] = mapped_column(Integer, default=0)
    playtime_s: Mapped[int] = mapped_column(Integer, default=0)
    submitted_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    best_run_id: Mapped[str | None] = mapped_column(String(36), nullable=True)


class Purchase(Base):
    __tablename__ = "purchases"

    id: Mapped[str] = mapped_column(String(36), primary_key=True, default=new_id)
    player_id: Mapped[str] = mapped_column(String(36), ForeignKey("players.id", ondelete="CASCADE"))
    product_id: Mapped[str] = mapped_column(String(64), index=True)
    purchase_token: Mapped[str] = mapped_column(String(256), unique=True, index=True)
    platform: Mapped[str] = mapped_column(String(16), default="google")
    status: Mapped[str] = mapped_column(String(16), default="granted")
    verified_by: Mapped[str] = mapped_column(String(32), default="stub")
    grant_id: Mapped[str] = mapped_column(String(36), default=new_id)
    raw: Mapped[dict] = mapped_column(JSONType, default=dict)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class Event(Base):
    __tablename__ = "events"
    __table_args__ = (Index("ix_events_server_ts", "server_ts"),)

    id: Mapped[int] = mapped_column(Integer, primary_key=True, autoincrement=True)
    player_id: Mapped[str | None] = mapped_column(String(36), nullable=True)
    name: Mapped[str] = mapped_column(String(64))
    props: Mapped[dict] = mapped_column(JSONType, default=dict)
    client_ts: Mapped[int | None] = mapped_column(BigInteger, nullable=True)
    external_id: Mapped[str | None] = mapped_column(String(128), unique=True, nullable=True)
    server_ts: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)


class MissionsState(Base):
    """Reserved for server-driven missions (schema required by §8.5)."""

    __tablename__ = "missions_state"

    player_id: Mapped[str] = mapped_column(
        String(36), ForeignKey("players.id", ondelete="CASCADE"), primary_key=True
    )
    week_id: Mapped[str] = mapped_column(String(16), default="")
    state: Mapped[dict] = mapped_column(JSONType, default=dict)
    updated_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, onupdate=utcnow)
