"""Token and hashing helpers. No passlib, no PyJWT: hmac/hashlib/secrets only.

Access tokens are stateless HS256 JWTs; refresh tokens are HS256 JWTs whose full
value is hashed (SHA-256) in the players table, so rotating invalidates the old
one. Nothing here logs a token.
"""

from __future__ import annotations

import base64
import hashlib
import hmac
import json
import time
import uuid


class TokenError(Exception):
    def __init__(self, code: str, message: str = "") -> None:
        self.code = code
        super().__init__(message or code)


def new_id() -> str:
    return str(uuid.uuid4())


def new_hex(byte_length: int = 32) -> str:
    import secrets

    return secrets.token_hex(byte_length)


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode("ascii")


def _b64url_decode(value: str) -> bytes:
    padding = "=" * (-len(value) % 4)
    return base64.urlsafe_b64decode(value + padding)


def _sign(signing_input: str, secret: str) -> str:
    digest = hmac.new(secret.encode("utf-8"), signing_input.encode("ascii"), hashlib.sha256).digest()
    return _b64url(digest)


def create_token(
    player_id: str,
    token_type: str,
    secret: str,
    ttl_seconds: int,
    now: int | None = None,
) -> tuple[str, int]:
    """Returns ``(jwt, expires_at_unix)``."""
    issued_at = int(time.time() if now is None else now)
    expires_at = issued_at + int(ttl_seconds)
    header = {"alg": "HS256", "typ": "JWT"}
    payload = {
        "sub": player_id,
        "typ": token_type,
        "iat": issued_at,
        "exp": expires_at,
        "jti": uuid.uuid4().hex,
    }
    encoded_header = _b64url(json.dumps(header, separators=(",", ":")).encode("utf-8"))
    encoded_payload = _b64url(json.dumps(payload, separators=(",", ":")).encode("utf-8"))
    signing_input = f"{encoded_header}.{encoded_payload}"
    return f"{signing_input}.{_sign(signing_input, secret)}", expires_at


def decode_token(token: str, secret: str, expected_type: str | None = None) -> dict:
    parts = token.split(".")
    if len(parts) != 3:
        raise TokenError("malformed_token")
    signing_input = f"{parts[0]}.{parts[1]}"
    expected = _sign(signing_input, secret)
    if not hmac.compare_digest(expected, parts[2]):
        raise TokenError("invalid_signature")
    try:
        payload = json.loads(_b64url_decode(parts[1]))
    except (ValueError, json.JSONDecodeError) as exc:
        raise TokenError("malformed_token") from exc
    if not isinstance(payload, dict) or not payload.get("sub"):
        raise TokenError("malformed_token")
    if expected_type is not None and payload.get("typ") != expected_type:
        raise TokenError("wrong_token_type")
    if int(payload.get("exp", 0)) <= int(time.time()):
        raise TokenError("token_expired")
    return payload


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def tokens_match(stored_hash: str | None, token: str) -> bool:
    if not stored_hash:
        return False
    return hmac.compare_digest(stored_hash, hash_token(token))
