/**
 * Creates the two App Review demo accounts for Spikers.
 *
 *   1. Member  — email-verified, role "player", membership EXPIRED (paidUntil
 *                in the past) so reviewers see the inactive-membership state.
 *   2. Active member — email-verified, role "player", membership ACTIVE
 *                (paidUntil in the future) so reviewers see the paid state.
 *   3. Coach   — email-verified, role "coach", lifetime member. Full staff
 *                powers (isStaffUid reads users/{uid}.role), so the reviewer can
 *                demonstrate the offline "purchase flow": open the member and
 *                tap Mark Paid — no payment sheet, status is a manual record.
 *
 * Both accounts set:
 *   - Auth emailVerified: true  → satisfies the email_verified token claim that
 *     the privileged Cloud Functions require.
 *   - Firestore verifiedAt != null → prevents cleanupUnverifiedUsers (runs
 *     every 5 min) from deleting the accounts.
 *
 * Re-runnable: if an account already exists it is updated in place.
 *
 * USAGE (from the functions/ directory):
 *   1. Firebase console → Project settings → Service accounts →
 *      "Generate new private key". Save it as functions/serviceAccountKey.json
 *      (already gitignored).
 *   2. node scripts/create_demo_users.js
 */

const path = require("path");
const admin = require("firebase-admin");

// ---------------------------------------------------------------------------
// Edit these if you want different demo credentials.
// ---------------------------------------------------------------------------
const MEMBER = {
  email: "demo.member@spikers-review.app",
  password: "SpikersDemo2026!",
  name: "Demo Member",
  role: "player",
};

const MEMBER_ACTIVE = {
  email: "demo.active@spikers-review.app",
  password: "SpikersActive2026!",
  name: "Demo Active Member",
  role: "player",
};

const COACH = {
  email: "demo.coach@spikers-review.app",
  password: "SpikersCoach2026!",
  name: "Demo Coach",
  role: "coach",
};
// ---------------------------------------------------------------------------

const keyPath =
  process.env.GOOGLE_APPLICATION_CREDENTIALS ||
  path.join(__dirname, "..", "serviceAccountKey.json");

let serviceAccount;
try {
  serviceAccount = require(keyPath);
} catch (e) {
  console.error(
    `\nCould not load a service account key at:\n  ${keyPath}\n\n` +
      "Download one from Firebase console → Project settings → Service " +
      "accounts → Generate new private key, save it as " +
      "functions/serviceAccountKey.json, then re-run.\n"
  );
  process.exit(1);
}

admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });
const auth = admin.auth();
const db = admin.firestore();
const { Timestamp, FieldValue } = admin.firestore;

const daysAgo = (n) => new Date(Date.now() - n * 24 * 60 * 60 * 1000);
const daysFromNow = (n) => new Date(Date.now() + n * 24 * 60 * 60 * 1000);

/** Create-or-update an Auth user, returning its uid. */
async function upsertAuthUser({ email, password, name }) {
  try {
    const existing = await auth.getUserByEmail(email);
    await auth.updateUser(existing.uid, {
      password,
      emailVerified: true,
      displayName: name,
      disabled: false,
    });
    console.log(`  updated existing auth user (${email})`);
    return existing.uid;
  } catch (e) {
    if (e.code !== "auth/user-not-found") throw e;
    const created = await auth.createUser({
      email,
      password,
      emailVerified: true,
      displayName: name,
    });
    console.log(`  created auth user (${email})`);
    return created.uid;
  }
}

async function run() {
  // --- Member with an EXPIRED membership -----------------------------------
  const memberUid = await upsertAuthUser(MEMBER);
  await db
    .collection("users")
    .doc(memberUid)
    .set(
      {
        name: MEMBER.name,
        role: MEMBER.role,
        gender: "male",
        dateOfBirth: Timestamp.fromDate(new Date("2000-01-01")),
        createdAt: FieldValue.serverTimestamp(),
        verifiedAt: FieldValue.serverTimestamp(), // non-null → survives cleanup
        paidAt: Timestamp.fromDate(daysAgo(60)),
        paidUntil: Timestamp.fromDate(daysAgo(30)), // EXPIRED 30 days ago
        lifetimeMember: false,
      },
      { merge: true }
    );
  console.log(`  member doc written (uid ${memberUid}, membership expired)\n`);

  // --- Member with an ACTIVE membership ------------------------------------
  const activeUid = await upsertAuthUser(MEMBER_ACTIVE);
  await db
    .collection("users")
    .doc(activeUid)
    .set(
      {
        name: MEMBER_ACTIVE.name,
        role: MEMBER_ACTIVE.role,
        gender: "male",
        dateOfBirth: Timestamp.fromDate(new Date("2000-01-01")),
        createdAt: FieldValue.serverTimestamp(),
        verifiedAt: FieldValue.serverTimestamp(), // non-null → survives cleanup
        paidAt: Timestamp.fromDate(daysAgo(5)),
        paidUntil: Timestamp.fromDate(daysFromNow(30)), // ACTIVE for 30 days
        lifetimeMember: false,
      },
      { merge: true }
    );
  console.log(`  active member doc written (uid ${activeUid}, membership active)\n`);

  // --- Coach ---------------------------------------------------------------
  const coachUid = await upsertAuthUser(COACH);
  await db
    .collection("users")
    .doc(coachUid)
    .set(
      {
        name: COACH.name,
        role: COACH.role,
        gender: "male",
        dateOfBirth: Timestamp.fromDate(new Date("1990-01-01")),
        createdAt: FieldValue.serverTimestamp(),
        verifiedAt: FieldValue.serverTimestamp(),
        lifetimeMember: true,
      },
      { merge: true }
    );
  console.log(`  coach doc written (uid ${coachUid}, role coach)\n`);

  console.log("Done. Demo accounts ready:");
  console.log(`  MEMBER         ${MEMBER.email}  /  ${MEMBER.password}`);
  console.log(`  MEMBER_ACTIVE  ${MEMBER_ACTIVE.email}  /  ${MEMBER_ACTIVE.password}`);
  console.log(`  COACH          ${COACH.email}  /  ${COACH.password}`);
}

run()
  .then(() => process.exit(0))
  .catch((e) => {
    console.error("Failed:", e);
    process.exit(1);
  });
