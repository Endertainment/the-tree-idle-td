"""Batched analytics: max 100 events, scalar props only, 90-day retention."""

from __future__ import annotations

import re
import time
from datetime import timedelta

from fastapi import APIRouter, Depends
from sqlalchemy import delete
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import api_error, get_optional_player
from ..models import Event, Player, utcnow
from ..schemas import EventsIn, EventsOut

router = APIRouter(tags=["events"])

EVENT_NAME = re.compile(r"^[a-z][a-z0-9_]{0,63}$")
MAX_PROP_KEYS = 32
MAX_STRING_LENGTH = 120
_last_prune: float = 0.0


def sanitized_props(props: dict) -> dict:
    clean: dict = {}
    for key, value in list(props.items())[:MAX_PROP_KEYS]:
        if not isinstance(key, str):
            continue
        if isinstance(value, (str, int, float, bool)) or value is None:
            clean[key[:64]] = value[:MAX_STRING_LENGTH] if isinstance(value, str) else value
        else:
            raise ValueError(f"props[{key}] must be a scalar")
    return clean


@router.post("/events", response_model=EventsOut)
async def post_events(
    payload: EventsIn,
    player: Player | None = Depends(get_optional_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    settings = get_settings()
    if len(payload.events) == 0:
        api_error(422, "empty_batch", "At least one event is required")
    if len(payload.events) > settings.max_events_per_batch:
        api_error(
            422,
            "batch_too_large",
            f"A batch may contain at most {settings.max_events_per_batch} events",
            max_events=settings.max_events_per_batch,
        )
    rows: list[Event] = []
    for item in payload.events:
        if not EVENT_NAME.match(item.name):
            api_error(422, "invalid_event_name", f"Invalid event name: {item.name[:64]}")
        try:
            props = sanitized_props(item.props)
        except ValueError as exc:
            api_error(422, "invalid_props", str(exc))
        rows.append(
            Event(
                player_id=player.id if player is not None else None,
                name=item.name,
                props=props,
                client_ts=item.client_ts,
            )
        )
    pruned = await _prune(session)
    session.add_all(rows)
    await session.commit()
    return {"accepted": len(rows), "dropped": 0, "pruned": pruned}


async def _prune(session: AsyncSession) -> int:
    global _last_prune
    now = time.monotonic()
    if now - _last_prune < 3600:
        return 0
    _last_prune = now
    cutoff = utcnow() - timedelta(days=90)
    result = await session.execute(delete(Event).where(Event.server_ts < cutoff))
    return int(result.rowcount or 0)
