"""Tournament eligibility, accepted submission, rejection storage and standings."""

from __future__ import annotations

import uuid

from app.models import Run
from app.week import week_id


def _run(waves: int, duration_s: float, damage: int = 2_000_000, cash: int = 20_000) -> dict:
    return {
        "run_seed": f"seed-{uuid.uuid4()}",
        "waves": waves,
        "duration_s": duration_s,
        "damage": damage,
        "cash": cash,
    }


async def test_level_gate_blocks_low_level_players(client, guest):
    player = await guest("Sprout", level=5)
    response = await client.post(
        "/v1/tournaments/current/submit", json=_run(10, 400), headers=player["headers"]
    )
    assert response.status_code == 403
    detail = response.json()["detail"]
    assert detail["code"] == "level_too_low"
    assert detail["required_level"] == 12


async def test_accepted_submission_places_player(client, guest, db):
    first = await guest("Champion", level=13)
    second = await guest("RunnerUp", level=13)

    first_submit = await client.post(
        "/v1/tournaments/current/submit", json=_run(40, 2400), headers=first["headers"]
    )
    assert first_submit.status_code == 200, first_submit.text
    first_body = first_submit.json()
    assert first_body["accepted"] is True
    assert first_body["tournament_rank"] >= 1
    assert first_body["weekly_rank"] >= 1
    assert first_body["cohort_id"] is not None

    second_submit = await client.post(
        "/v1/tournaments/current/submit", json=_run(20, 1200), headers=second["headers"]
    )
    assert second_submit.status_code == 200, second_submit.text
    second_body = second_submit.json()
    assert second_body["cohort_id"] == first_body["cohort_id"]
    assert second_body["tournament_rank"] > first_body["tournament_rank"]

    current = await client.get("/v1/tournaments/current", headers=second["headers"])
    assert current.status_code == 200, current.text
    meta = current.json()
    assert meta["cohort_size"] == 50
    assert meta["eligible"] is True
    assert meta["min_level"] == 12
    assert meta["cohort_id"] == second_body["cohort_id"]
    assert len(meta["reward_tiers"]) == 5
    assert meta["ends_at"] > meta["starts_at"]
    assert meta["entries_count"] >= 2

    standings = await client.get("/v1/tournaments/current/standings", headers=first["headers"])
    assert standings.status_code == 200, standings.text
    table = standings.json()
    assert table["cohort_id"] == first_body["cohort_id"]
    assert table["total"] >= 2
    assert table["entries"][0]["max_wave"] >= table["entries"][-1]["max_wave"]
    assert table["own_rank"] == 1
    assert table["own_percentile"] is not None
    ranks = [row["rank"] for row in table["entries"]]
    assert ranks == list(range(1, len(ranks) + 1))


async def test_impossible_submission_is_rejected_and_stored(client, guest, db):
    player = await guest("Cheater", level=20)
    response = await client.post(
        "/v1/tournaments/current/submit",
        json=_run(100, 60, damage=1_000_000_000, cash=9_000_000),
        headers=player["headers"],
    )
    assert response.status_code == 422
    detail = response.json()["detail"]
    assert detail["code"] == "run_rejected"
    assert detail["reason"] == "duration_too_short_for_waves"
    run = await db.get(Run, detail["run_id"])
    assert run is not None
    assert run.accepted is False
    assert run.rejection_reason == "duration_too_short_for_waves"
    assert run.player_id == player["player_id"]
    assert run.week_id == week_id(run.created_at)
