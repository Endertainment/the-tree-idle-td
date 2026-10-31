"""AdMob SSV callback: public, signed, idempotent by transaction id."""

from __future__ import annotations

import time

from fastapi import APIRouter, Depends, Query, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import api_error
from ..models import Event
from ..ssv import verify

router = APIRouter(prefix="/ads", tags=["ads"])


@router.get("/ssv", include_in_schema=False)
@router.post("/ssv")
async def ads_ssv(
    request: Request,
    transaction_id: str | None = Query(default=None),
    signature: str | None = Query(default=None),
    user_id: str | None = Query(default=None),
    custom_data: str | None = Query(default=""),
    timestamp: str | None = Query(default=None),
    reward_amount: str | None = Query(default="0"),
    reward_item: str | None = Query(default=""),
    ad_unit: str | None = Query(default=""),
    ad_network: str | None = Query(default=""),
    key_id: str | None = Query(default=""),
    session: AsyncSession = Depends(get_session),
) -> dict:
    settings = get_settings()
    if not settings.admob_ssv_secret:
        api_error(503, "ssv_disabled", "SSV shared secret is not configured")
    if not transaction_id or not signature or not user_id or timestamp is None:
        api_error(
            422,
            "missing_ssv_parameters",
            "transaction_id, signature, user_id and timestamp are required",
        )
    try:
        callback_time = int(timestamp)
    except (TypeError, ValueError):
        api_error(422, "invalid_timestamp", "timestamp must be unix seconds")
    if settings.ssv_max_skew_seconds > 0 and abs(int(time.time()) - callback_time) > settings.ssv_max_skew_seconds:
        api_error(403, "stale_callback", "SSV callback timestamp is outside the allowed skew")
    if not verify(
        settings.admob_ssv_secret,
        signature,
        transaction_id,
        user_id,
        custom_data or "",
        reward_amount or "0",
        str(timestamp),
    ):
        api_error(403, "invalid_signature", "SSV signature did not verify")

    existing = (
        await session.execute(select(Event).where(Event.external_id == transaction_id))
    ).scalar_one_or_none()
    if existing is not None:
        return {"ok": True, "duplicate": True, "transaction_id": transaction_id}

    event = Event(
        name="ad_ssv",
        player_id=None,
        props={
            "transaction_id": transaction_id,
            "user_id": user_id,
            "custom_data": custom_data or "",
            "reward_amount": reward_amount or "0",
            "reward_item": reward_item or "",
            "ad_unit": ad_unit or "",
            "ad_network": ad_network or "",
            "key_id": key_id or "",
            "ip": request.client.host if request.client else "",
        },
        external_id=transaction_id,
    )
    session.add(event)
    await session.commit()
    return {"ok": True, "duplicate": False, "transaction_id": transaction_id, "event_id": event.id}
