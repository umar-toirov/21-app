"""Seed initial data for ILM Mode."""

import asyncio
import uuid

from sqlalchemy import select

from app.db.session import SessionLocal, Base, engine
from app.models.profile import Badge, BadgeCode, Goal, MotivationalQuote
from app.services.challenge_service import QUOTES


GOALS = [
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

BADGES = [
    (BadgeCode.MORNING_WARRIOR, "Morning Warrior", "Complete wake-up task 14 days in a row"),
    (BadgeCode.CONSISTENCY_MASTER, "Consistency Master", "Complete a full challenge"),
    (BadgeCode.SEVEN_DAY_STREAK, "7-Day Streak", "Maintain a 7-day streak"),
    (BadgeCode.THIRTY_DAY_LEGEND, "30-Day Legend", "Complete a 30-day challenge"),
    (BadgeCode.NEVER_MISSED, "Never Missed", "Complete a challenge without missing a day"),
    (BadgeCode.RECOVERY_CHAMPION, "Recovery Champion", "Successfully recover from recovery mode"),
    (BadgeCode.TOP_100, "Top 100", "Reach top 100 on the global leaderboard"),
]


async def seed():
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

    async with SessionLocal() as db:
        for slug, name, icon in GOALS:
            existing = await db.execute(select(Goal).where(Goal.slug == slug))
            if not existing.scalar_one_or_none():
                db.add(Goal(slug=slug, name=name, icon=icon))

        for code, name, desc in BADGES:
            existing = await db.execute(select(Badge).where(Badge.code == code))
            if not existing.scalar_one_or_none():
                db.add(Badge(code=code, name=name, description=desc))

        for text, author in QUOTES:
            existing = await db.execute(
                select(MotivationalQuote).where(MotivationalQuote.text == text)
            )
            if not existing.scalar_one_or_none():
                db.add(MotivationalQuote(text=text, author=author))

        await db.commit()
        print("Seed completed successfully.")


if __name__ == "__main__":
    asyncio.run(seed())
