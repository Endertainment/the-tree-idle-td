# The Tree — Backend (FastAPI + SQLAlchemy 2 async)

Backend for **The Tree: Idle Tower Defense**: guest accounts, cloud saves, weekly
leaderboard, tournaments, purchase/SSV stubs and analytics. The Godot client stays
fully playable offline; this service is additive.

- **Stack:** Python 3.11+, FastAPI, Pydantic v2, SQLAlchemy 2 async
- **Database:** SQLite (`aiosqlite`) by default for local work; PostgreSQL/Neon
  (`asyncpg`) by setting `DATABASE_URL` — no code changes
- **Auth:** short HS256 access token + rotating refresh token, `hashlib`/`secrets`
  only (no passlib/PyJWT dependency)
- **OpenAPI:** `/docs` (Swagger UI), `/openapi.json`
- **Contract details:** [`SPEC.md`](SPEC.md)

## Quick start (verified path: local venv + uvicorn)

Docker is not required. This is the path that was actually run:

```powershell
cd server
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".[test]"
copy .env.example .env                       # optional; defaults already work
.\.venv\Scripts\python.exe -m uvicorn app.main:app --host 127.0.0.1 --port 8000
```

Open <http://127.0.0.1:8000/docs>. The database file is `server/thetree.db`
(created on startup), seeded with real data via:

```powershell
.\.venv\Scripts\python.exe -m app.seed --players 60
```

### Docker path (machine-dependent)

`docker` was not installed in the build environment, so the container path is
provided but **not verified here**. With Docker available:

```powershell
cd server
docker compose up --build          # API on :8000 with a named SQLite volume
docker compose --profile postgres up --build   # + PostgreSQL on :5432
```

The image runs `uvicorn app.main:app` and healthchecks `/healthz`.

## Neon (PostgreSQL) setup

1. Create a Neon project and copy the **pooled** connection string, e.g.
   `postgresql://user:pass@ep-xxx-pooler.eu-central-1.aws.neon.tech/thetree?sslmode=require`.
2. Put it in `server/.env` (never committed):
   ```text
   DATABASE_URL=postgresql+asyncpg://user:pass@ep-xxx-pooler.eu-central-1.aws.neon.tech/thetree?ssl=require
   JWT_SECRET=<python -c "import secrets; print(secrets.token_urlsafe(48))">
   ```
   `postgres://`, `postgresql://` and `?sslmode=require` are normalised to
   `postgresql+asyncpg://` with an SSL context automatically.
3. Run the schema once (the app also creates tables on startup unless
   `AUTO_CREATE_TABLES=false`):
   ```powershell
   .\.venv\Scripts\python.exe -m alembic upgrade head
   ```
4. Start uvicorn with that environment; no code changes.

JSON columns become `JSONB` on PostgreSQL and `JSON` on SQLite (one
`with_variant` alias), so both backends share the same metadata.

## Migrations

- `alembic upgrade head` is the formal path. `alembic/versions/0001_initial.py`
  is the baseline generated from the SQLAlchemy metadata.
- The `create_all` bootstrap (`AUTO_CREATE_TABLES=true`, default) is convenient
  for local dev and tests. Disable it in production and run Alembic instead.
- After a model change: `alembic revision --autogenerate -m "describe change"`
  then review the generated file before applying.

## Tests and proofs

```powershell
# 31 pytest tests on an isolated SQLite file (httpx ASGI client)
.\.venv\Scripts\python.exe -m pytest

# Full stack proof: starts uvicorn on :8000, runs a stdlib client,
# prints PASS, always stops the server
cd ..
pwsh -File tools/api_e2e.ps1
```

The pytest suite covers: guest auth + refresh rotation, save 409/idempotency,
leaderboard ordering/own rank/pagination, tournament accept/reject + stored
rejection reason, week boundaries (winter/summer DST), events batch validation,
SSV signatures, purchases and URL normalisation.

## Configuration

| Variable | Default | Purpose |
|---|---|---|
| `DATABASE_URL` | `sqlite+aiosqlite:///./thetree.db` | Any SQLAlchemy async URL; Neon/Postgres supported |
| `JWT_SECRET` | dev value | HS256 signing key — **change in production** |
| `ACCESS_TOKEN_TTL_SECONDS` | `900` | Access token lifetime |
| `REFRESH_TOKEN_TTL_SECONDS` | `2592000` | Refresh token lifetime |
| `RUN_HMAC_SECRET` | empty | Enables required run signatures when set |
| `ADMOB_SSV_SECRET` | `dev-ssv-secret` | Shared secret for the SSV callback |
| `SSV_MAX_SKEW_SECONDS` | `600` | Reject stale SSV callbacks |
| `PURCHASES_MODE` | `stub` | `stub`, `disabled` (real verifier is a documented hook) |
| `RATE_LIMIT_ENABLED` | `true` | In-process sliding-window limiter |
| `REMOTE_CONFIG_JSON` | `{}` | JSON deep-merged over `/v1/config` defaults |
| `AUTO_CREATE_TABLES` | `true` | create_all bootstrap on startup |
| `TOURNAMENT_MIN_LEVEL` | `12` | Tournament eligibility |
| `TOURNAMENT_COHORT_SIZE` | `50` | Cohort grouping |
| `MAX_EVENTS_PER_BATCH` | `100` | Analytics batch limit |

## Endpoints

| Method | Path | Auth | Purpose |
|---|---|---|---|
| POST | `/v1/auth/guest` | — | `{device_id, nickname}` → tokens |
| POST | `/v1/auth/refresh` | — | Rotate access + refresh tokens |
| GET | `/v1/profile` | Bearer | Player, wallet/level/stats mirror |
| GET | `/v1/save` | Bearer | Save blob + revision |
| PUT | `/v1/save` | Bearer | Revision-checked save (409 stale), Idempotency-Key |
| GET | `/v1/config` | Bearer | Remote config (flags, ad frequency, balance) |
| GET | `/v1/leaderboard` | Bearer | `scope=weekly\|all_time\|tournament`, `limit`, `cursor` |
| GET | `/v1/tournaments/current` | Bearer | Tournament, cohort, eligibility, tiers |
| GET | `/v1/tournaments/current/standings` | Bearer | Cohort table + own percentile |
| POST | `/v1/tournaments/current/submit` | Bearer | Validated placement (422 on impossible run) |
| POST | `/v1/runs` | Bearer | Run telemetry (always 200; accepted flag + reason) |
| POST | `/v1/purchases/verify` | Bearer | Stub receipt verification, idempotent grant |
| POST | `/v1/ads/ssv` | Signed | AdMob SSV callback (no bearer token) |
| POST | `/v1/events` | optional Bearer | Batched analytics (≤100 events) |
| GET | `/healthz`, `/` | — | Health and service metadata |

A ready-to-run request collection is in [`api.http`](api.http).

## Known limits / stubs (honest list)

- **Purchase verification is a stub.** `PURCHASES_MODE=stub` accepts any
  non-empty token and records `verified_by=stub`; it does not talk to Google
  Play. `PURCHASES_MODE=disabled` returns 503. A real Play Developer API
  verifier is the next integration.
- **AdMob SSV uses a shared-secret HMAC**, not Google's ECDSA keys. This is a
  local/production stopgap with tests; the Google public-key verifier is a
  documented hook in `app/ssv.py`.
- **Rate limiting is in-process**, so it is per-worker. Put a shared limiter
  (Redis) in front before scaling to multiple workers.
- `missions_state` is created (contract) but no missions endpoints are exposed
  yet.
- No friends endpoint yet (`feature_flags.friends = false`).
- Events are pruned opportunistically after 90 days when a batch arrives.
- Weekly entries are keyed by `week_id`; the previous week's rows remain stored
  and are excluded from the current board (no duplicate ranks). There is no
  public endpoint for archived weeks yet.
