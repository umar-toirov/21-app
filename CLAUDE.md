# CLAUDE.md — ILM Mode ("21")

Entry point for Claude Code / Claude agents. **Full project guidance lives in [AGENTS.md](./AGENTS.md)** — read that file first for run commands, paths, and gotchas.

## Project in one line

Flutter (`mobile/`) + FastAPI (`backend/`) discipline app. Supabase = **Auth + Postgres**. FastAPI = business logic (not hosted on Supabase).

## Non‑negotiables

1. **Never commit secrets** — `backend/.env`, `mobile/env*.json` (except `*.example`) are gitignored.
2. **Ask before** `git commit` / `git push` unless the user explicitly requested it.
3. **Minimal diffs** — match existing Flutter (Riverpod, go_router) and FastAPI patterns.
4. **Groups are not chat** — activity feed / announcements / leaderboard only (`docs/GROUPS_DESIGN.md`).
5. **One personal + one group** may run in parallel; day advances at **midnight** (`sync_calendar_day`), not on last task tap.
6. Prefer **Chrome** (`mobile/run-chrome.ps1`) for UI; don’t debug via the `8090` proxy (blank page).

## Default local stack (this machine)

```powershell
# Terminal 1 — API (port must match mobile/env.json)
cd backend
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001

# Terminal 2 — Flutter
cd mobile
.\run-chrome.ps1
```

- Health: `GET http://127.0.0.1:8001/v1/health`
- DB check: `python -m tools.test_db` (from `backend/`)
- Cloud data: Supabase Postgres via `DATABASE_URL` — see `docs/DEPLOY.md`
- Repo: https://github.com/toiroff/21-app (`main`)

## Where to edit

| Work | Start here |
|------|------------|
| Auth / landing UI | `mobile/lib/features/auth/` |
| Challenges | `mobile/lib/features/challenge/` |
| Groups | `mobile/lib/features/group_challenge/` |
| API / services | `backend/app/api/v1/router.py`, `backend/app/services/` |
| Theme | `mobile/lib/core/theme/app_theme.dart` |

## If stuck

| Symptom | Likely cause |
|---------|----------------|
| Login fails, UI fine | Supabase Auth / email confirm / Google redirect URL |
| Login OK, no data / 500 | Backend down, wrong `API_BASE_URL`, or DB/`as_utc` issues |
| Blank Chrome at `:8090` | Use `run-chrome.ps1`, not the proxy |
| Create group “date” errors | Ensure `datetime.date` imported in `group_service.py` |

## Deeper docs

- [AGENTS.md](./AGENTS.md) — complete agent handbook  
- [docs/DEPLOY.md](./docs/DEPLOY.md) — Phase 1 DB / Phase 2 API host  
- [docs/PLANNING.md](./docs/PLANNING.md) — product scope  
- [docs/GROUPS_DESIGN.md](./docs/GROUPS_DESIGN.md) — groups UX  
