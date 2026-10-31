"""FastAPI dependencies: bearer auth, optional auth and the rate limiter."""

from __future__ import annotations

import time
from collections import defaultdict

from fastapi import Depends, Request
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy.ext.asyncio import AsyncSession

from .config import get_settings
from .db import get_session
from .models import Player
from .security import TokenError, decode_token

bearer_scheme = HTTPBearer(auto_error=False)


def api_error(status_code: int, code: str, message: str, **extra):
    from fastapi import HTTPException

    detail = {"code": code, "message": message}
    detail.update(extra)
    raise HTTPException(status_code=status_code, detail=detail)


async def get_current_player(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> Player:
    if credentials is None or not credentials.credentials:
        api_error(401, "missing_token", "Authorization: Bearer <jwt> is required")
    settings = get_settings()
    try:
        payload = decode_token(credentials.credentials, settings.jwt_secret, expected_type="access")
    except TokenError as exc:
        api_error(401, exc.code, "Access token is not valid")
    player = await session.get(Player, str(payload["sub"]))
    if player is None:
        api_error(401, "unknown_player", "Token refers to a deleted player")
    return player


async def get_optional_player(
    credentials: HTTPAuthorizationCredentials | None = Depends(bearer_scheme),
    session: AsyncSession = Depends(get_session),
) -> Player | None:
    """Anonymous access is allowed; a bad token is treated as anonymous."""
    if credentials is None or not credentials.credentials:
        return None
    settings = get_settings()
    try:
        payload = decode_token(credentials.credentials, settings.jwt_secret, expected_type="access")
    except TokenError:
        return None
    return await session.get(Player, str(payload["sub"]))


class RateLimiter:
    """In-process sliding window. Single-worker only; documented in SPEC.md."""

    def __init__(self) -> None:
        self._hits: dict[str, list[float]] = defaultdict(list)

    def allow(self, key: str, limit: int, window_seconds: float) -> bool:
        now = time.monotonic()
        bucket = [stamp for stamp in self._hits[key] if now - stamp < window_seconds]
        if len(bucket) >= limit:
            self._hits[key] = bucket
            return False
        bucket.append(now)
        self._hits[key] = bucket
        return True

    def clear(self) -> None:
        self._hits.clear()


limiter = RateLimiter()


def enforce_rate_limit(
    request: Request, scope: str, limit: int = 60, window_seconds: float = 60.0, subject: str = ""
) -> None:
    settings = get_settings()
    if not settings.rate_limit_enabled:
        return
    client = request.client.host if request.client else "unknown"
    key = f"{scope}:{subject or client}"
    if not limiter.allow(key, limit, window_seconds):
        api_error(429, "rate_limited", "Too many requests, retry later", retry_after=int(window_seconds))
