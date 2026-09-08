/**
 * Backfill `affiliateUrl` from `applicationUrl` on discount docs.
 *
 * The discount CMS editor shows the "Deal / redemption link" field bound to
 * affiliateUrl (applicationUrl is only shown for non-discount opportunities).
 * The publish/repair scripts stored links in applicationUrl, so the editor
 * field looked empty. Copying it across makes the link visible + editable in
 * the CMS. App behaviour is unchanged (detail screen opens affiliateUrl ??
 * applicationUrl).
 *
 *   node backfill_affiliate_url.mjs          # DRY RUN
 *   node backfill_affiliate_url.mjs --live   # write
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
const __dirname = dirname(fileURLToPath(import.meta.url));
const LIVE = process.argv.includes("--live");

const sa = JSON.parse(readFileSync(resolve(__dirname, "serviceAccount.json"), "utf8"));
const { initializeApp, cert } = await import("firebase-admin/app");
const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const col = db.collection("resources");

console.log(`Project: ${sa.project_id}   Mode: ${LIVE ? "LIVE WRITE" : "DRY RUN"}\n`);

const snap = await col.where("type", "==", "discount").get();
const todo = [];
snap.forEach((d) => {
  const r = d.data();
  const app = (r.applicationUrl || "").trim();
  const aff = (r.affiliateUrl || "").trim();
  if (app && !aff) todo.push({ id: d.id, company: r.company || r.organization, url: app });
});

console.log(`Discounts to backfill (affiliateUrl := applicationUrl): ${todo.length}`);
for (const t of todo.slice(0, 10)) console.log(`  ${t.company}: ${t.url}`);
if (todo.length > 10) console.log(`  … and ${todo.length - 10} more`);

if (LIVE) {
  let n = 0, batch = db.batch();
  for (const t of todo) {
    batch.set(col.doc(t.id), { affiliateUrl: t.url, updatedAt: FieldValue.serverTimestamp(), updatedBy: "affiliate-backfill" }, { merge: true });
    if (++n % 400 === 0) { await batch.commit(); batch = db.batch(); }
  }
  await batch.commit();
  console.log(`\n✓ Backfilled affiliateUrl on ${n} discounts.`);
} else {
  console.log("\nDRY RUN — nothing written. Re-run with --live to apply.");
}
process.exit(0);
