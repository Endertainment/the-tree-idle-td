"""Pydantic v2 request/response models (the public contract in server/SPEC.md)."""

from __future__ import annotations

from datetime import datetime
from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


class GuestIn(BaseModel):
    device_id: str = Field(min_length=4, max_length=128)
    nickname: str = Field(default="", max_length=32)
    avatar_id: str = Field(default="avatar_01", max_length=32)

    @field_validator("nickname")
    @classmethod
    def _trim_nickname(cls, value: str) -> str:
        return value.strip()


class RefreshIn(BaseModel):
    refresh_token: str = Field(min_length=10, max_length=4096)


class TokenOut(BaseModel):
    player_id: str
    access_token: str
    refresh_token: str
    token_type: Literal["bearer"] = "bearer"
    expires_in: int
    refresh_expires_in: int
    is_new: bool = False
    nickname: str = ""


class ProfileOut(BaseModel):
    player_id: str
    nickname: str
    avatar_id: str
    level: int
    xp: int
    provider: str | None = None
    is_guest: bool
    created_at: datetime
    last_seen_at: datetime
    save_revision: int
    wallet: dict = Field(default_factory=dict)
    stats: dict = Field(default_factory=dict)


class SaveIn(BaseModel):
    revision: int = Field(ge=0)
    payload: dict[str, Any]
    checksum: str | None = Field(default=None, max_length=128)


class SaveOut(BaseModel):
    revision: int
    updated_at: datetime
    payload: dict[str, Any]
    checksum: str | None = None


class LeaderboardEntryOut(BaseModel):
    rank: int
    player_id: str
    nickname: str
    avatar_id: str
    max_wave: int
    playtime_s: int = 0
    submitted_at: datetime
    is_player: bool = False


class LeaderboardOut(BaseModel):
    scope: str
    week_id: str
    entries: list[LeaderboardEntryOut]
    own_rank: int | None = None
    own_entry: LeaderboardEntryOut | None = None
    total: int
    next_cursor: str | None = None
    updated_at: datetime


class RunSubmitIn(BaseModel):
    run_seed: str = Field(default="", max_length=128)
    waves: int = Field(ge=0, le=100_000)
    duration_s: float = Field(ge=0)
    damage: int = Field(ge=0)
    cash: int = Field(ge=0)
    signature: str | None = Field(default=None, max_length=256)
    playtime_s: int | None = Field(default=None, ge=0)


class RunResultOut(BaseModel):
    accepted: bool
    run_id: str | None = None
    rejection_reason: str | None = None
    week_id: str
    weekly_rank: int | None = None
    tournament_rank: int | None = None
    cohort_id: str | None = None


class TournamentOut(BaseModel):
    tournament_id: str
    week_id: str
    starts_at: datetime
    ends_at: datetime
    cohort_size: int
    cohort_id: str | None = None
    eligible: bool
    min_level: int
    entries_count: int = 0
    own_entry: LeaderboardEntryOut | None = None
    reward_tiers: list[dict] = Field(default_factory=list)


class StandingsOut(BaseModel):
    tournament_id: str
    week_id: str
    cohort_id: str
    entries: list[LeaderboardEntryOut]
    own_rank: int | None = None
    own_percentile: float | None = None
    total: int
    ends_at: datetime
    updated_at: datetime


class PurchaseIn(BaseModel):
    product_id: str = Field(min_length=3, max_length=64)
    purchase_token: str = Field(min_length=3, max_length=256)
    platform: Literal["google", "apple", "debug"] = "google"
    receipt: dict[str, Any] = Field(default_factory=dict)


class PurchaseOut(BaseModel):
    status: Literal["granted", "already_granted", "unverified"]
    product_id: str
    purchase_token: str
    grant_id: str | None = None
    already_granted: bool = False
    verified_by: str = "stub"
    granted_at: datetime | None = None


class EventIn(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    props: dict[str, Any] = Field(default_factory=dict)
    client_ts: int | None = Field(default=None, ge=0)


class EventsIn(BaseModel):
    events: list[EventIn]


class EventsOut(BaseModel):
    accepted: int
    dropped: int = 0
    pruned: int = 0
