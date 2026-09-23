# Google Play release guide — Habit Zone

Package ID (permanent): **`com.ilmhub.habitzone`**. Target SDK 36, min SDK 24.

## 1. One-time setup

1. **Play Console account** ($25 one-time): https://play.google.com/console. New personal accounts must run a **closed test with 12+ testers for 14 days** before they can publish to production. Organisation accounts skip this.
2. **Upload key** (from `mobile/`): `.\tools\create_upload_key.ps1`. Creates `android/upload-keystore.jks` + `android/key.properties` (both gitignored). **Back up the .jks and password** outside the repo.
3. **Privacy policy URL** (required): `docs/privacy.html`. Replace `CONTACT_EMAIL` in it, then publish it, e.g. GitHub Pages (repo Settings → Pages → branch `main`, folder `/docs`) → `https://<owner>.github.io/<repo>/privacy.html`. Use the same URL for the Play "Delete account" web link.
4. **GitHub secrets/variables** for CI (Settings → Secrets and variables → Actions):
   - Secrets: `UPLOAD_KEYSTORE_BASE64` (`[Convert]::ToBase64String([IO.File]::ReadAllBytes("android\upload-keystore.jks"))`), `UPLOAD_STORE_PASSWORD`, `UPLOAD_KEY_ALIAS` (`upload`), `UPLOAD_KEY_PASSWORD`
   - Variables (already used by the APK workflow): `API_BASE_URL` (`https://ilm-mode-api.onrender.com/v1`), `SUPABASE_URL`, `SUPABASE_ANON_KEY`
5. In Play Console leave **Play App Signing** on (default). Your key is only the *upload* key.

## 2. Build the bundle

- CI: Actions → **Build Play Store bundle** → Run workflow → download `habit-zone-release-aab`.
- Local: `cd mobile; flutter build appbundle --release --dart-define-from-file=env.production.json` → `build/app/outputs/bundle/release/app-release.aab`.
- Every upload needs a higher build number: bump `version:` in `mobile/pubspec.yaml` (`1.0.0+1` → `1.0.1+2`).
- Release builds allow **https only** (cleartext is debug-only). The API must be an https URL.

## 3. Store listing

Graphics in `mobile/store/` (regenerate with `python tools/generate_store_assets.py`): `icon-512.png`, `feature-graphic-1024x500.png`. Screenshots: at least 2 phone screenshots (take them from the real app: Home, Challenge, Ranking, Group).

- **App name:** Habit Zone: 21-Day Challenge  (max 30 chars)
- **Short description (80):** Build discipline with daily tasks, streaks and group challenges.
- **Full description:**

  Habit Zone helps you build discipline one day at a time.

  Pick a 21-day challenge, finish a few small tasks each day and protect your streak. Choose from ready-made frameworks (fitness, study, mindset, focus and more) or create your own.

  • Daily tasks with points: +5 for every task, +10 for a perfect day
  • Streaks and a calendar of everything you completed
  • Groups: join friends with an invite code, follow shared tasks, chat and see the group ranking
  • Leaderboards for people and groups
  • Daily reminders so you never miss a day
  • Light and dark mode
  • Free. No ads.

  Days close at 23:59 (UTC+5). Miss a day and you lose points, so every day counts.

  Made by ILM HUB.

- **Category:** Health & Fitness (or Productivity). **Tags:** habit tracker, productivity.
- **Contact email / website:** required in Console.

## 4. Policy forms

- **Content rating:** answer the IARC questionnaire honestly. Users can chat in groups → "users interact" = yes. Expect a Teen-or-lower rating.
- **Target audience:** 13+ (not for children; avoids the Families policy).
- **Ads:** No.
- **Data safety** (all data encrypted in transit; users can request deletion):

  | Data | Collected | Shared | Purpose |
  |------|-----------|--------|---------|
  | Name | Yes | No | App functionality, account |
  | Email address | Yes | No | Account management |
  | User IDs | Yes | No | App functionality |
  | Other user-generated content (chat, announcements) | Yes | No | App functionality |
  | App activity (tasks, progress) | Yes | No | App functionality |
  | Location, contacts, photos, files, device IDs | No | — | — |

- **Account deletion:** in-app *Settings → Delete account*; web link = privacy policy URL (section "Delete your account and data").
- **User-generated content:** Play requires a way to report/block abusive content. Group admins can remove members and delete messages. Consider adding a "Report message" action before production (not built yet).
- **Permissions:** `INTERNET`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED` (reminders). No sensitive permissions.
- **Test account:** in *App access*, give Play reviewers a working email + password (create one in the app).

## 5. Release

1. Testing → **Internal testing** → create release → upload the `.aab` → add yourself as tester → install from the Play link and check reminders, sign-up and login.
2. Personal account: Testing → **Closed testing** with 12+ testers for 14 days, then apply for production.
3. Production → create release → roll out.

## 6. Before you submit — checklist

- [ ] `CONTACT_EMAIL` replaced and privacy policy published
- [ ] Upload key created and backed up; CI secrets set
- [ ] Render API is awake and on https; consider a keep-alive ping (free plan sleeps)
- [ ] Supabase email confirmation flow works for new users
- [ ] Screenshots taken (2–8 phone screenshots)
- [ ] Test account given in App access
