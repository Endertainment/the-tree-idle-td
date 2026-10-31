"""Player profile (player + wallet/level/stats mirror)."""

from __future__ import annotations

from fastapi import APIRouter, Depends
from sqlalchemy.ext.asyncio import AsyncSession

from ..db import get_session
from ..deps import get_current_player
from ..models import Player, Save
from ..profile_utils import profile_dict
from ..schemas import ProfileOut

router = APIRouter(tags=["profile"])


@router.get("/profile", response_model=ProfileOut)
async def get_profile(
    player: Player = Depends(get_current_player),
    session: AsyncSession = Depends(get_session),
) -> dict:
    save = await session.get(Save, player.id)
    return profile_dict(player, save)
