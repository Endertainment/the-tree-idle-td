"""Tournament lifecycle and entry upserts (weekly, cohorts of 50)."""

from __future__ import annotations

from datetime import datetime, timezone

from sqlalchemy import func, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .models import (
    LeaderboardEntry,
    Player,
    Save,
    Tournament,
    TournamentEntry,
    utcnow,
)
from .week import week_bounds, week_id

REWARD_TIERS: list[dict] = [
    {"label_key": "leaderboard.reward.top1", "percentile": 1, "stones": 100},
    {"label_key": "leaderboard.reward.top10", "percentile": 10, "stones": 40},
    {"label_key": "leaderboard.reward.top25", "percentile": 25, "stones": 20},
    {"label_key": "leaderboard.reward.top50", "percentile": 50, "stones": 10},
    {"label_key": "leaderboard.reward.participation", "percentile": 100, "stones": 5},
]


async def get_or_create_tournament(
    session: AsyncSession, now: datetime | None = None
) -> Tournament:
    moment = now or datetime.now(timezone.utc)
    identifier = week_id(moment)
    existing = (
        await session.execute(select(Tournament).where(Tournament.week_id == identifier))
    ).scalar_one_or_none()
    if existing is not None:
        return existing
    starts_at, ends_at = week_bounds(moment)
    tournament = Tournament(
        week_id=identifier,
        starts_at=starts_at,
        ends_at=ends_at,
        cohort_size=get_settings().tournament_cohort_size,
    )
    try:
        async with session.begin_nested():
            session.add(tournament)
            await session.flush()
    except IntegrityError:
        # Another worker created it first; use theirs.
        existing = (
            await session.execute(select(Tournament).where(Tournament.week_id == identifier))
        ).scalar_one_or_none()
        if existing is None:
            raise
        return existing
    return tournament


async def assign_cohort(session: AsyncSession, tournament: Tournament) -> str:
    rows = (
        await session.execute(
            select(TournamentEntry.cohort_id, func.count(TournamentEntry.id))
            .where(TournamentEntry.tournament_id == tournament.id)
            .group_by(TournamentEntry.cohort_id)
        )
    ).all()
    counts = {str(row[0]): int(row[1]) for row in rows}
    index = 0
    while counts.get(f"c{index}", 0) >= max(tournament.cohort_size, 1):
        index += 1
    return f"c{index}"


async def upsert_weekly_entry(
    session: AsyncSession,
    player_id: str,
    waves: int,
    playtime_s: int,
    submitted_at: datetime,
    run_id: str,
) -> tuple[LeaderboardEntry, bool]:
    identifier = week_id(submitted_at)
    entry = (
        await session.execute(
            select(LeaderboardEntry).where(
                LeaderboardEntry.week_id == identifier,
                LeaderboardEntry.player_id == player_id,
            )
        )
    ).scalar_one_or_none()
    if entry is None:
        entry = LeaderboardEntry(
            week_id=identifier,
            player_id=player_id,
            max_wave=waves,
            playtime_s=max(playtime_s, 0),
            submitted_at=submitted_at,
            run_id=run_id,
        )
        session.add(entry)
        await session.flush()
        return entry, True
    if waves > entry.max_wave:
        entry.max_wave = waves
        entry.playtime_s = max(playtime_s, 0)
        entry.submitted_at = submitted_at
        entry.run_id = run_id
        await session.flush()
        return entry, True
    return entry, False


async def upsert_tournament_entry(
    session: AsyncSession,
    tournament: Tournament,
    player_id: str,
    waves: int,
    playtime_s: int,
    submitted_at: datetime,
    run_id: str,
) -> tuple[TournamentEntry, bool]:
    entry = (
        await session.execute(
            select(TournamentEntry).where(
                TournamentEntry.tournament_id == tournament.id,
                TournamentEntry.player_id == player_id,
            )
        )
    ).scalar_one_or_none()
    if entry is None:
        cohort_id = await assign_cohort(session, tournament)
        entry = TournamentEntry(
            tournament_id=tournament.id,
            player_id=player_id,
            cohort_id=cohort_id,
            max_wave=waves,
            playtime_s=max(playtime_s, 0),
            submitted_at=submitted_at,
            best_run_id=run_id,
        )
        session.add(entry)
        await session.flush()
        return entry, True
    if waves > entry.max_wave:
        entry.max_wave = waves
        entry.playtime_s = max(playtime_s, 0)
        entry.submitted_at = submitted_at
        entry.best_run_id = run_id
        await session.flush()
        return entry, True
    return entry, False


def percentile_for(rank: int, total: int) -> float:
    if total <= 0 or rank <= 0:
        return 100.0
    return round(100.0 * rank / total, 2)


def reward_for(rank: int, total: int) -> dict:
    percentile = percentile_for(rank, total)
    for tier in REWARD_TIERS:
        if percentile <= float(tier["percentile"]):
            return dict(tier)
    return dict(REWARD_TIERS[-1])


async def player_level(session: AsyncSession, player: Player) -> int:
    """Players table level is synced from PUT /save; fall back to the save blob."""
    if player.level and player.level > 1:
        return int(player.level)
    save = await session.get(Save, player.id)
    payload = save.payload if save is not None and isinstance(save.payload, dict) else {}
    profile = payload.get("player", {}) if isinstance(payload, dict) else {}
    try:
        return max(int(profile.get("level", player.level or 1)), 1)
    except (TypeError, ValueError):
        return int(player.level or 1)


def tournament_is_live(tournament: Tournament, now: datetime | None = None) -> bool:
    moment = now or utcnow()
    return tournament.starts_at <= moment < tournament.ends_at
