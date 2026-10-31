"""Helpers shared by profile, save and leaderboard endpoints."""

from __future__ import annotations

from typing import Any

from .models import Player, Save


def _dict(value: Any) -> dict:
    return value if isinstance(value, dict) else {}


def apply_payload_to_player(player: Player, payload: dict) -> None:
    """Mirrors the client-authoritative display fields into the players table."""
    profile = _dict(payload.get("player"))
    nickname = profile.get("nickname")
    if isinstance(nickname, str) and nickname.strip():
        player.nickname = nickname.strip()[:32]
    avatar = profile.get("avatar_id")
    if isinstance(avatar, str) and avatar.strip():
        player.avatar_id = avatar.strip()[:32]
    if "level" in profile:
        try:
            player.level = max(int(profile["level"]), 1)
        except (TypeError, ValueError):
            pass
    if "xp" in profile:
        try:
            player.xp = max(int(profile["xp"]), 0)
        except (TypeError, ValueError):
            pass


def profile_dict(player: Player, save: Save | None) -> dict:
    payload = _dict(save.payload) if save is not None else {}
    profile = _dict(payload.get("player"))
    stats = _dict(payload.get("stats"))
    wallet = _dict(payload.get("wallet"))
    return {
        "player_id": player.id,
        "nickname": player.nickname or str(profile.get("nickname", "")),
        "avatar_id": player.avatar_id or str(profile.get("avatar_id", "avatar_01")),
        "level": player.level,
        "xp": player.xp,
        "provider": player.provider,
        "is_guest": not bool(player.provider),
        "created_at": player.created_at,
        "last_seen_at": player.last_seen_at,
        "save_revision": int(save.revision) if save is not None else 0,
        "wallet": {
            "coins": _int(wallet.get("coins")),
            "gems": _int(wallet.get("gems")),
            "stones": _int(wallet.get("stones")),
        },
        "stats": {
            "best_wave": _int(stats.get("best_wave")),
            "runs_played": _int(stats.get("runs_played")),
            "total_kills": _int(stats.get("total_kills")),
            "total_playtime": _int(stats.get("total_playtime")),
            "weekly_max_wave": _int(stats.get("weekly_max_wave")),
            "week_id": str(stats.get("week_id", "")),
        },
    }


def _int(value: Any, default: int = 0) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return default
