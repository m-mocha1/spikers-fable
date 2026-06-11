# spikers-fable

Experimental copy of the Spikers app for testing the Fable 5 model. The original at
`..\Spikers` is the source of truth and is never modified from this folder.

## Important

- **Firebase config is LIVE**: `lib/firebase_options.dart`, `android/app/google-services.json`,
  and `.firebaserc` still point at the real dev project (`spikers-13db7`). Running this app
  manually reads/writes the shared dev Firestore and can send real FCM notifications.
- **Never deploy from here**: no `firebase deploy` (functions, rules, or indexes).
- All automated tests use fakes/mocks (`fake_cloud_firestore`, `firebase_auth_mocks`) — never
  the live project.
- Baseline commit = verbatim copy of the original (minus build artifacts). Everything after it
  is Fable's work; diff against the first commit to review.

## Goals (in order)

1. Bug/perf fixes from the in-repo audit (`FIXES_TO_BE_MADE.md`)
2. Test scaffolding
3. Architecture migration: GetX → feature-first + Riverpod + repository pattern (per CLAUDE.md)
4. go_router, full GetX removal
5. UI/UX polish
6. Discretionary improvements + functions type-check hardening
