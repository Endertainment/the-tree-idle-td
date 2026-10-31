"""POST /runs — optional analytics run intake with the same plausibility gate.

A rejected run is stored with its reason but still returns HTTP 200 so telemetry
never breaks a client. Tournaments use the stricter 422 path.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import enforce_rate_limit, get_current_player
from ..models import Player
from ..run_service import record_run
from ..schemas import RunResultOut, RunSubmitIn
from ..standings import weekly_own
from ..tournament_service import upsert_weekly_entry
from ..week import week_id

router = APIRouter(tags=["runs"])


@router.post("/runs", response_model=RunResultOut)
async def post_run(
    body: RunSubmitIn,
    request: Request,
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    enforce_rate_limit(request, "runs", limit=60, window_seconds=60, subject=player.id)
    run, reason = await record_run(session, player, body)
    if reason is not None:
        await session.commit()
        return {
            "accepted": False,
            "run_id": run.id,
            "rejection_reason": reason,
            "week_id": run.week_id,
            "weekly_rank": None,
            "tournament_rank": None,
            "cohort_id": None,
        }
    playtime = body.playtime_s if body.playtime_s is not None else int(round(body.duration_s))
    await upsert_weekly_entry(session, player.id, body.waves, playtime, run.created_at, run.id)
    await session.commit()
    own = await weekly_own(session, week_id(run.created_at), player.id)
    return {
        "accepted": True,
        "run_id": run.id,
        "rejection_reason": None,
        "week_id": run.week_id,
        "weekly_rank": int(own["rank"]) if own else None,
        "tournament_rank": None,
        "cohort_id": None,
    }
