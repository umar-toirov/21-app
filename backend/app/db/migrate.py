"""Lightweight SQLite migrations for dev (create_all does not alter existing tables)."""

from sqlalchemy import text
from sqlalchemy.engine import Connection


def _column_exists(conn: Connection, table: str, column: str) -> bool:
    rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
    return any(row[1] == column for row in rows)


def run_sqlite_migrations(conn: Connection) -> None:
    if conn.dialect.name != "sqlite":
        return

    if _column_exists(conn, "announcements", "body") and not _column_exists(
        conn, "announcements", "is_pinned"
    ):
        conn.execute(text("ALTER TABLE announcements ADD COLUMN is_pinned BOOLEAN DEFAULT 0"))
    if _column_exists(conn, "announcements", "body") and not _column_exists(
        conn, "announcements", "title"
    ):
        conn.execute(text("ALTER TABLE announcements ADD COLUMN title VARCHAR(255)"))
