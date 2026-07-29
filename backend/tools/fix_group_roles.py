import sqlite3

conn = sqlite3.connect(r"C:\Users\Muhammadumar\OneDrive\Desktop\App\backend\ilmmode.db")
c = conn.cursor()
c.execute("UPDATE group_members SET role = 'leader' WHERE upper(role) = 'LEADER'")
print("leader rows", c.rowcount)
c.execute("UPDATE group_members SET role = 'member' WHERE upper(role) = 'MEMBER'")
print("member rows", c.rowcount)
conn.commit()
for r in c.execute("SELECT group_id, user_id, role FROM group_members"):
    print(r)
conn.close()
