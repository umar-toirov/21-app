from datetime import datetime, timedelta, timezone
from typing import Annotated, Any
from uuid import UUID
import time

import httpx
from fastapi import Depends, Header
from jose import JWTError, jwk, jwt
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import settings
from app.core.exceptions import AppError, ForbiddenError
from app.db.session import get_db
from app.models.profile import Profile

_jwks_cache: dict[str, Any] | None = None
_jwks_fetched_at: float = 0.0
_JWKS_TTL_SECONDS = 600


async def _fetch_jwks() -> dict[str, Any]:
    global _jwks_cache, _jwks_fetched_at
    now = time.monotonic()
    if _jwks_cache is not None and (now - _jwks_fetched_at) < _JWKS_TTL_SECONDS:
        return _jwks_cache

    if not settings.supabase_url:
        return {"keys": []}

    url = f"{settings.supabase_url.rstrip('/')}/auth/v1/.well-known/jwks.json"
    async with httpx.AsyncClient(timeout=10.0) as client:
        response = await client.get(url)
        response.raise_for_status()
        _jwks_cache = response.json()
        _jwks_fetched_at = now
        return _jwks_cache


def _decode_hs256(token: str) -> dict[str, Any]:
    return jwt.decode(
        token,
        settings.supabase_jwt_secret,
        algorithms=["HS256"],
        options={"verify_aud": False},
    )


def _decode_with_jwks(token: str, jwks: dict[str, Any]) -> dict[str, Any]:
    header = jwt.get_unverified_header(token)
    kid = header.get("kid")
    alg = header.get("alg") or "ES256"
    keys = jwks.get("keys") or []
    key_data = next((k for k in keys if kid is None or k.get("kid") == kid), None)
    if key_data is None and keys:
        key_data = keys[0]
    if key_data is None:
        raise JWTError("No JWKS signing keys available")

    signing_key = jwk.construct(key_data)
    return jwt.decode(
        token,
        signing_key,
        algorithms=[alg],
        options={"verify_aud": False},
    )


async def decode_supabase_token(token: str) -> dict[str, Any]:
    """Verify a Supabase access token (ES256 via JWKS, with HS256 legacy fallback)."""
    try:
        header = jwt.get_unverified_header(token)
    except JWTError as exc:
        raise AppError("UNAUTHORIZED", "Invalid token", 401) from exc

    alg = header.get("alg", "HS256")
    try:
        if alg == "HS256":
            return _decode_hs256(token)

        jwks = await _fetch_jwks()
        return _decode_with_jwks(token, jwks)
    except (JWTError, httpx.HTTPError, ValueError) as primary:
        # Legacy secret may still work during signing-key migration.
        if alg != "HS256":
            try:
                return _decode_hs256(token)
            except JWTError:
                pass
        raise AppError("UNAUTHORIZED", "Invalid token", 401) from primary


async def get_current_user_id(
    authorization: Annotated[str | None, Header()] = None,
) -> UUID:
    if not authorization or not authorization.startswith("Bearer "):
        raise AppError("UNAUTHORIZED", "Missing or invalid authorization header", 401)

    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = await decode_supabase_token(token)
        user_id = payload.get("sub")
        if not user_id:
            raise AppError("UNAUTHORIZED", "Invalid token payload", 401)
        return UUID(user_id)
    except AppError:
        if settings.environment == "development":
            try:
                return UUID(token)
            except ValueError:
                pass
        raise
    except (JWTError, ValueError) as exc:
        if settings.environment == "development":
            try:
                return UUID(token)
            except ValueError:
                pass
        raise AppError("UNAUTHORIZED", "Invalid token", 401) from exc


async def get_current_profile(
    user_id: Annotated[UUID, Depends(get_current_user_id)],
    db: Annotated[AsyncSession, Depends(get_db)],
    authorization: Annotated[str | None, Header()] = None,
) -> Profile:
    result = await db.execute(select(Profile).where(Profile.id == user_id))
    profile = result.scalar_one_or_none()
    if profile and not profile.is_deleted:
        return profile

    if not authorization or not authorization.startswith("Bearer "):
        raise AppError("UNAUTHORIZED", "Profile not found", 401)

    token = authorization.removeprefix("Bearer ").strip()
    try:
        payload = await decode_supabase_token(token)
        email = payload.get("email") or f"{user_id}@ilmmode.local"
        metadata = payload.get("user_metadata") or {}
        full_name = (
            metadata.get("full_name")
            or metadata.get("name")
            or email.split("@")[0]
        )
        profile = Profile(
            id=user_id,
            email=email,
            full_name=full_name,
            discipline_score=0,
            hp=100,
        )
        db.add(profile)
        await db.flush()
        return profile
    except AppError as exc:
        raise AppError("UNAUTHORIZED", "Profile not found", 401) from exc


async def verify_internal_job(
    x_internal_secret: Annotated[str | None, Header()] = None,
) -> None:
    if x_internal_secret != settings.internal_job_secret:
        raise ForbiddenError("Invalid internal job secret")


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def as_utc(dt: datetime | None) -> datetime | None:
    """Normalize SQLite-naive datetimes to UTC-aware for safe arithmetic."""
    if dt is None:
        return None
    if dt.tzinfo is None:
        return dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc)


def user_local_date(timezone_name: str) -> datetime:
    try:
        from zoneinfo import ZoneInfo

        return datetime.now(ZoneInfo(timezone_name))
    except Exception:
        return datetime.now(timezone.utc)


def grace_cutoff(local_dt: datetime, grace_hours: int) -> datetime:
    midnight = local_dt.replace(hour=0, minute=0, second=0, microsecond=0)
    return midnight + timedelta(hours=grace_hours)
