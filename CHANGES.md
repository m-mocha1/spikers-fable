# spikers-fable — Changes & Rationale

This folder is an experimental copy of the Spikers app, rebuilt by the Fable 5 / Claude
model session. The original at `..\Spikers` was **never modified**. Every change below is
a separate git commit on a fresh history — run `git log --oneline` to follow along, or
`git diff 8d3b98e..HEAD` to see everything against the verbatim baseline.

> ⚠️ The Firebase config still points at the **real dev project** (`spikers-13db7`).
> Running this app reads/writes the shared dev Firestore. Nothing was deployed
> (no functions, rules, or indexes).

---

## The headline change: architecture migration

**What:** The app moved from GetX (controllers + screens organized by type, Firestore
calls inside controllers and widgets) to the architecture the project's own `CLAUDE.md`
prescribes: **feature-first folders + Riverpod + repository pattern**, with the strict
flow `UI → Provider → Repository → Datasource → Firebase`.

**Why:** `CLAUDE.md` is the project's stated contract ("the project must be understandable
by a new developer within 30 minutes", repository pattern mandatory, no Firestore inside
widgets) — but the real code didn't follow it. The audit file (`FIXES_TO_BE_MADE.md` item
B1) flagged Firestore-in-widgets as the biggest architectural debt. The migration was done
feature by feature, keeping the app compiling and tests green at every commit.

**The final tree:**

```
lib/
  core/                constants, theme, router, providers, services, utils, widgets
  features/
    auth/              data / domain / presentation (6 screens + repository + session lifecycle)
    sessions/          the largest feature: list, detail, create, quick, chat, history, recurring, templates
    players/           roster, peer view, profile, payment (absorbed PaymentController)
    coaches/           coach list
    announcements/     list, create/edit, unread bell
    leaderboard/       monthly + all-time
    home/              shell + profile tab
    notifications/     FCM tap-routing service
  l10n/                unchanged AR/EN localization
```

`lib/controller`, `lib/screens`, `lib/models`, `lib/routes` no longer exist. GetX is fully
removed from `pubspec.yaml`; routing is **go_router**, state is **Riverpod**.

---

## Real user-facing bugs fixed along the way

1. **Untranslated error messages (severe, app-wide).** The old controllers showed errors
   with GetX's `.tr` — but no GetX translations were ever registered, so users saw raw
   keys like `wrongPassword`, `sessionCreated`, `sessionFull` instead of real text (and
   never in Arabic). All user-facing messages now resolve through `AppLocalizations`
   (EN/AR). This also affected the session card's LIVE/FULL/gender badges.

2. **Plain-text credential storage (audit A1, security).** Email + base64(password) for
   silent login were kept in SharedPreferences — readable on a compromised device. They
   now live in the platform keystore via `flutter_secure_storage`
   (EncryptedSharedPreferences / Keychain), with a one-time migration that moves old
   values over and deletes them.

3. **Coach-key brute force (audit C5, backend).** `validateCoachKey` had constant-time
   comparison but no attempt cap. Added a transactional per-uid counter
   (`coach_key_attempts/{uid}`): max 5 tries per hour, cleared on success.
   Type-checked with `tsc`; **not deployed**.

4. **Hardcoded English relative times (audit B6).** "just now / 3h ago / 2d ago" on
   announcements stayed English in Arabic. Now proper localized keys in both ARB files.

5. **Silently swallowed errors (audit A2 remainder).** The last empty `catch (_) {}`
   (on-demand session archival) now logs via `debugPrint`.

6. **Missing error states.** Screens that previously showed an infinite spinner or empty
   list on stream errors (leaderboard, announcements, players, coaches, templates,
   recurring) now render a proper error message — most with a retry button.

---

## Testing (there were zero tests before)

A `test/` suite now exists and gates every commit — **49 tests**, all using fakes
(`fake_cloud_firestore`, `firebase_auth_mocks`, `mocktail`), never the live project:

- **Model round-trips** for all 6 Firestore models, including the regression for audit A5
  (defensive parsing of partial docs) and the `verifiedAt: null` write contract that the
  backend cleanup function depends on.
- **Repository tests:** leaderboard ordering/merging/whereIn-batching; auth credential
  save/restore/clear and error mapping; announcements lifecycle; players payment
  (30-day window, audit trail, **lifetime-member no-op guard**); sessions eligibility
  gates (unverified/unpaid/gender+age/coach), join result + error mapping, chat
  round-trip, template lifecycle.

**Why:** `CLAUDE.md` requires unit/repository tests per feature; more practically, the
migration could not have been done safely without them.

---

## Commit-by-commit map

| Commit | What | Why |
|---|---|---|
| `8d3b98e` | Baseline: verbatim copy (no build artifacts) | Diffable starting point |
| `5d0c6e7` | functions: rate-limit `validateCoachKey` | Audit C5 — brute-force guard |
| `fcf324e` | auth: credentials → secure storage; drop windows/linux folders | Audit A1; desktop folders were unused scaffolding that broke `pub get` on this machine (symlink requirement) |
| `9aca879` | sessions: log on-demand archival errors | Audit A2 leftover |
| `bee6c5c` | test scaffolding + 21 model tests | Safety net for the migration |
| `3b3de22` | Riverpod foundation (`ProviderScope`, Firebase providers) | Repositories depend on providers, not singletons — testable |
| `f02ed49` | leaderboard → feature-first (pattern-setter) | Smallest read-only feature; establishes the template |
| `089c125` | auth → feature-first + temporary GetX shim | Everything consumes the user stream; the shim let the rest migrate gradually |
| `50d8268` | announcements → feature-first; B6 l10n fix | Controller deleted outright; home bell became a Riverpod widget |
| `43d785f` | players + coaches → feature-first; payment absorbed | Typed entities replace `Map<String, dynamic>` rows |
| `4fdfbde` | sessions repository layer under existing controllers | Strangler step — 5 domains (sessions/chat/templates/recurring/history) behind interfaces, screens untouched |
| `75f89ba` – `bf41b9a` | sessions screens migrated in 4 sub-commits; Session/Template/Recurring controllers deleted | Each commit compiles; the 1,100-line detail screen went last |
| `39031ae` | home shell + notifications service; **AuthController shim deleted** | Notifications now key off the user stream — sign-out teardown choreography gone |
| `bd62f5a` | `lib/models` + `lib/screens` dissolved into features/core | Final folder shape per CLAUDE.md |
| `037c59e` | go_router replaces GetX routing; **`get` removed from pubspec** | Typed constructor params instead of `Get.arguments` casts; root-messenger snackbars; `localeProvider` |

---

## Design decisions worth knowing

- **Riverpod 2 without codegen.** Manual providers keep diffs reviewable and avoid
  build_runner in the loop.
- **Typed route arguments.** Screens now declare what they need
  (`SessionDetailScreen(session: …)` / `(sessionId: …)`) instead of casting
  `Get.arguments` at runtime — wrong-argument crashes (audit B3) become compile errors.
- **Coach-only routes** are enforced by go_router redirects reading the auth repository
  (same behavior as the old middleware, plus a signed-out → login case).
- **Snackbars** use a root `ScaffoldMessenger` key, so they survive navigation exactly
  like the old overlay-based `Get.snackbar`.
- **Roster queries stay unbounded on purpose** (audit B2 deferred): a server-side limit
  needs an `orderBy` + composite index that this experimental copy can't deploy. Noted
  in code; revisit before the roster grows.
- **Firestore-rules items D2/D3 untouched**: the audit itself warns the client currently
  relies on those writes, and rules can't be safely changed without deploying.

## Deliberately skipped

- **UI/UX polish phase** — wrapped up at your request after the architecture work; the
  UI is pixel-identical to the original except for the error states noted above and the
  Material snackbar style.
- **Anything requiring deployment** (functions, rules, indexes) — this copy must not
  touch the shared backend.

---

## Verification

- `flutter analyze`: 0 issues
- `flutter test`: 49/49 pass
- `functions`: `tsc` clean (type-check only)
- Debug APK built at baseline; **release APK** built at the end (signed with the copied
  `key.properties` upload key)
