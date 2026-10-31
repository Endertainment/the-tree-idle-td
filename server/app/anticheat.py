"""Plausibility validation for submitted runs (spec 6.7).

The server never trusts client-reported placement. These are deliberately
generous sanity bounds, not a full simulation: they reject fabricated runs whose
ratios are physically impossible for the wave table (waves cannot be cleared
faster than one per 20 s) while letting a legitimate great run through.
"""

from __future__ import annotations

import hashlib
import hmac
from dataclasses import dataclass

MAX_WAVES_PER_MINUTE = 2.5
MAX_DAMAGE_PER_SECOND = 250_000.0
MIN_SECONDS_PER_WAVE = 20.0
MAX_WAVES = 10_000
MAX_CASH_PER_WAVE = 250_000

REASON_INVALID_DURATION = "invalid_duration"
REASON_NEGATIVE = "negative_values"
REASON_WAVES_TOO_HIGH = "waves_too_high"
REASON_DURATION_TOO_SHORT = "duration_too_short_for_waves"
REASON_WPM_EXCEEDED = "waves_per_minute_exceeded"
REASON_DPS_EXCEEDED = "damage_per_second_exceeded"
REASON_CASH_EXCEEDED = "cash_per_wave_exceeded"
REASON_BAD_SIGNATURE = "bad_signature"


@dataclass(frozen=True)
class Verdict:
    accepted: bool
    reason: str | None = None


def validate_run(waves: int, duration_s: float, damage: int, cash: int) -> Verdict:
    if duration_s <= 0:
        return Verdict(False, REASON_INVALID_DURATION)
    if waves < 0 or damage < 0 or cash < 0:
        return Verdict(False, REASON_NEGATIVE)
    if waves > MAX_WAVES:
        return Verdict(False, REASON_WAVES_TOO_HIGH)
    if duration_s < waves * MIN_SECONDS_PER_WAVE:
        return Verdict(False, REASON_DURATION_TOO_SHORT)
    minutes = duration_s / 60.0
    if minutes > 0 and waves / minutes > MAX_WAVES_PER_MINUTE:
        return Verdict(False, REASON_WPM_EXCEEDED)
    if damage / duration_s > MAX_DAMAGE_PER_SECOND:
        return Verdict(False, REASON_DPS_EXCEEDED)
    if cash > max(waves, 1) * MAX_CASH_PER_WAVE:
        return Verdict(False, REASON_CASH_EXCEEDED)
    return Verdict(True)


def run_signature_payload(run_seed: str, waves: int, duration_s: float, damage: int, cash: int) -> str:
    return f"{run_seed}|{int(waves)}|{int(round(duration_s))}|{int(damage)}|{int(cash)}"


def sign_run(
    secret: str, run_seed: str, waves: int, duration_s: float, damage: int, cash: int
) -> str:
    payload = run_signature_payload(run_seed, waves, duration_s, damage, cash)
    return hmac.new(secret.encode("utf-8"), payload.encode("utf-8"), hashlib.sha256).hexdigest()


def verify_run_signature(
    secret: str,
    signature: str | None,
    run_seed: str,
    waves: int,
    duration_s: float,
    damage: int,
    cash: int,
) -> bool:
    """True when the secret is unset (dev) or the signature matches."""
    if not secret:
        return True
    if not signature:
        return False
    expected = sign_run(secret, run_seed, waves, duration_s, damage, cash)
    return hmac.compare_digest(expected, signature.strip().lower())
