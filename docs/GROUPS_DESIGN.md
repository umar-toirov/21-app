# ILM HUB Groups — Design & Information Architecture

> Signature accountability feature for the 21 app. Not chat — activity, progress, and team pressure done right.

## User types

| Role | Who | Key actions |
|------|-----|-------------|
| **Leader** | Teacher, mentor, coach, org | Create group, set duration (21/30), foundation tasks, post/pin announcements, schedule sessions, remove members, view analytics |
| **Participant** | Student | Join via code/QR, complete daily tasks, view leaderboard & feed, earn HP/badges |

## User flows

### Leader — create program
1. Groups tab → **Create Group**
2. Name, duration, max missed days, foundation tasks
3. Confirm (archives active personal challenge)
4. Lands on **Group Home** with invite QR/code

### Participant — join
1. Groups tab → **Join with invite code** (or scan QR)
2. Enter code → confirm archive of personal challenge
3. Lands on **Group Home**

### Daily loop (both roles)
1. Open group → **Home** tab (hero + today %)
2. Tap **Complete Today's Mission** → Home tab challenge tasks
3. Completion posts to **Team Activity** feed
4. Check **Leaderboard** rank + **Statistics**

### Leader — manage
1. Group Home → Settings (gear) or FAB **Announce**
2. Pin mission/reminder/meeting link
3. Schedule live session (API ready)
4. Remove participant from Settings

## Information architecture

```
Groups (tab)
├── Group List
│   ├── Join Group
│   └── Create Group
└── Group Home (/groups/:id/dashboard)
    ├── [Tab] Home
    │   ├── Hero card (name, day, members, today %)
    │   ├── Today's Group Status (5 stat cards)
    │   ├── Group Progress (+ bonus/badge thresholds)
    │   ├── Upcoming Live Session
    │   ├── Pinned Announcements
    │   └── Team Activity Feed
    ├── [Tab] Leaderboard
    │   ├── Top 3 podium
    │   └── Ranked member list → Member Profile
    ├── [Tab] Statistics
    │   ├── Completion, HP, active, streak
    │   ├── Weekly trend chart
    │   └── Top performer / consistent / improved
    ├── Invite sheet (share icon)
    ├── Settings (leader)
    │   ├── Edit name
    │   ├── Invite QR + code
    │   └── Remove members
    └── Member Profile (/groups/:id/members/:userId)
        ├── Stats row (HP, score, streak)
        ├── Attendance heatmap
        ├── Foundation + personal tasks
        └── Achievements
```

## Screens implemented

| Screen | File | States |
|--------|------|--------|
| Group List | `group_list_screen.dart` | empty, loading, error, list |
| Group Home | `group_home_screen.dart` | loading, error, 3 tabs |
| Member Profile | `group_member_profile_screen.dart` | loading, error, data |
| Group Settings | `group_settings_screen.dart` | leader-only |
| Create / Join | `create_group_screen.dart`, `join_group_screen.dart` | existing + navigation fix |

## Component library

`presentation/widgets/group_widgets.dart`:

- `GroupHeroCard` — dark gradient hero, animated progress, CTA
- `GroupStatGrid` — 5 today status cards
- `GroupProgressCard` — group % + bonus/badge unlocks
- `PinnedAnnouncements` — gold pin cards
- `GroupActivityFeed` — non-chat activity timeline
- `GroupPodium` — top 3 gold/silver/bronze
- `GroupLeaderboardTile` — rank row with movement arrow
- `AttendanceHeatmap` — GitHub-style day grid
- `LiveSessionCard` — upcoming session + join CTA
- `GroupLoadingState` / `GroupErrorState`

## Design tokens

- Primary CTA: `#F15A29` (orange)
- Success / completion: teal `#18BEBC`
- Achievements: gold `#F6C744`
- Accent: navy `#033D95`
- Surfaces: white cards on `#F7F8FA`, 20–28px radius
- Motion: `flutter_animate` fade/slide, `AnimatedFillBar` on progress

## API (backend)

| Endpoint | Purpose |
|----------|---------|
| `GET /groups/{id}/dashboard` | Hero data, stats, members, feed, announcements, sessions |
| `GET /groups/{id}/statistics` | Group analytics |
| `GET /groups/{id}/members/{userId}` | Profile + heatmap + tasks |
| `POST /groups/{id}/announcements` | Leader post (title, pin) |
| `POST /groups/{id}/sessions` | Leader schedule session |
| `PATCH /groups/{id}` | Leader edit settings |
| `DELETE /groups/{id}/members/{userId}` | Leader remove |

Activity feed auto-records: joins, announcements, daily mission complete, streak milestones.

## Group rewards (logic)

- **95% today completion** → `bonus_hp_unlocked` flag (UI; grant HP in next iteration)
- **100% today** → `group_badge_unlocked` flag

## Not in v1 (planned)

- Transfer ownership, approve join requests
- Custom 3D asset pipeline (using glossy icons + gradients for now)
- Real-time rank delta history
- Push notifications for announcements
- Payment-gated group programs
