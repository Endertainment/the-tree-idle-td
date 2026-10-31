"""Weekly/all-time leaderboard ordering, pagination and own rank."""

from __future__ import annotations


def _run(waves: int, duration_s: float = 1800.0) -> dict:
    return {
        "run_seed": "test-seed",
        "waves": waves,
        "duration_s": duration_s,
        "damage": 2_000_000,
        "cash": 20_000,
    }


async def test_weekly_ordering_and_own_rank(client, guest):
    low = await guest("Low")
    high = await guest("High")
    for player, waves, duration in ((low, 30, 1800.0), (high, 60, 3600.0)):
        response = await client.post(
            "/v1/runs", json=_run(waves, duration), headers=player["headers"]
        )
        assert response.status_code == 200, response.text
        assert response.json()["accepted"] is True

    board = await client.get("/v1/leaderboard?scope=weekly", headers=high["headers"])
    assert board.status_code == 200, board.text
    data = board.json()
    assert data["scope"] == "weekly"
    assert data["week_id"].startswith("20")
    assert data["total"] >= 2
    ranks = [entry["rank"] for entry in data["entries"]]
    assert ranks == list(range(1, len(ranks) + 1))
    ids = [entry["player_id"] for entry in data["entries"]]
    assert ids.index(high["player_id"]) < ids.index(low["player_id"])
    own = data["own_entry"]
    assert own is not None and own["is_player"] is True
    assert own["player_id"] == high["player_id"]
    assert own["rank"] == data["own_rank"]
    assert own["max_wave"] == 60
    assert own["nickname"] == "High"


async def test_pagination_cursor(client, guest):
    player = await guest("Pager")
    await client.post("/v1/runs", json=_run(10, 600.0), headers=player["headers"])
    first = await client.get("/v1/leaderboard?scope=weekly&limit=1", headers=player["headers"])
    assert first.status_code == 200
    body = first.json()
    assert len(body["entries"]) == 1
    assert body["next_cursor"], "there must be more rows for this test to be meaningful"
    second = await client.get(
        f"/v1/leaderboard?scope=weekly&limit=1&cursor={body['next_cursor']}",
        headers=player["headers"],
    )
    assert second.status_code == 200
    assert second.json()["entries"][0]["rank"] == 2
    assert second.json()["entries"][0]["player_id"] != body["entries"][0]["player_id"]

    invalid = await client.get(
        "/v1/leaderboard?scope=weekly&cursor=not-a-cursor", headers=player["headers"]
    )
    assert invalid.status_code == 400
    assert invalid.json()["detail"]["code"] == "invalid_cursor"

    bad_scope = await client.get("/v1/leaderboard?scope=daily", headers=player["headers"])
    assert bad_scope.status_code == 400


async def test_all_time_and_tournament_scopes(client, guest):
    player = await guest("Scoper")
    await client.post("/v1/runs", json=_run(25, 1500.0), headers=player["headers"])
    all_time = await client.get("/v1/leaderboard?scope=all_time", headers=player["headers"])
    assert all_time.status_code == 200, all_time.text
    body = all_time.json()
    assert body["scope"] == "all_time"
    own = body["own_entry"]
    assert own is not None and own["max_wave"] == 25
    assert body["own_rank"] >= 1

    tournament = await client.get("/v1/leaderboard?scope=tournament", headers=player["headers"])
    assert tournament.status_code == 200, tournament.text
    assert tournament.json()["scope"] == "tournament"
