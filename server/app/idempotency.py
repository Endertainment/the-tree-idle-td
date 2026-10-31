"""Idempotency-key storage shared by mutating endpoints.

A retried PUT /save or purchase verify with the same key returns the stored
response instead of applying the mutation twice. Reusing a key with a different
body is rejected, because silently returning an unrelated response is worse.
"""

from __future__ import annotations

import hashlib
import json

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import IdempotencyKey


def body_hash(body: dict) -> str:
    canonical = json.dumps(body, sort_keys=True, separators=(",", ":"), default=str)
    return hashlib.sha256(canonical.encode("utf-8")).hexdigest()


async def find(
    session: AsyncSession, scope: str, player_id: str | None, key: str
) -> IdempotencyKey | None:
    statement = select(IdempotencyKey).where(
        IdempotencyKey.scope == scope,
        IdempotencyKey.player_id == player_id,
        IdempotencyKey.key == key,
    )
    return (await session.execute(statement)).scalar_one_or_none()


async def remember(
    session: AsyncSession,
    scope: str,
    player_id: str | None,
    key: str,
    request_hash: str,
    response: dict,
    status_code: int = 200,
) -> None:
    session.add(
        IdempotencyKey(
            scope=scope,
            player_id=player_id,
            key=key,
            request_hash=request_hash,
            response=response,
            status_code=status_code,
        )
    )
