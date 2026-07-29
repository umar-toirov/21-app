import sqlite3
from pathlib import Path

db = Path(__file__).resolve().parents[1] / "ilmmode.db"
conn = sqlite3.connect(db)
c = conn.cursor()
print("challenges:")
for row in c.execute(
    "SELECT id, status, type, current_day, duration_days, start_date, name FROM challenges ORDER BY created_at DESC LIMIT 8"
):
    print(row)
print("\nday counts:")
for row in c.execute("SELECT challenge_id, COUNT(*) FROM challenge_days GROUP BY challenge_id"):
    print(row)
print("\ntask types:")
for row in c.execute("SELECT DISTINCT type FROM tasks"):
    print(row)
print("\nactive-ish:")
for row in c.execute(
    "SELECT id, status, current_day, duration_days, start_date FROM challenges WHERE upper(status) IN ('ACTIVE','RECOVERY')"
):
    print(row)
conn.close()
