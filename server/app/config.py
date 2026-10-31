"""Runtime settings for The Tree backend.

All configuration comes from environment variables so the same image runs with
SQLite locally and PostgreSQL/Neon in production without code changes.
"""

from __future__ import annotations

import json
import os
import ssl
from dataclasses import dataclass, field
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

DEFAULT_DATABASE_URL = "sqlite+aiosqlite:///./thetree.db"
DEFAULT_REMOTE_CONFIG: dict = {
    "version": 1,
    "feature_flags": {
        "tournaments": True,
        "weekly_leaderboard": True,
        "cloud_saves": True,
        "remote_config": True,
        "ads": True,
        "iap": True,
        "friends": False,
    },
    "ad_frequency": {
        "rewarded_daily_cap": 8,
        "interstitial_every_runs": 3,
        "interstitial_min_interval_s": 120,
        "interstitial_min_wave": 5,
    },
    "balance_overrides": {},
    "shop_catalog_version": 1,
    "min_client_version": "0.8.0",
}


def _env_bool(name: str, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _env_int(name: str, default: int) -> int:
    raw = os.environ.get(name)
    if raw is None or raw.strip() == "":
        return default
    return int(raw)


def _parse_json_object(name: str) -> dict:
    raw = os.environ.get(name, "").strip()
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError as exc:  # fail fast: a typo must not be silent
        raise ValueError(f"{name} must contain valid JSON: {exc}") from exc
    if not isinstance(value, dict):
        raise ValueError(f"{name} must be a JSON object")
    return value


@dataclass(frozen=True)
class Settings:
    database_url: str = DEFAULT_DATABASE_URL
    jwt_secret: str = "dev-insecure-secret-change-me"
    access_token_ttl_seconds: int = 900
    refresh_token_ttl_seconds: int = 2_592_000
    run_hmac_secret: str = ""
    admob_ssv_secret: str = "dev-ssv-secret"
    ssv_max_skew_seconds: int = 600
    purchases_mode: str = "stub"
    rate_limit_enabled: bool = True
    remote_config_json: dict = field(default_factory=dict)
    auto_create_tables: bool = True
    tournament_min_level: int = 12
    tournament_cohort_size: int = 50
    max_events_per_batch: int = 100

    @classmethod
    def from_env(cls) -> "Settings":
        return cls(
            database_url=os.environ.get("DATABASE_URL", DEFAULT_DATABASE_URL).strip(),
            jwt_secret=os.environ.get("JWT_SECRET", "dev-insecure-secret-change-me"),
            access_token_ttl_seconds=_env_int("ACCESS_TOKEN_TTL_SECONDS", 900),
            refresh_token_ttl_seconds=_env_int("REFRESH_TOKEN_TTL_SECONDS", 2_592_000),
            run_hmac_secret=os.environ.get("RUN_HMAC_SECRET", ""),
            admob_ssv_secret=os.environ.get("ADMOB_SSV_SECRET", "dev-ssv-secret"),
            ssv_max_skew_seconds=_env_int("SSV_MAX_SKEW_SECONDS", 600),
            purchases_mode=os.environ.get("PURCHASES_MODE", "stub").strip().lower(),
            rate_limit_enabled=_env_bool("RATE_LIMIT_ENABLED", True),
            remote_config_json=_parse_json_object("REMOTE_CONFIG_JSON"),
            auto_create_tables=_env_bool("AUTO_CREATE_TABLES", True),
            tournament_min_level=_env_int("TOURNAMENT_MIN_LEVEL", 12),
            tournament_cohort_size=_env_int("TOURNAMENT_COHORT_SIZE", 50),
            max_events_per_batch=_env_int("MAX_EVENTS_PER_BATCH", 100),
        )

    @property
    def remote_config(self) -> dict:
        return deep_merge(DEFAULT_REMOTE_CONFIG, self.remote_config_json)


_settings: Settings | None = None


def get_settings() -> Settings:
    global _settings
    if _settings is None:
        _settings = Settings.from_env()
    return _settings


def reset_settings() -> None:
    """Test hook: drop the cached settings so a new environment is read."""
    global _settings
    _settings = None


def deep_merge(base: dict, override: dict) -> dict:
    """Recursively merges ``override`` into ``base`` (override wins).

    Nested dicts merge; every other value (including lists) replaces. Neither
    input is mutated; both sides may be reused safely.
    """
    result = _copy_json(base)
    for key, value in override.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = deep_merge(result[key], value)
        else:
            result[key] = _copy_json(value)
    return result


def _copy_json(value):
    if isinstance(value, dict):
        return {key: _copy_json(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_copy_json(item) for item in value]
    return value


def prepare_database_url(url: str) -> tuple[str, dict]:
    """Normalises a database URL and extracts asyncpg TLS connect args.

    Accepts ``postgres://`` and ``postgresql://`` spellings, maps them to the
    asyncpg driver, and turns ``?ssl=require`` (Neon style) into an SSLContext
    because asyncpg's connect() does not accept libpq's sslmode string verbatim
    in every deployment.
    """
    url = url.strip()
    if url.startswith("postgres://"):
        url = "postgresql+asyncpg://" + url[len("postgres://") :]
    elif url.startswith("postgresql://"):
        url = "postgresql+asyncpg://" + url[len("postgresql://") :]

    connect_args: dict = {}
    if url.startswith("postgresql+asyncpg:"):
        parts = urlsplit(url)
        query = dict(parse_qsl(parts.query))
        ssl_mode = query.pop("ssl", query.pop("sslmode", "")).lower()
        clean = urlunsplit((parts.scheme, parts.netloc, parts.path, urlencode(query), parts.fragment))
        if ssl_mode:
            connect_args["ssl"] = _ssl_context(ssl_mode)
        elif "neon.tech" in parts.netloc:
            # Neon always requires TLS; require it even if the query is missing.
            connect_args["ssl"] = _ssl_context("require")
        return clean, connect_args
    return url, connect_args


def _ssl_context(mode: str) -> ssl.SSLContext | bool:
    if mode in {"require", "true", "1", "allow", "prefer"}:
        # Encrypted transport. Neon terminates TLS; full verification is opt-in
        # with ?ssl=verify-full so local/self-signed proxies also work.
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
        return context
    if mode in {"verify-ca", "verify_ca"}:
        context = ssl.create_default_context()
        context.check_hostname = False
        return context
    if mode in {"verify-full", "verify_full"}:
        return ssl.create_default_context()
    return True
