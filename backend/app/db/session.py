from urllib.parse import urlparse

from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine
from sqlalchemy.orm import DeclarativeBase

from app.core.config import settings


class Base(DeclarativeBase):
    pass


def normalize_database_url(url: str) -> str:
    """Accept postgres:// or postgresql:// from Supabase/Railway dashboards."""
    if url.startswith("postgres://"):
        url = "postgresql://" + url[len("postgres://") :]
    if url.startswith("postgresql://") and "+asyncpg" not in url:
        url = "postgresql+asyncpg://" + url[len("postgresql://") :]
    return url


def _needs_ssl(url: str) -> bool:
    """Require SSL for hosted Postgres (Supabase / Railway / Render)."""
    if not url.startswith("postgresql"):
        return False
    host = (urlparse(url.replace("postgresql+asyncpg://", "postgresql://", 1)).hostname or "").lower()
    if host in ("localhost", "127.0.0.1", "db"):
        return False
    if settings.environment == "production":
        return True
    # Supabase and most cloud hosts need SSL even in development.
    return any(
        tip in host
        for tip in ("supabase.co", "supabase.com", "railway.app", "render.com", "neon.tech", "amazonaws.com")
    )


def _engine_kwargs(url: str) -> dict:
    kwargs: dict = {"echo": settings.environment == "development"}
    if _needs_ssl(url):
        # asyncpg accepts ssl=True / ssl="require"
        kwargs["connect_args"] = {"ssl": "require"}
    return kwargs


DATABASE_URL = normalize_database_url(settings.database_url)
engine = create_async_engine(DATABASE_URL, **_engine_kwargs(DATABASE_URL))
SessionLocal = async_sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)


async def get_db():
    async with SessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
