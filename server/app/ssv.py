"""AdMob server-side verification (SSV) signature helpers.

AdMob signs callbacks with Google-managed ECDSA keys. Production should verify
against Google's published keys; until that verifier is wired, this deployment
uses the shared-secret HMAC form documented in SPEC.md and exercised by tests.
The callback is public (no bearer token), so the signature is the only gate.
"""

from __future__ import annotations

import hashlib
import hmac


def signature_payload(
    transaction_id: str,
    user_id: str,
    custom_data: str,
    reward_amount: str,
    timestamp: str,
) -> str:
    return "|".join([transaction_id, user_id, custom_data, reward_amount, timestamp])


def sign(
    secret: str,
    transaction_id: str,
    user_id: str,
    custom_data: str,
    reward_amount: str,
    timestamp: str,
) -> str:
    payload = signature_payload(transaction_id, user_id, custom_data, reward_amount, timestamp)
    return hmac.new(secret.encode("utf-8"), payload.encode("utf-8"), hashlib.sha256).hexdigest()


def verify(
    secret: str,
    signature: str | None,
    transaction_id: str,
    user_id: str,
    custom_data: str,
    reward_amount: str,
    timestamp: str,
) -> bool:
    if not signature:
        return False
    expected = sign(secret, transaction_id, user_id, custom_data, reward_amount, timestamp)
    provided = signature.removeprefix("hmac:").strip().lower()
    return hmac.compare_digest(expected, provided)
