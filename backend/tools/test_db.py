"""Test DATABASE_URL connectivity (SQLite or Supabase Postgres).

Usage (from backend/):
  python -m tools.test_db
"""

from __future__ import annotations

import asyncio
import sys
from pathlib import Path

# Allow `python -m tools.test_db` from backend/
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import text

from app.core.config import settings
from app.db.session import DATABASE_URL, engine


def _redact(url: str) -> str:
    if "@" not in url:
        return url
    scheme, rest = url.split("://", 1)
    creds, host = rest.rsplit("@", 1)
    user = creds.split(":")[0] if ":" in creds else creds
    return f"{scheme}://{user}:***@{host}"


async def main() -> int:
    print("DATABASE_URL =", _redact(DATABASE_URL))
    print("ENVIRONMENT  =", settings.environment)
    try:
        async with engine.connect() as conn:
            row = await conn.execute(text("SELECT 1 AS ok"))
            print("OK — database reachable, SELECT 1 =", row.scalar())
        return 0
    except Exception as exc:
        print("FAIL —", type(exc).__name__, str(exc)[:400])
        print()
        print("If this is Supabase Postgres and your home network blocks it:")
        print("  - Keep SQLite locally for now (DATABASE_URL=sqlite+aiosqlite:///./ilmmode.db)")
        print("  - Phase 2 (Render/Railway) can still use Supabase DB from the cloud")
        return 1
    finally:
        await engine.dispose()


if __name__ == "__main__":
    raise SystemExit(asyncio.run(main()))
