"""Tournaments: current cohort, standings and validated run submission."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from ..anticheat import REASON_BAD_SIGNATURE
from ..config import get_settings
from ..db import get_session
from ..deps import api_error, enforce_rate_limit, get_current_player
from ..models import Player, TournamentEntry, utcnow
from ..run_service import record_run
from ..schemas import RunResultOut, RunSubmitIn, StandingsOut, TournamentOut
from ..standings import tournament_own, tournament_page, weekly_own
from ..tournament_service import (
    REWARD_TIERS,
    get_or_create_tournament,
    player_level,
    upsert_tournament_entry,
    upsert_weekly_entry,
)
from ..week import week_id

router = APIRouter(prefix="/tournaments", tags=["tournaments"])


async def _entry_for(session: AsyncSession, tournament_id: str, player_id: str):
    return (
        await session.execute(
            select(TournamentEntry).where(
                TournamentEntry.tournament_id == tournament_id,
                TournamentEntry.player_id == player_id,
            )
        )
    ).scalar_one_or_none()


@router.get("/current", response_model=TournamentOut)
async def current_tournament(
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    tournament = await get_or_create_tournament(session)
    level = await player_level(session, player)
    min_level = get_settings().tournament_min_level
    entry = await _entry_for(session, tournament.id, player.id)
    own = None
    count = 0
    if entry is not None:
        cohort_count = int(
            (
                await session.execute(
                    select(func.count())
                    .select_from(TournamentEntry)
                    .where(
                        TournamentEntry.tournament_id == tournament.id,
                        TournamentEntry.cohort_id == entry.cohort_id,
                    )
                )
            ).scalar_one()
        )
        count = cohort_count
        own = await tournament_own(session, tournament.id, entry.cohort_id, player.id)
    return {
        "tournament_id": tournament.id,
        "week_id": tournament.week_id,
        "starts_at": tournament.starts_at,
        "ends_at": tournament.ends_at,
        "cohort_size": tournament.cohort_size,
        "cohort_id": entry.cohort_id if entry is not None else None,
        "eligible": level >= min_level,
        "min_level": min_level,
        "entries_count": count,
        "own_entry": own,
        "reward_tiers": REWARD_TIERS,
    }


@router.get("/current/standings", response_model=StandingsOut)
async def current_standings(
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    tournament = await get_or_create_tournament(session)
    entry = await _entry_for(session, tournament.id, player.id)
    cohort = entry.cohort_id if entry is not None else "c0"
    page = await tournament_page(session, tournament.id, cohort, player.id)
    own_rank = page["own_rank"]
    own_percentile = None
    if own_rank is not None and page["total"] > 0:
        own_percentile = round(100.0 * own_rank / page["total"], 2)
    return {
        "tournament_id": tournament.id,
        "week_id": tournament.week_id,
        "cohort_id": cohort,
        "entries": page["entries"],
        "own_rank": own_rank,
        "own_percentile": own_percentile,
        "total": page["total"],
        "ends_at": tournament.ends_at,
        "updated_at": datetime.now(timezone.utc),
    }


@router.post("/current/submit", response_model=RunResultOut)
async def submit_run(
    body: RunSubmitIn,
    request: Request,
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    enforce_rate_limit(request, "tournament_submit", limit=30, window_seconds=60, subject=player.id)
    settings = get_settings()
    level = await player_level(session, player)
    if level < settings.tournament_min_level:
        api_error(
            403,
            "level_too_low",
            f"Tournaments unlock at level {settings.tournament_min_level}",
            required_level=settings.tournament_min_level,
            level=level,
        )
    moment = utcnow()
    run, reason = await record_run(session, player, body, now=moment)
    if reason is not None:
        await session.commit()
        if reason == REASON_BAD_SIGNATURE:
            api_error(403, "bad_signature", "Run signature did not verify", run_id=run.id)
        api_error(422, "run_rejected", "Run failed plausibility validation", reason=reason, run_id=run.id)

    tournament = await get_or_create_tournament(session, moment)
    playtime = body.playtime_s if body.playtime_s is not None else int(round(body.duration_s))
    await upsert_weekly_entry(session, player.id, body.waves, playtime, moment, run.id)
    entry, _ = await upsert_tournament_entry(
        session, tournament, player.id, body.waves, playtime, moment, run.id
    )
    await session.commit()

    weekly = await weekly_own(session, week_id(moment), player.id)
    placement = await tournament_own(session, tournament.id, entry.cohort_id, player.id)
    return {
        "accepted": True,
        "run_id": run.id,
        "rejection_reason": None,
        "week_id": week_id(moment),
        "weekly_rank": int(weekly["rank"]) if weekly is not None else None,
        "tournament_rank": int(placement["rank"]) if placement is not None else None,
        "cohort_id": entry.cohort_id,
    }
