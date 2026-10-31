"""Remote config: built-in defaults deep-merged with the deployment override."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends

from ..config import get_settings
from ..deps import get_current_player
from ..models import Player
from ..week import week_end_utc, week_id

router = APIRouter(tags=["config"])


@router.get("/config")
async def get_config(_player: Player = Depends(get_current_player)) -> dict:
    settings = get_settings()
    now = datetime.now(timezone.utc)
    config = settings.remote_config
    return {
        **config,
        "server_time": now.isoformat(),
        "week_id": week_id(now),
        "week_resets_at": week_end_utc(now).isoformat(),
        "tournament": {
            "min_level": settings.tournament_min_level,
            "cohort_size": settings.tournament_cohort_size,
            "starts_at": week_id(now),
        },
        "purchases_mode": settings.purchases_mode,
    }
