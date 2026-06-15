import * as admin from "firebase-admin";
import * as crypto from "crypto";
import * as logger from "firebase-functions/logger";
import { onSchedule } from "firebase-functions/v2/scheduler";
import {
  onDocumentCreated,
  onDocumentWritten,
} from "firebase-functions/v2/firestore";
import { onCall, HttpsError } from "firebase-functions/v2/https";

admin.initializeApp();
const db = admin.firestore();

const REGION = "europe-west1";

function chunkArray<T>(arr: T[], size: number): T[][] {
  const chunks: T[][] = [];
  for (let i = 0; i < arr.length; i += size) {
    chunks.push(arr.slice(i, i + size));
  }
  return chunks;
}

function calcAge(dob: admin.firestore.Timestamp): number {
  const ms = Date.now() - dob.toDate().getTime();
  return Math.floor(ms / (365.25 * 24 * 60 * 60 * 1000));
}

function isPaid(p: FirebaseFirestore.DocumentData): boolean {
  const paidUntil = p["paidUntil"] as admin.firestore.Timestamp | undefined;
  return !!paidUntil && paidUntil.toMillis() > Date.now();
}

// Reads a user's display name from users/{uid}.name. Returns '' if missing.
async function fetchUserName(uid: string): Promise<string> {
  if (!uid) return "";
  try {
    const doc = await db.collection("users").doc(uid).get();
    return (doc.data()?.["name"] as string | undefined) ?? "";
  } catch {
    return "";
  }
}

// Reads users/{uid}.role and returns true if the caller is an admin.
async function isAdminUid(uid: string): Promise<boolean> {
  if (!uid) return false;
  try {
    const doc = await db.collection("users").doc(uid).get();
    return doc.data()?.["role"] === "admin";
  } catch {
    return false;
  }
}

// Asserts the caller is an authenticated, email-verified admin and returns
// their uid. Throws an HttpsError otherwise.
async function requireAdmin(
  request: { auth?: { uid?: string; token?: { email_verified?: boolean } } }
): Promise<string> {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Email not verified");
  }
  if (!(await isAdminUid(uid))) {
    throw new HttpsError("permission-denied", "Admins only");
  }
  return uid;
}

// FCM tokens live at users/{uid}/private/fcm.token (moved off the user doc
// so token refreshes don't fan out to client listeners on the users
// collection). Fetches in parallel; skips uids with no token document.
async function fetchFcmTokens(uids: string[]): Promise<string[]> {
  if (uids.length === 0) return [];
  const docs = await Promise.all(
    uids.map((uid) =>
      db.collection("users").doc(uid).collection("private").doc("fcm").get()
    )
  );
  const tokens: string[] = [];
  for (const doc of docs) {
    const t = doc.data()?.["token"] as string | undefined;
    if (t) tokens.push(t);
  }
  return tokens;
}

// ---------------------------------------------------------------------------
// cleanupUnverifiedUsers — every 5 min, deletes registrations that never
// confirmed their email after 30 minutes (Firestore profile + Auth user +
// profile photo). Self-heals docs whose user actually IS verified.
// ---------------------------------------------------------------------------
export const cleanupUnverifiedUsers = onSchedule(
  { schedule: "every 5 minutes", region: REGION },
  async () => {
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 30 * 60 * 1000
    );

    const candidates = await db
      .collection("users")
      .where("verifiedAt", "==", null)
      .where("createdAt", "<", cutoff)
      .get();

    for (const doc of candidates.docs) {
      const uid = doc.id;
      try {
        const authUser = await admin
          .auth()
          .getUser(uid)
          .catch((e) => {
            logger.warn("cleanupUnverifiedUsers: getUser failed", {
              uid,
              error: e,
            });
            return null;
          });
        if (authUser?.emailVerified) {
          await doc.ref.update({
            verifiedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          continue;
        }

        await admin
          .storage()
          .bucket()
          .file(`profilePhotos/${uid}.jpg`)
          .delete()
          .catch((e) => {
            logger.warn("cleanupUnverifiedUsers: profile photo delete failed", {
              uid,
              error: e,
            });
            return undefined;
          });

        await doc.ref.delete();

        if (authUser) {
          await admin
            .auth()
            .deleteUser(uid)
            .catch((e) => {
              logger.warn("cleanupUnverifiedUsers: deleteUser failed", {
                uid,
                error: e,
              });
              return undefined;
            });
        }
      } catch (e) {
        console.error("cleanupUnverifiedUsers failed for", uid, e);
      }
    }
  }
);

// FIXED sessionCleanup function — replace your current one with this

// ---------------------------------------------------------------------------
// sessionCleanup — runs every 5 minutes, archives sessions that ended 1+ min ago
// ---------------------------------------------------------------------------
export const sessionCleanup = onSchedule(
  { schedule: "every 1 minutes", region: REGION },
  async () => {
    // Only archive sessions that ended more than 1 minute ago
    const cutoff = admin.firestore.Timestamp.fromMillis(
      Date.now() - 1 * 60 * 1000
    );

    const snap = await db
      .collection("sessions")
      .where("endTime", "<=", cutoff)
      .get();

    logger.info("sessionCleanup: found sessions to archive", {
      count: snap.size,
      ids: snap.docs.map((d) => d.id),
    });

    if (snap.empty) return;

    try {
      const archivedAt = admin.firestore.FieldValue.serverTimestamp();
      const batch = db.batch();
      snap.docs.forEach((doc) => {
        const historyRef = db.collection("sessions_history").doc(doc.id);
        batch.set(historyRef, { ...doc.data(), archivedAt });
        batch.delete(doc.ref);
      });
      await batch.commit();
      logger.info("sessionCleanup: archived and deleted", {
        count: snap.size,
      });
    } catch (e) {
      logger.error("sessionCleanup failed", { error: e });
    }
  }
);

// ---------------------------------------------------------------------------
// archiveExpiredSessionsNow — coach-callable on-demand archival.
// Lets the Sessions History page populate within seconds of opening instead
// of waiting up to 15 min for the next sessionCleanup tick.
// ---------------------------------------------------------------------------
export const archiveExpiredSessionsNow = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");

    const now = admin.firestore.Timestamp.now();
    const snap = await db
      .collection("sessions")
      .where("endTime", "<=", now)
      .get();

    logger.info("archiveExpiredSessionsNow: found expired sessions", {
      count: snap.size,
      ids: snap.docs.map((d) => d.id),
    });

    if (snap.empty) return { archived: 0 };

    const archivedAt = admin.firestore.FieldValue.serverTimestamp();
    const batch = db.batch();
    snap.docs.forEach((doc) => {
      const historyRef = db.collection("sessions_history").doc(doc.id);
      batch.set(historyRef, { ...doc.data(), archivedAt });
      batch.delete(doc.ref);
    });
    await batch.commit();
    logger.info("archiveExpiredSessionsNow: archived and deleted", {
      count: snap.size,
    });
    return { archived: snap.docs.length };
  }
);

// ---------------------------------------------------------------------------
// onSessionCreated — sends FCM to all matching players when a session is added
// ---------------------------------------------------------------------------
export const onSessionCreated = onDocumentCreated(
  { document: "sessions/{sessionId}", region: REGION },
  async (event) => {
    const snap = event.data;
    if (!snap) return;

    const session = snap.data();
    if (session["notified"] === true) return;

    const gender = session["gender"];
    const minAge = session["minAge"];
    const maxAge = session["maxAge"];
    const title = (session["title"] as string) ?? "";
    const location = (session["location"] as string) ?? "";

    if (
      typeof gender !== "string" ||
      !["male", "female", "mixed"].includes(gender) ||
      typeof minAge !== "number" ||
      typeof maxAge !== "number"
    ) {
      logger.error("onSessionCreated: invalid session fields, skipping", {
        sessionId: event.params["sessionId"],
        gender,
        minAge,
        maxAge,
      });
      return;
    }

    const genders = gender === "mixed" ? ["male", "female"] : [gender];

    const playersSnap = await db
      .collection("users")
      .where("role", "==", "player")
      .where("gender", "in", genders)
      .get();

    const matchedUids: string[] = [];
    for (const doc of playersSnap.docs) {
      const p = doc.data();
      if (!p["dateOfBirth"]) continue;
      if (!isPaid(p)) continue;
      const age = calcAge(p["dateOfBirth"] as admin.firestore.Timestamp);
      if (age >= minAge && age <= maxAge) {
        matchedUids.push(doc.id);
      }
    }
    const tokens = await fetchFcmTokens(matchedUids);

    if (tokens.length > 0) {
      const coachName = await fetchUserName(session["coachId"] as string);
      try {
        for (const chunk of chunkArray(tokens, 500)) {
          await admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification: {
              title: `${coachName} created a new practice ${title}`,
              body: location,
            },
            data: { sessionId: event.params["sessionId"] },
          });
        }
      } catch (e) {
        logger.error("onSessionCreated: FCM send failed", {
          sessionId: event.params["sessionId"],
          error: e,
        });
      }
    }

    await snap.ref.update({ notified: true });
  }
);

// ---------------------------------------------------------------------------
// cancelSession — deletes session + notifies all attendees
// ---------------------------------------------------------------------------
export const cancelSession = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Email not verified");
  }

  const sessionId = request.data["sessionId"] as string | undefined;
  if (!sessionId)
    throw new HttpsError("invalid-argument", "sessionId required");

  const sessionRef = db.collection("sessions").doc(sessionId);
  const sessionDoc = await sessionRef.get();

  if (!sessionDoc.exists)
    throw new HttpsError("not-found", "Session not found");

  const session = sessionDoc.data()!;
  if (session["coachId"] !== uid && !(await isAdminUid(uid))) {
    throw new HttpsError("permission-denied", "Not your session");
  }

  // Notify attendees before deleting
  const attendeeIds: string[] = session["attendeeIds"] ?? [];
  if (attendeeIds.length > 0) {
    const tokens = await fetchFcmTokens(attendeeIds);
    if (tokens.length > 0) {
      const sessionTitle = session["title"] as string;
      const coachName = await fetchUserName(session["coachId"] as string);
      const startDate = (
        session["startTime"] as admin.firestore.Timestamp
      ).toDate();
      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];
      const day = startDate.getDate().toString().padStart(2, "0");
      const month = months[startDate.getMonth()];
      const hh = startDate.getHours().toString().padStart(2, "0");
      const mm = startDate.getMinutes().toString().padStart(2, "0");
      const dateStr = `${day} ${month}  ${hh}:${mm}`;

      try {
        for (const chunk of chunkArray(tokens, 500)) {
          await admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification: {
              title: sessionTitle,
              body: `${coachName} cancelled practice ${sessionTitle} · ${dateStr}`,
            },
            data: { sessionId },
          });
        }
      } catch (e) {
        logger.error("cancelSession: FCM send failed", { sessionId, error: e });
      }
    }
  }

  await sessionRef.delete();
  return { success: true };
});

// Removes a user from every session they belong to (attendee or waitlist),
// promoting the head of the waitlist into any vacated attendee slot and
// notifying the promotee. Best-effort per session — failures are logged, not
// thrown, so account deletion still completes.
async function removeUserFromAllSessions(userId: string): Promise<void> {
  const [asAttendee, asWaitlisted] = await Promise.all([
    db.collection("sessions").where("attendeeIds", "array-contains", userId).get(),
    db.collection("sessions").where("waitlistIds", "array-contains", userId).get(),
  ]);

  const seen = new Set<string>();
  const promotions: { uid: string; sessionId: string; title: string }[] = [];

  for (const doc of [...asAttendee.docs, ...asWaitlisted.docs]) {
    if (seen.has(doc.id)) continue;
    seen.add(doc.id);

    const session = doc.data();
    const attendeeIds: string[] = session["attendeeIds"] ?? [];
    const waitlistIds: string[] = session["waitlistIds"] ?? [];
    const attendedIds: string[] = session["attendedIds"] ?? [];
    const update: Record<string, unknown> = {};

    if (attendeeIds.includes(userId)) {
      const next = attendeeIds.filter((x) => x !== userId);
      if (waitlistIds.length > 0) {
        const promoted = waitlistIds[0];
        if (!next.includes(promoted)) next.push(promoted);
        update["waitlistIds"] = waitlistIds.slice(1);
        promotions.push({
          uid: promoted,
          sessionId: doc.id,
          title: (session["title"] as string) ?? "",
        });
      }
      update["attendeeIds"] = next;
      if (attendedIds.includes(userId)) {
        update["attendedIds"] = attendedIds.filter((x) => x !== userId);
      }
    } else if (waitlistIds.includes(userId)) {
      update["waitlistIds"] = waitlistIds.filter((x) => x !== userId);
    }

    if (Object.keys(update).length > 0) {
      await doc.ref.update(update).catch((e) => {
        logger.warn("adminDeleteUser: session cleanup failed", {
          sessionId: doc.id,
          error: e,
        });
        return undefined;
      });
    }
  }

  for (const p of promotions) {
    await notifyPromoted([p.uid], p.sessionId, p.title).catch(() => undefined);
  }
}

// ---------------------------------------------------------------------------
// adminDeleteUser — admin-only permanent deletion of a user account
// (players and coaches are both /users docs). Removes the user from any
// sessions, the profile photo, the Firestore user doc + subcollections
// (mirrorUserPublic then drops the public mirror), and the Firebase Auth login.
// ---------------------------------------------------------------------------
export const adminDeleteUser = onCall({ region: REGION }, async (request) => {
  const callerUid = await requireAdmin(request);

  const userId = request.data["userId"] as string | undefined;
  if (!userId) throw new HttpsError("invalid-argument", "userId required");
  if (userId === callerUid) {
    throw new HttpsError("permission-denied", "Cannot delete yourself");
  }

  // Drop the user from any sessions they're in (with waitlist promotion).
  await removeUserFromAllSessions(userId);

  // Profile photo (best-effort).
  await admin
    .storage()
    .bucket()
    .file(`profilePhotos/${userId}.jpg`)
    .delete()
    .catch((e) => {
      logger.warn("adminDeleteUser: profile photo delete failed", {
        userId,
        error: e,
      });
      return undefined;
    });

  // User doc + subcollections (payments, templates, private). The
  // mirrorUserPublic trigger deletes users_public/{userId} afterwards.
  await db.recursiveDelete(db.collection("users").doc(userId));

  // Auth login (best-effort — may already be gone).
  await admin
    .auth()
    .deleteUser(userId)
    .catch((e) => {
      logger.warn("adminDeleteUser: deleteUser failed", { userId, error: e });
      return undefined;
    });

  logger.info("adminDeleteUser: deleted", { userId, by: callerUid });
  return { success: true };
});

// ---------------------------------------------------------------------------
// validateCoachKey — server-side check so the secret never reaches the client
// ---------------------------------------------------------------------------
// Called during registration (before email verification) so it cannot
// require email_verified — the user has just been created. Auth is still
// required, so an anonymous attacker can't brute-force. On success the
// caller's own user doc is promoted to role='coach' here, server-side,
// so the rules can force role='player' at create.
const MAX_COACH_KEY_ATTEMPTS = 5;
const COACH_KEY_WINDOW_MS = 60 * 60 * 1000; // 1 hour

export const validateCoachKey = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");

  const key = request.data["key"] as string | undefined;
  if (!key) throw new HttpsError("invalid-argument", "key required");

  // Brute-force guard: per-uid attempt window. Check-and-increment runs in a
  // transaction so parallel calls can't slip past the cap. Only the Admin SDK
  // touches this collection — client rules never grant access to it.
  const attemptsRef = db.collection("coach_key_attempts").doc(uid);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(attemptsRef);
    const now = Date.now();
    const windowStart = (snap.data()?.["windowStart"] ?? 0) as number;
    const count = (snap.data()?.["count"] ?? 0) as number;
    const inWindow = now - windowStart < COACH_KEY_WINDOW_MS;
    if (inWindow && count >= MAX_COACH_KEY_ATTEMPTS) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many attempts — try again later"
      );
    }
    tx.set(
      attemptsRef,
      inWindow ? { count: count + 1, windowStart } : { count: 1, windowStart: now }
    );
  });

  const doc = await db.collection("config").doc("coachKey").get();
  const stored = (doc.data()?.["value"] ?? "") as string;

  const a = Buffer.from(key.trim(), "utf8");
  const b = Buffer.from(stored, "utf8");
  const valid =
    a.length > 0 && a.length === b.length && crypto.timingSafeEqual(a, b);

  if (!valid) return { valid: false };

  await db.collection("users").doc(uid).update({ role: "coach" });
  await attemptsRef.delete().catch((e) => {
    logger.warn("validateCoachKey: failed to clear attempts", { uid, error: e });
  });
  return { valid: true };
});

// ---------------------------------------------------------------------------
// notifyPromoted — pushes "a spot opened, you're in" to a list of UIDs.
// Body is sent as a localization key in the data payload so the client can
// render it in the user's current locale (same pattern other notifications
// could later adopt). Falls back to the EN body in the visible notification.
// ---------------------------------------------------------------------------
async function notifyPromoted(
  uids: string[],
  sessionId: string,
  sessionTitle: string
): Promise<void> {
  if (uids.length === 0) return;
  const tokens = await fetchFcmTokens(uids);
  if (tokens.length === 0) return;
  try {
    for (const chunk of chunkArray(tokens, 500)) {
      await admin.messaging().sendEachForMulticast({
        tokens: chunk,
        notification: {
          title: sessionTitle,
          body: "A spot opened — you're in!",
        },
        data: { sessionId, kind: "waitlist_promoted" },
      });
    }
  } catch (e) {
    logger.error("notifyPromoted: FCM send failed", { sessionId, error: e });
  }
}

// ---------------------------------------------------------------------------
// joinSession — transactional join. Falls back to the waitlist (FIFO) when
// attendees are full; rejects only when both are full.
// Returns { status: 'joined' | 'waitlisted' | 'already_joined' | 'already_waitlisted' }
// ---------------------------------------------------------------------------
export const joinSession = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  const sessionId = request.data?.["sessionId"] as string | undefined;
  logger.info("joinSession called", { uid, sessionId });

  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Email not verified");
  }
  if (!sessionId)
    throw new HttpsError("invalid-argument", "sessionId required");

  const sessionRef = db.collection("sessions").doc(sessionId);

  const status = await db.runTransaction<
    "joined" | "waitlisted" | "already_joined" | "already_waitlisted"
  >(async (tx) => {
    const sessionDoc = await tx.get(sessionRef);
    if (!sessionDoc.exists)
      throw new HttpsError("not-found", "Session not found");

    const session = sessionDoc.data()!;
    const attendeeIds: string[] = session["attendeeIds"] ?? [];
    const waitlistIds: string[] = session["waitlistIds"] ?? [];
    const maxPlayers = session["maxPlayers"] as number;
    const waitlistSize = (session["waitlistSize"] ?? 0) as number;

    if (attendeeIds.includes(uid)) return "already_joined";
    if (waitlistIds.includes(uid)) return "already_waitlisted";

    if (attendeeIds.length < maxPlayers) {
      tx.update(sessionRef, {
        attendeeIds: admin.firestore.FieldValue.arrayUnion(uid),
      });
      return "joined";
    }

    if (waitlistIds.length < waitlistSize) {
      // Rewrite the full array to guarantee FIFO order (arrayUnion gives
      // no ordering guarantees that we want to rely on for promotion).
      tx.update(sessionRef, {
        waitlistIds: [...waitlistIds, uid],
      });
      return "waitlisted";
    }

    throw new HttpsError(
      "failed-precondition",
      "Session and waitlist are full"
    );
  });

  return { status };
});

// ---------------------------------------------------------------------------
// leaveSession — transactional leave (attendees or waitlist). When an
// attendee leaves, the head of the waitlist is promoted in the same
// transaction and notified after commit. Leaving an in-progress session is
// blocked only for attendees; waitlisted users can leave any time.
// ---------------------------------------------------------------------------
export const leaveSession = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  const sessionId = request.data?.["sessionId"] as string | undefined;
  logger.info("leaveSession called", { uid, sessionId });

  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Email not verified");
  }
  if (!sessionId)
    throw new HttpsError("invalid-argument", "sessionId required");

  const sessionRef = db.collection("sessions").doc(sessionId);
  let promotedUid: string | null = null;
  let sessionTitle = "";

  await db.runTransaction(async (tx) => {
    const sessionDoc = await tx.get(sessionRef);
    if (!sessionDoc.exists)
      throw new HttpsError("not-found", "Session not found");

    const session = sessionDoc.data()!;
    const attendeeIds: string[] = session["attendeeIds"] ?? [];
    const waitlistIds: string[] = session["waitlistIds"] ?? [];
    sessionTitle = (session["title"] as string) ?? "";

    if (attendeeIds.includes(uid)) {
      const startTime = session["startTime"] as admin.firestore.Timestamp;
      if (startTime.toMillis() <= Date.now()) {
        throw new HttpsError("failed-precondition", "Session already started");
      }

      const update: Record<string, unknown> = {
        attendeeIds: admin.firestore.FieldValue.arrayRemove(uid),
      };
      if (waitlistIds.length > 0) {
        promotedUid = waitlistIds[0];
        update["attendeeIds"] =
          admin.firestore.FieldValue.arrayUnion(promotedUid);
        // The leaver and promotee can't be the same person (idempotency
        // check above) so the two arrayUnion/arrayRemove ops compose fine,
        // but arrayUnion and arrayRemove on the SAME field in one update
        // is not allowed — collapse to an explicit rewrite.
        const next = attendeeIds.filter((x) => x !== uid);
        if (promotedUid && !next.includes(promotedUid)) next.push(promotedUid);
        update["attendeeIds"] = next;
        update["waitlistIds"] = waitlistIds.slice(1);
      }
      tx.update(sessionRef, update);
      return;
    }

    if (waitlistIds.includes(uid)) {
      tx.update(sessionRef, {
        waitlistIds: waitlistIds.filter((x) => x !== uid),
      });
      return;
    }
    // Not a member — no-op (idempotent).
  });

  if (promotedUid) {
    await notifyPromoted([promotedUid], sessionId, sessionTitle);
  }

  return { success: true };
});

// ---------------------------------------------------------------------------
// removeAttendee — owner-coach or admin removes a specific player from a
// session (attendee or waitlist). Mirrors leaveSession's waitlist promotion,
// but acts on an arbitrary targetUid instead of the caller.
// ---------------------------------------------------------------------------
export const removeAttendee = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Email not verified");
  }

  const sessionId = request.data?.["sessionId"] as string | undefined;
  const targetUid = request.data?.["userId"] as string | undefined;
  if (!sessionId || !targetUid) {
    throw new HttpsError("invalid-argument", "sessionId and userId required");
  }

  const callerIsAdmin = await isAdminUid(uid);
  const sessionRef = db.collection("sessions").doc(sessionId);
  let promotedUid: string | null = null;
  let sessionTitle = "";

  await db.runTransaction(async (tx) => {
    const sessionDoc = await tx.get(sessionRef);
    if (!sessionDoc.exists)
      throw new HttpsError("not-found", "Session not found");

    const session = sessionDoc.data()!;
    // Only the owning coach or an admin may remove someone.
    if (session["coachId"] !== uid && !callerIsAdmin) {
      throw new HttpsError("permission-denied", "Not allowed");
    }

    const attendeeIds: string[] = session["attendeeIds"] ?? [];
    const waitlistIds: string[] = session["waitlistIds"] ?? [];
    const attendedIds: string[] = session["attendedIds"] ?? [];
    sessionTitle = (session["title"] as string) ?? "";

    if (attendeeIds.includes(targetUid)) {
      const next = attendeeIds.filter((x) => x !== targetUid);
      const update: Record<string, unknown> = { attendeeIds: next };
      if (waitlistIds.length > 0) {
        promotedUid = waitlistIds[0];
        if (!next.includes(promotedUid)) next.push(promotedUid);
        update["attendeeIds"] = next;
        update["waitlistIds"] = waitlistIds.slice(1);
      }
      // Drop any attendance mark for the removed player.
      if (attendedIds.includes(targetUid)) {
        update["attendedIds"] = attendedIds.filter((x) => x !== targetUid);
      }
      tx.update(sessionRef, update);
      return;
    }

    if (waitlistIds.includes(targetUid)) {
      tx.update(sessionRef, {
        waitlistIds: waitlistIds.filter((x) => x !== targetUid),
      });
      return;
    }
    // Not a member — no-op (idempotent).
  });

  if (promotedUid) {
    await notifyPromoted([promotedUid], sessionId, sessionTitle);
  }

  return { success: true };
});

// ---------------------------------------------------------------------------
// updateSessionCapacity — coach-only. Increases maxPlayers and/or
// waitlistSize (never decreases). Promotes head-of-waitlist UIDs into newly
// freed attendee spots and notifies them.
// ---------------------------------------------------------------------------
export const updateSessionCapacity = onCall(
  { region: REGION },
  async (request) => {
    const uid = request.auth?.uid;
    const sessionId = request.data?.["sessionId"] as string | undefined;
    const newMaxPlayers = request.data?.["newMaxPlayers"] as number | undefined;
    const newWaitlistSize = request.data?.["newWaitlistSize"] as
      | number
      | undefined;
    logger.info("updateSessionCapacity called", {
      uid,
      sessionId,
      newMaxPlayers,
      newWaitlistSize,
    });

    if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
    if (request.auth?.token?.email_verified !== true) {
      throw new HttpsError("permission-denied", "Email not verified");
    }
    if (!sessionId)
      throw new HttpsError("invalid-argument", "sessionId required");
    if (newMaxPlayers === undefined && newWaitlistSize === undefined) {
      throw new HttpsError("invalid-argument", "Nothing to update");
    }
    if (
      newMaxPlayers !== undefined &&
      (!Number.isInteger(newMaxPlayers) ||
        newMaxPlayers < 1 ||
        newMaxPlayers > 1000)
    ) {
      throw new HttpsError("invalid-argument", "newMaxPlayers out of range");
    }
    if (
      newWaitlistSize !== undefined &&
      (!Number.isInteger(newWaitlistSize) ||
        newWaitlistSize < 0 ||
        newWaitlistSize > 1000)
    ) {
      throw new HttpsError("invalid-argument", "newWaitlistSize out of range");
    }

    const sessionRef = db.collection("sessions").doc(sessionId);
    let promotedUids: string[] = [];
    let sessionTitle = "";

    await db.runTransaction(async (tx) => {
      const sessionDoc = await tx.get(sessionRef);
      if (!sessionDoc.exists)
        throw new HttpsError("not-found", "Session not found");

      const session = sessionDoc.data()!;
      if (session["coachId"] !== uid) {
        throw new HttpsError("permission-denied", "Not your session");
      }

      const curMax = session["maxPlayers"] as number;
      const curWaitSize = (session["waitlistSize"] ?? 0) as number;
      const attendeeIds: string[] = session["attendeeIds"] ?? [];
      const waitlistIds: string[] = session["waitlistIds"] ?? [];
      sessionTitle = (session["title"] as string) ?? "";

      if (newMaxPlayers !== undefined && newMaxPlayers < curMax) {
        throw new HttpsError(
          "failed-precondition",
          "maxPlayers cannot decrease"
        );
      }
      if (newWaitlistSize !== undefined && newWaitlistSize < curWaitSize) {
        throw new HttpsError(
          "failed-precondition",
          "waitlistSize cannot decrease"
        );
      }

      const update: Record<string, unknown> = {};
      const effectiveMax = newMaxPlayers ?? curMax;

      if (newMaxPlayers !== undefined && newMaxPlayers !== curMax) {
        update["maxPlayers"] = newMaxPlayers;
      }
      if (newWaitlistSize !== undefined && newWaitlistSize !== curWaitSize) {
        update["waitlistSize"] = newWaitlistSize;
      }

      const freeSpots = effectiveMax - attendeeIds.length;
      if (freeSpots > 0 && waitlistIds.length > 0) {
        const promoteCount = Math.min(freeSpots, waitlistIds.length);
        promotedUids = waitlistIds.slice(0, promoteCount);
        update["attendeeIds"] = [...attendeeIds, ...promotedUids];
        update["waitlistIds"] = waitlistIds.slice(promoteCount);
      }

      if (Object.keys(update).length === 0) return;
      tx.update(sessionRef, update);
    });

    if (promotedUids.length > 0) {
      await notifyPromoted(promotedUids, sessionId, sessionTitle);
    }

    logger.info("updateSessionCapacity ok", {
      sessionId,
      newMaxPlayers,
      newWaitlistSize,
      promoted: promotedUids.length,
    });
    return { success: true, promoted: promotedUids.length };
  }
);

// ---------------------------------------------------------------------------
// markAttended — transactional toggle of a user's presence at a session.
// Only the owning coach can call. attendanceCount on the user doc and
// attendedIds on the session are written together; idempotent so two
// concurrent calls for the same user produce exactly one increment.
// ---------------------------------------------------------------------------
export const markAttended = onCall({ region: REGION }, async (request) => {
  const uid = request.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "Not authenticated");
  if (request.auth?.token?.email_verified !== true) {
    throw new HttpsError("permission-denied", "Email not verified");
  }

  const sessionId = request.data?.["sessionId"] as string | undefined;
  const userId = request.data?.["userId"] as string | undefined;
  const attended = request.data?.["attended"];
  if (!sessionId || !userId || typeof attended !== "boolean") {
    throw new HttpsError(
      "invalid-argument",
      "sessionId/userId/attended required"
    );
  }

  const sessionRef = db.collection("sessions").doc(sessionId);
  const historyRef = db.collection("sessions_history").doc(sessionId);
  const userRef = db.collection("users").doc(userId);

  await db.runTransaction(async (tx) => {
    const sessionDoc = await tx.get(sessionRef);
    let ref: FirebaseFirestore.DocumentReference;
    let data: FirebaseFirestore.DocumentData;

    if (sessionDoc.exists) {
      ref = sessionRef;
      data = sessionDoc.data()!;
    } else {
      const historyDoc = await tx.get(historyRef);
      if (!historyDoc.exists)
        throw new HttpsError("not-found", "Session not found");
      ref = historyRef;
      data = historyDoc.data()!;
    }

    if (data["coachId"] !== uid) {
      throw new HttpsError("permission-denied", "Not your session");
    }

    const attendedIds: string[] = data["attendedIds"] ?? [];
    const wasAttended = attendedIds.includes(userId);
    if (attended === wasAttended) return;

    const nextAttended = attended
      ? [...attendedIds, userId]
      : attendedIds.filter((x) => x !== userId);

    tx.update(ref, { attendedIds: nextAttended });
    tx.update(userRef, {
      attendanceCount: admin.firestore.FieldValue.increment(attended ? 1 : -1),
    });
  });

  return { success: true };
});

// ---------------------------------------------------------------------------
// mirrorUserPublic — maintains users_public/{uid} with only the fields any
// verified user is allowed to know about any other user. Skips writes when
// none of the mirrored fields actually changed.
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// createRecurringSessions — runs nightly at 21:00 Jerusalem time, creates
// tomorrow's sessions from enabled recurring_sessions docs.
// ---------------------------------------------------------------------------
function getJerusalemDateParts(date: Date): { str: string; dayOfWeek: number } {
  const str = date.toLocaleDateString("en-CA", { timeZone: "Asia/Jerusalem" });
  const [y, m, d] = str.split("-").map(Number);
  const dayOfWeek = new Date(y, m - 1, d).getDay();
  return { str, dayOfWeek };
}

function jerusalemDateToUtcMs(dateStr: string, hour: number, minute: number): number {
  const formatter = new Intl.DateTimeFormat("en-US", {
    timeZone: "Asia/Jerusalem",
    hour12: false,
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
  });
  const utcGuess = new Date(`${dateStr}T${String(hour).padStart(2, "0")}:${String(minute).padStart(2, "0")}:00Z`);
  const parts = formatter.formatToParts(utcGuess);
  const get = (t: string) => parseInt(parts.find((p) => p.type === t)!.value);
  const localH = get("hour");
  const localM = get("minute");
  const diffMin = (localH * 60 + localM) - (hour * 60 + minute);
  return utcGuess.getTime() - diffMin * 60_000;
}

export const createRecurringSessions = onSchedule(
  { schedule: "every day 21:00", region: REGION, timeZone: "Asia/Jerusalem" },
  async () => {
    const tomorrow = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const { str: tomorrowStr, dayOfWeek } = getJerusalemDateParts(tomorrow);

    const snap = await db
      .collection("recurring_sessions")
      .where("enabled", "==", true)
      .where("recurrenceDays", "array-contains", dayOfWeek)
      .get();

    if (snap.empty) {
      logger.info("createRecurringSessions: no matches", { dayOfWeek, tomorrowStr });
      return;
    }

    let created = 0;
    for (const doc of snap.docs) {
      const data = doc.data();
      if (data["lastCreatedDate"] === tomorrowStr) {
        logger.info("createRecurringSessions: skipping (dedup)", { id: doc.id });
        continue;
      }

      const startMs = jerusalemDateToUtcMs(tomorrowStr, data["startHour"], data["startMinute"]);
      const endMs = jerusalemDateToUtcMs(tomorrowStr, data["endHour"], data["endMinute"]);

      const sessionData = {
        title: data["title"],
        location: data["location"],
        gender: data["gender"],
        minAge: data["minAge"],
        maxAge: data["maxAge"],
        startTime: admin.firestore.Timestamp.fromMillis(startMs),
        endTime: admin.firestore.Timestamp.fromMillis(endMs),
        maxPlayers: data["maxPlayers"],
        coachId: data["coachId"],
        attendeeIds: [] as string[],
        attendedIds: [] as string[],
        waitlistSize: data["waitlistSize"] ?? 0,
        waitlistIds: [] as string[],
        notified: false,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        designIndex: Math.floor(Math.random() * 4),
      };

      try {
        // Atomic dedup: re-check lastCreatedDate inside the transaction and
        // write the session + marker together, so a parallel run/retry can't
        // create a duplicate session for the same day.
        const didCreate = await db.runTransaction(async (tx) => {
          const fresh = await tx.get(doc.ref);
          if (fresh.data()?.["lastCreatedDate"] === tomorrowStr) return false;
          const sessionRef = db.collection("sessions").doc();
          tx.set(sessionRef, sessionData);
          tx.update(doc.ref, { lastCreatedDate: tomorrowStr });
          return true;
        });
        if (didCreate) {
          created++;
          logger.info("createRecurringSessions: created", { recurringId: doc.id, tomorrowStr });
        } else {
          logger.info("createRecurringSessions: skipping (dedup, tx)", { id: doc.id });
        }
      } catch (e) {
        logger.error("createRecurringSessions: failed", { recurringId: doc.id, error: e });
      }
    }

    logger.info("createRecurringSessions: done", { created, total: snap.size });
  }
);

const PUBLIC_KEYS = ["name", "photoUrl", "role", "gender", "attendanceCount"];

export const mirrorUserPublic = onDocumentWritten(
  { document: "users/{uid}", region: REGION },
  async (event) => {
    const uid = event.params["uid"] as string;
    const after = event.data?.after.data();
    if (!after) {
      await db
        .collection("users_public")
        .doc(uid)
        .delete()
        .catch((e) => {
          logger.warn("mirrorUserPublic: users_public delete failed", {
            uid,
            error: e,
          });
          return undefined;
        });
      return;
    }
    const before = event.data?.before.data() ?? {};
    const changed = PUBLIC_KEYS.some((k) => before[k] !== after[k]);
    if (!changed && event.data?.before.exists) return;

    await db
      .collection("users_public")
      .doc(uid)
      .set(
        {
          name: after["name"] ?? "",
          photoUrl: after["photoUrl"] ?? null,
          role: after["role"] ?? "player",
          gender: after["gender"] ?? "male",
          attendanceCount: after["attendanceCount"] ?? 0,
        },
        { merge: false }
      );
  }
);
