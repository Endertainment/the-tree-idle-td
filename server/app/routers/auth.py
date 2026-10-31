"""Guest auth and refresh-token rotation."""

from __future__ import annotations

from datetime import datetime, timezone

from fastapi import APIRouter, Depends, Request
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from ..config import get_settings
from ..db import get_session
from ..deps import api_error, enforce_rate_limit
from ..models import Player, utcnow
from ..schemas import GuestIn, RefreshIn, TokenOut
from ..security import TokenError, create_token, decode_token, hash_token, tokens_match

router = APIRouter(prefix="/auth", tags=["auth"])


def _issue_tokens(player: Player, is_new: bool = False) -> TokenOut:
    settings = get_settings()
    access_token, _ = create_token(
        player.id, "access", settings.jwt_secret, settings.access_token_ttl_seconds
    )
    refresh_token, refresh_expires = create_token(
        player.id, "refresh", settings.jwt_secret, settings.refresh_token_ttl_seconds
    )
    player.refresh_token_hash = hash_token(refresh_token)
    player.refresh_expires_at = datetime.fromtimestamp(refresh_expires, timezone.utc)
    return TokenOut(
        player_id=player.id,
        access_token=access_token,
        refresh_token=refresh_token,
        expires_in=settings.access_token_ttl_seconds,
        refresh_expires_in=settings.refresh_token_ttl_seconds,
        is_new=is_new,
        nickname=player.nickname,
    )


@router.post("/guest", response_model=TokenOut)
async def guest_login(
    payload: GuestIn,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> TokenOut:
    enforce_rate_limit(request, "auth_guest", limit=30, window_seconds=60)
    player = (
        await session.execute(select(Player).where(Player.device_id == payload.device_id))
    ).scalar_one_or_none()
    is_new = player is None
    if player is None:
        player = Player(
            device_id=payload.device_id,
            nickname=payload.nickname or "Gardener",
            avatar_id=payload.avatar_id or "avatar_01",
        )
        session.add(player)
        await session.flush()
    else:
        player.last_seen_at = utcnow()
        if payload.nickname:
            player.nickname = payload.nickname[:32]
        if payload.avatar_id:
            player.avatar_id = payload.avatar_id[:32]
    tokens = _issue_tokens(player, is_new=is_new)
    session.add(player)
    await session.commit()
    return tokens


@router.post("/refresh", response_model=TokenOut)
async def refresh_tokens(
    payload: RefreshIn,
    request: Request,
    session: AsyncSession = Depends(get_session),
) -> TokenOut:
    enforce_rate_limit(request, "auth_refresh", limit=60, window_seconds=60)
    settings = get_settings()
    try:
        claims = decode_token(payload.refresh_token, settings.jwt_secret, expected_type="refresh")
    except TokenError as exc:
        api_error(401, exc.code, "Refresh token is not valid")
    player = await session.get(Player, str(claims["sub"]))
    if player is None or not tokens_match(player.refresh_token_hash, payload.refresh_token):
        api_error(401, "refresh_revoked", "Refresh token was already rotated or revoked")
    expires = player.refresh_expires_at
    if expires is not None:
        if expires.tzinfo is None:
            expires = expires.replace(tzinfo=timezone.utc)
        if expires < datetime.now(timezone.utc):
            api_error(401, "refresh_expired", "Refresh token has expired")
    player.last_seen_at = utcnow()
    tokens = _issue_tokens(player)
    await session.commit()
    return tokens
