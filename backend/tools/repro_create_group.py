"""Reproduce group create for umar.throv (has recovery challenge)."""
import asyncio
import traceback
from datetime import date

from sqlalchemy import select

from app.db.session import SessionLocal
from app.models.profile import Profile
from app.services.group_service import GroupService


async def main() -> None:
    async with SessionLocal() as db:
        profile = (
            await db.execute(select(Profile).where(Profile.email == "umar.throv@gmail.com"))
        ).scalar_one_or_none()
        if not profile:
            profile = (await db.execute(select(Profile).limit(1))).scalar_one()
        print("user", profile.email, profile.id)
        svc = GroupService(db)
        try:
            groups = await svc.get_user_groups(profile.id)
            print("list groups OK", groups)
        except Exception:
            traceback.print_exc()
        try:
            g = await svc.create_group(
                profile,
                {
                    "name": "Test Group Fix",
                    "duration_days": 21,
                    "max_missed_days": 3,
                    "starts_at": date.today(),
                    "foundation_tasks": ["Wake up on time", "Daily planning", "Evening review"],
                },
            )
            print("CREATE OK", g.id, g.invite_code)
            await db.rollback()  # don't keep test group
        except Exception as e:
            print("CREATE FAIL:", type(e).__name__, e)
            traceback.print_exc()
            await db.rollback()


if __name__ == "__main__":
    asyncio.run(main())
