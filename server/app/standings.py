"""Server-side leaderboard queries: ordering, pagination and own rank.

Ordering is normative (spec 6.7): ``max_wave`` descending, then earlier
submission, then lower play time, then player id for a deterministic total order.
"""

from __future__ import annotations

import base64
import binascii
from datetime import datetime, timezone

from sqlalchemy import and_, func, or_, select
from sqlalchemy.ext.asyncio import AsyncSession

from .models import LeaderboardEntry, Player, TournamentEntry
from .week import week_id as current_week_id

MAX_LIMIT = 200
DEFAULT_LIMIT = 100


def clamp_limit(limit: int) -> int:
    return max(1, min(int(limit), MAX_LIMIT))


def encode_cursor(offset: int) -> str:
    return base64.urlsafe_b64encode(f"offset:{offset}".encode("ascii")).decode("ascii")


def decode_cursor(cursor: str | None) -> int:
    if not cursor:
        return 0
    try:
        raw = base64.urlsafe_b64decode(cursor.encode("ascii")).decode("ascii")
        if not raw.startswith("offset:"):
            raise ValueError
        return max(int(raw.split(":", 1)[1]), 0)
    except (ValueError, binascii.Error, UnicodeDecodeError) as exc:
        from .deps import api_error

        api_error(400, "invalid_cursor", "cursor is not a cursor returned by this endpoint")
        raise exc  # unreachable; keeps type checkers happy


def _weekly_base(week: str):
    return (
        select(
            LeaderboardEntry.player_id,
            LeaderboardEntry.max_wave,
            LeaderboardEntry.playtime_s,
            LeaderboardEntry.submitted_at,
            Player.nickname,
            Player.avatar_id,
        )
        .join(Player, Player.id == LeaderboardEntry.player_id)
        .where(LeaderboardEntry.week_id == week)
    )


def _weekly_order(statement):
    return statement.order_by(
        LeaderboardEntry.max_wave.desc(),
        LeaderboardEntry.submitted_at.asc(),
        LeaderboardEntry.playtime_s.asc(),
        LeaderboardEntry.player_id.asc(),
    )


def _row_to_entry(row, rank: int, player_id: str) -> dict:
    mapping = row._mapping
    return {
        "rank": rank,
        "player_id": str(mapping["player_id"]),
        "nickname": str(mapping["nickname"]),
        "avatar_id": str(mapping["avatar_id"]),
        "max_wave": int(mapping["max_wave"]),
        "playtime_s": int(mapping.get("playtime_s", 0) or 0),
        "submitted_at": mapping["submitted_at"],
        "is_player": str(mapping["player_id"]) == player_id,
    }


async def weekly_page(
    session: AsyncSession, week: str, player_id: str, limit: int, offset: int
) -> dict:
    total = int(
        (
            await session.execute(
                select(func.count()).select_from(LeaderboardEntry).where(LeaderboardEntry.week_id == week)
            )
        ).scalar_one()
    )
    rows = (
        await session.execute(_weekly_order(_weekly_base(week)).offset(offset).limit(limit))
    ).all()
    entries = [_row_to_entry(row, offset + index + 1, player_id) for index, row in enumerate(rows)]
    own = await weekly_own(session, week, player_id)
    return {
        "scope": "weekly",
        "week_id": week,
        "entries": entries,
        "own_rank": own["rank"] if own else None,
        "own_entry": own,
        "total": total,
        "next_cursor": encode_cursor(offset + len(entries)) if offset + len(entries) < total else None,
        "updated_at": datetime.now(timezone.utc),
    }


async def weekly_own(session: AsyncSession, week: str, player_id: str) -> dict | None:
    row = (
        await session.execute(
            select(
                LeaderboardEntry.player_id,
                LeaderboardEntry.max_wave,
                LeaderboardEntry.playtime_s,
                LeaderboardEntry.submitted_at,
                Player.nickname,
                Player.avatar_id,
            )
            .join(Player, Player.id == LeaderboardEntry.player_id)
            .where(LeaderboardEntry.week_id == week, LeaderboardEntry.player_id == player_id)
        )
    ).first()
    if row is None:
        return None
    own = row._mapping
    better = or_(
        LeaderboardEntry.max_wave > own["max_wave"],
        and_(
            LeaderboardEntry.max_wave == own["max_wave"],
            LeaderboardEntry.submitted_at < own["submitted_at"],
        ),
        and_(
            LeaderboardEntry.max_wave == own["max_wave"],
            LeaderboardEntry.submitted_at == own["submitted_at"],
            LeaderboardEntry.playtime_s < own["playtime_s"],
        ),
        and_(
            LeaderboardEntry.max_wave == own["max_wave"],
            LeaderboardEntry.submitted_at == own["submitted_at"],
            LeaderboardEntry.playtime_s == own["playtime_s"],
            LeaderboardEntry.player_id < player_id,
        ),
    )
    better_count = int(
        (
            await session.execute(
                select(func.count())
                .select_from(LeaderboardEntry)
                .where(LeaderboardEntry.week_id == week, better)
            )
        ).scalar_one()
    )
    return _row_to_entry(row, better_count + 1, player_id)


def _all_time_best_subquery():
    ranked = (
        select(
            LeaderboardEntry.player_id.label("player_id"),
            LeaderboardEntry.max_wave.label("max_wave"),
            LeaderboardEntry.playtime_s.label("playtime_s"),
            LeaderboardEntry.submitted_at.label("submitted_at"),
            func.row_number()
            .over(
                partition_by=LeaderboardEntry.player_id,
                order_by=(
                    LeaderboardEntry.max_wave.desc(),
                    LeaderboardEntry.submitted_at.asc(),
                    LeaderboardEntry.playtime_s.asc(),
                    LeaderboardEntry.player_id.asc(),
                ),
            )
            .label("row_number"),
        )
        .subquery()
    )
    return select(ranked).where(ranked.c.row_number == 1).subquery()


async def all_time_page(
    session: AsyncSession, player_id: str, limit: int, offset: int
) -> dict:
    best = _all_time_best_subquery()
    base = (
        select(
            best.c.player_id,
            best.c.max_wave,
            best.c.playtime_s,
            best.c.submitted_at,
            Player.nickname,
            Player.avatar_id,
        )
        .join(Player, Player.id == best.c.player_id)
        .order_by(
            best.c.max_wave.desc(),
            best.c.submitted_at.asc(),
            best.c.playtime_s.asc(),
            best.c.player_id.asc(),
        )
    )
    total = int((await session.execute(select(func.count()).select_from(best))).scalar_one())
    rows = (await session.execute(base.offset(offset).limit(limit))).all()
    entries = [_row_to_entry(row, offset + index + 1, player_id) for index, row in enumerate(rows)]
    own = await _all_time_own(session, best, player_id)
    return {
        "scope": "all_time",
        "week_id": current_week_id(datetime.now(timezone.utc)),
        "entries": entries,
        "own_rank": own["rank"] if own else None,
        "own_entry": own,
        "total": total,
        "next_cursor": encode_cursor(offset + len(entries)) if offset + len(entries) < total else None,
        "updated_at": datetime.now(timezone.utc),
    }


async def _all_time_own(session: AsyncSession, best, player_id: str) -> dict | None:
    row = (
        await session.execute(
            select(
                best.c.player_id,
                best.c.max_wave,
                best.c.playtime_s,
                best.c.submitted_at,
                Player.nickname,
                Player.avatar_id,
            )
            .join(Player, Player.id == best.c.player_id)
            .where(best.c.player_id == player_id)
        )
    ).first()
    if row is None:
        return None
    own = row._mapping
    better = or_(
        best.c.max_wave > own["max_wave"],
        and_(best.c.max_wave == own["max_wave"], best.c.submitted_at < own["submitted_at"]),
        and_(
            best.c.max_wave == own["max_wave"],
            best.c.submitted_at == own["submitted_at"],
            best.c.playtime_s < own["playtime_s"],
        ),
        and_(
            best.c.max_wave == own["max_wave"],
            best.c.submitted_at == own["submitted_at"],
            best.c.playtime_s == own["playtime_s"],
            best.c.player_id < player_id,
        ),
    )
    better_count = int(
        (await session.execute(select(func.count()).select_from(best).where(better))).scalar_one()
    )
    return _row_to_entry(row, better_count + 1, player_id)


def _tournament_base(tournament_id: str, cohort_id: str):
    return (
        select(
            TournamentEntry.player_id,
            TournamentEntry.max_wave,
            TournamentEntry.playtime_s,
            TournamentEntry.submitted_at,
            Player.nickname,
            Player.avatar_id,
        )
        .join(Player, Player.id == TournamentEntry.player_id)
        .where(
            TournamentEntry.tournament_id == tournament_id,
            TournamentEntry.cohort_id == cohort_id,
        )
    )


def _tournament_order(statement):
    return statement.order_by(
        TournamentEntry.max_wave.desc(),
        TournamentEntry.submitted_at.asc(),
        TournamentEntry.playtime_s.asc(),
        TournamentEntry.player_id.asc(),
    )


async def tournament_page(
    session: AsyncSession,
    tournament_id: str,
    cohort_id: str,
    player_id: str,
    limit: int = MAX_LIMIT,
    offset: int = 0,
) -> dict:
    total = int(
        (
            await session.execute(
                select(func.count())
                .select_from(TournamentEntry)
                .where(
                    TournamentEntry.tournament_id == tournament_id,
                    TournamentEntry.cohort_id == cohort_id,
                )
            )
        ).scalar_one()
    )
    rows = (
        await session.execute(
            _tournament_order(_tournament_base(tournament_id, cohort_id)).offset(offset).limit(limit)
        )
    ).all()
    entries = [_row_to_entry(row, offset + index + 1, player_id) for index, row in enumerate(rows)]
    own = await tournament_own(session, tournament_id, cohort_id, player_id)
    return {
        "entries": entries,
        "own_rank": own["rank"] if own else None,
        "own_entry": own,
        "total": total,
        "next_cursor": encode_cursor(offset + len(entries)) if offset + len(entries) < total else None,
    }


async def tournament_own(
    session: AsyncSession, tournament_id: str, cohort_id: str, player_id: str
) -> dict | None:
    row = (
        await session.execute(
            select(
                TournamentEntry.player_id,
                TournamentEntry.max_wave,
                TournamentEntry.playtime_s,
                TournamentEntry.submitted_at,
                Player.nickname,
                Player.avatar_id,
            )
            .join(Player, Player.id == TournamentEntry.player_id)
            .where(
                TournamentEntry.tournament_id == tournament_id,
                TournamentEntry.cohort_id == cohort_id,
                TournamentEntry.player_id == player_id,
            )
        )
    ).first()
    if row is None:
        return None
    own = row._mapping
    better = or_(
        TournamentEntry.max_wave > own["max_wave"],
        and_(
            TournamentEntry.max_wave == own["max_wave"],
            TournamentEntry.submitted_at < own["submitted_at"],
        ),
        and_(
            TournamentEntry.max_wave == own["max_wave"],
            TournamentEntry.submitted_at == own["submitted_at"],
            TournamentEntry.playtime_s < own["playtime_s"],
        ),
        and_(
            TournamentEntry.max_wave == own["max_wave"],
            TournamentEntry.submitted_at == own["submitted_at"],
            TournamentEntry.playtime_s == own["playtime_s"],
            TournamentEntry.player_id < player_id,
        ),
    )
    better_count = int(
        (
            await session.execute(
                select(func.count())
                .select_from(TournamentEntry)
                .where(
                    TournamentEntry.tournament_id == tournament_id,
                    TournamentEntry.cohort_id == cohort_id,
                    better,
                )
            )
        ).scalar_one()
    )
    return _row_to_entry(row, better_count + 1, player_id)
