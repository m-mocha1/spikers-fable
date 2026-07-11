# Jerusalem Spikers — UX Audit (v1.0.2+26)

Audited against the 6 provided screenshots (splash, sign-in, home/sessions, session detail,
players tab coach-view, profile) plus the full client + Cloud Functions code on `animation`.
Priorities are weighted by how often a typical player/coach hits the path.
Tags: **EN** / **AR** / **Both**.

**What's genuinely fine (no action needed):**

- **Loading/error/empty states** — uniformly good. Every Firestore-backed screen has
  `ListShimmer` loading, `ErrorView` with retry, `EmptyStateView` with copy, and
  pull-to-refresh. Cloud Function latency on the hot paths (join/leave/attendance/endorse)
  is fully masked by optimistic UI with server reconciliation and rollback. This is the
  strongest part of the app.
- **Attendance marking** — coach taps a circle per player, optimistic flip, live count,
  works during a live session, ≥36px targets. Fast enough for courtside use. (One
  convenience gap: no "mark all", see M-11.)
- **Login screen** — clean, complete, nothing to fix.
- **Sign-in error mapping, form validation, photo pickers, account deletion flow** — solid.
- **AR string coverage** — 264/264 keys translated (two exceptions noted below), including
  correct Arabic plural rules (`endorseRemaining` handles the dual). Someone cared.

---

## 1. Onboarding / auth

### H-1 · Verify-email screen is dead weight since auto-verify was enabled — **Both, HIGH**
`autoVerifyNewUsers` (deployed 2026-07-10) marks every signup verified server-side, but
registration still routes to `VerifyEmailScreen`: *"We sent a verification link to {email}.
Tap it, then come back and press Continue."* The moment of confusion is concrete: the user
opens their inbox, may or may not find anything relevant, comes back, taps **Continue**, and
it just… works, having never tapped a link. Every single new member hits this.
**Fix:** on screen mount, run `reloadAndCheckVerified()` automatically (retry ~3× over 3s to
let the trigger land) and `context.go(Routes.home)` on success — keep the manual screen only
as the fallback. If email verification stays disabled long-term, skip the route entirely
after registration.

### H-2 · Coach role picker is in every player's face; a failed coach key fails silently — **Both, HIGH**
`register_screen.dart` shows **Role: Player / Coach** chips + a required "Coach Access Key"
field to every new user. Two concrete failure moments:
1. A curious player taps **Coach**, gets a required key field they can't fill, and is stuck
   until they figure out they must tap Player again.
2. A real coach typos the key → the account is **created as a player anyway**, and the only
   signal is a snackbar (`invalidCoachKey`) fired *during navigation* to the verify screen —
   trivially missed. They land in the player experience with no idea why and (see H-3) no
   way to retry.
**Fix:** replace the role chips with a low-key text button *"Have a coach key?"* that
reveals the field; on submit, call `validateCoachKey` **before** account creation and show
an inline field error on failure ("Invalid key — check with the club admin"), so a coach
never completes signup in the wrong role.

### H-3 · No way to enter a coach key after signup — **Both, HIGH (coach-only path)**
The code comments say a player "can retry coach promotion later" — but no UI exists anywhere
to do it. `validateCoachKey` is deployed, rate-limited, and unused outside registration.
**Fix:** add an "Enter coach key" row on the own-profile tab (bottom, low-key, near
Membership History). One dialog + one callable — the server side is done.

### M-4 · First run ignores the device language; no language switch before login — **AR, MED**
`LocaleNotifier.build()` hardcodes `Locale('en')` and the EN/AR toggle lives only in the
Profile tab, post-login. An Arabic-speaking newcomer does splash → login → register →
(verify) entirely in English.
**Fix:** default to `PlatformDispatcher.instance.locale` (clamped to en/ar) when no pref is
saved, and add a small `العربية / English` text toggle on the login screen's top corner.

### M-5 · New-player double wall: "Complete your profile" then "Membership inactive" — **Both, MED**
`SessionsRepositoryImpl.watchUpcoming` returns an empty stream for players with incomplete
profiles or inactive membership, and the tab shows one gate at a time. A new player completes
gender/DOB, and is immediately hit with *"Your club membership isn't active. Contact your
coach to renew"* — with no action button and no visibility of what the club even offers.
**Fix:** combine into one onboarding card listing both steps with states
("✓ Profile complete · ○ Membership — talk to your coach"), and consider letting gated
players *see* the session list read-only (join disabled) so the app isn't a blank wall on
day one.

## 2. Session lifecycle & waitlist (audited hardest)

The join/leave core is genuinely good: optimistic membership flip with race reconciliation,
FIFO waitlist held in one transaction, promotion in the same transaction as the leave, a push
on promotion, and the full ordered waitlist (with `#position`) visible to everyone on the
detail screen. The foundation is right; the gaps are in *communication*.

### H-6 · A waitlisted player's own standing is buried — **Both, HIGH**
The button flips to "Leave Waitlist" but nothing tells the player *where they stand* — they
must scroll the waitlist and find their own avatar among rows. On the home card there is no
trace at all. The question the brief asks — "does a player know where they stand?" — the
answer today is "only if they hunt for it."
**Fix (small):** when `isWaitlisted`, render one line above the button:
EN *"You're #2 in line — we'll notify you the moment a spot opens."*
AR *"أنت في المركز ٢ بقائمة الانتظار — سنعلمك فور توفر مكان."*
(`session.waitlistIds.indexOf(uid) + 1`). Also append the position to `waitlistedSnack`.

### H-7 · Auto-promotion is a silent commitment — **Both, HIGH**
When an attendee leaves, the head of the waitlist is *instantly* moved into attendees and
pushed "A spot opened — you're in!". If that lands 30 minutes before start on a player who
made other plans, they are committed without consent; if they no-show, attendance data and
the coach's headcount are polluted. Leaving is allowed up to start time, so late-leave →
late-promote chains are common by design.
**Fix (quick):** enrich the push with the start time and an out:
*"Tuesday practice · today 12:30 — a spot opened and you're in! Can't make it? Leave the
session so the next player gets the spot."*
**Fix (bigger):** promotion-with-confirmation — hold the freed spot for the promotee for a
window (e.g. 30 min, or until T-2h) with Accept / Pass actions on the notification; pass
rolls to the next in line.

### H-8 · Every push notification is hardcoded English — **AR, HIGH**
`functions/src/index.ts` sends all visible notification text in English: `"A spot opened —
you're in!"`, `` `${coachName} created a new practice ${title}` ``, `` `${authorName}
posted: ${title}` ``, `` `${coachName} cancelled practice … · ${dateStr}` `` (with an
EN-formatted date). The client's `NotificationsService` only routes taps — it never
re-renders bodies. For a club where Arabic is first-class, half the members get every
time-critical message (promotion! cancellation!) in the wrong language.
**Fix (quick stopgap):** bilingual template bodies in one push — e.g.
`"فتح مكان — تم تسجيلك! · A spot opened — you're in!"`. Titles are mostly user content
(session/announcement titles) and pass through fine.
**Fix (proper):** persist the user's locale (client writes `locale` into
`users/{uid}/private/fcm` on toggle — the doc and its writers already exist) and pick per-token
copy in `sendFcmToUids`.

### M-9 · Countdown shows raw hour counts past 24h — **Both, MED**
`_CountdownTimer` renders `HH:MM:SS` from `diff.inHours` — a session 36 hours out shows
**"36:00:00"**, which reads like a broken clock.
**Fix:** when `diff.inDays >= 1`, render `1d 12:00:00` (localized "d"), or switch the label
row to "TOMORROW · 12:30".

### M-10 · Session cards don't show the viewer's membership; two unlabeled fractions — **Both, MED**
On the sessions list, a joined or waitlisted session looks identical to any other (the gold
"Next up" spotlight covers only the *earliest* one). A player with two bookings can't tell
which cards are theirs without tapping in. Meanwhile a full card shows `0/12` **and**
`⏳ 0/2` side by side — two unlabeled fractions that regular users must decode.
**Fix:** add a compact status chip to `SessionCard` when `isJoinedBy/isWaitlistedBy(uid)`:
`✓ Joined` / `⏳ #2`. That chip also disambiguates the waitlist fraction for everyone else.

### M-11 · "Mark all attended" is missing — **Both, MED (coach, every session)**
Realistic case: 12 of 12 showed up → 12 individual taps mid-practice.
**Fix:** one "Mark all" text button in the attendees header (staff only, with the existing
optimistic pattern). Server loop over `markAttended` or a small batch callable.

### M-12 · Recurring sessions only exist 1 day ahead — **Both, MED**
`createRecurringSessions` materializes *tomorrow's* sessions nightly at 21:00. A player can
never see next Tuesday's practice, and joining becomes a nightly 21:00 scramble for popular
slots. If that scramble is intended (fair-start), keep it but *say so*; otherwise
materialize N days ahead.
**Fix (either/or):** materialize 7 days out; or add a footer to the sessions list:
*"Weekly sessions open for booking each evening at 21:00."*

### L-13 · After start, controls vanish silently; leave-after-start error is generic — **Both, LOW**
`_JoinButton` returns nothing for ongoing sessions, and `_leave`'s catch-all maps the
server's `failed-precondition: "Session already started"` to *"Something went wrong. Please
try again."* — factually wrong (nothing went wrong; it's a rule).
**Fix:** map the code to *"The session has started — the roster is locked."* and render that
as static text where the button was.

## 3. Attendance marking — fine (see M-11 only)

## 4. Announcements

### M-14 · Audience chip reads as a mystery label — **Both, MED**
The card shows a chip that just says **"Male"** / **"Female"**. To a player whose feed is
already gender-filtered, it reads like a label of the *author*, or noise. It only carries
meaning for coaches reviewing what they targeted.
**Fix:** copy change: "For men" / "For women" (AR: "للرجال" / "للسيدات"); or show the chip
only to staff.

### L-15 · Notification tap lands on the list, not the item — **Both, LOW**
Tapping an announcement push opens the announcements screen and immediately marks
*everything* read; the tapped item isn't highlighted or scrolled to. With a handful of
announcements this is fine; note it will degrade as volume grows. Also, after creating an
announcement, coaches get no sense of reach — *"Sent to 34 players"* in the confirmation
snackbar would also pre-empt the recurring "notifications don't work" confusion (the author
is excluded from their own push by design).

### L-16 · Dates older than 7 days render as raw `2026-07-03` — **AR, LOW**
`_relativeTime` falls back to a hand-built ISO string. Use a locale-aware
`DateFormat.yMMMd(localeName)`.

## 5. Profile / levels / leaderboard

The tier system itself is legible and motivating: named tiers, progress bar, "1 to Regular",
one-shot milestone celebrations. No demotivation problem at low tiers — Rookie with a
progress bar reads as a runway, not a stigma. Leave the mechanics alone.

### M-17 · Leaderboard gender scoping is invisible to players — **Both, MED**
A female player's board silently shows only women. Anyone who compares boards with a male
teammate concludes the app is broken or players are missing. Also the score pill is an
unlabeled number.
**Fix:** for players, add a one-line subtitle under the tabs: *"Women's board — sessions
attended"* / *"لوحة السيدات — عدد الحصص"*. That fixes both gaps in one string.

### M-18 · RTL bug: level pill hugs the badge instead of the card edge — **AR, MED**
`profile_stat_cards.dart` uses `Alignment.centerRight` — a physical alignment. In RTL the
row mirrors but the pill doesn't, landing next to the badge art.
**Fix:** `AlignmentDirectional.centerEnd` (two occurrences: games card + endorsements card).

### L-19 · "Level 1" endorsements card is flat next to the games card — **Both, LOW**
The games card has named tiers + a progress bar; endorsements has a bare "Level 1" and no
progress. Same card, less life.
**Fix:** add the same progress-to-next-level bar (`endorsementLevel` thresholds exist) and
consider naming the levels.

### L-20 · Non-mirroring chevrons in RTL — **AR, LOW**
`Icons.arrow_forward_ios` (Membership History row) and `Icons.chevron_right`
(Complete-profile card, Next-up card) don't flip in RTL, pointing "back" in Arabic.
**Fix:** `Icon(..., matchTextDirection: true)` or swap to directional icons. (The language
toggle row hand-picks its arrow per locale already — make the rest consistent.)

## 6. Coach-invite key — see H-2 / H-3. Server side (timing-safe compare, rate limiting, server-side promotion) is sound; the problems are purely presentational.

## 7. Payments (in-progress)

Coach side works: tap the pill on the players tab → confirm dialog → toggle, with
days-left and lifetime states. The player side is the half-built part that confuses real
users today:

### H-21 · Players can't see their own membership status — and expiry is a cliff — **Both, HIGH**
A player has *no* view of their own membership: the profile offers only a "Membership
History" log (and its empty state is untranslated — see L-23). There is no warning at
6d/3d/1d. The concrete moment: membership lapses overnight and the sessions tab goes from a
full list to **empty** with "Membership inactive" — the app's single most alarming screen
transition, and it happens to every player every renewal cycle.
**Fix (quick):** status row on own profile using the data the coach pill already uses:
*"Membership: Active · 6d left"* / amber ≤9d / red expired.
**Fix (bigger):** expiry-warning push at 7d/1d (*"Your membership ends Friday — see your
coach to renew"*), and on expiry keep the session list visible with Join disabled instead of
blanking the tab.

### L-22 · "Active/Inactive" conflates payment with activity — **EN, LOW**
The pill on the players tab reads "Active 6d left" — a new coach can read "active" as
"plays often". If the club is comfortable naming money, "Paid · 6d" / "Expired" is
unambiguous. (AR "نشط" has the same softness; change both or neither.)

### L-23 · ~~`noPayments` is untranslated~~ — **WITHDRAWN**
False positive: the key doesn't exist in either ARB file (the audit script printed a
missing-key marker that read like an English value). Nothing to fix.

## Cross-cutting

### H-24 · Dates are never localized — **AR, HIGH**
No `Intl.defaultLocale` is ever set and no `DateFormat` receives a locale, so **every**
date/day-name in the app ("Tuesday, Jul 7 • 12:30", "EEEE" in the Next-up card, history,
payment log) renders in English inside the Arabic UI.
**Fix:** in the `MaterialApp.builder` (or wherever `locale` resolves), set
`Intl.defaultLocale = locale.toLanguageTag()`. One line fixes all ten call sites; audit the
two `yyyy-MM-dd` DOB fields to make sure they *stay* ISO (they feed parsing, not display).

### M-25 · Material 3: chips and pills built on GestureDetector — **Both, MED**
The design system verdict first: this is "M3 in name only" — hardcoded `AppColors`
everywhere, no dynamic color, custom nav bar — **and that's fine**. The navy/gold brand is
coherent and consistent; do not chase dynamic color. The real cost is interaction states:
`_GenderChip` (register), `_PaidBadge` (players tab) use `GestureDetector` — no ripple, no
state layer, and `_PaidBadge` (a primary coach action, tapped constantly) is a small target.
**Fix:** wrap in `InkWell` with a 44px min constraint. Everything else already uses
InkWell/IconButton correctly.

### M-26 · Notification fatigue: zero user control — **Both, MED**
Players receive session-created, cancellation, announcement, and promotion pushes with no
way to mute any category. At current club volume this is tolerable; it's the first thing
that will hurt when a second weekly recurring session lands.
**Fix (bigger):** a notifications section in profile with per-kind toggles stored in
`users/{uid}/private/fcm` (doc already exists), respected in `sendFcmToUids`. Pairs
naturally with the per-user locale from H-8.

### L-27 · Latin names inside Arabic sentences — **AR, LOW**
Templates like `endorsedPlayer(name)` / `confirmRemovePlayer(name)` interpolate
Latin-script names into Arabic sentences. Unicode bidi handles most cases; names starting
with digits/punctuation can jumble.
**Fix:** wrap interpolations in FSI/PDI (`⁨…⁩`) — cheap insurance, do it in the
ARB templates.

---

# Punch list

## Quick wins (small change, big impact)

| # | Item | Ref | Lang | Est |
|---|------|-----|------|-----|
| 1 | Set `Intl.defaultLocale` from the app locale → all dates localize | H-24 | AR | ~1h |
| 2 | Auto-check + skip the verify-email screen while auto-verify is deployed | H-1 | Both | ~2h |
| 3 | "You're #N in line" line above the Leave-Waitlist button + position in the snackbar | H-6 | Both | ~2h |
| 4 | Bilingual (AR·EN) bodies for all FCM pushes, promotion push gains time + "can't make it? leave the spot" | H-7/H-8 | AR | ~2h |
| 5 | Membership status row on the player's own profile ("Active · 6d left") | H-21 | Both | ~3h |
| 6 | Register: demote Coach to "Have a coach key?" + inline invalid-key error before account creation | H-2 | Both | ~4h |
| 7 | "Enter coach key" row in profile → `validateCoachKey` (server ready) | H-3 | Both | ~3h |
| 8 | `✓ Joined` / `⏳ #2` chip on session cards | M-10 | Both | ~3h |
| 9 | Countdown: `1d 12:00:00` (or "Tomorrow") past 24h | M-9 | Both | ~1h |
| 10 | Leaderboard player subtitle: "Women's/Men's board — sessions attended" | M-17 | Both | ~1h |
| 11 | "Mark all attended" for staff | M-11 | Both | ~2h |
| 12 | AR nits batch: `noPayments` translation, `AlignmentDirectional.centerEnd` pills, `matchTextDirection` chevrons, FSI/PDI around names | M-18/L-20/L-23/L-27 | AR | ~2h |
| 13 | InkWell + 44px targets for `_PaidBadge` and `_GenderChip` | M-25 | Both | ~1h |
| 14 | Map leave-after-start to "roster is locked" message; audience chip copy "For men/For women" | L-13/M-14 | Both | ~1h |

Rough total: ~3–4 dev-days. Items 1–5 alone fix the highest-frequency confusion in the app.

## Bigger investments (worth doing, need design/dev time)

1. **Per-user notification locale + per-category preferences** (H-8 + M-26) — one settings
   surface, one `private/fcm` schema change, functions filter per token. Kills the two
   biggest systemic issues (EN pushes, fatigue) properly.
2. **Waitlist promotion with a confirmation window** (H-7) — hold the freed spot with
   Accept/Pass, roll to next on timeout. The highest-stakes real-time flow deserves consent.
3. **Membership lifecycle for players** (H-21) — expiry-warning pushes, expired state that
   still shows the schedule with Join disabled, "how to renew" card.
4. **Recurring-session horizon** (M-12) — materialize a week ahead (or a schedule view), or
   explicitly message the nightly 21:00 opening.
5. **Unified first-run onboarding** (M-5 + M-4) — device-locale default + login-screen
   language toggle + a single gating card (profile ✓ / membership ○) instead of sequential
   walls.
6. **Announcement reach + deep-link polish** (L-15) — "Sent to N players" confirmation,
   scroll-to/highlight the tapped announcement.
