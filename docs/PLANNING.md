# ILM Mode ("21") — Product & Technical Planning Document

> Single source of truth for V1 planning. Implementation proceeds one feature at a time per the phased roadmap at the end.

---

## 1. Critical PRD Review

### Strengths
- Clear positioning: discipline platform, not a habit tracker
- Strong gamification loop: HP, streaks, discipline score, certificates
- Well-scoped V1 navigation (4 tabs)
- Sensible tech stack (Flutter + FastAPI + PostgreSQL + Supabase)
- Monetization is simple and testable (first challenge free)

### Gaps & Ambiguities in Original PRD

| Area | Issue | Resolution (V1) |
|------|-------|-----------------|
| **Day boundary** | When does "today" reset? | User-local midnight; configurable timezone on signup |
| **Task completion window** | What is "late completion"? | Same calendar day after a grace period (default 2h after midnight = still previous day until 02:00) |
| **Partial completion** | User completes 4/5 tasks — HP? Streak? | Partial day = streak broken for that day; −5 HP if ≥1 task done after grace; −15 HP if zero tasks |
| **Recovery Mode** | 3 consecutive missed days triggers recovery — what counts as "activity"? | Complete ≥1 task OR explicitly tap "I'm back" + complete foundation tasks within 24h |
| **Multiple challenges** | Can user run 2 individual challenges simultaneously? | V1: **one active individual challenge** at a time |
| **Group + Individual** | Can both run together? | V1: yes — group challenge runs parallel; separate task lists |
| **Leaderboard scope** | Global only? | V1: global + challenge cohort (same start date/duration) |
| **Payment** | 99,000 UZS — when charged? | At **challenge creation** (after first free one) |
| **Certificate** | Generated on day N or after final day tasks? | After final day **all tasks** marked complete |
| **Discipline Score** | Formula not defined | Defined in §3 below |
| **Notifications** | No permission/onboarding flow | Ask during onboarding step 5 (optional skip) |
| **Offline** | Not mentioned | Queue task completions locally; sync with conflict resolution |
| **Account deletion** | GDPR-style data handling undefined | Soft-delete 30 days, then hard purge |

### V1 Scope Boundaries (Explicitly Out)
- Google OAuth, friends, social feed, AI coach, widgets, health integrations, subscriptions, QR verification, custom challenge lengths, season rankings

---

## 2. Missing Edge Cases

### Authentication & Onboarding
- Email already registered → clear error, link to login
- Unverified email → block challenge start until verified
- User abandons onboarding mid-flow → resume from last completed step
- User selects <2 personal tasks → validation blocks continue
- User changes goal after onboarding → allowed in settings before challenge starts; locked after Day 1

### Challenge Lifecycle
- User completes Day 21 tasks on Day 20 (early) → day counter does not advance early; extra completions don't grant bonus HP in V1
- User in Recovery Mode completes all tasks → exits recovery; streak for missed days remains broken
- User misses 3 days, enters recovery, completes 1 task, then misses again → recovery timer resets on activity; 4th consecutive miss without recovery success = fail
- Challenge fails → archive with status `failed`; user can purchase new challenge
- User deletes account mid-challenge → forfeit; no refund in V1
- Timezone change mid-challenge → day boundaries re-evaluate; show warning modal

### HP System
- HP floor: **minimum 0** (never negative display; internal can track "debt" for analytics)
- HP ceiling: **no cap** in V1 (display cap at 999 for UI cleanliness optional)
- Perfect week definition: Mon–Sun all days fully complete (configurable to challenge start weekday)
- Duplicate completion taps → idempotent API (same task/day = no double HP)

### Tasks
- Custom task empty name → reject
- Leader removes foundation task in group → not allowed in V1 (immutable after group creation)
- User edits personal tasks mid-challenge → V1: **locked after Day 1**

### Group Challenges
- Leader leaves group → transfer ownership to co-leader or archive group
- Participant joins after Day 1 → joins with pro-rated expectations; flagged as "late joiner" on leaderboard
- Participant removed by leader → read-only access to their history; active participation ends
- Group max size → default 100 (configurable by admin)

### Payments
- Payment succeeds but challenge creation fails → idempotent retry; support manual reconcile
- Payment pending (mobile money delay) → challenge status `pending_payment`
- Refund policy → none in V1 except duplicate charge

### Statistics & Leaderboard
- New user with 0 data → empty states with CTAs
- Tie-breaking on leaderboard → higher discipline score → longer streak → earlier registration

### Notifications
- User disables notifications → in-app banners still show
- FCM token invalid → re-register on app launch

---

## 3. Suggested Improvements (Preserving Vision)

### Product
1. **"Today's Mission" one-liner** — auto-generated from incomplete foundation task (e.g., "Wake up by 6:30 AM") — increases focus
2. **Recovery as training, not punishment** — copy: "Discipline isn't perfection. Get back in." + simplified task set (foundation only) during recovery
3. **Discipline Score formula (transparent)** — show breakdown on Statistics tab to reinforce identity
4. **Weekly report push** — Sunday evening summary (completion %, HP delta, rank change)
5. **Challenge naming** — auto-name from goal + duration ("IELTS 21-Day Discipline") editable once
6. **Pre-challenge commitment screen** — user taps "I commit" before Day 1 — psychological anchor

### UX
- Duolingo-style progress path for 21/30 days (subtle, not childish)
- Haptic feedback on task complete
- Dark mode from day one (settings toggle)
- Uzbek + English i18n structure from start (default: English)

### Technical
- **Event-sourced task completions** — append-only `task_completions` for audit and discipline score recompute
- **Idempotent payment webhooks** — Payme/Click/Uzum integration ready (abstract provider)
- **Feature flags** — group challenges can ship behind flag

### Discipline Score Formula (V1)
```
Base: 100
+ (completion_rate × 400)           // lifetime weighted, recent 90 days heavier
+ (challenges_completed × 25)       // max 200 from this term
+ (perfect_weeks × 10)              // max 100
+ (successful_recoveries × 5)       // max 50
− (failed_challenges × 30)          // floor at 0 total
+ (longest_streak × 2)              // max 100 from this term
Clamp: 0–1000
```
Recomputed nightly via background job; cached on `users.discipline_score`.

---

## 4. Information Architecture

```
ILM Mode
├── Auth (unauthenticated)
│   ├── Landing
│   ├── Login
│   ├── Sign Up
│   └── Forgot Password
├── Onboarding (authenticated, no active challenge)
│   ├── Step 1: Goal
│   ├── Step 2: Duration
│   ├── Step 3: Foundation Tasks (read-only)
│   ├── Step 4: Personal Tasks
│   ├── Step 5: Notifications + Commitment
│   └── Payment (if not first challenge)
├── Main App (authenticated, bottom nav)
│   ├── Challenges (Tab 1) — default home when active challenge
│   │   ├── Challenge Dashboard
│   │   ├── Day Detail / Task List
│   │   ├── Recovery Mode
│   │   ├── Challenge Complete / Celebration
│   │   └── Challenge Failed
│   ├── Group Challenges (Tab 2)
│   │   ├── My Groups List
│   │   ├── Join Group (code/link)
│   │   ├── Group Detail (participant view)
│   │   └── Leader Dashboard
│   ├── Statistics (Tab 3)
│   │   ├── Personal Analytics
│   │   ├── Global Leaderboard
│   │   └── Weekly Report
│   └── Profile (Tab 4)
│       ├── Profile Overview
│       ├── Certificates
│       ├── Badges
│       ├── Payment History
│       └── Settings
│           ├── Edit Profile
│           ├── Notifications
│           ├── Dark Mode
│           ├── Language
│           ├── Privacy
│           ├── Delete Account
│           ├── Support
│           └── Legal (Terms, Privacy)
└── Deep Links
    ├── /certificate/:id
    └── /group/join/:code
```

### Entity Relationships (Conceptual)
```
User 1──* Challenge 1──* ChallengeDay 1──* TaskCompletion
User 1──* Badge (via user_badges)
User 1──* Certificate
Challenge *──* Task (foundation + personal)
Group 1──* GroupMember *──1 User
Group 1──1 Challenge (template)
```

---

## 5. Screens & User Flows

### 5.1 Landing → Auth
```
[Landing] ──Login──► [Login] ──success──► [Onboarding or Main]
          ──Sign Up─► [Sign Up] ──verify──► [Onboarding]
          ──Start Free──► [Sign Up] (prefilled intent)
```

**Landing screen:** Hero headline, 3 value props, discipline quote, pricing note, 3 CTAs.

### 5.2 Onboarding Flow
```
Goal → Duration → Foundation (info) → Personal Tasks (≥2) → Notifications → Commitment → [Payment?] → Challenge Dashboard
```

**Validation gates:** each step saves progress to backend (`onboarding_state` JSON on user).

### 5.3 Daily Challenge Loop (Core Loop)
```
Open App → Challenge Dashboard
  → View today's tasks + mission + quote
  → Tap task checkbox → optimistic UI → API confirm
  → All complete → Celebration modal (+5 HP animation)
  → Update streak, discipline score (async)
```

### 5.4 Recovery Flow
```
Miss Day 3 consecutive → Push notification + in-app banner
  → Recovery screen (24h countdown)
  → User completes foundation tasks OR "I'm back"
  → Exit recovery OR timer expires → Challenge Failed
```

### 5.5 Challenge Completion
```
Final day all tasks done → Celebration (full-screen)
  → Certificate preview → Save / Share
  → Badge unlocks toast
  → CTA: Start new challenge (payment) or Join group
```

### 5.6 Group Challenge (Leader)
```
Profile/Group Tab → Create Group
  → Set duration, foundation tasks, penalty rules, max missed days
  → Share invite code
  → Leader Dashboard (live participant stats)
```

### 5.7 Screen Inventory (V1)

| # | Screen | Key Components |
|---|--------|----------------|
| 1 | Landing | Hero, benefits, testimonials placeholder, CTAs |
| 2 | Login | Email, password, forgot link |
| 3 | Sign Up | Name, email, password, terms checkbox |
| 4 | Forgot Password | Email submit |
| 5 | Onboarding Goal | Grid of goal cards |
| 6 | Onboarding Duration | 21 / 30 day cards |
| 7 | Onboarding Foundation | Read-only task list + explanation |
| 8 | Onboarding Personal Tasks | Select ≥2 + custom task modal |
| 9 | Onboarding Notifications | Permission prompt + toggle |
| 10 | Onboarding Commitment | Commit button + summary |
| 11 | Payment | Amount, provider selection, status |
| 12 | Challenge Dashboard | Progress, HP, streak, tasks, quote, rank |
| 13 | Task Complete Celebration | Lottie animation, HP +5 |
| 14 | Recovery Mode | Countdown, reduced task list |
| 15 | Challenge Failed | Summary, retry CTA |
| 16 | Challenge Complete | Certificate, badges, share |
| 17 | Group List | Active + past groups |
| 18 | Join Group | Code input |
| 19 | Group Participant View | Group tasks + personal tasks |
| 20 | Leader Dashboard | Table: name, today %, HP, streak, rank |
| 21 | Statistics Personal | Charts: completion, consistency, trends |
| 22 | Statistics Leaderboard | Tabs: Discipline, HP, Streak, Challenges |
| 23 | Profile | Avatar, score, badges preview, links |
| 24 | Certificates List | Grid of earned certificates |
| 25 | Certificate Detail | Full cert + share |
| 26 | Badges List | Earned + locked (greyed) |
| 27 | Payment History | List of transactions |
| 28 | Settings | Grouped list |
| 29 | Edit Profile | Name, photo, timezone |
| 30 | Delete Account | Confirmation + password |

---

## 6. Database Schema (PostgreSQL)

### Enums
```sql
CREATE TYPE challenge_status AS ENUM ('draft','pending_payment','active','recovery','completed','failed','archived');
CREATE TYPE challenge_type AS ENUM ('individual','group');
CREATE TYPE task_type AS ENUM ('foundation','personal');
CREATE TYPE payment_status AS ENUM ('pending','completed','failed','refunded');
CREATE TYPE group_member_role AS ENUM ('leader','member');
CREATE TYPE badge_code AS ENUM ('morning_warrior','consistency_master','seven_day_streak','thirty_day_legend','never_missed','recovery_champion','top_100');
```

### Core Tables

```sql
-- Users (extends Supabase auth.users)
CREATE TABLE profiles (
  id              UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  email           TEXT NOT NULL UNIQUE,
  full_name       TEXT NOT NULL,
  avatar_url      TEXT,
  bio             TEXT,
  timezone        TEXT NOT NULL DEFAULT 'Asia/Tashkent',
  locale          TEXT NOT NULL DEFAULT 'en',
  onboarding_step INT NOT NULL DEFAULT 0,
  onboarding_data JSONB NOT NULL DEFAULT '{}',
  hp              INT NOT NULL DEFAULT 100 CHECK (hp >= 0),
  discipline_score INT NOT NULL DEFAULT 100 CHECK (discipline_score BETWEEN 0 AND 1000),
  current_streak  INT NOT NULL DEFAULT 0,
  longest_streak  INT NOT NULL DEFAULT 0,
  perfect_weeks   INT NOT NULL DEFAULT 0,
  challenges_completed INT NOT NULL DEFAULT 0,
  is_deleted      BOOLEAN NOT NULL DEFAULT FALSE,
  deleted_at      TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE goals (
  id    SERIAL PRIMARY KEY,
  slug  TEXT NOT NULL UNIQUE,  -- ielts, sat, programming, etc.
  name  TEXT NOT NULL,
  icon  TEXT
);

CREATE TABLE challenges (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id),
  goal_id         INT REFERENCES goals(id),
  name            TEXT NOT NULL,
  type            challenge_type NOT NULL DEFAULT 'individual',
  duration_days   INT NOT NULL CHECK (duration_days IN (21, 30)),
  status          challenge_status NOT NULL DEFAULT 'draft',
  start_date      DATE,
  current_day     INT NOT NULL DEFAULT 0,
  max_missed_days INT NOT NULL DEFAULT 3,
  consecutive_missed INT NOT NULL DEFAULT 0,
  recovery_started_at TIMESTAMPTZ,
  is_first_free   BOOLEAN NOT NULL DEFAULT FALSE,
  payment_id      UUID REFERENCES payments(id),
  group_id        UUID REFERENCES groups(id),
  completed_at    TIMESTAMPTZ,
  failed_at       TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE tasks (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  title        TEXT NOT NULL,
  type         task_type NOT NULL,
  sort_order   INT NOT NULL DEFAULT 0,
  is_active    BOOLEAN NOT NULL DEFAULT TRUE,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE challenge_days (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  challenge_id UUID NOT NULL REFERENCES challenges(id) ON DELETE CASCADE,
  day_number   INT NOT NULL,
  calendar_date DATE NOT NULL,
  is_complete  BOOLEAN NOT NULL DEFAULT FALSE,
  is_perfect   BOOLEAN NOT NULL DEFAULT FALSE,
  hp_delta     INT NOT NULL DEFAULT 0,
  completed_at TIMESTAMPTZ,
  UNIQUE(challenge_id, day_number)
);

CREATE TABLE task_completions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id      UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES profiles(id),
  challenge_day_id UUID NOT NULL REFERENCES challenge_days(id) ON DELETE CASCADE,
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  is_late      BOOLEAN NOT NULL DEFAULT FALSE,
  UNIQUE(task_id, challenge_day_id)
);

CREATE TABLE hp_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES profiles(id),
  challenge_id UUID REFERENCES challenges(id),
  delta        INT NOT NULL,
  reason       TEXT NOT NULL,  -- daily_complete, perfect_week, missed_day, late, recovery
  created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE badges (
  id          SERIAL PRIMARY KEY,
  code        badge_code NOT NULL UNIQUE,
  name        TEXT NOT NULL,
  description TEXT NOT NULL,
  icon_url    TEXT
);

CREATE TABLE user_badges (
  user_id    UUID NOT NULL REFERENCES profiles(id),
  badge_id   INT NOT NULL REFERENCES badges(id),
  earned_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  challenge_id UUID REFERENCES challenges(id),
  PRIMARY KEY (user_id, badge_id)
);

CREATE TABLE certificates (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id),
  challenge_id    UUID NOT NULL REFERENCES challenges(id) UNIQUE,
  certificate_no  TEXT NOT NULL UNIQUE,  -- ILM-2026-XXXXXX
  title           TEXT NOT NULL,
  duration_days   INT NOT NULL,
  issued_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  pdf_url         TEXT
);

CREATE TABLE payments (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES profiles(id),
  amount_uzs      INT NOT NULL DEFAULT 99000,
  status          payment_status NOT NULL DEFAULT 'pending',
  provider        TEXT,  -- payme, click, uzum
  provider_ref    TEXT,
  idempotency_key TEXT NOT NULL UNIQUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  completed_at    TIMESTAMPTZ
);

CREATE TABLE groups (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  leader_id       UUID NOT NULL REFERENCES profiles(id),
  name            TEXT NOT NULL,
  invite_code     TEXT NOT NULL UNIQUE,
  duration_days   INT NOT NULL,
  max_missed_days INT NOT NULL DEFAULT 3,
  penalty_rules   JSONB NOT NULL DEFAULT '{}',
  status          TEXT NOT NULL DEFAULT 'active',
  starts_at       DATE NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE group_members (
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES profiles(id),
  role       group_member_role NOT NULL DEFAULT 'member',
  joined_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_id, user_id)
);

CREATE TABLE announcements (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_id   UUID NOT NULL REFERENCES groups(id) ON DELETE CASCADE,
  author_id  UUID NOT NULL REFERENCES profiles(id),
  body       TEXT NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE device_tokens (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id    UUID NOT NULL REFERENCES profiles(id),
  fcm_token  TEXT NOT NULL,
  platform   TEXT NOT NULL,  -- ios, android
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, fcm_token)
);

CREATE TABLE motivational_quotes (
  id     SERIAL PRIMARY KEY,
  text   TEXT NOT NULL,
  author TEXT
);
```

### Indexes
```sql
CREATE INDEX idx_challenges_user_status ON challenges(user_id, status);
CREATE INDEX idx_challenge_days_date ON challenge_days(challenge_id, calendar_date);
CREATE INDEX idx_task_completions_user ON task_completions(user_id, completed_at);
CREATE INDEX idx_profiles_discipline_score ON profiles(discipline_score DESC);
CREATE INDEX idx_profiles_hp ON profiles(hp DESC);
CREATE INDEX idx_profiles_longest_streak ON profiles(longest_streak DESC);
```

### Row Level Security (Supabase)
- Users read/update own `profiles`
- Users read/write own challenges, tasks, completions
- Group members read group data; leaders manage group + announcements
- Leaderboard: public read on aggregated profile fields (name, avatar, scores)

---

## 7. API Specification (FastAPI)

**Base URL:** `https://api.ilmmode.app/v1`  
**Auth:** Bearer JWT from Supabase Auth  
**Format:** JSON; errors `{ "detail": "...", "code": "MISSED_DAY" }`

### Auth & Profile
| Method | Path | Description |
|--------|------|-------------|
| GET | `/me` | Current user profile + stats |
| PATCH | `/me` | Update name, avatar, timezone, locale |
| DELETE | `/me` | Soft-delete account |
| POST | `/me/device-token` | Register FCM token |

### Onboarding
| Method | Path | Description |
|--------|------|-------------|
| GET | `/onboarding` | Current step + saved data |
| PUT | `/onboarding/step/{n}` | Save step data, advance |
| POST | `/onboarding/complete` | Finalize → create challenge |

### Goals & Tasks (Reference)
| Method | Path | Description |
|--------|------|-------------|
| GET | `/goals` | List available goals |
| GET | `/tasks/templates?goal={slug}` | Suggested personal tasks |

### Challenges
| Method | Path | Description |
|--------|------|-------------|
| GET | `/challenges` | List user challenges (filter by status) |
| GET | `/challenges/active` | Current active individual challenge + today |
| POST | `/challenges` | Create challenge (triggers payment if not free) |
| GET | `/challenges/{id}` | Challenge detail + progress |
| GET | `/challenges/{id}/days/{day}` | Specific day tasks + completion state |
| POST | `/challenges/{id}/days/{day}/complete-task` | `{ "task_id": "uuid" }` idempotent |
| POST | `/challenges/{id}/recovery/check-in` | Exit recovery attempt |
| GET | `/challenges/{id}/certificate` | Certificate metadata + PDF URL |

### HP & Streaks
| Method | Path | Description |
|--------|------|-------------|
| GET | `/me/hp/history` | Paginated HP events |
| GET | `/me/streaks` | Current, longest, perfect weeks |

### Payments
| Method | Path | Description |
|--------|------|-------------|
| POST | `/payments/intent` | Create payment intent `{ "challenge_id"? }` |
| GET | `/payments` | Payment history |
| POST | `/payments/webhook/{provider}` | Provider callback (HMAC verified) |

### Leaderboard & Statistics
| Method | Path | Description |
|--------|------|-------------|
| GET | `/leaderboard?metric=discipline_score&limit=50` | Global board |
| GET | `/leaderboard/challenge/{id}` | Cohort board |
| GET | `/statistics/me` | Personal analytics aggregate |
| GET | `/statistics/me/weekly-report` | Latest weekly summary |

### Badges & Certificates
| Method | Path | Description |
|--------|------|-------------|
| GET | `/me/badges` | Earned + available |
| GET | `/me/certificates` | All certificates |
| GET | `/certificates/{id}` | Public certificate (for sharing) |

### Groups
| Method | Path | Description |
|--------|------|-------------|
| POST | `/groups` | Create group (leader) |
| POST | `/groups/join` | `{ "invite_code": "ABC123" }` |
| GET | `/groups` | My groups |
| GET | `/groups/{id}` | Group detail |
| GET | `/groups/{id}/dashboard` | Leader analytics |
| GET | `/groups/{id}/members` | Member list + today's status |
| POST | `/groups/{id}/announcements` | Leader post |
| DELETE | `/groups/{id}/members/{user_id}` | Leader remove member |

### Quotes
| Method | Path | Description |
|--------|------|-------------|
| GET | `/quotes/today` | Deterministic daily quote per user |

### Background Jobs (Internal / Cron)
- `POST /internal/jobs/close-day` — run hourly; close days per timezone, apply HP penalties
- `POST /internal/jobs/check-recovery` — expire recovery timers
- `POST /internal/jobs/recompute-discipline-scores` — nightly
- `POST /internal/jobs/send-notifications` — scheduled pushes

---

## 8. Folder Structure

### Flutter (`mobile/`)
```
mobile/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── core/
│   │   ├── config/env.dart
│   │   ├── constants/
│   │   ├── theme/              # light/dark, typography, colors
│   │   ├── router/app_router.dart
│   │   ├── network/dio_client.dart
│   │   ├── storage/secure_storage.dart
│   │   ├── utils/date_utils.dart
│   │   └── widgets/            # shared buttons, loaders, empty states
│   └── features/
│       ├── auth/
│       │   ├── data/           # auth_repository, supabase_auth_datasource
│       │   ├── domain/         # entities, repository interfaces
│       │   └── presentation/   # screens, controllers (Riverpod)
│       ├── onboarding/
│       ├── challenge/
│       ├── group_challenge/
│       ├── statistics/
│       ├── profile/
│       ├── payment/
│       └── settings/
├── assets/
│   ├── fonts/
│   ├── lottie/
│   └── i18n/
├── test/
└── pubspec.yaml
```

**State management:** Riverpod 2.x + code generation where helpful  
**Routing:** go_router  
**Local storage:** drift (offline task queue) + flutter_secure_storage

### Backend (`backend/`)
```
backend/
├── app/
│   ├── main.py
│   ├── core/
│   │   ├── config.py
│   │   ├── security.py         # JWT verify via Supabase
│   │   ├── dependencies.py
│   │   └── exceptions.py
│   ├── db/
│   │   ├── session.py
│   │   ├── base.py
│   │   └── migrations/         # Alembic
│   ├── models/                 # SQLAlchemy ORM
│   ├── schemas/                # Pydantic v2
│   ├── repositories/
│   ├── services/
│   │   ├── challenge_service.py
│   │   ├── hp_service.py
│   │   ├── discipline_score_service.py
│   │   ├── payment_service.py
│   │   ├── certificate_service.py
│   │   ├── group_service.py
│   │   └── notification_service.py
│   ├── api/
│   │   └── v1/
│   │       ├── router.py
│   │       ├── auth.py
│   │       ├── challenges.py
│   │       ├── groups.py
│   │       ├── payments.py
│   │       └── statistics.py
│   └── jobs/
│       ├── close_day.py
│       └── recompute_scores.py
├── tests/
├── alembic.ini
├── pyproject.toml
└── Dockerfile
```

### Repo Root
```
/
├── mobile/
├── backend/
├── docs/
│   ├── PLANNING.md
│   └── api/                    # OpenAPI export
├── .github/workflows/
└── README.md
```

---

## 9. Phased Development Roadmap

### Phase 0 — Foundation (Week 1)
- [ ] Monorepo scaffold (Flutter + FastAPI)
- [ ] Supabase project: Auth, PostgreSQL, Storage bucket
- [ ] CI: lint, test, build
- [ ] Design system: colors, typography, components (Time Balance × Duolingo)
- [ ] App shell: router, theme, bottom nav placeholders

### Phase 1 — Auth & Onboarding (Week 2)
- [ ] Landing, Login, Sign Up, Forgot Password
- [ ] Supabase Auth integration
- [ ] Onboarding 5-step flow + backend persistence
- [ ] Profile creation webhook (Supabase → FastAPI)

### Phase 2 — Individual Challenge Core (Weeks 3–4)
- [ ] Challenge creation (first free)
- [ ] Challenge Dashboard (today's tasks, progress, HP, streak)
- [ ] Task completion API + optimistic UI
- [ ] Day boundary job + HP events
- [ ] Celebration animation on full day complete
- [ ] Motivational quote

### Phase 3 — Challenge Lifecycle (Week 5)
- [ ] Recovery Mode (3-day miss trigger)
- [ ] Challenge failure flow
- [ ] Challenge completion + certificate generation (PDF → Supabase Storage)
- [ ] Badges (auto-award rules)
- [ ] Discipline score computation job

### Phase 4 — Statistics & Leaderboard (Week 6)
- [ ] Personal analytics screens + charts
- [ ] Global leaderboard (4 metrics)
- [ ] Weekly report (push + in-app)

### Phase 5 — Payments (Week 7)
- [ ] Payment intent flow (99,000 UZS)
- [ ] Provider integration (Payme or Click first)
- [ ] Payment history in Profile
- [ ] Idempotent webhooks

### Phase 6 — Group Challenges (Weeks 8–9)
- [ ] Create/join group
- [ ] Participant group view
- [ ] Leader dashboard + announcements
- [ ] Group leaderboard

### Phase 7 — Polish & Launch (Week 10)
- [ ] Push notifications (FCM)
- [ ] Dark mode, i18n (EN + UZ)
- [ ] Offline task queue
- [ ] Error states, empty states, accessibility
- [ ] App Store / Play Store prep

---

## 10. Next Implementation Step

**Start Phase 0:** scaffold monorepo, design tokens, app shell with bottom navigation.

First user-visible milestone: **Landing page + Auth shell** (Phase 1 entry).
