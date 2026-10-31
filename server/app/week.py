"""Weekly reset math: Europe/Kyiv Monday 04:00, stored as UTC.

The reset is a *local wall-clock* boundary: it stays 04:00 through DST changes,
so the UTC instant moves between 01:00Z (summer, UTC+3) and 02:00Z (winter,
UTC+2). Week ids are ISO-8601 week labels (``2026-W44``) derived from the local
reset date, which keeps weeks contiguous across a year boundary.
"""

from __future__ import annotations

from datetime import datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

KYIV = ZoneInfo("Europe/Kyiv")
WEEK_RESET_HOUR = 4
WEEK_SECONDS = 7 * 24 * 3600


def as_utc(value: datetime) -> datetime:
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


def week_start_utc(now: datetime) -> datetime:
    """The UTC instant of the most recent Monday 04:00 Europe/Kyiv."""
    local = as_utc(now).astimezone(KYIV)
    shifted = local - timedelta(hours=WEEK_RESET_HOUR)
    monday = shifted.date() - timedelta(days=shifted.weekday())
    start_local = datetime.combine(monday, time(WEEK_RESET_HOUR, 0), tzinfo=KYIV)
    return start_local.astimezone(timezone.utc)


def week_end_utc(now: datetime) -> datetime:
    """The next reset instant (exclusive end of the current week)."""
    return week_start_utc(as_utc(now) + timedelta(days=7))


def week_id(now: datetime) -> str:
    """ISO week label of the local reset Monday, e.g. ``2026-W44``."""
    local_start = week_start_utc(now).astimezone(KYIV)
    iso = local_start.date().isocalendar()
    return f"{iso.year}-W{iso.week:02d}"


def week_bounds(now: datetime) -> tuple[datetime, datetime]:
    return week_start_utc(now), week_end_utc(now)
