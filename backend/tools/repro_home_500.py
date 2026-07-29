"""Call the same code paths that Home uses and print any crash."""
import asyncio
import traceback
from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.db.session import SessionLocal
from app.models.profile import Challenge, ChallengeStatus, ChallengeType, Profile
from app.services.challenge_service import ChallengeService
from app.services.group_service import GroupService


async def main() -> None:
    async with SessionLocal() as db:
        profiles = (await db.execute(select(Profile).where(Profile.is_deleted.is_(False)))).scalars().all()
        print(f"profiles={len(profiles)}")
        for profile in profiles:
            print(f"\n=== {profile.email} hp={profile.hp} score={profile.discipline_score} ===")
            try:
                # Simulate ProfileResponse-ish access
                _ = {
                    "id": profile.id,
                    "email": profile.email,
                    "full_name": profile.full_name,
                    "avatar_url": profile.avatar_url,
                    "timezone": profile.timezone,
                    "locale": profile.locale,
                    "hp": profile.hp,
                    "discipline_score": profile.discipline_score,
                    "current_streak": profile.current_streak,
                    "longest_streak": profile.longest_streak,
                    "perfect_weeks": profile.perfect_weeks,
                    "challenges_completed": profile.challenges_completed,
                    "onboarding_step": profile.onboarding_step,
                    "notifications_enabled": profile.notifications_enabled,
                    "dark_mode": profile.dark_mode,
                }
                print("profile dict OK")
            except Exception:
                traceback.print_exc()

            svc = ChallengeService(db)
            try:
                ch = await svc.get_active_challenge(profile.id)
                print("active challenge:", None if not ch else f"{ch.id} {ch.status} day={ch.current_day}")
                if ch:
                    detail = await svc.build_detail(profile, ch)
                    print("build_detail OK", detail["status"], detail.get("recovery_hours_left"))
            except Exception:
                print("ACTIVE FAIL:")
                traceback.print_exc()

            try:
                groups = await GroupService(db).list_for_user(profile.id)
                print("groups OK", len(groups) if groups is not None else None)
            except AttributeError:
                # method name may differ
                try:
                    from app.api.v1 import router as r

                    print("GroupService methods:", [m for m in dir(GroupService) if not m.startswith("_")])
                except Exception:
                    pass
                traceback.print_exc()
            except Exception:
                print("GROUPS FAIL:")
                traceback.print_exc()


if __name__ == "__main__":
    asyncio.run(main())
