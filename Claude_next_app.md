# CLAUDE.md

## What this doc is

Operating principles for me and Claude while building this app.
Short on purpose. If a rule isn't here, it isn't a rule.

## Principles (don't change these)

- Boring code over clever code. A new dev should grok the app in 30 minutes.
- Less code beats more architecture. Three similar lines is fine; premature
  abstraction is not.
- Security lives in Firestore rules and Cloud Functions, never in the UI.
- Never silently swallow errors. Log or surface, but don't `catch (_) {}`.
- Never commit secrets. Keystores, service-account JSONs, .env files: gitignored.
- "Done" means working in the app on a real device, not just `flutter analyze` clean.

## Tech stack — fixed at project init

- Flutter + Dart (stable channel)
- State management: <ONE choice — GetX | Riverpod | bloc>. Pick one in the
  first commit and don't mix. Reason for picking it goes in decisions.md.
- Firebase: Auth, Firestore, Storage, Messaging, Functions, Crashlytics, App Check.
- l10n: `flutter_localizations` + ARB files from day 1, even if shipping one language.

## Folder layout

```
lib/
  controllers/   (or providers/ — whatever the state lib calls them)
  models/
  screens/
    <feature>/
  widgets/        (shared)
  core/
    constants/
    theme/
    services/     (FCM, analytics, image upload)
    utils/
  l10n/
  routes/
  main.dart
functions/
firestore.rules
storage.rules
```

No `data/domain/presentation` per feature. Add a layer only when you've
felt the pain of not having it.

## Five non-negotiables

1. Firestore + Storage rules exist on day 1 and are updated **before** the
   code that depends on them ships.
2. Server-side enforcement for anything authorization-related. Rules and/or
   callable Cloud Functions. UI gates are convenience, never security.
3. No `email` field on the user doc — Firebase Auth is the source of truth.
   Mirror only what other users need to read (`name`, `photoUrl`, `role`,
   `gender`, `attendanceCount`, …) into `users_public/` via a Function.
4. No silent errors. Every snapshot listener has `onError` that logs. Every
   `fromDoc` cast that could fail has a `??` fallback; per-doc `try/catch`
   so one corrupt doc can't blank the whole list.
5. App Check enforced from launch. Crashlytics live before TestFlight /
   internal track.

## Day-1 setup checklist

- [ ] Flutter project + git init + `.gitignore` covers keystores, .env,
      service accounts, build outputs.
- [ ] Firebase project + `firestore.rules` + `storage.rules` committed.
- [ ] One state-mgmt lib pinned in pubspec.
- [ ] `flutter_localizations` + ARB files wired, even with one locale.
- [ ] Crashlytics initialized in `main.dart`.
- [ ] App Check activated (debug provider locally, Play Integrity / DeviceCheck
      in release).
- [ ] Theme constants (`AppColors`, `AppSpacing`, text styles).
- [ ] Firebase budget alert configured. Daily cost cap reasoning in decisions.md.

## Workflow per feature

1. Write down what changes in the schema and rules. Update `firestore.rules`
   + `database.md` (single file, not seven).
2. Write the smallest code path that delivers value. No layers added "in case."
3. Test it on a real device in both auth states / both locales / both roles.
4. Ship.

For 10-line bug fixes or copy changes: skip step 1. The "think first" gate
applies only when data shape, rules, or new collections are involved.

## Tests — what's actually required

- Cloud Function callables: yes, integration-test the happy + auth-fail paths.
- Firestore rules: rules-unit-test the deny paths that matter (write to other
  users, escalate role, bypass payment).
- Anything money-related: yes.
- Everything else: opt-in. Write a test if it'd save future-you debugging time,
  not because a doc said so.

## Docs we keep — and the only ones we keep

- `docs/decisions.md` — append-only. Format:
  - **Date** • **Decision** • **Why** • **What'd make us reverse it**
- `docs/bugs.md` — append-only. Format:
  - **Title** • **Severity** • **Root cause** • **Fix** • **Prevention**
- `database.md` — current schema and rules summary. Updated with rule changes.
- README.md — how to run it.

No roadmap.md, no todo.md, no features.md. Use issues for those — they don't
get committed to the repo and rot.

## Naming

- Classes: `PascalCase`
- Variables / methods: `camelCase`
- Files: `snake_case.dart`
- Firestore collections: lowercase plural (`users`, `sessions`)
- Routes: kebab-case strings, declared as `static const` in `routes/app_routes.dart`

## Code I will reject in review

- A `catch (_) {}` or `onError: (_) {}` block.
- A widget that calls `FirebaseFirestore.instance` directly when a controller/
  provider already exists for that collection. (Direct streams are fine in
  small one-off screens; not when there's duplication.)
- A new abstraction added "for flexibility we might need."
- A migration script or backwards-compat shim before launch — wipe test users
  and move on.
- Email or secrets in source.
- A test file written purely to satisfy coverage with no failure mode.

## Scope kill-switch

If a feature grows past its original ticket — stop, write down what's grown,
decide whether to keep going or split. Most "while I'm in here" detours are
how small apps become unmaintainable.

## Final rule

A small app that ships and a person can hold in their head beats a beautifully
architected one that drags. Optimize for shipping + clarity. Architecture
earns its place only when the pain of not having it is real.
