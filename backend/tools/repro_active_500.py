"""Reproduce GET /challenges/active failure for the challenge that returned 500."""
import asyncio
import traceback
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db.session import SessionLocal
from app.models.profile import Challenge, ChallengeStatus, ChallengeType, Profile
from app.services.challenge_service import ChallengeService


async def main() -> None:
    # Challenge from proxy log that succeeded complete-task then failed active
    cid = UUID("b6a4d4ee-ef81-4da8-922f-f7bcedc97670")
    async with SessionLocal() as db:
        result = await db.execute(
            select(Challenge)
            .where(Challenge.id == cid)
            .options(selectinload(Challenge.tasks), selectinload(Challenge.days))
        )
        challenge = result.scalar_one_or_none()
        print("challenge found:", bool(challenge))
        if not challenge:
            # list individuals
            r = await db.execute(
                select(Challenge).where(Challenge.type == ChallengeType.INDIVIDUAL).limit(5)
            )
            print("sample:", [(c.id, c.status, c.type, c.current_day) for c in r.scalars()])
            return

        print("status=", challenge.status, type(challenge.status))
        print("type=", challenge.type, type(challenge.type))
        print("current_day=", challenge.current_day, "start=", challenge.start_date)
        print("tasks=", [(t.title, t.type, type(t.type)) for t in challenge.tasks[:3]])
        print("days=", len(challenge.days))

        profile = (
            await db.execute(select(Profile).where(Profile.id == challenge.user_id))
        ).scalar_one()
        service = ChallengeService(db)
        try:
            detail = await service.build_detail(profile, challenge)
            print("OK keys:", list(detail.keys())[:8])
        except Exception:
            traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
