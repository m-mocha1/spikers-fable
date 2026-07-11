You're doing a UX audit of Jerusalem Spikers, a production Flutter mobile app for running a volleyball club's operations. Go deep and specific — this is a live app on the App Store/Play Store (v1.0.2+26), not a mockup.

APP CONTEXT
- Purpose: day-to-day club operations — session scheduling, membership, communication
- Users: players, coaches, admins (coach/admin have equal permissions) — mix of ages and tech comfort, used in-context (checking a session while heading to practice, etc.)
- Stack: Flutter/Dart, Material 3, Riverpod, feature-first architecture; Firebase (Auth, Firestore, Cloud Functions, FCM, Storage)
- Critical constraint: fully bilingual EN/AR with RTL as first-class, not an afterthought

WHAT I'M GIVING YOU is ui screen shots in this folder: app-ui-screenshots


AUDIT THE FOLLOWING FLOWS SPECIFICALLY
1. Onboarding/auth — signup, role assignment, first-run experience for a new player vs. a new coach
2. Session lifecycle — browsing sessions, joining, the FIFO waitlist experience (does a player know where they stand? what happens when a spot opens up — is it clear, is it fast, is there confusion around auto-promotion?), leaving/cancelling, recurring session clarity
3. Attendance marking — coach-side flow, how fast/frictionless is it during a live practice
4. Announcements — how audience targeting reads to the player receiving it, push notification → deep link → in-app landing coherence
5. Player profile/levels/leaderboard — is the badge tier system (bronze→Champion) legible and motivating, or confusing/demotivating for lower tiers; gender-scoped leaderboard framing
6. Coach-invite key flow — is this self-promotion flow discoverable in the right way (i.e., not accidentally exposed to regular players) and not confusing
7. Payments (in-progress) — flag anything half-built that's currently confusing to a real user today

SPECIFIC THINGS TO CHECK, NOT JUST GENERIC HEURISTICS
- RTL correctness: icon mirroring, text alignment, gesture directions (swipe-to-X), number/date formatting in Arabic, mixed-direction strings (e.g. a player name in Latin script inside an Arabic sentence)
- Material 3 usage: are you actually getting M3 benefits (dynamic color, proper elevation/state layers) or is it M3 in name only with default widgets everywhere
- Loading/error states for every Firestore-backed screen — what does a player see on slow connection or Cloud Function failure (since privileged actions round-trip through Cloud Functions, latency here directly affects perceived responsiveness)
- Waitlist UX specifically — this is the highest-stakes real-time state in the app; audit it harder than anything else
- Empty states (new club member with no sessions/history/endorsements yet)
- Notification fatigue — session reminders + announcements, is there any user control over what they receive

FOR EACH ISSUE
- What's wrong and the concrete user impact (not "could be better" — describe the actual moment of confusion/friction)
- Specific fix: exact copy, specific widget/layout change, or specific interaction pattern — something a developer could implement without further clarification
- Priority: high/med/low, weighted by how often a typical player/coach hits this path
- Note if it's an EN-only issue, AR-only issue, or both

DELIVERABLE
End with a prioritized punch list, split into "quick wins" (small changes, big impact) and "bigger investments" (worth doing but need design/dev time), so I can plan a sprint around it.

Be direct. If a flow is genuinely fine, say so and move on — I want signal, not padding.