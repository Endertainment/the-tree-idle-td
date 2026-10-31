"""GET /leaderboard — weekly, all-time and tournament scopes with own rank."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import api_error, get_current_player
from ..models import Player, TournamentEntry
from ..schemas import LeaderboardOut
from ..standings import (
    all_time_page,
    clamp_limit,
    decode_cursor,
    tournament_page,
    weekly_page,
)
from ..tournament_service import get_or_create_tournament
from ..week import week_id

router = APIRouter(tags=["leaderboard"])

SCOPES = {"weekly", "all_time", "tournament"}


@router.get("/leaderboard", response_model=LeaderboardOut)
async def get_leaderboard(
    scope: str = Query(default="weekly"),
    limit: int = Query(default=100, ge=1, le=200),
    cursor: str | None = Query(default=None),
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    scope = scope.strip().lower()
    if scope not in SCOPES:
        api_error(400, "unsupported_scope", f"scope must be one of {sorted(SCOPES)}")
    limit = clamp_limit(limit)
    offset = decode_cursor(cursor)
    if scope == "weekly":
        return await weekly_page(session, week_id(datetime.now(timezone.utc)), player.id, limit, offset)
    if scope == "all_time":
        return await all_time_page(session, player.id, limit, offset)
    return await _tournament_scope(session, player, limit, offset)


async def _tournament_scope(
    session: AsyncSession, player: Player, limit: int, offset: int
) -> dict:
    tournament = await get_or_create_tournament(session)
    entry = (
        await session.execute(
            select(TournamentEntry).where(
                TournamentEntry.tournament_id == tournament.id,
                TournamentEntry.player_id == player.id,
            )
        )
    ).scalar_one_or_none()
    cohort = entry.cohort_id if entry is not None else "c0"
    page = await tournament_page(session, tournament.id, cohort, player.id, limit, offset)
    return {
        "scope": "tournament",
        "week_id": tournament.week_id,
        "entries": page["entries"],
        "own_rank": page["own_rank"],
        "own_entry": page["own_entry"],
        "total": page["total"],
        "next_cursor": page["next_cursor"],
        "updated_at": datetime.now(timezone.utc),
    }
