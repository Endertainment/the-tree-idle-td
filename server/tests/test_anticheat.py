"""Anti-cheat rules (pure) and a stored rejected run."""

from __future__ import annotations

from app.anticheat import (
    REASON_CASH_EXCEEDED,
    REASON_DPS_EXCEEDED,
    REASON_DURATION_TOO_SHORT,
    REASON_WPM_EXCEEDED,
    sign_run,
    validate_run,
    verify_run_signature,
)


def test_plausible_run_is_accepted():
    verdict = validate_run(waves=30, duration_s=1800, damage=5_000_000, cash=50_000)
    assert verdict.accepted is True
    assert verdict.reason is None


def test_duration_shorter_than_waves_times_20_is_rejected():
    verdict = validate_run(waves=60, duration_s=600, damage=1_000_000, cash=1_000)
    assert verdict.accepted is False
    assert verdict.reason == REASON_DURATION_TOO_SHORT


def test_waves_per_minute_cap_is_rejected():
    # 60 waves in 1250 s passes the 20 s/wave floor but is 2.88 waves/min.
    verdict = validate_run(waves=60, duration_s=1250, damage=2_000_000, cash=10_000)
    assert verdict.accepted is False
    assert verdict.reason == REASON_WPM_EXCEEDED


def test_damage_per_second_cap_is_rejected():
    # 20 waves in 600 s = 2 waves/min (passes the cadence rules); the damage is
    # 1.67M DPS, far above the 250k cap.
    verdict = validate_run(waves=20, duration_s=600, damage=1_000_000_000, cash=1_000)
    assert verdict.accepted is False
    assert verdict.reason == REASON_DPS_EXCEEDED


def test_cash_per_wave_cap_is_rejected():
    verdict = validate_run(waves=10, duration_s=1000, damage=2_000_000, cash=10 * 250_001)
    assert verdict.accepted is False
    assert verdict.reason == REASON_CASH_EXCEEDED


def test_hmac_signature_round_trip():
    secret = "run-secret"
    signature = sign_run(secret, "seed-1", 12, 240.0, 1_500_000, 4_000)
    assert verify_run_signature(secret, signature, "seed-1", 12, 240.0, 1_500_000, 4_000)
    assert not verify_run_signature(secret, signature, "seed-2", 12, 240.0, 1_500_000, 4_000)
    assert not verify_run_signature(secret, None, "seed-1", 12, 240.0, 1_500_000, 4_000)
    # An empty secret means local development: signatures are optional.
    assert verify_run_signature("", None, "seed-1", 12, 240.0, 1_500_000, 4_000)
