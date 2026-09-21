# CLAUDE.md — Habit Zone (formerly ILM Mode / "21")

Entry point for Claude Code / Claude agents. **Full project guidance lives in [AGENTS.md](./AGENTS.md)** — read that file first for run commands, paths, and gotchas.

## Project in one line

Flutter (`mobile/`) + FastAPI (`backend/`) discipline app. Supabase = **Auth + Postgres**. FastAPI = business logic (not hosted on Supabase).

## Non‑negotiables

1. **Never commit secrets** — `backend/.env`, `mobile/env*.json` (except `*.example`) are gitignored.
2. **Ask before** `git commit` / `git push` unless the user explicitly requested it.
3. **Minimal diffs** — match existing Flutter (Riverpod, go_router) and FastAPI patterns.
4. **Groups have chat** (added on the user's request, see AGENTS.md → *Groups v2*): group chat, announcements, activity feed, ranking. No DMs/media. There are **no foundation tasks in groups** — the admin sets group tasks for everyone.
5. **One personal + one group** may run in parallel; day advances at **midnight** (`sync_calendar_day`), not on last task tap.
6. Prefer **Chrome** (`mobile/run-chrome.ps1`, pinned to `127.0.0.1:5210`) for UI; don’t debug via the `8090` proxy (blank page).
7. **Challenges are free** — no payment code. Do not reintroduce prices or payment endpoints.
8. **Group points are separate from personal HP** — group rank uses only the member’s group-challenge points (`GroupService._group_points`), never `profile.hp`.
9. **Challenge frameworks are static data** in `backend/app/data/challenge_templates.py`; new challenges go through `POST /v1/challenges`; personal challenges can be **scheduled** (future `start_date`) and can't be ticked before it starts. See AGENTS.md → *Challenge frameworks, start date, skip*.
10. **Points:** +5 per task, +10 perfect-day bonus, −15 per missed day (backend constants in `challenge_service.py`); new users start at 0. See AGENTS.md → *Points system*.
11. **The app is called Habit Zone** and uses the supplied icon (`mobile/assets/brand/habitzone_icon.svg`, regenerate assets with `tools/generate_brand_assets.py`). Do not show the ILM HUB logo in the app — only the text credit "Made by ILM HUB". See AGENTS.md → *Branding*.
12. **Startup must never block on the API** — profile/programs providers are cache-first `StreamProvider`s. See *Startup speed*.
13. **API schemas are the contract:** a field not in the response model is silently dropped (see *Groups v2 → Lesson*). Test through the schema, not just the service.
14. **Dark mode is real** — use `AppColors.*` getters (surface/text/border/…Soft), never hard-coded light colors, and don’t put theme-dependent colors in `const` widgets. See AGENTS.md → *Theme & dark mode*.

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
- Web dev URL is always `http://127.0.0.1:5210` (Supabase Redirect URLs and CORS are set for it). `.\run-chrome.ps1` (hot reload) only works in the Chrome window it opens; to view in **VS Code Simple Browser** or any tab run `flutter build web --release --dart-define-from-file=env.json` then `python tools/serve_web.py`
- Deployed API: https://ilm-mode-api.onrender.com/v1 (Render free plan; sleeps when idle, ~30–60 s cold start)
- Repo: remote `umar` → https://github.com/umartohirov/21-app.git (moved to `umar-toirov/21-app`); old remote `origin` = `toiroff/21-app`. Push with `git push umar main`.
- github.com:443 is flaky on this network: a failed push says `port 443` — just retry.

## Where to edit

| Work | Start here |
|------|------------|
| Auth / landing UI | `mobile/lib/features/auth/` |
| Challenges | `mobile/lib/features/challenge/` |
| Groups | `mobile/lib/features/group_challenge/` |
| API / services | `backend/app/api/v1/router.py`, `backend/app/services/` |
| Theme / dark mode | `mobile/lib/core/theme/app_theme.dart`, `mobile/lib/app.dart` |
| Brand intro / icons | `mobile/lib/core/widgets/brand_intro.dart`, `mobile/tools/generate_brand_assets.py` |
| Challenge picker / setup | `mobile/lib/features/onboarding/.../onboarding_screen.dart`, `mobile/lib/features/challenge/.../challenge_setup_screen.dart` |
| Task rows / completion effects | `mobile/lib/core/widgets/shared_widgets.dart` (`TaskTile`), `mobile/lib/core/services/sound_service.dart` |
| Cache / fast startup | `mobile/lib/core/cache/app_cache.dart`, `mobile/lib/core/providers/providers.dart` |
| Group chat / group home | `mobile/lib/features/group_challenge/presentation/widgets/group_chat.dart`, `.../screens/group_home_screen.dart` |
| Rankings (people + groups) | `mobile/lib/core/widgets/ranking_widgets.dart`, `mobile/lib/features/statistics/.../leaderboard_tab.dart` |
| Home calendar / explanations | `mobile/lib/features/challenge/.../activity_calendar.dart`, `mobile/lib/core/widgets/how_it_works.dart` |
| Group points / ranking | `backend/app/services/group_service.py` (+ `backend/tests/test_group_points.py`) |

## If stuck

| Symptom | Likely cause |
|---------|----------------|
| Login fails, UI fine | Supabase Auth / email confirm / Google redirect URL |
| Login OK, no data / 500 | Backend down, wrong `API_BASE_URL`, or DB/`as_utc` issues |
| Blank Chrome at `:8090` | Use `run-chrome.ps1`, not the proxy |
| Create group “date” errors | Ensure `datetime.date` imported in `group_service.py` |
| `tools.test_db` says “tenant/user not found” | Supabase project paused or wrong pooler host/region in `DATABASE_URL` |
| Android build: “NDK … source.properties” | Broken NDK download. Delete `%LOCALAPPDATA%\Android\sdk\ndk\<ver>` and rebuild, or use the GitHub Actions APK build |
| `flutter run` fails writing the Chrome profile | Old Chrome still holds `%TEMP%\ilm-mode-chrome` — close it, rerun |
| Theme change doesn’t show on a widget | It uses a `const` widget or static color; use an `AppColors` getter in a non-const context |

## Deeper docs

- [AGENTS.md](./AGENTS.md) — complete agent handbook  
- [docs/DEPLOY.md](./docs/DEPLOY.md) — Phase 1 DB / Phase 2 API host  
- [docs/PLANNING.md](./docs/PLANNING.md) — product scope  
- [docs/GROUPS_DESIGN.md](./docs/GROUPS_DESIGN.md) — groups UX  
- AGENTS.md → *Change log* and *Open TODOs* — what was done and what is pending
