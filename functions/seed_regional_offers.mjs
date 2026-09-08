/**
 * Populate `regionalVariants` on multi-region discount docs so each country's
 * user sees their own price + link (model: Resource.effectiveOffer).
 *
 *   node seed_regional_offers.mjs            # DRY RUN — prints the plan, checks links, writes nothing
 *   node seed_regional_offers.mjs --live     # writes regionalVariants to the listed docs
 *
 * Variants are keyed by the live Firestore doc id (from _probe_brands). Each
 * variant overrides discountText and/or url for its countries; empty fields
 * fall back to the resource-level defaults at read time.
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const LIVE = process.argv.includes("--live");

// doc id → { note, variants: [{countries, discountText?, url?}] }
const PLAN = {
  "seed-disc-001-spotify-spotify-premium-student": {
    note: "Spotify Premium Student",
    variants: [
      { countries: ["United States"], discountText: "$5.99/mo", url: "https://www.spotify.com/us/student/" },
      { countries: ["India"], discountText: "₹59/mo", url: "https://www.spotify.com/in-en/student/" },
      { countries: ["United Kingdom"], discountText: "£5.99/mo", url: "https://www.spotify.com/uk/student/" },
    ],
  },
  "seed-disc-100-youtube-youtube-premium": {
    note: "YouTube Premium (single URL, geo-priced)",
    variants: [
      { countries: ["United States"], discountText: "$7.99/mo" },
      { countries: ["India"], discountText: "₹79/mo" },
      { countries: ["United Kingdom"], discountText: "£6.99/mo" },
    ],
  },
  "seed-disc-007-amazon-amazon-prime-student": {
    note: "Amazon Prime Student",
    variants: [
      { countries: ["United States"], discountText: "6 mo. free, then 50% off", url: "https://www.amazon.com/student" },
      { countries: ["United Kingdom"], discountText: "6 mo. free, then 50% off", url: "https://www.amazon.co.uk/prime-student" },
    ],
  },
  "seed-disc-010-nike-nike-student-discount": {
    note: "Nike Student Discount (10% both regions; link differs)",
    variants: [
      { countries: ["United States"], url: "https://www.nike.com/help/a/student-discount" },
      { countries: ["United Kingdom"], url: "https://www.nike.com/gb/help/a/student-discount" },
    ],
  },
  "seed-disc-016-adidas-adidas": {
    note: "Adidas (15% both regions; link differs)",
    variants: [
      { countries: ["United States"], url: "https://www.adidas.com/us/student-discount" },
      { countries: ["United Kingdom"], url: "https://www.adidas.co.uk/student-discount" },
    ],
  },
  "seed-disc-008-adobe-adobe-creative-suite": {
    note: "Adobe Creative Cloud Students",
    variants: [
      { countries: ["United States"], discountText: "60% off", url: "https://www.adobe.com/creativecloud/buy/students.html" },
      { countries: ["India"], discountText: "65% off", url: "https://www.adobe.com/in/creativecloud/buy/students.html" },
      { countries: ["United Kingdom"], discountText: "65% off", url: "https://www.adobe.com/uk/creativecloud/buy/students.html" },
    ],
  },
  "seed-disc-104-apple-apple-music": {
    note: "Apple Music Student",
    variants: [
      { countries: ["United States"], discountText: "$5.99/mo", url: "https://www.apple.com/apple-music/" },
      { countries: ["India"], discountText: "₹59/mo", url: "https://www.apple.com/in/apple-music/" },
      { countries: ["United Kingdom"], discountText: "£5.99/mo", url: "https://www.apple.com/uk/apple-music/" },
    ],
  },
};

const DEAD_STATUS = new Set([404, 410, 522, 523, 525, 530]);
async function checkUrl(url) {
  if (!url) return { skip: true };
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 12000);
  try {
    const res = await fetch(url, { method: "GET", redirect: "follow", signal: ac.signal,
      headers: { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/124.0 Safari/537.36" } });
    return { status: res.status, dead: DEAD_STATUS.has(res.status) };
  } catch (e) {
    const timedOut = String(e.name || e).includes("Abort");
    return { status: 0, dead: !timedOut, timedOut };
  } finally { clearTimeout(t); }
}

const sa = JSON.parse(readFileSync(resolve(__dirname, "serviceAccount.json"), "utf8"));
const { initializeApp, cert } = await import("firebase-admin/app");
const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const col = db.collection("resources");

console.log(`Project: ${sa.project_id}   Mode: ${LIVE ? "LIVE WRITE" : "DRY RUN"}\n`);

let writes = 0;
let batch = db.batch();
for (const [id, cfg] of Object.entries(PLAN)) {
  const doc = await col.doc(id).get();
  if (!doc.exists) { console.log(`⚠ MISSING doc: ${id} (${cfg.note}) — skipped\n`); continue; }
  const d = doc.data();
  console.log(`● ${cfg.note}  [${id}]`);
  console.log(`   default: "${d.discountText}" → ${d.applicationUrl}`);
  for (const v of cfg.variants) {
    const chk = await checkUrl(v.url);
    const linkNote = v.url ? (chk.dead ? `DEAD(${chk.status})` : `ok(${chk.status || (chk.timedOut ? "timeout" : "?")})`) : "(price-only, uses default link)";
    console.log(`     ${v.countries.join("/")}: "${v.discountText ?? "(default price)"}"  ${v.url ?? ""}  ${linkNote}`);
    if (v.url && chk.dead) {
      console.log(`       ↳ dropping dead link; variant will fall back to default url`);
      delete v.url;
    }
  }
  if (LIVE) {
    batch.set(col.doc(id), { regionalVariants: cfg.variants, updatedAt: FieldValue.serverTimestamp(), updatedBy: "regional-offers-script" }, { merge: true });
    writes++;
  }
  console.log("");
}

if (LIVE) {
  await batch.commit();
  console.log(`✓ Wrote regionalVariants to ${writes} discounts.`);
} else {
  console.log("DRY RUN — nothing written. Re-run with --live to apply.");
}
process.exit(0);
