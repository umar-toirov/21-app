# AGENTS.md — ILM Mode ("21")

Guidance for AI agents and developers working in this repo.

## What this project is

Discipline-building Flutter + FastAPI app for students: challenges, HP, streaks, groups, badges, certificates. Not a chat app — groups are an **accountability platform**.

| Doc | Purpose |
|-----|---------|
| `README.md` | Human quick start |
| `docs/PLANNING.md` | Product / technical PRD |
| `docs/DEPLOY.md` | Supabase DB + future API host |
| `docs/GROUPS_DESIGN.md` | Groups IA / screens |
| `CLAUDE.md` | Short entry for Claude Code (points here) |

**GitHub:** https://github.com/toiroff/21-app (branch `main`)

## Three pieces (do not confuse them)

| Piece | Role | When it fails |
|-------|------|----------------|
| **Flutter** (`mobile/`) | UI, navigation, Riverpod, go_router | App won’t open / layout bugs |
| **Backend** (`backend/`) | FastAPI: challenges, HP, groups, profiles | Data after login fails; `/v1/health` down |
| **Supabase** | **Auth** (email + Google JWT) **and** **Postgres** (app data) | Signup/login errors; empty/missing cloud data |

**Design / UI** → Flutter (+ optional backend). Does **not** need login or Android Studio.  
**Login/signup** → Supabase Auth.  
**App data after auth** → FastAPI → Supabase Postgres (preferred) or local SQLite fallback.

Supabase **cannot** host the Python FastAPI process. Phase 2 later: Render Free or Railway for the API only (`docs/DEPLOY.md`).

## Machine / toolchain (this workspace)

- OS: Windows
- Flutter SDK: `C:\src\flutter` (`PATH` += `C:\src\flutter\bin`; `FLUTTER_ROOT=C:\src\flutter`)
- Backend: Python + uvicorn — prefer **`http://127.0.0.1:8001`** (also fine on `8000` if free)
- Database: **`DATABASE_URL` in `backend/.env`**
  - Production-like: Supabase Postgres (`postgresql+asyncpg://…` or `postgresql://…`; app normalizes + SSL)
  - Fallback: `sqlite+aiosqlite:///./ilmmode.db` if home network blocks Supabase
- Test DB: `cd backend; python -m tools.test_db`
- Secrets (gitignored — never commit or paste into chat):  
  `backend/.env`, `mobile/env.json`, `mobile/env.android.json`, `mobile/env.android.usb.json`

## Project layout

```
App/
├── AGENTS.md / CLAUDE.md
├── README.md
├── docs/
│   ├── PLANNING.md
│   ├── DEPLOY.md
│   └── GROUPS_DESIGN.md
├── docker-compose.yml
├── backend/
│   ├── .env / .env.example
│   ├── Dockerfile          # $PORT-aware (Render/Railway later)
│   ├── tools/test_db.py
│   ├── tools/set_supabase_db_url.ps1
│   └── app/
└── mobile/
    ├── env.json            # Chrome → 127.0.0.1:8001
    ├── env.android.json    # Emulator → 10.0.2.2:8001
    ├── env.android.usb.json
    ├── env.production.json.example
    ├── run-chrome.ps1      # Preferred Flutter web
    ├── run-phone-preview.ps1
    ├── run-android-emulator.ps1
    ├── run-phone-usb.ps1
    └── lib/
```

## How to run (Windows)

### 1. Backend

```powershell
cd C:\Users\Muhammadumar\OneDrive\Desktop\App\backend
python -m pip install -r requirements.txt
python -m tools.test_db
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8001
```

Health: `http://127.0.0.1:8001/v1/health` → `{"status":"ok","service":"ilm-mode-api"}`  
Docs: `http://127.0.0.1:8001/docs`

Match `API_BASE_URL` in `mobile/env.json` to the same port.

### 2. Flutter — Chrome (preferred)

```powershell
cd C:\Users\Muhammadumar\OneDrive\Desktop\App\mobile
.\run-chrome.ps1
```

Phone-sized window: `.\run-phone-preview.ps1`  
Hot reload: `r` / hot restart: `R` in the Flutter terminal.

**Do not** use the same-origin proxy (`8090`) for day-to-day debug — Flutter `web-server` + proxy often shows a blank page. Use `flutter run -d chrome` via `run-chrome.ps1`.

### 3. Flutter — Android emulator

AVD exists (e.g. `Pixel_9_Pro`). Backend must be up.

```powershell
cd mobile
.\run-android-emulator.ps1
# or: flutter run -d android --dart-define-from-file=env.android.json
```

`10.0.2.2` = emulator → host PC. Align port with uvicorn (8001).

USB phone: `.\run-phone-usb.ps1` + `adb reverse` (USB debugging required).  
No iOS Simulator on Windows.

### Launch configs

`mobile/.vscode/launch.json`: Phone preview (Chrome), Android emulator, Android USB, Chrome full.

## Auth flow

1. **Signup:** Supabase `signUp` → `POST /profiles` → onboarding  
2. **Login:** `signInWithPassword` or Google OAuth (PKCE web) → `GET /me`  
3. JWT verified with `SUPABASE_JWT_SECRET`  
4. Web: path URL strategy + `/auth/callback`; add Redirect URLs in Supabase for each origin used  

Email confirm / `429 over_email_send_rate_limit`: wait or disable confirm email for local testing.

## Product rules agents must respect

- **One personal + one group challenge** may run in parallel; starting a second personal (or second group) archives/blocks only that type. Creating/joining a group does **not** archive a personal challenge  
- **Day advance at midnight** via `sync_calendar_day` — do not bump `current_day` on task complete  
- **Discipline score** starts at **0** for new profiles  
- **Groups ≠ chat** — activity feed, announcements, leaderboard, stats only  
- Foundation tasks on group create: leader-chosen; joiners inherit leader’s foundation list. Task mode `shared` (foundation only) or `freedom` (foundation + each member’s personal tasks)  

## Flutter UI map

| Area | Path |
|------|------|
| Landing / auth | `mobile/lib/features/auth/presentation/screens/` |
| Onboarding | `mobile/lib/features/onboarding/` |
| Challenge home / detail / history | `mobile/lib/features/challenge/presentation/screens/` |
| Groups | `mobile/lib/features/group_challenge/` (not `features/groups/`) |
| Group widgets | `…/group_challenge/presentation/widgets/group_widgets.dart` |
| Statistics | `mobile/lib/features/statistics/` |
| Profile / badges | `mobile/lib/features/profile/` |
| Settings | `mobile/lib/features/settings/` |
| Shell / tabs | `mobile/lib/features/shell/` |
| Router | `mobile/lib/core/router/app_router.dart` |
| Theme | `mobile/lib/core/theme/app_theme.dart` |

Import depth from feature screens: usually `../../../../core/...`.

Brand: primary orange `#F15A29`, teal success, gold achievements, blue accent only.

## Backend notes

- Prefer **Supabase Postgres** via `DATABASE_URL` (`asyncpg`, SSL for cloud hosts)  
- SQLite still supported for offline/local if Postgres unreachable  
- Startup: `create_all` + seed goals/badges/quotes when empty  
- Group APIs: dashboard (stats/feed/announcements/sessions), member profile + heatmap, statistics, announcements, settings, remove member  
- Jobs: `POST /v1/close-day` (internal secret)  
- Portable types (`JSON`, UUID) — avoid Postgres-only types that break SQLite  

## Known issues / gotchas

- Blank page on `http://127.0.0.1:8090` (proxy + web-server) — use `run-chrome.ps1` instead  
- `localhost` vs `127.0.0.1` IPv6 mismatch on Windows — prefer `127.0.0.1`  
- CORS: list explicit origins; `*` incompatible with credentials  
- Naive vs aware datetimes from SQLite/Postgres — use `as_utc` helpers  
- Android USB: device may not appear until USB debugging + allow prompt  
- First Android Gradle build can take many minutes (esp. under OneDrive)  
- Visual Studio incomplete → skip Windows desktop Flutter target  
- Secrets may have been shared in chat historically — rotate if unsure  

## What agents should / should not do

**Do:**

- Prefer Chrome for UI/design  
- Keep backend running when testing authenticated / group flows  
- Match Riverpod / go_router / existing patterns; minimal diffs  
- Ask before git commit / push  
- Read `docs/DEPLOY.md` before changing hosting or `DATABASE_URL` strategy  

**Do not:**

- Confuse Supabase Auth failures with Flutter layout bugs  
- Assume FastAPI can run *inside* Supabase  
- Commit `.env` / env JSON with keys  
- Rewrite large unrelated areas or build a chat UI for groups  
- Assume iOS Simulator on Windows  
- Spend long on Android setup when the user only wants Chrome design work  

## Quick decision guide

| User goal | Do this |
|-----------|---------|
| Edit design / see screens | `.\run-chrome.ps1` (backend optional) |
| Test login / Google | Supabase + Flutter; check Redirect URLs |
| Test challenges / groups | Backend + Flutter + auth; DB = Supabase or SQLite |
| Wire / check cloud DB | `python -m tools.test_db`; see `docs/DEPLOY.md` |
| Phone-shaped preview | `.\run-phone-preview.ps1` |
| Android emulator | `.\run-android-emulator.ps1` |
| Public API without PC | Phase 2 — Render/Railway (not done yet) |

## API reminder

- Base: `/v1`  
- Health: `GET /v1/health`  
- Profile: `GET/PATCH/DELETE /me`  
- Groups: `/groups`, `/groups/preview/{code}`, `/groups/join`, `/groups/{id}/dashboard`, `/groups/{id}/day-roster`, announcements, members, statistics, sessions  
- Full map: `README.md`, `docs/PLANNING.md`
