# Deploy / cloud data — ILM Mode

## Ownership map

| Piece | Where | Notes |
|-------|--------|--------|
| Login / Google / JWT | **Supabase Auth** | Already wired in Flutter + FastAPI |
| App tables (profiles, challenges, groups…) | **Supabase Postgres** | Phase 1 — use as `DATABASE_URL` |
| FastAPI process | Your PC (now) → Render/Railway later | Phase 2 — public URL without PC |
| Flutter UI | Device / Chrome | Points at API base URL |

Supabase **cannot** run the Python FastAPI app. It stores Auth + database only.

---

## Phase 1 — Supabase as data storage (now)

Goal: app data lives in Supabase Postgres while you still run the API on your PC.

### 1. Get the connection string

1. Open [Supabase Dashboard](https://supabase.com/dashboard) → your project  
2. **Project Settings → Database**  
3. Under **Connection string**, copy the **URI**  
4. Prefer **Session mode pooler** (port `6543`) if direct `db.*.supabase.co:5432` times out from home Wi‑Fi  

Example shapes (password URL-encoded if it has special chars):

```text
postgresql://postgres.[REF]:[PASSWORD]@aws-0-[REGION].pooler.supabase.com:6543/postgres
postgresql://postgres:[PASSWORD]@db.[REF].supabase.co:5432/postgres
```

The app auto-converts `postgresql://` → `postgresql+asyncpg://`.

### 2. Update local `backend/.env`

```env
DATABASE_URL=postgresql+asyncpg://postgres.[REF]:[PASSWORD]@aws-0-....pooler.supabase.com:6543/postgres
```

Keep your existing `SUPABASE_URL` and `SUPABASE_JWT_SECRET`.

Do **not** commit `.env`. See [`.env.example`](../backend/.env.example).

### 3. Install driver + test

```powershell
cd backend
python -m pip install -r requirements.txt
python -m tools.test_db
```

Expect: `OK — database reachable`.

If **FAIL** (timeout / network): your network may block Supabase Postgres (known on this machine). Leave:

```env
DATABASE_URL=sqlite+aiosqlite:///./ilmmode.db
```

Phase 2 cloud API → Supabase usually still works.

### 4. Start API (creates tables on empty DB)

```powershell
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

On first boot against empty Postgres, `create_all` + seed creates goals/badges/quotes.

Flutter keeps using local API (`env.json` / `env.android.json`) until Phase 2.

---

## Phase 2 — Host FastAPI (later)

When phones/friends must work without your PC:

| Host | Cost | Behavior |
|------|------|----------|
| **Render Free** | $0 | Sleeps after ~15 **minutes** idle; ~30–60s cold start |
| **Railway Hobby** | ~$5/mo | Always on |

Steps (summary):

1. Push `backend/` (Dockerfile already binds `$PORT`)  
2. Set env on host: `DATABASE_URL` (same Supabase URI), `SUPABASE_JWT_SECRET`, `SUPABASE_URL`, `ENVIRONMENT=production`, `CORS_ORIGINS`, `INTERNAL_JOB_SECRET`  
3. Health: `GET https://<host>/v1/health`  
4. Point Flutter `API_BASE_URL` at `https://<host>/v1` (`env.production.json`)

Same Supabase DB — no data rewrite if Phase 1 already used it.

---

## Security

- Never paste DB password or service role key into git or public chat  
- Rotate secrets if they were exposed  
- Production: strong `INTERNAL_JOB_SECRET`, restrict CORS to real app origins  
