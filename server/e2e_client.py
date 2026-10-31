"""End-to-end client for tools/api_e2e.ps1 (stdlib only, no project imports).

Flow: guest login -> PUT save -> GET leaderboard -> POST tournament submit.
Prints PASS with the observed ranks. Any failed assertion exits non-zero.
"""

from __future__ import annotations

import json
import os
import sys
import urllib.error
import urllib.request
import uuid

BASE_URL = os.environ.get("E2E_BASE_URL", "http://127.0.0.1:8000").rstrip("/")


def call(method: str, path: str, body: dict | None = None, headers: dict | None = None):
    data = json.dumps(body).encode("utf-8") if body is not None else None
    request_headers = {"Content-Type": "application/json", "Accept": "application/json"}
    request_headers.update(headers or {})
    request = urllib.request.Request(
        f"{BASE_URL}{path}", data=data, method=method, headers=request_headers
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            return response.status, json.loads(response.read().decode("utf-8"))
    except urllib.error.HTTPError as exc:
        raw = exc.read().decode("utf-8", errors="replace")
        try:
            parsed = json.loads(raw)
        except json.JSONDecodeError:
            parsed = {"raw": raw}
        return exc.code, parsed


def expect(condition: bool, message: str) -> None:
    if not condition:
        raise AssertionError(message)


def main() -> int:
    device_id = f"e2e-device-{uuid.uuid4()}"
    nickname = "E2E Gardener"

    status, guest = call(
        "POST", "/v1/auth/guest", {"device_id": device_id, "nickname": nickname}
    )
    expect(status == 200, f"guest login failed: {status} {guest}")
    token = guest["access_token"]
    player_id = guest["player_id"]
    auth = {"Authorization": f"Bearer {token}"}
    print(f"  guest login: player {player_id} (new={guest['is_new']})")

    payload = {
        "player": {
            "id": player_id,
            "nickname": nickname,
            "avatar_id": "avatar_02",
            "level": 13,
            "xp": 120,
            "created_at": 1760000000,
        },
        "wallet": {"coins": 12480, "gems": 350, "stones": 0},
        "stats": {"best_wave": 24, "runs_played": 3, "week_id": "e2e"},
        "is_onboarded": True,
    }
    idempotency_key = str(uuid.uuid4())
    save_headers = {**auth, "Idempotency-Key": idempotency_key}
    status, saved = call(
        "PUT", "/v1/save", {"revision": 0, "payload": payload, "checksum": "sha256:e2e"}, save_headers
    )
    expect(status == 200, f"save put failed: {status} {saved}")
    expect(saved["revision"] == 1, f"expected revision 1, got {saved['revision']}")
    print(f"  save put: revision {saved['revision']}")

    # Idempotent replay must not create revision 2.
    status, replay = call(
        "PUT", "/v1/save", {"revision": 0, "payload": payload, "checksum": "sha256:e2e"}, save_headers
    )
    expect(status == 200 and replay["revision"] == 1, f"idempotent replay broke: {replay}")
    print("  save replay: revision stayed 1")

    status, profile = call("GET", "/v1/profile", headers=auth)
    expect(status == 200 and profile["level"] == 13, f"profile sync failed: {profile}")
    print(f"  profile: level {profile['level']}, coins {profile['wallet']['coins']}")

    status, board = call("GET", "/v1/leaderboard?scope=weekly&limit=100", headers=auth)
    expect(status == 200, f"leaderboard failed: {status} {board}")
    expect(board["scope"] == "weekly", "leaderboard scope mismatch")
    print(f"  leaderboard: week {board['week_id']}, {board['total']} entries")

    run = {
        "run_seed": f"e2e-seed-{uuid.uuid4()}",
        "waves": 24,
        "duration_s": 900,
        "damage": 3_500_000,
        "cash": 42_000,
        "playtime_s": 900,
    }
    status, submitted = call("POST", "/v1/tournaments/current/submit", run, auth)
    expect(status == 200, f"tournament submit failed: {status} {submitted}")
    expect(submitted["accepted"] is True, "tournament rejected a plausible run")
    print(
        "  tournament submit: "
        f"cohort {submitted['cohort_id']}, tournament rank {submitted['tournament_rank']}, "
        f"weekly rank {submitted['weekly_rank']}"
    )

    status, standings = call("GET", "/v1/tournaments/current/standings", headers=auth)
    expect(status == 200, f"standings failed: {status} {standings}")
    expect(standings["own_rank"] == submitted["tournament_rank"], "standings own rank mismatch")
    print(f"  standings: {standings['total']} in cohort, own percentile {standings['own_percentile']}")

    status, board_after = call("GET", "/v1/leaderboard?scope=weekly&limit=100", headers=auth)
    expect(status == 200 and board_after["own_entry"] is not None, "own leaderboard entry missing")
    expect(board_after["own_entry"]["max_wave"] == 24, "weekly best wave not updated")
    print(
        f"  leaderboard after run: own rank {board_after['own_rank']}, "
        f"best wave {board_after['own_entry']['max_wave']}"
    )

    print("PASS: guest login -> save put -> leaderboard get -> tournament submit")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except AssertionError as exc:
        print(f"FAIL: {exc}", file=sys.stderr)
        sys.exit(1)
    except Exception as exc:  # connection refused and friends
        print(f"FAIL: {type(exc).__name__}: {exc}", file=sys.stderr)
        sys.exit(1)
