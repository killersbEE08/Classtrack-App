/**
 * Revoke ClassTrack Pro entitlements (server-trusted `_entitlements/{uid}`).
 *
 * Use this to clean up Pro that was granted by SANDBOX/TEST purchases or by the
 * "second account on the same Google Play account" transfer bug. It flips
 * `pro` to false (leaving any referral `proUntil` gift intact unless --hard),
 * and can optionally drop the matching `_subscriptionOwners` record so the
 * purchase can be re-attributed to its rightful owner later.
 *
 * Auth: needs ./serviceAccount.json (same file setAdmin.mjs / seed_resources.mjs use).
 *
 * SAFE BY DEFAULT: prints what it WOULD do and writes nothing until you add
 * --commit.
 *
 * Usage:
 *   # Review every account currently marked Pro (uid, lastEvent, updatedAt):
 *   node revokeEntitlements.mjs --list
 *
 *   # Revoke specific users (comma-separated UIDs). Dry-run first:
 *   node revokeEntitlements.mjs --uids uidA,uidB
 *   node revokeEntitlements.mjs --uids uidA,uidB --commit
 *
 *   # Revoke every account marked pro:true (NUCLEAR — real payers re-unlock
 *   # only on their next RevenueCat webhook event). Requires --commit:
 *   node revokeEntitlements.mjs --all --commit
 *
 * Flags:
 *   --list            List all pro:true docs and exit (no writes).
 *   --uids a,b,c      Revoke these specific UIDs.
 *   --all             Revoke every doc where pro === true.
 *   --hard            Delete the whole `_entitlements/{uid}` doc (also removes a
 *                     referral `proUntil` gift) instead of just setting pro:false.
 *   --clear-until     Also delete a lingering `proUntil` ("lifetime"/gift) while
 *                     keeping the rest of the doc (soft mode only).
 *   --purge-owner     Also delete `_subscriptionOwners` docs owned by revoked UIDs.
 *   --commit          Actually write. Without it, this is a dry run.
 */

import { initializeApp, cert } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { readFileSync } from "node:fs";

const args = process.argv.slice(2);
const has = (f) => args.includes(f);
const val = (f) => {
  const i = args.indexOf(f);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
};

const LIST = has("--list");
const ALL = has("--all");
const HARD = has("--hard");
const CLEAR_UNTIL = has("--clear-until");
const PURGE_OWNER = has("--purge-owner");
const COMMIT = has("--commit");
const UIDS = (val("--uids") || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const sa = JSON.parse(readFileSync("./serviceAccount.json", "utf8"));
initializeApp({ credential: cert(sa) });
const db = getFirestore();

function proActive(data) {
  if (!data) return false;
  if (data.pro === true) return true;
  const until = data.proUntil;
  if (!until) return false;
  const ms =
    typeof until === "number"
      ? until
      : typeof until.toMillis === "function"
      ? until.toMillis()
      : 0;
  return ms > Date.now();
}

// ── --list: show everyone currently Pro, then exit ─────────────────────────
if (LIST) {
  const snap = await db.collection("_entitlements").get();
  const rows = [];
  snap.forEach((doc) => {
    const d = doc.data() || {};
    if (proActive(d)) {
      rows.push({
        uid: doc.id,
        pro: d.pro === true,
        proUntil: d.proUntil
          ? new Date(
              typeof d.proUntil === "number" ? d.proUntil : d.proUntil.toMillis()
            ).toISOString()
          : null,
        lastEvent: d.lastEvent || null,
        updatedAt: d.updatedAt
          ? new Date(d.updatedAt).toISOString()
          : null,
      });
    }
  });
  console.log(`Pro accounts: ${rows.length}`);
  console.table(rows);
  process.exit(0);
}

// ── Determine the target UIDs ──────────────────────────────────────────────
let targets = [];
if (ALL) {
  const snap = await db.collection("_entitlements").where("pro", "==", true).get();
  targets = snap.docs.map((d) => d.id);
} else if (UIDS.length) {
  targets = UIDS;
} else {
  console.error(
    "Nothing to do. Pass --list, --uids a,b,c, or --all. Add --commit to write."
  );
  process.exit(1);
}

if (targets.length === 0) {
  console.log("No matching Pro accounts found.");
  process.exit(0);
}

console.log(
  `${COMMIT ? "REVOKING" : "[dry-run] would revoke"} Pro for ${targets.length} account(s):`
);
targets.forEach((u) => console.log("  -", u));
console.log(
  HARD ? "Mode: HARD (delete entitlement doc)" : "Mode: soft (set pro:false)"
);
if (CLEAR_UNTIL && !HARD) console.log("Also clearing proUntil (lifetime/gift).");
if (PURGE_OWNER) console.log("Also purging _subscriptionOwners for these UIDs.");

if (!COMMIT) {
  console.log("\nDry run only — re-run with --commit to apply.");
  process.exit(0);
}

// ── Apply ──────────────────────────────────────────────────────────────────
let done = 0;
for (const uid of targets) {
  const ref = db.collection("_entitlements").doc(uid);
  if (HARD) {
    await ref.delete();
  } else {
    const patch = { pro: false, updatedAt: Date.now(), lastEvent: "ADMIN_REVOKE" };
    // A "lifetime" that survives setting pro:false is a far-future `proUntil`
    // (a time-boxed gift, or a test grant). --clear-until removes it too while
    // keeping the rest of the doc.
    if (CLEAR_UNTIL) patch.proUntil = FieldValue.delete();
    await ref.set(patch, { merge: true });
  }
  done++;
}

if (PURGE_OWNER) {
  const owners = await db.collection("_subscriptionOwners").get();
  const batch = db.batch();
  let n = 0;
  owners.forEach((doc) => {
    if (targets.includes((doc.data() || {}).ownerUid)) {
      batch.delete(doc.ref);
      n++;
    }
  });
  if (n) await batch.commit();
  console.log(`Purged ${n} ownership record(s).`);
}

console.log(`\u2713 Revoked Pro for ${done} account(s).`);
process.exit(0);
