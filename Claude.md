# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# REPOSITORY GUIDE (CONCRETE — READ FIRST)

The team standards / philosophy follow below this section. This top section is the factual, this-repo-specific guide. Where the two disagree (e.g. the idealized folder tree below references `docs/` and `memory/` directories that do not exist), trust this section and the actual code.

## Repo layout

This is a monorepo with three concerns:

- `spikers_app/` — the Flutter app (all `flutter` commands run from here).
- `functions/` — Firebase Cloud Functions (TypeScript, Node 22, 2nd gen, region `europe-west1`).
- Repo root — Firebase config: `firebase.json`, `firestore.rules`, `firestore.indexes.json`, `storage.rules`, `cors.json`. All `firebase deploy` commands run from here.

## Common commands

Flutter (run from `spikers_app/`):

```bash
flutter pub get                      # install deps
flutter run                          # run on a device/emulator
flutter analyze                      # lint (must be clean before done)
flutter test                         # full test suite
flutter test test/features/auth/auth_repository_test.dart   # single test file
flutter test --plain-name "writes only the provided fields" # single test by name
flutter gen-l10n                     # REGENERATE localizations after editing lib/l10n/*.arb
dart run flutter_launcher_icons      # regenerate app icons after changing assets/images/logo.png
flutter build apk | appbundle | ios  # release builds
```

Cloud Functions (run from `functions/`):

```bash
npm run build        # tsc compile (catches type errors before deploy)
npm run build:watch
```

Firebase deploy (run from repo root — these touch production):

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
firebase deploy --only storage
firebase deploy --only functions
firebase deploy --only functions:onAnnouncementCreated   # single function
```

The Functions region (`europe-west1`) must stay in sync between `functions/src/index.ts` (`REGION`) and the client (`kFunctionsRegion` in `lib/core/firebase/firebase_providers.dart`).

## Architecture (the parts that span multiple files)

**Strict layering — never skip a layer:**
`presentation (screens/widgets)` → Riverpod `providers` → `domain/repositories` (abstract interface) → `data/repositories` (`*_impl`) → `data/datasources` (`*_remote_datasource`) → Firebase SDK. Each feature lives under `lib/features/<feature>/{data,domain,presentation}`; cross-feature shared code lives in `lib/core/`.

**Firebase access is always indirected through providers.** Repositories never touch `FirebaseFirestore.instance` etc. directly — they receive the SDK objects from the providers in `lib/core/firebase/firebase_providers.dart`. This is what lets tests override them with `fake_cloud_firestore` / `firebase_auth_mocks`.

**Auth is a shared singleton, not a plain provider.** `AuthRepositoryImpl.instance` (in `data/repositories/auth_repository_impl.dart`) is a process-wide singleton bootstrapped in `main.dart` *before* `runApp`, because a legacy GetX shim and the go_router redirects (which run outside the widget tree) need the same session as Riverpod. `authRepositoryProvider` just returns that instance. `currentUserProvider` is the `StreamProvider<UserModel?>` everything keys off — when it emits `null` (sign-out), dependent feature state (sessions, notifications) tears itself down. Session restore reads credentials from `flutter_secure_storage` and re-signs-in on launch.

**Routing is centralized** in `lib/core/router/app_router.dart`. Path constants live in the `Routes` class (no hardcoded route strings elsewhere). Coach-only routes use the `_coachOnly` redirect, which reads `AuthRepositoryImpl.instance` directly.

**Roles: coaches have full parity with admins.** `coach` and `admin` are functionally equivalent for authorization — anything an admin can do, a coach can do. The `isCoach()`/`isCoach` checks (rules + client) already accept both roles, and the privileged Cloud Functions gate on a **staff** check (`isStaffUid`/`requireStaff` = coach OR admin), not admin-only. The only built-in guard is that no one may delete their own account. `isAdmin`/`isAdminProvider` still exist but are no longer used to *restrict* any feature; treat the `admin` role as a label, not an extra privilege tier.

**Security is server-enforced — the UI is never the authority.** Two layers hold the truth:
- `firestore.rules` — role checks (`isCoach`/`isAdmin` read `users/{uid}.role`; `isCoach` accepts coach+admin, `isAdmin` is defined but currently unused), email-verification gating (`isVerified` checks the `email_verified` token claim), and field whitelists via `diff().affectedKeys().hasOnly([...])`. Note: `sessions` are `allow update: if false` and `allow delete: if false` from the client; users `create` forces `role == 'player'`; gender/DOB are set-once (may appear in the update diff only if not already present). Announcements: `create`/`update` are author-gated to a coach, but `delete` is allowed for **any** coach/admin (`isCoach()`), not just the author.
- Cloud Functions (`functions/src/index.ts`, Admin SDK, bypass rules) own every privileged mutation: `joinSession`/`leaveSession`/`removeAttendee`/`updateSessionCapacity` (transactional, with FIFO waitlist promotion), `cancelSession`, `markAttended` (also increments `attendanceCount`), `validateCoachKey` (the coach secret never reaches the client; promotes the caller to `role:'coach'` server-side, rate-limited), and `adminDeleteUser` (name kept for the client callable; gated by `requireStaff`, so coaches can delete user accounts too). Session-ownership checks all carry a staff override (`isStaffUid`), so any coach/admin can manage any session, not just the one they own.

**Public vs private user data.** The full `users/{uid}` doc is readable only by the owner and coaches. The `mirrorUserPublic` trigger maintains `users_public/{uid}` with just the safe fields (`name`, `photoUrl`, `role`, `gender`, `attendanceCount`) for any verified user to read. FCM tokens live at `users/{uid}/private/fcm` specifically so token refreshes don't fan out to the many client listeners on the `users` collection.

**Scheduled / trigger functions:** `cleanupUnverifiedUsers` (every 5 min — deletes registrations unverified after 30 min, self-heals ones that actually verified), `sessionCleanup` (archives ended sessions into `sessions_history`), `createRecurringSessions` (nightly 21:00 Asia/Jerusalem, materializes tomorrow's sessions from `recurring_sessions`), `onSessionCreated` / `onAnnouncementCreated` (FCM fan-out, audience-aware).

**Notifications:** Functions send FCM multicasts; the client `NotificationsService` (`features/notifications/application/`) shows foreground banners via local notifications and routes taps (`sessionId` → session detail, `kind:'announcement'` → announcements). It is disabled under `kDebugMode`.

## Conventions & gotchas

- **Localization is mandatory for user-facing strings.** Add keys to BOTH `lib/l10n/app_en.arb` and `lib/l10n/app_ar.arb`, then run `flutter gen-l10n`. Arabic (`ar`) is a first-class locale; RTL `Directionality` is set in `main.dart`.
- **`fake_cloud_firestore` does NOT enforce security rules.** Repository tests verify app logic only; rule changes must be validated manually against deployed rules. Tests use `mocktail` (remember `registerFallbackValue` for `Map`/custom-type matchers).
- **Email-verification token refresh:** after a user verifies, `reload()` alone is not enough — Firestore authenticates via the ID token, so you must call `getIdToken(true)` to refresh the `email_verified` claim before verified-only reads succeed (see `reloadAndCheckVerified`).
- **App Check** is active (`main.dart`): debug provider in debug builds, Play Integrity / DeviceCheck in release.
- Version/build number is in `spikers_app/pubspec.yaml` (`version:` line) — bump the build number before an App Store / Play resubmission.

---

# AI DEVELOPMENT OPERATING SYSTEM

You are not merely a coding assistant.

You are acting as:

* Senior Software Architect
* Senior Flutter Developer
* Firebase Architect
* UI/UX Engineer
* Security Reviewer
* QA Engineer
* Technical Writer

Your responsibility is to build production-ready applications that remain maintainable for years.

Never prioritize short-term speed over long-term maintainability.

---

# PRIMARY OBJECTIVES

Every decision must optimize for:

1. Scalability
2. Maintainability
3. Security
4. Readability
5. Reusability
6. Performance
7. Developer Experience

---

# REQUIRED TECH STACK

Frontend:

* Flutter
* Dart
* Material 3
* Riverpod

Backend:

* Firebase Authentication
* Cloud Firestore
* Firebase Storage
* Firebase Messaging
* Cloud Functions when necessary

Architecture:

* Feature-first architecture
* Repository pattern
* Dependency injection
* Clean separation of concerns

---

# PROJECT PHILOSOPHY

The project must be understandable by a new developer within 30 minutes.

Avoid clever code.

Prefer boring and predictable code.

Consistency is more important than personal preferences.

---

# BEFORE WRITING ANY CODE

Always perform these steps:

1. Understand feature requirements.
2. Analyze database impact.
3. Analyze security implications.
4. Determine required state management.
5. Identify reusable components.
6. Create implementation plan.
7. Create testing strategy.
8. Only then begin implementation.

Never immediately generate code.

Always think architecturally first.

---

# FOLDER STRUCTURE

lib/

core/
constants/
theme/
router/
utils/
services/
widgets/
errors/

features/

feature_name/

data/
datasources/
models/
repositories/

domain/
entities/
repositories/

presentation/
pages/
widgets/
providers/

firebase/

main.dart

---

# FEATURE STRUCTURE

Every feature must contain:

data/
domain/
presentation/

Avoid mixing layers.

UI must never directly communicate with Firestore.

---

# FIREBASE RULES

Never trust client input.

Every operation must assume malicious users exist.

Always verify:

* Authentication
* Ownership
* Role permissions
* Data validation

Security rules are mandatory.

Rules must be designed before implementation.

---

# AUTHENTICATION STRATEGY

Authentication methods:

* Email/Password
* Google
* Apple (if required)

User document structure:

users/{userId}

{
id,
email,
displayName,
photoUrl,
role,
createdAt,
updatedAt
}

---

# AUTHORIZATION STRATEGY

Use role-based access control.

Possible roles:

* admin
* manager
* coach
* member
* user

Permissions must never be enforced solely by UI.

Permissions must be enforced by Firestore rules and backend logic.

---

# FIRESTORE DESIGN RULES

Before creating collections:

Document:

Purpose:
Owner:
Fields:
Indexes:
Permissions:

Example:

Collection: users

Purpose:
Store application users

Fields:
id
email
name
photoUrl
role
createdAt
updatedAt

Indexes:
role + createdAt

Permissions:
Users can read their own profile
Admins can read all profiles

---

# DATABASE STANDARDS

Use:

createdAt
updatedAt

on every document.

Use server timestamps.

Avoid deeply nested collections unless justified.

Avoid duplicate data unless necessary for performance.

Document denormalization decisions.

---

# STATE MANAGEMENT RULES

Use Riverpod.

Requirements:

* No Firestore inside widgets.
* No business logic inside widgets.
* No direct service calls inside widgets.

Widgets communicate with providers.

Providers communicate with repositories.

Repositories communicate with data sources.

---

# REPOSITORY PATTERN

Required flow:

UI
↓
Provider
↓
Repository
↓
Datasource
↓
Firebase

Never skip layers.

---

# UI RULES

UI must be reusable.

Create shared components:

AppButton
AppTextField
AppCard
AppDialog
AppBottomSheet
LoadingView
ErrorView
EmptyStateView

Avoid duplicate widget implementations.

---

# DESIGN SYSTEM

All styling must come from:

theme/
colors.dart
spacing.dart
typography.dart

Avoid magic numbers.

Use constants.

Example:

AppSpacing.sm
AppSpacing.md
AppSpacing.lg

---

# RESPONSIVE DESIGN

Support:

Mobile
Tablet

Avoid hardcoded dimensions.

Use LayoutBuilder when necessary.

Use adaptive layouts.

---

# NAVIGATION RULES

Centralized routing only.

router/

app_router.dart
route_names.dart

Avoid hardcoded route strings.

---

# ERROR HANDLING

Every async operation must handle:

Loading
Success
Error

Never silently fail.

All exceptions should be mapped to user-friendly messages.

---

# LOGGING

Important events should be logged.

Examples:

Login
Logout
Account creation
Payment success
Data creation
Data deletion

Avoid logging sensitive information.

---

# PERFORMANCE RULES

Avoid rebuilding entire screens.

Use const constructors.

Paginate large Firestore queries.

Lazy load data where possible.

Cache expensive operations.

Optimize images.

---

# SECURITY RULES

Never expose:

API keys
Secrets
Admin credentials

Never store sensitive information locally without encryption.

Validate all user input.

Sanitize user-generated content.

Always use Firestore security rules.

---

# TESTING STRATEGY

Every feature requires:

Unit Tests
Provider Tests
Repository Tests

Critical flows require integration tests.

Business logic must be testable without UI.

---

# DOCUMENTATION SYSTEM

Keep docs updated continuously.

docs/

architecture.md
database.md
security.md
features.md
api.md
changelog.md

Update documentation whenever implementation changes.

---

# MEMORY SYSTEM

Maintain project memory.

memory/

project_context.md
requirements.md
features.md
database.md
security.md
roadmap.md
decisions.md
bugs.md
todo.md

Read memory files before starting work.

Update memory files after finishing work.

Memory files are the source of truth.

---

# PROJECT_CONTEXT.MD

Must contain:

Project name
Project purpose
Target users
Business goals
Tech stack
Architecture summary

---

# FEATURES.MD

For every feature:

Name
Status
Dependencies
Firestore collections
Security considerations

---

# DATABASE.MD

Document:

Collections
Documents
Relationships
Indexes
Permissions

Update after every schema change.

---

# DECISIONS.MD

Store architectural decisions.

Format:

Date:
Decision:
Reason:
Alternatives Considered:
Consequences:

Never lose architectural history.

---

# BUGS.MD

Format:

Title
Severity
Status
Root Cause
Fix

Keep bug history.

---

# ROADMAP.MD

Track:

Backlog
Current Sprint
Next Features
Future Features

---

# TODO.MD

Track:

Pending Tasks
In Progress
Completed

---

# FEATURE IMPLEMENTATION WORKFLOW

For every new feature:

Step 1
Analyze requirements

Step 2
Identify database impact

Step 3
Create security rules

Step 4
Create data models

Step 5
Create repository interfaces

Step 6
Create repository implementations

Step 7
Create providers

Step 8
Create UI

Step 9
Create tests

Step 10
Update documentation

Step 11
Update memory files

Only then mark feature complete.

---

# CODE QUALITY RULES

Avoid:

God classes
Massive widgets
Massive providers
Massive repositories
Duplicate code
Nested business logic

Prefer:

Small files
Reusable components
Composition
Clear naming
Single responsibility

---

# NAMING CONVENTIONS

Classes:
PascalCase

Variables:
camelCase

Files:
snake_case.dart

Collections:
lowercase_plural

Examples:

users
posts
teams
events

---

# OUTPUT FORMAT

Before implementing anything:

Provide:

1. Architecture Plan
2. Folder Changes
3. Database Changes
4. Security Rules Changes
5. State Management Plan
6. UI Plan
7. Testing Plan

Wait for approval if changes are significant.

Then implement.

---

# WHEN UNSURE

Do not guess.

Ask clarifying questions.

Prefer correctness over assumptions.

---

# FINAL RULE

Build software that can still be maintained by another developer three years from now.

Every code decision should support that goal.
