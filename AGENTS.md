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
- Supabase project (new account): ref `bbjbrjuyzfzavpdlednp` → `https://bbjbrjuyzfzavpdlednp.supabase.co` (the old project `jnwylgvm…` is dead/paused)
- Database: **`DATABASE_URL` in `backend/.env`**
  - Production-like: Supabase Postgres (`postgresql+asyncpg://…` or `postgresql://…`; app normalizes + SSL). Use the **Session pooler** URI, port 5432
  - Fallback: `sqlite+aiosqlite:///./ilmmode.db` if home network blocks Supabase
- Test DB: `cd backend; python -m tools.test_db`
- Secrets (gitignored — never commit or paste into chat):  
  `backend/.env`, `mobile/env.json`, `mobile/env.android.json`, `mobile/env.android.usb.json`, `mobile/env.production.json`
- The Supabase **anon key** is public by design (it ships in the app); never paste the DB password, JWT secret or service-role key into chat or git

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

`run-chrome.ps1` pins the web server to **`127.0.0.1:5210`** (`--web-hostname` / `--web-port`). Supabase Redirect URLs (`http://127.0.0.1:5210/**`, `/auth/callback`) and `CORS_ORIGINS` are configured for that port — don’t change it casually.  
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
- **Challenges are free.** Payment endpoints, `PaymentService`, price config and the payment-history screen were deleted. The `payments` table/model and `Challenge.payment_id` / `PENDING_PAYMENT` remain only so the live DB schema needs no migration — don’t build on them  
- **Group points ≠ personal HP.** A member’s group score is the sum of `HpEvent` deltas on *their group challenge only* (`GroupService._group_points`): the daily reward (+10) and the missed-day penalty (−15) both count, floored at 0. Legacy challenges with zero events fall back to completed days × 10. Leaderboard order: group points, perfect days, completed today, streak, name. The app must never fall back to `profile.hp` in group UI  
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

- `flutter run` can’t restart if an old dev Chrome still owns `%TEMP%\ilm-mode-chrome` (“file is being used by another program”) — close that Chrome (only the one started by `run-chrome.ps1`) first  
- `github.com:443` timeouts are intermittent on this network; retry `git push` (usually works within 1–3 tries)  
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
- **No payment endpoints** — `/payments*` were removed (challenges are free)

## Theme & dark mode (read before touching UI)

- Design language: calm, habit-tracker style — **Inter**, weights 500–700, 1 px borders, soft shadows, flat buttons (`PrimaryButton` = orange, subtle press-scale, no 3D edge), tinted flat icon tiles (`GlossyIcon` is now flat), no looping/bouncing animations
- **`AppColors`** (`mobile/lib/core/theme/app_theme.dart`): brand hues are `const` (`orange`, `teal`, `gold`); surfaces/text/borders/tints are **getters** that read `AppColors.isDark` (`background`, `surface`, `surfaceRaised`, `border`, `borderStrong`, `textPrimary`, `textSecondary`, `muted`, `cream`, `orangeSoft`, `blueSoft`, `tealSoft`, `goldSoft`, `dangerSoft`, `blue`, `navy`)
- **Rules:** never hard-code light colors (`Color(0xFFFFF…)`, `Colors.white` fills); do not use theme-dependent `AppColors` inside `const` widgets or `static const` fields (use `static Color get …`). After adding such code run `flutter analyze` — const errors mean a theme color slipped into a const context
- `mobile/lib/app.dart` sets `AppColors.isDark` each build from `themeModeProvider` (Auto/Light/Dark, saved in SharedPreferences key `theme_mode`, follows the OS in Auto) and wraps the tree in `KeyedSubtree(ValueKey(isDark))` so a flip rebuilds everything once. `setThemeMode(ref, mode)` is the only setter
- `ThemeData` for both modes is built in `AppTheme._build` (buttons, inputs, dialogs, sheets, snackbars, switches, segmented buttons). Page transitions are a fast fade+rise (`_SnappyTransitions`; Cupertino on iOS)
- Settings (`features/settings/…`) has the Auto/Light/Dark selector; Language and Support/About/Terms/Privacy are working sheets

## Challenge frameworks, start date, skip (onboarding)

- **Catalog:** ~40 built-in frameworks in 9 categories live in `backend/app/data/challenge_templates.py` (static code, no DB migration). Each has `id, title, category, difficulty (easy/medium/hard), icon key, goal slug, description, duration_days, tasks[]`. Served by `GET /v1/challenge-templates`. `backend/tests/test_challenge_templates.py` validates the catalog (unique ids, known categories/goals, 2–10 tasks) — keep it passing when adding templates
- **Create:** `POST /v1/challenges` `{template_id?, name?, duration_days 7–90, start_date?, personal_tasks (2–10), include_foundation}` → `ChallengeService.create_personal_challenge` (also used by the legacy `/onboarding/complete`). Task titles are trimmed and de-duplicated; one active personal challenge at a time (409 otherwise)
- **Start date:** today up to 60 days ahead (a past date is treated as today). Calendar days start on the chosen date. **Scheduled = personal challenge whose `start_date` is in the future** (status stays `ACTIVE`, no schema change). While scheduled: `complete_task` raises `NOT_STARTED`, `sync_calendar_day` applies no penalties, `build_detail` returns `days_until_start` and a "Starts …" mission. Group challenges are unaffected (they use the group's own start date)
- **Skip:** `POST /v1/onboarding/skip` sets `onboarding_step = 6` without creating a challenge; the app then opens the Groups tab so the user can join a group. Home shows the "No personal program" card, so they can start one later
- **App:** `features/onboarding/.../onboarding_screen.dart` is now the **picker** (header, search, category chips, 2/3-column grid, "Create your own", Skip only when `profile.needsOnboarding`, back button when pushed from Home). `features/challenge/.../challenge_setup_screen.dart` (route `AppRoutes.newChallenge`, `extra` = template or null) edits name, duration (7/14/21/30/60), tasks, "daily basics" toggle and start date (Today / Tomorrow / Pick). **No icon picker** — the icon comes from the framework (`core/widgets/challenge_icons.dart` maps the API's icon key + category colour). Home's "Start Challenge" must `push` (not `go`) the picker so Back works. Errors are shown via `core/network/api_error.dart`
- **UI tests:** `mobile/test/challenge_flow_test.dart` renders picker + setup at phone size in light and dark (search/filter/select/continue, Skip visibility, start-date summary, task validation). Run `cd mobile; flutter test`
- Not done on purpose: reminder time (no notification backend yet — don't add a dead control)

## Points system (backend is the source of truth)

- Constants in `backend/app/services/challenge_service.py`: `TASK_POINTS = 5` (every completed task, immediately), `DAY_BONUS_POINTS = 10` (perfect day, plus streak +1), `MISSED_DAY_PENALTY = 15` (each missed day, streak reset). Stored as `HpEvent` rows (`task_complete`, `daily_complete`, `missed_day`) and summed into `profile.hp` (floored at 0). New profiles start at **0** points
- Missed days are applied in `sync_calendar_day` (runs whenever the challenge is read, and from the `close-day` job). The response carries a transient `penalty_points` (not stored) so the app can show a one-time "You missed a day" dialog; the app strips it before caching. `points_today` = the current day's `hp_delta`
- `complete_task` returns `hp_delta` (this tap only, e.g. 5, or 15 on the last task) and `celebration` (perfect day). The app shows `+5` hints from `_taskPointsHint` in `challenge_detail_screen.dart` — keep it equal to `TASK_POINTS`
- Group ranking uses the same events for the group challenge only (see *Group points* above). Tests: `backend/tests/test_points.py`

## Task completion feedback

- `TaskTile` (`core/widgets/shared_widgets.dart`) plays a burst (ring + confetti + floating `+points`), a haptic tap and a sound when `isCompleted` flips to true. A perfect day plays a longer sound + `CelebrationOverlay`
- Sounds: `mobile/assets/sounds/task_done.wav`, `day_complete.wav` (regenerate with `python tools/generate_sounds.py`), played by `core/services/sound_service.dart` (`audioplayers`, never throws; `SoundService.instance.enabled`, persisted). Set `enabled = false` in tests. Settings has a Sounds switch

## Startup speed (why the app used to take ~1 minute)

- Cause: the API runs on Render's free plan, which sleeps when idle (30–60 s wake) and every launch blocked on `GET /me`, with 15 s timeouts and retries
- Fixes: `core/cache/app_cache.dart` keeps the last profile/programs (and an `onboarded` flag); `profileProvider` and `activeProgramsProvider` are now **`StreamProvider`s that emit the cached value first, then the fresh one** (errors are swallowed if a cache exists). The router sends a signed-in, onboarded user straight to Home. Dio timeouts are 30 s connect / 60 s receive, with 2 automatic retries for GETs. `main.dart` fires a warm-up `GET /health` immediately. `SlowLoadingHint` explains the wait after 6 s
- Real fix still needed on the server side: an always-on host, or a cron keep-alive pinging `/v1/health` every ~10 min. Tests must override these providers with `Stream.value(...)`

## Branding (app name **Habit Zone**)

- **Name:** the app is called **Habit Zone** (`AppConfig.appName` in `core/config/env.dart`; Android label in `AndroidManifest.xml`; `web/index.html`; `web/manifest.json`). It was "21" before. The "21-day" idea remains the product concept and copy ("21-Day Challenge…"). Package id is still `com.ilmmode.app.ilm_mode` — **decide the permanent one before publishing** (e.g. `com.ilmhub.habitzone`). Store title suggestion: "Habit Zone – 21-Day Challenges"
- **Icon:** supplied by the user as `mobile/assets/brand/habitzone_icon.svg` (navy→blue rounded square, orange/gold and teal progress rings, white check). Regenerate every derived file with `python tools/generate_brand_assets.py` (from `mobile/`; needs Pillow + Chrome, which renders the SVG). It writes: Android adaptive icon layers (`drawable-*/ic_launcher_background|foreground|monochrome.png`, monochrome = Android 13 themed icon), legacy `mipmap-*/ic_launcher.png`, splash images, web icons/favicon/maskable icons, and `assets/brand/app_icon.png`, `app_glyph.png` (white check, for dark backgrounds), `app_glyph_light.png` (navy check, for light backgrounds), `app_icon_1024.png` (store icon)
- **Native launch screen:** brand navy `#033D95` (`values*/colors.xml` → `splash_background`) with the glyph (`splash_icon.png` Android 12+, `splash_logo.png` older). The Flutter intro (`core/widgets/brand_intro.dart`, `kBrandNavy`) uses the same navy + glyph so the hand-off has no flash; then app name, tagline and "Made by ILM HUB". ~1.6 s, tap to skip, once per launch. It needs its own `Material` (it sits above the Navigator; text otherwise gets the debug yellow underline)
- **ILM HUB** appears only as the text credit "Made by ILM HUB" (intro, landing, About). The old ILM emblem files in `assets/brand/` (`icon*.png`, `logo*.png`, `mountain*.png`, `emblem.png`) are no longer bundled or used and can be deleted. Only `google_logo.svg`, `app_icon.png`, `app_glyph.png` are bundled (`pubspec.yaml`)
- Landing shows the app icon + name; login/signup/home use the `AppWordmark` text widget

## Preview harness (screenshots without login)

`mobile/tools/preview_main.dart` renders detail/home/picker/setup/intro with sample data. Build: `flutter build web --debug -t tools/preview_main.dart --output build/preview`, serve it, open `?screen=detail&dark=1`, screenshot with headless Chrome at `--window-size=500,900`

## Groups v2: tasks, chat, rankings, leaving

- **Rule change:** groups now have **chat** (the user asked for it). Older docs saying "groups are not chat" are obsolete. Still no direct messages, no media, no reactions
- **No foundation tasks in groups.** The admin defines "group tasks" (shared by everyone) at creation and can add/remove them any time (`POST/DELETE /groups/{id}/tasks`, `GET` to list; Group settings screen). They are stored on each member's group challenge as `TaskType.FOUNDATION` (no DB enum change) and shown as **"Group task"**; a member's own tasks are `PERSONAL` and shown as **"My task"** (`TaskTile(groupTask: true)`). `task_mode`: `shared` (everyone does the admin's tasks; needs ≥1) or `freedom` (members also choose their own; admin's group tasks optional; each joiner needs ≥1 own task unless the group has tasks). Old app builds may send `foundation_tasks`; `GroupCreate.group_tasks` accepts both names
- **Join flow:** `GET /groups/preview/{code}` returns `group_tasks`, `leader_name`, `member_count`. The join screen shows the admin's tasks read-only, and only asks for own tasks in `freedom` groups. `JoinGroupScreen(initialCode:)` supports links
- **Leave/end:** `POST /groups/{id}/leave` (members; the admin gets `LEADER_CANNOT_LEAVE`), `DELETE /groups/{id}` (admin ends the group, archives everyone's challenge). Cancelling a *group* challenge is not allowed (`USE_LEAVE_GROUP`)
- **Chat:** table `group_messages` (new, created by `create_all`, no migration). `GET /groups/{id}/messages?after=<id>|before=<id>&limit`, `POST` (≤1000 chars, 15/min → 429), `DELETE /messages/{id}` (author or admin; soft delete). The app polls every 4 s while the Chat tab is open (`features/group_challenge/presentation/widgets/group_chat.dart`), sends optimistically, and can retry failed sends
- **Rankings:** members ranked by group points (see *Points system*). `GET /leaderboard` (people; metrics `hp` Points, `longest_streak`, `challenges_completed`; the redundant Discipline metric is no longer offered in the UI), `GET /leaderboard/me` (your rank), `GET /leaderboard/groups?metric=total|average` (groups ranked by the sum/average of their members' non-negative group points). Shared UI: `core/widgets/ranking_widgets.dart` (`RankList`, `RankPodium`, `RankRow`, shows points for every place) used by `features/statistics/.../leaderboard_tab.dart` (People | Groups) and the group Ranking tab. **Privacy note:** every active group appears (name, size, points) in the groups leaderboard; add an opt-out if that becomes a concern
- **Group home** (`group_home_screen.dart`) is a compact header + 4 tabs: Today (my progress card, who finished today, announcements, activity, leader roster), Ranking, Chat, Stats. The old big hero card is gone
- **Lesson:** `GroupMemberStatus`/`GroupStatsSummary` in `schemas.py` are the API contract for the dashboard. A field missing there is silently dropped (this once made group points show 0). `test_dashboard_reports_group_points_through_the_response_schema` guards it — when adding fields to dashboard dicts, add them to the schema too

## Cancel, calendar, explanations

- **Cancel:** `POST /challenges/{id}/cancel` (personal only; status `ARCHIVED`, points kept). Challenge screen menu (⋮): "Cancel challenge" for personal, "Leave group" for group challenges, each with an explaining confirm dialog
- **Calendar on Home:** `GET /me/activity?month=YYYY-MM` → per-day `status` (`done`/`partial`/`missed`/`pending`/`upcoming`), tasks done (title, personal/group, challenge, time) and totals. UI: `features/challenge/presentation/widgets/activity_calendar.dart` (month navigation, tap a day for the task list)
- **Explanations:** `core/widgets/how_it_works.dart` — 5-slide walkthrough shown once on first Home (flag via `AppCache.flag`), reopenable from the Home "?" button, Settings → How it works and the group menu; `showPointsInfo` (ⓘ next to points, leaderboards); a one-time "How groups work" card on the Groups tab. Constants `kTaskPoints/kDayBonusPoints/kMissedDayPenalty` must match the backend
- **Toasts vs bottom buttons:** screens with a bottom action bar inside `body` must show SnackBars with `behavior: floating` and a bottom `margin` (~92) or the toast covers the button (found by tests)

## Build, deploy, git

- **API (Render):** `render.yaml` blueprint → https://ilm-mode-api.onrender.com (env: `DATABASE_URL`, `SUPABASE_URL`, `SUPABASE_JWT_SECRET`, `SUPABASE_SERVICE_ROLE_KEY`, `CORS_ORIGINS`, `INTERNAL_JOB_SECRET`; `ENVIRONMENT=production`). Free plan sleeps after ~15 min idle. Verified: `/v1/health` 200, `/v1/me` without token 401, `close-day` rejects the default secret (403), CORS OK for `:5210`
- **Midnight job:** `POST /v1/internal/jobs/close-day` with header `X-Internal-Secret: <INTERNAL_JOB_SECRET>`; needs an external scheduler (e.g. cron-job.org, 00:00 Asia/Tashkent). Also ping `/v1/health` every ~10 min to avoid cold starts
- **Flutter against the cloud API:** `mobile/env.production.json` (gitignored; `API_BASE_URL=https://ilm-mode-api.onrender.com/v1`). `flutter run -d chrome --web-port=5211 --dart-define-from-file=env.production.json` (add `:5211` to Supabase Redirect URLs and `CORS_ORIGINS`)
- **APK:** `.github/workflows/build-apk.yml` (manual "Run workflow" and on `mobile/**` pushes) reads **repository Variables** `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY` (Settings → Secrets and variables → Actions → *Variables*, not Secrets) and uploads the `ilm-mode-release-apk` artifact. A local `flutter build apk --release --dart-define-from-file=env.production.json` currently fails on a **broken NDK** (`ndk/28.2.13676358` has no `source.properties`; delete the folder and let Gradle re-download, which needs a good connection; the build is also slow under OneDrive)
- **Git:** remote `umar` = `github.com/umartohirov/21-app` (repo moved to `umar-toirov/21-app`, the redirect works); `origin` = `toiroff/21-app`. Local git identity is `umar-toirov`. Commit and push only when the user asks; use the attribution trailer from the harness reminder. Do not repoint remotes unasked (the permission classifier blocks it)

## Change log (what was done, oldest first)

1. Migrated to a **new Supabase project**; `mobile/env.json` and `backend/.env` updated; pinned web port 5210; added `5210` to `CORS_ORIGINS`
2. Deployed the API to **Render**; added `env.production.json` (gitignored)
3. **UI redesign** away from the Duolingo look to a calm habit-tracker style (see *Theme & dark mode*); home reordered: greeting, stat tiles, today's tasks, programs, quote
4. **Payments removed** (app, API, config, README)
5. **Dark mode** (Auto/Light/Dark), snappy transitions, **optimistic task ticking** in `challenge_detail_screen.dart` (`_pendingDone`, reverts with a snackbar on failure), dead buttons wired (home bell opens settings, "Join Session" uses `url_launcher`), settings rewritten
6. **Branding**: adaptive icon, native splash, animated intro, web icons/manifest, `tools/generate_brand_assets.py` (now driven by the Habit Zone SVG)
7. **Group points** computed per group challenge, net of penalties, one method, deterministic ranking; regression test `backend/tests/test_group_points.py` (`cd backend; python -m pytest tests -q`)

8. **Challenge frameworks + start date + Skip** (see that section); replaced the 5-step onboarding wizard with a picker + setup screen; fixed a ListTile-on-decorated-box warning (settings, setup) and a card overflow; replaced the failing placeholder `widget_test.dart` with an offline `AppColors` test

9. **Points per task + missed-day penalty notice, sounds/effects, cache-first startup, intro/branding cleanup (no ILM logo, credit line), redesigned challenge screen** (day strip, progress card, To do / Done rows, filters) and `TaskTile`; new tests `test_points.py`, `challenge_detail_test.dart`

10. **Groups v2** (admin-set tasks, no foundation in groups, join preview, leave/end, chat, group + people leaderboards with points on the podium, compact group home), **cancel challenge**, **Home calendar**, **How it works** explanations; fixed a regression where group points were dropped by the API schema; new tests `backend/tests/test_groups.py`, `mobile/test/groups_test.dart`, `challenge_actions_test.dart`

## Open TODOs / recommendations

- Add the three GitHub Actions **Variables**, then run **Build APK** (or fix the local NDK)
- Set up the **midnight `close-day` scheduler** and a `/v1/health` keep-alive
- Choose a permanent **package id** (e.g. `com.ilmhub.twentyone`) and create a **release keystore** (release builds are signed with the debug key)
- Remove `usesCleartextTraffic="true"` from `AndroidManifest.xml` for production (the API is HTTPS)
- Get a **vector or ≥1024 px logo** (the emblem is ~220×280 px, so the store icon and splash are upscaled) and a real **dark-mode wordmark**
- Play Store assets: 1024×500 feature graphic and screenshots; iOS icons/splash need a Mac
- Add other dev ports to Supabase Redirect URLs if used; Android Google login needs `io.supabase.ilmmode://login-callback/`
- Not yet visually verified: logged-in screens in dark mode, the intro animation frame by frame, the icon and splash on a real device
- Full-app widget test is not possible offline (Supabase init + google_fonts downloads); screens are tested with provider overrides and plain `ThemeData` (see `challenge_flow_test.dart`)
- **Day rollover uses the server's UTC date** (`date.today()` in `challenge_service.py` / `group_service.py`), so days advance at 05:00 Tashkent, and a user just after local midnight may see "tomorrow" as their start date. `profile.timezone` exists but is unused — fix by computing "today" in the user's (default `Asia/Tashkent`) timezone in one helper
- Choose the permanent **package id** for **Habit Zone** (see *Branding*) — the app name and icon are done
- Set up a **keep-alive ping / always-on host** so cold starts stop hurting (see *Startup speed*)
- Groups: optional opt-out from the public groups leaderboard; push/unread badges for chat (polling only for now); moderation beyond admin delete
- Deploy: the new `group_messages` table is created automatically on first start of the API (create_all); push to redeploy Render and rebuild the APK so old builds do not talk to removed behaviour
- Optional next: reminders (time + push), 66-day/habit-formation framework, per-template tips, editing or cancelling a scheduled challenge
- Group leaderboard runs one query per member (N+1); fine for small groups, batch it if groups grow

11. **Habit Zone rebrand**: app renamed from "21"; new icon from `habitzone_icon.svg` (adaptive + themed + legacy + web), navy launch screen and intro, landing shows icon + name; web served for VS Code Simple Browser with `mobile/tools/serve_web.py` (`flutter build web --release --dart-define-from-file=env.json` then `python tools/serve_web.py`; the `flutter run` dev server only works in the Chrome window it launches)
