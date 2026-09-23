"""Lightweight migrations (create_all does not alter existing tables)."""

from sqlalchemy import text
from sqlalchemy.engine import Connection


def _column_exists(conn: Connection, table: str, column: str) -> bool:
    dialect = conn.dialect.name
    if dialect == "sqlite":
        rows = conn.execute(text(f"PRAGMA table_info({table})")).fetchall()
        return any(row[1] == column for row in rows)
    if dialect == "postgresql":
        row = conn.execute(
            text(
                "SELECT 1 FROM information_schema.columns "
                "WHERE table_name = :table AND column_name = :column"
            ),
            {"table": table, "column": column},
        ).fetchone()
        return row is not None
    return False


def _add_column(conn: Connection, table: str, column: str, ddl_type: str) -> None:
    if _column_exists(conn, table, column):
        return
    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {ddl_type}"))


def run_sqlite_migrations(conn: Connection) -> None:
    """Run portable column migrations for SQLite and Postgres."""
    dialect = conn.dialect.name
    if dialect not in ("sqlite", "postgresql"):
        return

    if _column_exists(conn, "announcements", "body"):
        pin_default = "BOOLEAN DEFAULT 0" if dialect == "sqlite" else "BOOLEAN DEFAULT FALSE"
        _add_column(conn, "announcements", "is_pinned", pin_default)
        _add_column(conn, "announcements", "title", "VARCHAR(255)")

    if _column_exists(conn, "groups", "name"):
        _add_column(conn, "groups", "task_mode", "VARCHAR(16) DEFAULT 'shared'")
        bool_default = "BOOLEAN DEFAULT 0" if dialect == "sqlite" else "BOOLEAN DEFAULT FALSE"
        _add_column(conn, "groups", "is_public", bool_default)
