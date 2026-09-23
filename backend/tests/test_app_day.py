from datetime import date, datetime, timezone
from unittest.mock import patch

from app.core import security


def test_app_day_is_utc_plus_5():
    # 19:30 UTC is 00:30 next day in UTC+5, so the day has rolled over.
    class Fake(datetime):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 1, 1, 19, 30, tzinfo=timezone.utc).astimezone(tz)

    with patch.object(security, "datetime", Fake):
        assert security.app_today() == date(2026, 1, 2)
    # 18:59 UTC is 23:59 in UTC+5, still the same day.
    class Fake2(Fake):
        @classmethod
        def now(cls, tz=None):
            return datetime(2026, 1, 1, 18, 59, tzinfo=timezone.utc).astimezone(tz)

    with patch.object(security, "datetime", Fake2):
        assert security.app_today() == date(2026, 1, 1)
