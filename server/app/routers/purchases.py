"""Purchase verification (stub).

The real Google Play / App Store receipt validator is a documented hook: with
PURCHASES_MODE=stub any non-empty token is accepted and marked verified_by=stub;
with PURCHASES_MODE=disabled the endpoint returns 503 rather than granting for
free. Grants are idempotent by purchase_token.
"""

from __future__ import annotations

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import api_error, enforce_rate_limit, get_current_player
from ..models import Player, Purchase, utcnow
from ..schemas import PurchaseIn, PurchaseOut
from ..security import new_id

router = APIRouter(prefix="/purchases", tags=["purchases"])

KNOWN_PRODUCTS = {
    "thetree.gems_100",
    "thetree.gems_550",
    "thetree.gems_1200",
    "thetree.coins_5000",
    "thetree.starter_pack",
    "thetree.no_ads",
    "thetree.speed_pack",
}


@router.post("/verify", response_model=PurchaseOut)
async def verify_purchase(
    body: PurchaseIn,
    request: Request,
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    enforce_rate_limit(request, "purchases", limit=30, window_seconds=60, subject=player.id)
    settings = get_settings()
    if body.product_id not in KNOWN_PRODUCTS:
        api_error(422, "unknown_product", "Product id is not in the launch catalogue")
    if settings.purchases_mode == "disabled":
        api_error(503, "verification_unavailable", "Receipt verification is not configured")

    existing = (
        await session.execute(select(Purchase).where(Purchase.purchase_token == body.purchase_token))
    ).scalar_one_or_none()
    if existing is not None:
        if existing.player_id != player.id or existing.product_id != body.product_id:
            api_error(409, "purchase_token_conflict", "Token belongs to another player or product")
        return {
            "status": "already_granted",
            "product_id": existing.product_id,
            "purchase_token": existing.purchase_token,
            "grant_id": existing.grant_id,
            "already_granted": True,
            "verified_by": existing.verified_by,
            "granted_at": existing.created_at,
        }

    purchase = Purchase(
        id=new_id(),
        player_id=player.id,
        product_id=body.product_id,
        purchase_token=body.purchase_token,
        platform=body.platform,
        status="granted",
        verified_by="stub" if settings.purchases_mode == "stub" else settings.purchases_mode,
        grant_id=new_id(),
        raw=body.receipt,
        created_at=utcnow(),
    )
    session.add(purchase)
    await session.commit()
    return {
        "status": "granted",
        "product_id": purchase.product_id,
        "purchase_token": purchase.purchase_token,
        "grant_id": purchase.grant_id,
        "already_granted": False,
        "verified_by": purchase.verified_by,
        "granted_at": purchase.created_at,
    }
