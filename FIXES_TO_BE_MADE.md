# Fixes To Be Made — Spikers Project Audit

> Whole-project audit for the Spikers app. Each item lists its location, why it matters, and
> a copy-paste **Fix prompt**. Every prompt is scoped to be safe — apply **one at a time** and
> run `flutter analyze` (app) / `npm run build` in `functions/` (backend) after each.
>
> **Severity legend:** 🔴 High · 🟠 Medium · 🟡 Low
>
> _Already fixed in earlier sessions (not repeated here): GetX listener leaks in
> `NotificationController`/`AuthController`, incomplete logout teardown, and the
> `home_screen.dart` bottom-nav `Obx` with no observable._

---

## A. App — data & logic layer (`lib/controller`, `lib/models`, `lib/core`)

### A1 🔴 Credentials stored in SharedPreferences for auto-login
- **Where:** `lib/controller/auth_controller.dart:86–97` (`_saveCredentials`/`_clearCredentials`), keys `_kEmail`/`_kPass` (45–46), used by `_tryRestoreSession` (70–84).
- **Why:** email + base64(password) in plain SharedPreferences. Base64 is encoding, not encryption — readable on a rooted/compromised device.
- **Fix prompt:** "In `auth_controller.dart`, replace the SharedPreferences storage of email/password with `flutter_secure_storage` (add the dependency). Keep the exact same public behavior of `_saveCredentials`, `_clearCredentials`, and `_tryRestoreSession` (silent session restore on launch). Migrate gracefully: if old SharedPreferences keys exist, read them once, move them into secure storage, then delete them. Do not change any call sites. Run `flutter analyze` and confirm login + auto-restore still work."

### A2 🟠 Empty catch blocks swallow errors silently
- **Where:** `lib/controller/auth_controller.dart:63, 161, 182` (`catch (_) {}`), plus the `_initAuth` init path.
- **Why:** init failures (user listener, FCM token write) vanish with no log; impossible to diagnose in production.
- **Fix prompt:** "In `auth_controller.dart`, change the empty `catch (_) {}` blocks at the FCM/init paths to log via `debugPrint('auth: <context> $e')` while keeping them non-fatal (do not rethrow, do not change control flow). Only add logging — no behavioral change."

### A3 🟠 Firestore listeners without `onError`
- **Where:** `lib/controller/announcement_controller.dart:25–37` (no `onError`); `lib/controller/template_controller.dart:38` (`onError: (_) {}`).
- **Why:** stream errors (permission loss, disconnect) silently kill the listener and leave stale state.
- **Fix prompt:** "Add an `onError` callback to the snapshot listeners in `announcement_controller.dart` and `template_controller.dart` that calls `debugPrint(...)` with the error. Do not change the success path or the data shape. Keep `_latestSub`/`_sub` cancellation in `onClose` intact."

### A4 🟠 Leaderboard: unawaited `Future.wait`, force-unwrap, unbounded reads
- **Where:** `lib/controller/leaderboard_controller.dart:30` (`Future.wait` not awaited in `onInit`), `:114` (`counts[uid]!`), `:41` (full `users_public` read), `:68–75` (sessions since cutoff, no limit).
- **Why:** loading flags can stick if an inner fetch throws outside its try; force-unwrap is fragile; reads grow unbounded with data.
- **Fix prompt:** "In `leaderboard_controller.dart`: (1) ensure `_fetchAllTime`/`_fetchMonthly` always set their `isLoading*` flags to false in a `finally`; (2) replace `counts[uid]!` with `counts[uid] ?? 0`; (3) add `.limit(200)` to the all-time `users_public` query and sort/trim to top entries client-side. Keep the displayed leaderboard identical for current small data. Run `flutter analyze`."

### A5 🟠 `SessionTemplate.fromDoc` unguarded casts
- **Where:** `lib/models/session_template_model.dart:30–35` (`d['title'] as String`, `as int`, …).
- **Why:** a malformed/partial Firestore doc throws and breaks the whole template stream — inconsistent with `SessionModel.fromDoc` which uses `?? default`.
- **Fix prompt:** "In `session_template_model.dart`, make `fromDoc` defensive like `SessionModel.fromDoc`: use `?? ''` / `?? 0` defaults for each field instead of bare casts, and `(d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now()`. Do not change the constructor or field types."

### A6 🟡 `createdAt` silently defaults to `DateTime.now()`
- **Where:** `lib/models/announcement_model.dart:29`, `lib/models/recurring_session_model.dart:62`.
- **Why:** a missing `createdAt` makes old records look new; corrupts ordering/badges.
- **Fix prompt:** "Leave the `?? DateTime.now()` fallback but add a `debugPrint` when it triggers so missing-timestamp docs are visible in logs. Do not change model types or call sites."

### A7 🟡 `SessionModel.isOngoing` calls `DateTime.now()` twice
- **Where:** `lib/models/session_model.dart:44–45`.
- **Why:** two reads of `now` can disagree by milliseconds → momentary inconsistent status.
- **Fix prompt:** "In `session_model.dart`, refactor `isOngoing` to capture `final now = DateTime.now();` once and compare against it. No other change."

---

## B. App — UI layer (`lib/screens`)

### B1 🔴 Business logic / Firestore calls live inside widgets (architectural)
- **Where:** `coaches_tab.dart:34`, `players_tab.dart:40`, `players_peer_tab.dart:44`, `session_detail_screen.dart` (55, 61, 121, 145, 172, 1118), `session_chat_screen.dart` (73, 115, 151), `sessions_history_screen.dart` (44, 110), `player_profile_screen.dart:29`, `announcements_screen.dart:44`, `verify_email_screen.dart:65`.
- **Why:** violates the controller/repository separation the project targets; hard to test; schema changes touch many screens. **Large refactor — do incrementally, lowest risk last.**
- **Fix prompt:** "Pick ONE screen (start with `coaches_tab.dart`). Move its `FirebaseFirestore` query into the matching GetX controller (or a new lightweight controller), expose the data as an `.obs`/stream, and have the widget consume it via `Obx`/`StreamBuilder`. Preserve identical UI and loading/empty/error states. Run `flutter analyze` and verify the screen behaves the same before moving to the next screen."

### B2 🟠 Unbounded `.snapshots()` (no `.limit()`)
- **Where:** `coaches_tab.dart:34`, `players_tab.dart:40`, `players_peer_tab.dart:44`, `announcements_screen.dart:44`.
- **Why:** every doc is streamed; cost and latency grow with the club roster.
- **Fix prompt:** "Add a sensible `.limit(...)` (e.g. 100) to these list `.snapshots()` queries and a 'show more'/pagination affordance only if the limit is hit. Keep current ordering and filters. Verify lists still render."

### B3 🟠 Unsafe `Get.arguments` casts
- **Where:** `session_chat_screen.dart:46–48` (`as Map<String,String>` then `['id']!`), `player_profile_screen.dart:17`, `session_detail_screen.dart:42`, `create_announcement_screen.dart:27`, `create_recurring_session_screen.dart:41`.
- **Why:** wrong/null args crash the screen instead of failing gracefully.
- **Fix prompt:** "Harden `Get.arguments` handling in these screens: cast with null-safety, validate required keys, and if missing show an error state or `Get.back()` instead of force-unwrapping. Don't change the navigation call sites that pass correct args."

### B4 🟠 `StreamBuilder`s ignore the error state
- **Where:** `session_detail_screen.dart:1117`, `announcements_screen.dart:43`, `sessions_history_screen.dart:43`, `player_profile_screen.dart:34`.
- **Why:** on stream error the user sees an infinite spinner.
- **Fix prompt:** "In each listed `StreamBuilder`, add a `snapshot.hasError` branch that renders a small error widget (reuse existing error UI/strings). Keep loading and data branches unchanged."

### B5 🟠 `TextEditingController` created inline in `build()`
- **Where:** `create_recurring_session_screen.dart:322, 334`.
- **Why:** a new controller is allocated every rebuild and never disposed.
- **Fix prompt:** "In `create_recurring_session_screen.dart`, create the two time-field `TextEditingController`s once as State fields, initialize/update their `.text` from `_startTime`/`_endTime` in `initState` and in `_pickTime`, and dispose them in `dispose()`. Keep the read-only time-picker behavior identical."

### B6 🟡 Hardcoded English relative-time strings in a bilingual app
- **Where:** `announcements_screen.dart:~93–97` (`'just now'`, `'m ago'`, `'h ago'`, `'d ago'`).
- **Why:** app is AR/EN via `AppLocalizations`; these stay English in Arabic.
- **Fix prompt:** "Move the relative-time strings in `announcements_screen.dart` into `AppLocalizations` (add keys to both `app_localizations_en` and `app_localizations_ar`) and use `.tr`-style lookups. Keep formatting logic the same."

---

## C. Backend — Cloud Functions (`functions/src/index.ts`)

### C1 🔴 Missing input validation on callable params
- **Where:** `updateSessionCapacity` (~525–535: `newMaxPlayers`, `newWaitlistSize`), `markAttended` (~629–636: `sessionId`, `userId`).
- **Why:** negative/huge/typed-wrong values reach business logic unchecked.
- **Fix prompt:** "Add strict validation at the top of these callables: numbers must be integers in sane ranges (e.g. 1–1000), ids must be non-empty strings; throw `HttpsError('invalid-argument', ...)` otherwise. Keep the existing auth/role checks and happy path unchanged. `npm run build` in `functions/`."

### C2 🟠 Unchecked field casts in `onSessionCreated`
- **Where:** `index.ts:~208–215, 231, 288` (`gender`/`minAge`/`maxAge`/`dateOfBirth` cast without null checks).
- **Why:** malformed docs cause silent wrong filtering (e.g. `undefined >= minAge`), excluding valid players from notifications.
- **Fix prompt:** "In `onSessionCreated`, validate `gender`/`minAge`/`maxAge` exist and have correct types before use; `logger.error` and return early if not. Guard `dateOfBirth` before `calcAge`. Don't change the notification logic for well-formed docs."

### C3 🟠 Silent `.catch(() => undefined/null)`
- **Where:** `index.ts:~40, 87, 100, 108` (storage delete, `auth().getUser`).
- **Why:** failures are invisible; cleanup gaps go unnoticed.
- **Fix prompt:** "Replace these silent catches with `.catch((e) => { logger.warn('<context>', { error: e }); return undefined; })`. Behavior unchanged, just logged."

### C4 🟠 FCM multicast loop not wrapped in try/catch
- **Where:** `index.ts:~239–248`.
- **Why:** one failing chunk throws and aborts the rest; notifications lost without a log.
- **Fix prompt:** "Wrap the `sendEachForMulticast` chunk loop in `onSessionCreated` in try/catch, log failures per chunk, and continue. Don't change token gathering."

### C5 🟠 `validateCoachKey` has no rate limiting
- **Where:** `index.ts:~335–354`.
- **Why:** `timingSafeEqual` blocks timing attacks but nothing caps brute-force attempts.
- **Fix prompt:** "Add a per-uid attempt counter in Firestore (e.g. `coach_key_attempts/{uid}`) to `validateCoachKey`: increment per call, throw `resource-exhausted` after N (e.g. 5) within a window. Keep the constant-time comparison and the existing success path."

### C6 🟠 Non-atomic dedup in `createRecurringSessions`
- **Where:** `index.ts:~736–738` (check `lastCreatedDate` then write).
- **Why:** parallel runs/retries can both pass the check → duplicate sessions.
- **Fix prompt:** "Make the dedup in `createRecurringSessions` transactional: inside `runTransaction`, re-read the recurring doc, skip if `lastCreatedDate === tomorrowStr`, else create the session and set `lastCreatedDate` atomically. Keep the generated session fields identical."

### C7 🟡 Promotion notification runs outside the transaction
- **Where:** `index.ts:~509–511` (`leaveSession`).
- **Why:** post-commit notify can fail with no retry; promoted user not told.
- **Fix prompt:** "Leave the transaction as-is but wrap the post-commit `notifyPromoted` call in try/catch with a `logger.warn` so a failed notification is at least recorded. No data-path change."

---

## D. Backend — security & storage rules

### D1 🟠 (verify) Missing composite index for `onSessionCreated` users query
- **Where:** `functions/src/index.ts:~219–223` queries `users` where `role == 'player'` and `gender in [...]`; `firestore.indexes.json` has no `(role, gender)`.
- **Why:** the query can fail or fall back to slow scans, dropping session notifications.
- **Fix prompt:** "Confirm whether the `users (role ASC, gender ASC)` composite index exists in the Firebase console. If not, add it to `firestore.indexes.json` and deploy with `firebase deploy --only firestore:indexes`. Don't touch other indexes."

### D2 🟡 Owner can write `createdAt`/`verifiedAt` — but the client RELIES on this
- **Where:** `firestore.rules:~54–76` allows owner updates to `verifiedAt`/`createdAt`. Note: `auth_controller.dart:141` self-heals `verifiedAt` and `:242` bumps `createdAt` on email change.
- **Why:** integrity smell (user can fake dates), **but tightening the rule would break the current client writes.** Flag for review, don't blindly remove.
- **Fix prompt:** "Investigate moving the `verifiedAt` heal and `createdAt` bump to server-side (Cloud Functions/triggers). Only after the client no longer writes these fields, remove them from the allowed-update keys in `firestore.rules`. Do NOT remove them while the client still writes them — verify with the verify-email and change-email flows first."

### D3 🟡 `messages` create rule depends on a session `get()` (TOCTOU)
- **Where:** `firestore.rules:~119–126`.
- **Why:** minor race / fails oddly if `attendeeIds` missing.
- **Fix prompt:** "Make the `messages` create rule defensive: use `.get('attendeeIds', [])` style access so a missing field doesn't error, keeping sender + membership checks. Test that a coach and an attendee can still post and a non-member cannot."

### D4 🟡 Storage: no per-user upload throttle
- **Where:** `storage.rules:7–12` (profile photos).
- **Why:** repeated 5 MB overwrites waste quota; not a security hole.
- **Fix prompt:** "Optional: add a lightweight throttle or rely on a Cloud Storage lifecycle rule to expire old profile-photo versions. Keep size/content-type checks. Verify photo upload still works."

---

## E. Config, secrets, Android

### E1 🟠 `.gitignore` doesn't cover signing secrets
- **Where:** repo `.gitignore` (no `key.properties`, `*.jks`, `*.keystore`, `local.properties`). These files exist locally and are currently **untracked** (good) — but unprotected.
- **Fix prompt:** "Append `android/key.properties`, `*.jks`, `*.keystore`, and `android/local.properties` to `.gitignore`. Run `git status` to confirm the keystore and key.properties remain untracked. Do not commit those files."

### E2 🟡 `google-services.json` is committed (informational — not a real secret)
- **Where:** `spikers_app/android/app/google-services.json` (tracked).
- **Why:** Firebase **client** config ships inside every APK — it is not a secret. Real protection is Firestore rules + **Firebase App Check**.
- **Fix prompt:** "No rotation needed. Optionally enable Firebase App Check (Play Integrity) to ensure only your app calls your backend. If you prefer to stop tracking the file, gitignore it and document that each dev/CI must supply their own — but leaving it committed is acceptable for Firebase."

### E3 🟡 Android `minSdk` uses Flutter default (21)
- **Where:** `spikers_app/android/app/build.gradle.kts:~40`.
- **Fix prompt:** "Optionally set `minSdk = 23` (or 24) explicitly in `build.gradle.kts` to drop very old devices. Rebuild the app bundle and confirm it still builds."

### E4 🟡 Confirm TypeScript strict mode in functions
- **Where:** `functions/tsconfig.json`.
- **Fix prompt:** "Check `functions/tsconfig.json` has `strict: true`. If not, enable it and fix the resulting type errors. Run `npm run build`."

---

## Suggested order of execution
1. **Quick safe wins:** E1, A2, A3, A6, A7, B4, C3, C4.
2. **Correctness:** A4, A5, B3, B5, C1, C2, C6, D1.
3. **Security:** A1, C5, E2 (App Check), D2/D3 (careful).
4. **Architectural (largest, last, incremental):** B1, B2.

---

## Verified NON-issues (do not "fix" — these were false alarms)
- `'photoUrl': ?photoUrl` and `?newMaxPlayers` are **valid Dart 3 null-aware elements**. The app compiles and the release bundle builds.
- `session_chat_screen.dart` `_inputCtrl`/`_scroll` **are** disposed (lines 59–60).
- `verify_email_screen.dart` `_ChangeEmailDialog._ctrl` **is** disposed (line 226).
- "`setState` + `Obx` mixing" is idiomatic GetX (reactive button inside a form `StatefulWidget`), not a bug.
