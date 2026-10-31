"""Shared run intake: signature check, plausibility verdict, run row.

Every submitted run is stored, including rejected ones, so abuse is auditable.
"""

from __future__ import annotations

from datetime import datetime

from sqlalchemy.ext.asyncio import AsyncSession

from .anticheat import (
    REASON_BAD_SIGNATURE,
    validate_run,
    verify_run_signature,
)
from .config import get_settings
from .models import Player, Run, utcnow
from .schemas import RunSubmitIn
from .week import week_id


async def record_run(
    session: AsyncSession,
    player: Player,
    body: RunSubmitIn,
    now: datetime | None = None,
) -> tuple[Run, str | None]:
    settings = get_settings()
    moment = now or utcnow()
    reason: str | None = None
    if not verify_run_signature(
        settings.run_hmac_secret,
        body.signature,
        body.run_seed,
        body.waves,
        body.duration_s,
        body.damage,
        body.cash,
    ):
        reason = REASON_BAD_SIGNATURE
    else:
        verdict = validate_run(body.waves, body.duration_s, body.damage, body.cash)
        if not verdict.accepted:
            reason = verdict.reason
    run = Run(
        player_id=player.id,
        run_seed=body.run_seed[:128],
        waves=body.waves,
        duration_s=float(body.duration_s),
        damage=body.damage,
        cash=body.cash,
        playtime_s=body.playtime_s if body.playtime_s is not None else int(round(body.duration_s)),
        signature=body.signature,
        accepted=reason is None,
        rejection_reason=reason,
        week_id=week_id(moment),
        created_at=moment,
    )
    session.add(run)
    await session.flush()
    return run, reason
