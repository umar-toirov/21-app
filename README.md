# ILM Mode ("21")

Discipline-building platform for students. Not a habit tracker — a structured training program with challenges, HP, streaks, leaderboards, group accountability, and certificates.

## Stack

| Layer | Technology |
|-------|------------|
| Mobile | Flutter, Riverpod, go_router, Supabase Auth |
| Backend | FastAPI, SQLAlchemy, PostgreSQL |
| Auth | Supabase Auth |
| Storage | Supabase Storage (certificates) |
| Notifications | Firebase Cloud Messaging (placeholder) |
| Hosting | Railway (backend) |

## Project Structure

```
App/
├── mobile/          # Flutter app ("21")
├── backend/         # FastAPI API
├── docs/            # Planning & architecture
└── docker-compose.yml
```

## Quick Start

### 1. Database & API (Docker)

```bash
docker compose up -d
```

API runs at `http://localhost:8000` · Docs at `http://localhost:8000/docs`

### 2. Backend (local)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate        # Windows
pip install -r requirements.txt
copy .env.example .env
python -m scripts.seed
uvicorn app.main:app --reload --port 8000
```

### 3. Flutter Mobile

Install [Flutter SDK](https://docs.flutter.dev/get-started/install), then:

```bash
cd mobile
flutter create . --project-name ilm_mode   # generates android/ios if missing
flutter pub get
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1 \
            --dart-define=SUPABASE_URL=https://your-project.supabase.co \
            --dart-define=SUPABASE_ANON_KEY=your-anon-key
```

> Use `10.0.2.2` for Android emulator; `localhost` for iOS simulator / desktop.

### 4. Supabase Setup

1. Create a Supabase project
2. Enable **Email** auth
3. Enable **Google** auth (Authentication → Providers → Google):
   - Create OAuth credentials in [Google Cloud Console](https://console.cloud.google.com/apis/credentials)
   - Application type: **Web application**
   - Authorized redirect URI: `https://<YOUR_PROJECT_REF>.supabase.co/auth/v1/callback`
   - Paste Client ID + Client Secret into Supabase Google provider
4. Authentication → URL Configuration → Redirect URLs, add:
   - `http://localhost:8090/**`
   - `http://127.0.0.1:8090/**`
   - `http://localhost:*/**` (optional for Flutter web ports)
   - `io.supabase.ilmmode://login-callback/` (Android / iOS deep link)
5. Copy URL + anon key + JWT secret into `.env` (backend) and `env.json` / `--dart-define` (Flutter)
6. Optional: add a Database Webhook on `auth.users` INSERT → `POST /v1/profiles`

Google sign-in uses Supabase OAuth (`Continue with Google` on Login / Sign Up). After consent, the app opens `/auth/callback`, creates a profile if needed, then routes to onboarding or home.

## Features Implemented

- Landing, login, signup, forgot password
- 5-step onboarding (goal, duration, foundation, personal tasks, commitment)
- Challenge dashboard with tasks, HP, streak, progress path, celebration
- Recovery mode (3-day miss trigger)
- Challenge completion + certificates + badges
- Statistics (personal analytics + global leaderboard)
- Group challenges (create, join, leader dashboard)
- Profile, badges, certificates, payment history
- Settings (notifications, dark mode, delete account, sign out)
- Payment intent API (+ dev simulate endpoint)

## API Overview

Base URL: `/v1`

| Area | Endpoints |
|------|-----------|
| Profile | `GET/PATCH/DELETE /me` |
| Onboarding | `GET /onboarding`, `PUT /onboarding/step/{n}`, `POST /onboarding/complete` |
| Challenges | `GET /challenges/active`, `POST .../complete-task` |
| Groups | `POST /groups`, `POST /groups/join`, `GET /groups/{id}/dashboard` |
| Stats | `GET /statistics/me`, `GET /leaderboard` |
| Payments | `POST /payments/intent`, `POST /payments/{id}/simulate-complete` (dev) |

Full spec: [`docs/PLANNING.md`](docs/PLANNING.md)

## Development

```bash
# Backend lint
cd backend && ruff check app

# Run backend tests
cd backend && pytest

# Flutter analyze
cd mobile && flutter analyze
```

## Environment Variables

### Backend (`.env`)

| Variable | Description |
|----------|-------------|
| `DATABASE_URL` | PostgreSQL connection string |
| `SUPABASE_JWT_SECRET` | Supabase JWT secret for auth |
| `INTERNAL_JOB_SECRET` | Secret for cron job endpoints |
| `CHALLENGE_PRICE_UZS` | Price for additional challenges (default 99000) |

### Flutter (`--dart-define`)

| Variable | Description |
|----------|-------------|
| `API_BASE_URL` | Backend API base URL |
| `SUPABASE_URL` | Supabase project URL |
| `SUPABASE_ANON_KEY` | Supabase anon key |

## License

Proprietary — ILM Mode
