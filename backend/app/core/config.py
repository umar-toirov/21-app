from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8", extra="ignore")

    # Local default: SQLite. Production / Phase 1 cloud: Supabase Postgres URI.
    database_url: str = "sqlite+aiosqlite:///./ilmmode.db"
    supabase_url: str = ""
    supabase_jwt_secret: str = "dev-secret-change-in-production"
    supabase_service_role_key: str = ""
    environment: str = "development"
    # Browsers reject Access-Control-Allow-Origin: * when credentials are used.
    cors_origins: str = (
        "http://127.0.0.1:8090,http://localhost:8090,"
        "http://127.0.0.1:8100,http://localhost:8100,"
        "http://127.0.0.1:8080,http://localhost:8080,"
        "http://127.0.0.1:3000,http://localhost:3000"
    )
    internal_job_secret: str = "change-me-in-production"
    challenge_price_uzs: int = 99000
    grace_hours: int = 2

    @property
    def cors_origin_list(self) -> list[str]:
        raw = [o.strip() for o in self.cors_origins.split(",") if o.strip()]
        # Expand "*" into local Flutter/web origins (cannot use * + credentials).
        if raw == ["*"]:
            return [
                "http://127.0.0.1:8090",
                "http://localhost:8090",
                "http://127.0.0.1:8080",
                "http://localhost:8080",
                "http://127.0.0.1:3000",
                "http://localhost:3000",
            ]
        return raw

    @property
    def uses_sqlite(self) -> bool:
        return self.database_url.startswith("sqlite")


settings = Settings()
