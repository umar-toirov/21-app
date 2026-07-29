# AGENTS.md — ILM Mode ("21")

Guidance for AI agents and developers working in this repo.

## What this project is

Discipline-building Flutter + FastAPI app for students: challenges, HP, streaks, groups, badges, certificates. Planning/spec: `docs/PLANNING.md`. Human README: `README.md`.

## Three separate pieces (do not confuse them)

| Piece | Role | When it fails |
|-------|------|----------------|
| **Flutter** (`mobile/`) | UI: screens, design, navigation | App won’t open / layout bugs |
| **Backend** (`backend/`) | API: challenges, HP, groups, profiles (SQLite locally) | Data after login fails; `/v1/health` down |
| **Supabase** | Auth only (email signup/login JWT) | Signup/login errors, email rate limits |

**Design / UI editing** needs Flutter (+ optional backend). It does **not** require a successful login or Android Studio.

**Login/signup** = Supabase. **App data after auth** = backend.

## Machine / toolchain (this workspace)

- OS: Windows
- Flutter SDK: `C:\src\flutter` (add `C:\src\flutter\bin` to `PATH`; set `FLUTTER_ROOT=C:\src\flutter`)
- Backend: Python + uvicorn on `http://127.0.0.1:8000`
- Local DB: SQLite at `backend/ilmmode.db` (`DATABASE_URL=sqlite+aiosqlite:///./ilmmode.db`) — used because Supabase Postgres was unreachable from this network
- Secrets: `backend/.env`, `mobile/env.json`, `mobile/env.android.json` (gitignored; never commit or paste keys into docs/chat)

## Project layout

```
App/
├── AGENTS.md              # This file
├── README.md
├── docs/PLANNING.md
├── docker-compose.yml
├── backend/               # FastAPI + SQLAlchemy
│   ├── .env
│   ├── ilmmode.db         # Local SQLite (dev)
│   └── app/
└── mobile/                # Flutter app
    ├── env.json           # Chrome / localhost API
    ├── env.android.json   # Emulator → 10.0.2.2
    ├── run-chrome.ps1
    ├── run-phone-preview.ps1
    └── lib/
```

## How to run (Windows)

### 1. Backend (Terminal 1)

```powershell
cd C:\Users\Muhammadumar\OneDrive\Desktop\App\backend
python -m pip install -r requirements.txt
python -m uvicorn app.main:app --reload --host 127.0.0.1 --port 8000
```

Health check: `http://127.0.0.1:8000/v1/health` → `{"status":"ok","service":"ilm-mode-api"}`  
API docs: `http://127.0.0.1:8000/docs`

### 2. Flutter — Chrome (preferred for design)

```powershell
cd C:\Users\Muhammadumar\OneDrive\Desktop\App\mobile
.\run-chrome.ps1
```

Phone-sized Chrome window (side-by-side coding):

```powershell
.\run-phone-preview.ps1
```

Hot reload: press `r` in the Flutter terminal (or `R` for hot restart).  
Side-by-side: Cursor **Win+←**, Chrome **Win+→**.

Uses `env.json` → `API_BASE_URL=http://localhost:8000/v1`.

### 3. Flutter — Android emulator

Requires Android Studio + a virtual device (AVD). Chrome works without this.

1. Install [Android Studio](https://developer.android.com/studio)
2. Device Manager → Create Device (e.g. Pixel 7) → download **one** system image (~1–2 GB) → Finish → Play
3. Accept licenses: `flutter doctor --android-licenses`
4. With emulator running and backend up:

```powershell
cd C:\Users\Muhammadumar\OneDrive\Desktop\App\mobile
$env:Path = "C:\src\flutter\bin;" + $env:Path
flutter run --dart-define-from-file=env.android.json
```

Uses `env.android.json` → `API_BASE_URL=http://10.0.2.2:8000/v1` (emulator’s alias for host localhost).

There is **no iPhone simulator on Windows**. Closest options: Chrome phone window or Android emulator.

### VS Code / Cursor launch configs

`mobile/.vscode/launch.json` includes:

- Phone preview (Chrome)
- Android emulator
- Chrome (full browser)

## Auth flow (brief)

1. **Signup:** Supabase `signUp` → `POST /profiles` → onboarding  
2. **Login:** Supabase `signInWithPassword` → `GET /me` (JWT + profile; backend may auto-create profile)  
3. JWT verified with `SUPABASE_JWT_SECRET` from `backend/.env`

If Supabase “Confirm email” is enabled, signup may require checking email. Rate limit `429 over_email_send_rate_limit` means wait or disable confirm email in Supabase Auth settings for local testing.

## Flutter UI locations (design work)

| Area | Path |
|------|------|
| Landing | `mobile/lib/features/auth/presentation/screens/landing_screen.dart` |
| Login / signup | `mobile/lib/features/auth/presentation/screens/` |
| Onboarding | `mobile/lib/features/onboarding/` |
| Challenge dashboard | `mobile/lib/features/challenge/presentation/screens/` |
| Groups | `mobile/lib/features/groups/` |
| Statistics | `mobile/lib/features/statistics/` |
| Profile / badges | `mobile/lib/features/profile/` |
| Settings | `mobile/lib/features/settings/` |
| Router | `mobile/lib/core/router/app_router.dart` |
| Theme | `mobile/lib/core/theme/` (or equivalent under `core/`) |

Import depth: feature screens typically use `../../../../core/...` (not `../../../core/`).

## Backend notes

- Dev DB is **SQLite**, not Postgres. Models use portable `JSON` / UUID types (not Postgres-only `JSONB` where avoided for SQLite).
- **Phase 1 cloud data:** point `DATABASE_URL` at **Supabase Postgres** (see `docs/DEPLOY.md`). Auth stays on Supabase; FastAPI still runs locally until Phase 2 host (Render/Railway).
- Startup seeds goals/badges/quotes when empty.
- Do not assume Docker Postgres is required for local UI work.

## Known issues / gotchas

- **Android toolchain incomplete** without Android Studio AVD + licenses; `flutter emulators` may show none until AVD is created.
- **Visual Studio** incomplete → Windows desktop Flutter target may fail; use Chrome instead.
- **Landing overflow** on narrow Chrome windows (yellow/black stripes) — widen window or fix layout in landing screen.
- **Login `setState` after dispose** — guard with `mounted` after async auth.
- **Secrets exposed in chat historically** — rotate Supabase keys if they were shared; never commit `.env` / `env.json`.
- Manual cmdline-tools installs on this machine were unreliable; prefer Android Studio’s SDK Manager for emulator setup.

## What agents should / should not do

**Do:**

- Prefer Chrome (`run-chrome.ps1` / phone preview) for UI/design iteration
- Keep backend on port 8000 when testing API-backed flows
- Use `env.android.json` only for Android emulator runs
- Match existing Flutter/Riverpod/go_router patterns; minimal diffs
- Ask before git commit/push

**Do not:**

- Confuse Supabase auth failures with Flutter UI bugs
- Switch back to remote Postgres without confirming network/connectivity
- Commit secrets or rewrite large unrelated areas
- Assume iOS Simulator exists on Windows
- Spend time on Android emulator setup when the user only wants design editing in Chrome

## Quick decision guide

| User goal | Do this |
|-----------|---------|
| Edit design / see screens | Backend optional; `.\run-chrome.ps1` |
| Test login | Supabase + Flutter; check email confirm / rate limits |
| Test challenges after login | Backend + Flutter + successful auth |
| Phone-shaped preview without Android | `.\run-phone-preview.ps1` |
| Real Android emulator | Android Studio AVD + `env.android.json` |

## API base (reminder)

- Base path: `/v1`
- Health: `GET /v1/health`
- Profile: `GET/PATCH/DELETE /me`
- Full route map: `README.md` and `docs/PLANNING.md`
