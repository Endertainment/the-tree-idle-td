"""Seed the local database with a realistic weekly cohort.

Usage (from ``server/``):
    python -m app.seed --players 60
    python -m app.seed --players 120 --week 2026-W44

Seeded players are marked with ``device_id = seed-device-NNN`` so the script is
idempotent: running it twice updates the same rows instead of duplicating them.
"""

from __future__ import annotations

import argparse
import asyncio
import random
import uuid
from datetime import datetime, timedelta, timezone

from sqlalchemy import select

from .db import get_session_factory, init_db
from .models import Player, utcnow
from .tournament_service import get_or_create_tournament, upsert_tournament_entry, upsert_weekly_entry

FIRST = ["Elandra", "Thorn", "Bramble", "Oaken", "Sylva", "Fen", "Rowan", "Moss", "Willow", "Ash"]
LAST = ["Warden", "Whisper", "Root", "Bloom", "Shade", "Keeper", "Grove", "Spire", "Fern", "Bark"]


def _player_name(index: int) -> str:
    return f"{FIRST[index % len(FIRST)]} {LAST[(index // len(FIRST)) % len(LAST)]}"


async def seed(players: int = 60, seed_value: int = 5, level_min: int = 12) -> dict:
    rng = random.Random(seed_value)
    await init_db()
    factory = get_session_factory()
    now = datetime.now(timezone.utc)
    created = 0
    updated = 0
    async with factory() as session:
        tournament = await get_or_create_tournament(session, now)
        for index in range(players):
            device_id = f"seed-device-{index:03d}"
            player = (
                await session.execute(select(Player).where(Player.device_id == device_id))
            ).scalar_one_or_none()
            if player is None:
                player = Player(
                    id=str(uuid.uuid4()),
                    device_id=device_id,
                    nickname=_player_name(index),
                    avatar_id=f"avatar_{index % 6 + 1:02d}",
                    level=max(level_min, rng.randint(level_min, 40)),
                )
                session.add(player)
                await session.flush()
                created += 1
            else:
                updated += 1
            waves = rng.randint(4, 55)
            duration = max(waves * 90, rng.randint(waves * 60, waves * 180))
            submitted_at = now - timedelta(minutes=rng.randint(0, 6 * 24 * 60))
            await upsert_weekly_entry(session, player.id, waves, duration, submitted_at, None)
            await upsert_tournament_entry(
                session, tournament, player.id, waves, duration, submitted_at, None
            )
        await session.commit()
    return {
        "players": players,
        "created": created,
        "updated": updated,
        "week_id": tournament.week_id,
        "tournament_id": tournament.id,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed leaderboard/tournament demo data")
    parser.add_argument("--players", type=int, default=60)
    parser.add_argument("--seed", type=int, default=5)
    args = parser.parse_args()
    summary = asyncio.run(seed(players=max(args.players, 1), seed_value=args.seed))
    print(f"[seed] week {summary['week_id']} tournament {summary['tournament_id']}")
    print(
        f"[seed] {summary['players']} players: {summary['created']} created, "
        f"{summary['updated']} updated"
    )


if __name__ == "__main__":
    main()
