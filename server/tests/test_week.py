"""Weekly reset math: Europe/Kyiv Monday 04:00 stored as UTC."""

from datetime import datetime, timedelta, timezone

from app.week import week_end_utc, week_id, week_start_utc

UTC = timezone.utc


def test_winter_boundary_is_0200_utc():
    # 2026-11-02 is a Monday; Kyiv is EET (UTC+2) after the Oct 25 DST change.
    before = datetime(2026, 11, 2, 1, 59, 59, tzinfo=UTC)
    after = datetime(2026, 11, 2, 2, 0, 0, tzinfo=UTC)
    assert week_start_utc(before) == datetime(2026, 10, 26, 2, 0, tzinfo=UTC)
    assert week_start_utc(after) == datetime(2026, 11, 2, 2, 0, tzinfo=UTC)
    assert week_id(before) == "2026-W44"
    assert week_id(after) == "2026-W45"
    assert week_end_utc(after) == datetime(2026, 11, 9, 2, 0, tzinfo=UTC)


def test_summer_boundary_is_0100_utc():
    # 2026-07-06 is a Monday; Kyiv is EEST (UTC+3) in July.
    before = datetime(2026, 7, 6, 0, 59, tzinfo=UTC)
    after = datetime(2026, 7, 6, 1, 0, tzinfo=UTC)
    assert week_start_utc(before) == datetime(2026, 6, 29, 1, 0, tzinfo=UTC)
    assert week_start_utc(after) == datetime(2026, 7, 6, 1, 0, tzinfo=UTC)
    assert week_id(before) == "2026-W27"
    assert week_id(after) == "2026-W28"


def test_every_instant_of_a_week_maps_to_one_start():
    start = datetime(2026, 10, 26, 2, 0, tzinfo=UTC)
    for hour in range(0, 168):
        moment = start + timedelta(hours=hour)
        assert week_start_utc(moment) == start
        assert week_id(moment) == "2026-W44"


def test_year_boundary_week_ids_are_iso():
    # 2027-01-01 (Friday) belongs to the week that started 2026-12-28.
    moment = datetime(2027, 1, 1, 12, 0, tzinfo=UTC)
    assert week_start_utc(moment) == datetime(2026, 12, 28, 2, 0, tzinfo=UTC)
    assert week_id(moment) == "2026-W53"
