# The Tree API — implementation contract (M7)

This file documents the **implemented** behaviour; `docs/AI_BUILD_PROMPT.md §8.5`
is the source contract. Base URL: `/v1`. JSON in, JSON out. All endpoints except
the ones marked *public* require `Authorization: Bearer <access_token>`.

Error shape:

```json
{"detail": {"code": "stale_revision", "message": "…", "server": {"…": "…"}}}
```

Clients should branch on `detail.code`, never on the message.

---

## 1. Authentication

### `POST /auth/guest` — public

```json
{"device_id": "uuid-or-device-token", "nickname": "Vova", "avatar_id": "avatar_02"}
```

`device_id` is unique; calling again with the same id returns the same player and
rotates tokens (`is_new: false`). Response:

```json
{
  "player_id": "uuid",
  "access_token": "jwt",
  "refresh_token": "jwt",
  "token_type": "bearer",
  "expires_in": 900,
  "refresh_expires_in": 2592000,
  "is_new": true,
  "nickname": "Vova"
}
```

Tokens are HS256 JWTs signed with `JWT_SECRET`:
`{sub, typ: "access"|"refresh", iat, exp, jti}`. The refresh token's SHA-256 is
stored in `players.refresh_token_hash`; **rotation invalidates the previous one**.

### `POST /auth/refresh` — public

```json
{"refresh_token": "…"}
```

Returns a new token pair. Errors: `401 malformed_token`, `401 invalid_signature`,
`401 token_expired`, `401 wrong_token_type`, `401 refresh_revoked`,
`401 refresh_expired`. A revoked/expired refresh token requires a new guest login.

---

## 2. Profile and cloud save

### `GET /profile`

Returns the players row plus the display fields mirrored from the latest save:

```json
{
  "player_id": "uuid", "nickname": "Vova", "avatar_id": "avatar_02",
  "level": 13, "xp": 320, "provider": null, "is_guest": true,
  "created_at": "2026-10-31T08:00:00Z", "last_seen_at": "…", "save_revision": 7,
  "wallet": {"coins": 12480, "gems": 350, "stones": 0},
  "stats": {"best_wave": 24, "runs_played": 42, "total_kills": 9120,
            "total_playtime": 5400, "weekly_max_wave": 24, "week_id": "2026-W44"}
}
```

`PUT /save` refreshes `nickname`, `avatar_id`, `level`, `xp` from
`payload.player`. The save payload itself stays opaque JSON — the server never
recomputes the client's economy.

### `GET /save`

`200` with `{revision, updated_at, payload, checksum}` or `404 save_not_found`.

### `PUT /save`

```json
{"revision": 3, "payload": {…full save document…}, "checksum": "sha256:…"}
```

- No server save + `revision: 0` → creates revision **1**.
- No server save + `revision > 0` → `409 save_missing`.
- `revision != current` → `409 stale_revision`, response detail includes
  `server_revision` and `server` (the full current save) for a pull/merge.
- Match → writes `revision + 1`, returns `{revision, updated_at, payload, checksum}`.
- `checksum` is stored for auditing; the server does not re-derive it because
  the client's canonical JSON is a client concern.

**Idempotency:** an `Idempotency-Key` header (≤80 chars) stores the successful
response in `idempotency_keys`. Replaying the same key + same body returns the
stored response without incrementing the revision. Same key + different body →
`409 idempotency_key_reused`. Keys are scoped per player and operation.

---

## 3. Remote config

### `GET /config`

Built-in defaults are deep-merged with the `REMOTE_CONFIG_JSON` env override
(dicts merge, lists replace), then decorated with server time:

```json
{
  "version": 1,
  "feature_flags": {"tournaments": true, "weekly_leaderboard": true,
                    "cloud_saves": true, "remote_config": true,
                    "ads": true, "iap": true, "friends": false},
  "ad_frequency": {"rewarded_daily_cap": 8, "interstitial_every_runs": 3,
                   "interstitial_min_interval_s": 120, "interstitial_min_wave": 5},
  "balance_overrides": {},
  "shop_catalog_version": 1,
  "min_client_version": "0.8.0",
  "server_time": "…", "week_id": "2026-W44", "week_resets_at": "…",
  "tournament": {"min_level": 12, "cohort_size": 50, "starts_at": "2026-W44"},
  "purchases_mode": "stub"
}
```

---

## 4. Leaderboard

### `GET /leaderboard?scope=weekly&limit=100&cursor=`

- `scope`: `weekly` (default), `all_time`, `tournament`.
- `limit`: 1–200, default 100.
- `cursor`: opaque `next_cursor` from the previous page. Invalid → `400 invalid_cursor`.
- Ordering (normative §6.7): `max_wave` desc → earlier `submitted_at` → lower
  `playtime_s` → `player_id` (deterministic total order).
- `weekly` uses the current `week_id`; `all_time` uses each player's best row;
  `tournament` uses the player's cohort (or `c0` when they have no entry).
- `own_rank` is computed against the **whole** ordered board, not only the page;
  it is `null` when the player has no entry. `own_entry` is the same row DTO.

```json
{
  "scope": "weekly", "week_id": "2026-W44",
  "entries": [{"rank": 1, "player_id": "…", "nickname": "Elandra",
               "avatar_id": "avatar_02", "max_wave": 42, "playtime_s": 3600,
               "submitted_at": "…", "is_player": false}],
  "own_rank": 7, "own_entry": {"…": "…"}, "total": 61,
  "next_cursor": "b2Zmc2V0OjEwMA==", "updated_at": "…"
}
```

---

## 5. Tournaments

Weekly, aligned to the same reset as the leaderboard. A tournament row is created
lazily for the current `week_id`; players are assigned to the **first cohort with
fewer than 50 entries** (`c0`, `c1`, …).

### `GET /tournaments/current`

`{tournament_id, week_id, starts_at, ends_at, cohort_size, cohort_id, eligible,
min_level, entries_count, own_entry, reward_tiers}`. Eligibility is
`player.level >= TOURNAMENT_MIN_LEVEL` (12).

### `GET /tournaments/current/standings`

`{tournament_id, week_id, cohort_id, entries, own_rank, own_percentile, total,
ends_at, updated_at}`. `own_percentile = 100 * rank / total` (2 decimals).

Reward tiers (percentile → stones): top 1 % → 100, top 10 % → 40, top 25 % → 20,
top 50 % → 10, participation → 5. The server returns the tiers, not the grant.

### `POST /tournaments/current/submit`

```json
{"run_seed": "seed", "waves": 24, "duration_s": 900, "damage": 3500000,
 "cash": 42000, "signature": "optional-hex", "playtime_s": 900}
```

- Level < 12 → `403 level_too_low` (`required_level`, `level`).
- Signature mismatch (when `RUN_HMAC_SECRET` is set) → `403 bad_signature`.
- Implausible ratios → `422 run_rejected` with `reason` and `run_id`.
  **Every** submission is stored in `runs` including rejected ones.
- Accepted → upserts the weekly leaderboard row and the tournament entry when the
  wave total improves; returns `{accepted, run_id, week_id, weekly_rank,
  tournament_rank, cohort_id}`.

### Anti-cheat rules (`app/anticheat.py`)

| Rule | Bound | Reason code |
|---|---|---|
| Duration positive | `duration_s > 0` | `invalid_duration` |
| Non-negative values | waves/damage/cash ≥ 0 | `negative_values` |
| Wave cap | `waves ≤ 10 000` | `waves_too_high` |
| Minimum pace | `duration_s ≥ waves × 20 s` | `duration_too_short_for_waves` |
| Waves per minute | `waves / (duration_s/60) ≤ 2.5` | `waves_per_minute_exceeded` |
| Damage per second | `damage / duration_s ≤ 250 000` | `damage_per_second_exceeded` |
| Cash | `cash ≤ waves × 250 000` | `cash_per_wave_exceeded` |

Run signature (when enabled): hex HMAC-SHA256 over
`"{run_seed}|{waves}|{round(duration_s)}|{damage}|{cash}"` with
`RUN_HMAC_SECRET`. Empty secret = development mode (signature optional, stored).

### `POST /runs`

Same body and validation, but returns `200` with `{accepted, rejection_reason,
run_id, week_id, weekly_rank}` — telemetry must never break a client. Accepted
runs update the weekly board; they do **not** enter the tournament.

---

## 6. Purchases

### `POST /purchases/verify`

```json
{"product_id": "thetree.gems_100", "purchase_token": "token", "platform": "google"}
```

Stub mode (`PURCHASES_MODE=stub`) accepts any non-empty token for one of the
seven §7.3 products and marks `verified_by: "stub"`. Idempotent by
`purchase_token` (unique index): a repeat returns `status: "already_granted"`
with the same `grant_id`; another player’s token → `409 purchase_token_conflict`;
unknown product → `422 unknown_product`; `PURCHASES_MODE=disabled` → `503`.
A real Play/App Store verifier replaces the stub and should write the same table.

---

## 7. AdMob SSV callback

### `POST /ads/ssv` — public, query parameters

AdMob sends `transaction_id, signature, user_id, custom_data, timestamp,
reward_amount, reward_item, ad_unit, ad_network, key_id`.

Signature (this deployment’s stopgap, documented in `app/ssv.py`):

```
hex(HMAC-SHA256(ADMOB_SSV_SECRET,
    transaction_id + "|" + user_id + "|" + custom_data + "|" + reward_amount + "|" + timestamp))
```

`signature` may be prefixed with `hmac:`. Failures: `403 invalid_signature`,
`403 stale_callback` (`|now - timestamp| > SSV_MAX_SKEW_SECONDS`),
`422 missing_ssv_parameters`, `503 ssv_disabled` (empty secret). The callback is
idempotent by `transaction_id` (stored as `events.external_id`); a repeat returns
`{"ok": true, "duplicate": true}`. A GET route is also accepted for AdMob but is
not shown in OpenAPI.

---

## 8. Analytics

### `POST /events`

```json
{"events": [{"name": "app_open", "props": {"version": "0.8.0"}, "client_ts": 1761800000}]}
```

- 1–`MAX_EVENTS_PER_BATCH` (100) events; empty → `422 empty_batch`; too many →
  `422 batch_too_large`.
- Names must match `^[a-z][a-z0-9_]{0,63}$` → `422 invalid_event_name`.
- Props must be scalar (string ≤120 chars, number, bool, null), ≤32 keys →
  `422 invalid_props` for nested objects.
- `Authorization` is optional: a valid token attaches `player_id`; otherwise the
  event is stored anonymously.
- Returns `{accepted, dropped, pruned}`. Events older than 90 days are pruned at
  most once per hour.

---

## 9. Weekly reset (normative)

Europe/Kyiv, **Monday 04:00 local time**, stored as UTC. The reset follows local
wall-clock time across DST:

| Period | Local offset | Reset instant (UTC) |
|---|---|---|
| Summer (EEST) | UTC+3 | Monday **01:00Z** |
| Winter (EET) | UTC+2 | Monday **02:00Z** |

`week_id` is the ISO week of the reset Monday, e.g. `2026-W44`. `week_start_utc`
implements: take local time, subtract 4 h, take that date's Monday, combine with
04:00 Kyiv, convert to UTC. `week_end_utc(now) = week_start_utc(now + 7 days)`,
which keeps the boundary correct through DST.

On a new week, the current board queries a new `week_id`; previous rows remain
and are never ranked with the new week, so no duplicate ranks appear.

---

## 10. Database schema

| Table | Key columns |
|---|---|
| `players` | `id` uuid PK, `device_id` unique, nickname/avatar/level/xp, provider fields, `refresh_token_hash`, `refresh_expires_at`, timestamps |
| `saves` | `player_id` PK/FK, `revision`, `payload` (JSONB/JSON), `checksum`, `updated_at` |
| `runs` | id, `player_id`, run stats, `signature`, `accepted`, `rejection_reason`, `week_id`, `created_at` |
| `leaderboard_entries` | unique (`week_id`, `player_id`), `max_wave`, `playtime_s`, `submitted_at`, `run_id` |
| `tournaments` | unique `week_id`, `starts_at`, `ends_at`, `cohort_size` |
| `tournament_entries` | unique (`tournament_id`, `player_id`), `cohort_id`, `max_wave`, `playtime_s`, `submitted_at`, `best_run_id` |
| `purchases` | unique `purchase_token`, product, platform, status, `grant_id`, `verified_by`, raw |
| `events` | name, props JSON, `client_ts`, `external_id` unique (SSV), `server_ts` |
| `idempotency_keys` | unique (`scope`, `player_id`, `key`), `request_hash`, stored response |
| `missions_state` | reserved for server-driven missions |

All tables are also created by the Alembic baseline; see README.

## 11. Limits and operational notes

- Rate limits (per process): guest 30/min/IP, refresh 60/min/IP, submits
  30/min/player, runs 60/min/player, purchases 30/min/player, events unlimited
  beyond the batch size.
- CORS is permissive for tooling; the Godot client is native.
- Tokens must never be logged or written into the save file; the client stores
  them in `user://auth.json`.
- The server is authoritative for placement and purchase grants. The client
  never decides a rank.

## 12. Deliberate deviations from §8.5

- `POST /runs` always returns `200` (accepted flag) rather than 4xx so optional
  telemetry cannot break the client; tournament submission is the strict path.
- `idempotency_keys` and `missions_state` are extra tables (the latter required
  by the contract, the former needed for retried saves/purchases).
- Purchase and SSV verification are explicit stubs (no credentials in this
  environment). They are isolated in one module each so a real verifier is a
  single-file change.
- Alembic's baseline is generated from metadata instead of hand-written DDL to
  avoid drift; future revisions should be autogenerated.
