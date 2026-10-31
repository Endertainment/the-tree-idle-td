"""Cloud save: GET returns the blob, PUT is revision-checked and idempotent."""

from __future__ import annotations

from fastapi import APIRouter, Depends, Header, Request
from fastapi.responses import JSONResponse
from sqlalchemy.ext.asyncio import AsyncSession

from .. import idempotency
from ..db import get_session
from ..deps import api_error, get_current_player
from ..models import Player, Save, utcnow
from ..profile_utils import apply_payload_to_player
from ..schemas import SaveIn, SaveOut

router = APIRouter(tags=["save"])


def _out(save: Save) -> dict:
    return SaveOut(
        revision=save.revision,
        updated_at=save.updated_at,
        payload=save.payload if isinstance(save.payload, dict) else {},
        checksum=save.checksum,
    ).model_dump(mode="json")


@router.get("/save", response_model=SaveOut)
async def get_save(
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    save = await session.get(Save, player.id)
    if save is None:
        api_error(404, "save_not_found", "No cloud save exists for this player yet")
    return _out(save)


@router.put("/save", response_model=SaveOut)
async def put_save(
    payload: SaveIn,
    request: Request,
    idempotency_key: str | None = Header(default=None, alias="Idempotency-Key"),
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
):
    key = (idempotency_key or "").strip()[:80]
    request_hash = idempotency.body_hash(payload.model_dump(mode="json"))
    if key:
        stored = await idempotency.find(session, "save", player.id, key)
        if stored is not None:
            if stored.request_hash != request_hash:
                api_error(
                    409,
                    "idempotency_key_reused",
                    "This Idempotency-Key was already used with a different body",
                )
            return JSONResponse(content=stored.response, status_code=stored.status_code)

    save = await session.get(Save, player.id)
    if save is None:
        if payload.revision > 0:
            api_error(
                409,
                "save_missing",
                "The client has a revision but the server has no save",
                server_revision=0,
                server=None,
            )
        save = Save(
            player_id=player.id,
            revision=1,
            payload=payload.payload,
            checksum=payload.checksum,
        )
        session.add(save)
    else:
        if payload.revision != save.revision:
            api_error(
                409,
                "stale_revision",
                "Revision is stale; pull the server copy and merge",
                server_revision=save.revision,
                server=_out(save),
            )
        save.revision = int(save.revision) + 1
        save.payload = payload.payload
        save.checksum = payload.checksum
        save.updated_at = utcnow()

    apply_payload_to_player(player, payload.payload)
    player.last_seen_at = utcnow()
    await session.flush()
    response = _out(save)
    if key:
        await idempotency.remember(
            session, "save", player.id, key, request_hash, response, status_code=200
        )
    await session.commit()
    return response
