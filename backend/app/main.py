import logging

from contextlib import asynccontextmanager

from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.base import BaseHTTPMiddleware

from app.api.v1.jobs import router as jobs_router
from app.api.v1.router import router as v1_router
from app.core.config import settings
from app.db.migrate import run_sqlite_migrations
from app.db.session import Base, SessionLocal, engine


class AllowPrivateNetworkMiddleware(BaseHTTPMiddleware):
    """Chrome Private Network Access: allow localhost API calls from the web app."""

    async def dispatch(self, request: Request, call_next):
        response = await call_next(request)
        response.headers["Access-Control-Allow-Private-Network"] = "true"
        return response


logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)
        await conn.run_sync(run_sqlite_migrations)
    await _seed_if_empty()
    yield
    await engine.dispose()


async def _seed_if_empty() -> None:
    from sqlalchemy import func, select

    from app.models.profile import Badge, BadgeCode, Goal, MotivationalQuote
    from app.services.challenge_service import QUOTES

    goals = [
        ("ielts", "IELTS", "school"),
        ("sat", "SAT", "edit_note"),
        ("programming", "Programming", "code"),
        ("fitness", "Fitness", "fitness_center"),
        ("reading", "Reading", "menu_book"),
        ("productivity", "Productivity", "bolt"),
        ("quran", "Quran", "auto_stories"),
        ("personal_development", "Personal Development", "self_improvement"),
        ("other", "Other", "flag"),
    ]
    badges = [
        (BadgeCode.MORNING_WARRIOR, "Morning Warrior", "Complete wake-up task 14 days in a row"),
        (BadgeCode.CONSISTENCY_MASTER, "Consistency Master", "Complete a full challenge"),
        (BadgeCode.SEVEN_DAY_STREAK, "7-Day Streak", "Maintain a 7-day streak"),
        (BadgeCode.THIRTY_DAY_LEGEND, "30-Day Legend", "Complete a 30-day challenge"),
        (BadgeCode.NEVER_MISSED, "Never Missed", "Complete a challenge without missing a day"),
        (BadgeCode.RECOVERY_CHAMPION, "Recovery Champion", "Successfully recover from recovery mode"),
        (BadgeCode.TOP_100, "Top 100", "Reach top 100 on the global leaderboard"),
    ]

    async with SessionLocal() as db:
        count = await db.execute(select(func.count()).select_from(Goal))
        if (count.scalar() or 0) > 0:
            return
        for slug, name, icon in goals:
            db.add(Goal(slug=slug, name=name, icon=icon))
        for code, name, desc in badges:
            db.add(Badge(code=code, name=name, description=desc))
        for text, author in QUOTES:
            db.add(MotivationalQuote(text=text, author=author))
        await db.commit()


app = FastAPI(
    title="ILM Mode API",
    description="Discipline-building platform API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
# Added after CORS so it runs first on the request and can annotate the response.
app.add_middleware(AllowPrivateNetworkMiddleware)

app.include_router(v1_router, prefix="/v1")
app.include_router(jobs_router, prefix="/v1")


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception):
    from fastapi.responses import JSONResponse

    logger.exception("Unhandled error on %s %s", request.method, request.url.path)
    return JSONResponse(
        status_code=500,
        content={"detail": {"code": "INTERNAL", "message": str(exc)}},
    )


@app.get("/")
async def root():
    return {"name": "ILM Mode API", "version": "1.0.0", "docs": "/docs"}
