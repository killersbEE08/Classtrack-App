/**
 * Backfill real brand favicons/logos on `resources`.
 *
 * Clearbit's logo API is dead, so we use Google's favicon service
 * (https://www.google.com/s2/favicons?domain=<d>&sz=128), which returns the
 * site's ACTUAL favicon. We only replace the stored logoUrl when it's not a
 * real brand image already:
 *   - missing, OR an SVG (app can't render), OR a dead Clearbit URL, OR
 *   - a GENERIC icons8 icon whose filename doesn't mention the brand.
 * Brand-specific stored logos are kept. If Google has no real favicon for the
 * domain (it returns a default globe), we KEEP the existing logo as-is.
 *
 *   node backfill_logos.mjs            # DRY RUN
 *   node backfill_logos.mjs --live     # apply
 *   node backfill_logos.mjs --discounts-only
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const LIVE = process.argv.includes("--live");
const DISCOUNTS_ONLY = process.argv.includes("--discounts-only");

const MULTI_TLD = new Set([
  "co.uk", "org.uk", "ac.uk", "co.in", "com.au", "co.nz", "com.br", "co.jp",
]);
function rootDomain(host) {
  const h = host.toLowerCase().replace(/^www\./, "");
  const parts = h.split(".");
  if (parts.length <= 2) return h;
  const last2 = parts.slice(-2).join(".");
  const last3 = parts.slice(-3).join(".");
  return MULTI_TLD.has(last2) ? last3 : last2;
}
function domainOf(r) {
  for (const raw of [r.officialWebsite, r.applicationUrl, r.affiliateUrl]) {
    const s = (raw || "").trim();
    if (!s) continue;
    try {
      const host = new URL(s).host;
      if (host && host.includes(".")) return rootDomain(host);
    } catch {/* skip */}
  }
  return null;
}

const norm = (s) => (s || "").toLowerCase();
const isSvg = (url) =>
  norm(url).split("?")[0].split("#")[0].endsWith(".svg");
function isGenericIcon(url, brand, domain) {
  const u = norm(url);
  if (!u.includes("icons8.com")) return false;
  const name = u.split("/").pop().split(".")[0];
  const tokens = new Set(
    `${brand} ${domain ? domain.split(".")[0] : ""}`
      .toLowerCase().split(/[^a-z0-9]+/).filter((t) => t.length >= 3)
  );
  for (const t of tokens) if (name.includes(t)) return false;
  return true;
}

const faviconUrl = (domain) =>
  `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;

async function faviconBytes(domain) {
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 12000);
  try {
    const res = await fetch(faviconUrl(domain), { redirect: "follow", signal: ac.signal });
    if (!res.ok) return null;
    const ct = res.headers.get("content-type") || "";
    if (!ct.startsWith("image/")) return null;
    return Buffer.from(await res.arrayBuffer());
  } catch {
    return null;
  } finally {
    clearTimeout(t);
  }
}

async function mapPool(items, size, fn) {
  const out = new Array(items.length);
  let i = 0;
  const worker = async () => {
    while (i < items.length) { const idx = i++; out[idx] = await fn(items[idx], idx); }
  };
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, worker));
  return out;
}

const sa = JSON.parse(readFileSync(resolve(__dirname, "serviceAccount.json"), "utf8"));
const { initializeApp, cert } = await import("firebase-admin/app");
const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const col = db.collection("resources");

console.log(`Project: ${sa.project_id}   Mode: ${LIVE ? "LIVE WRITE" : "DRY RUN"}${DISCOUNTS_ONLY ? " (discounts only)" : ""}\n`);

// Baseline "no favicon" globe images for a couple of bogus domains, so we can
// recognise (and skip) domains Google has no real icon for.
const baselines = [];
for (const bogus of ["no-such-brand-zzq123.com", "definitely-not-real-9x8y7.io"]) {
  const b = await faviconBytes(bogus);
  if (b) baselines.push(b);
}
const isDefaultGlobe = (buf) =>
  buf != null && baselines.some((b) => b.length === buf.length && b.equals(buf));
console.log(`Loaded ${baselines.length} default-globe baseline(s) (sizes: ${baselines.map((b) => b.length).join(", ")}).\n`);

const snap = await col.get();
const all = [];
snap.forEach((d) => all.push({ id: d.id, ...d.data() }));

const candidates = [];
for (const r of all) {
  if (DISCOUNTS_ONLY && r.type !== "discount") continue;
  const domain = domainOf(r);
  if (!domain) continue;
  const brand = r.company || r.organization || r.title || "";
  const logo = (r.logoUrl || "").trim();
  const replaceable =
    !logo || isSvg(logo) || norm(logo).includes("clearbit.com") ||
    isGenericIcon(logo, brand, domain);
  if (!replaceable) continue;
  candidates.push({ r, domain, brand });
}

console.log(`Scanned ${all.length} resources; ${candidates.length} have a replaceable logo (missing/svg/dead-clearbit/generic) with a domain.`);
console.log(`Fetching favicons…`);
const bytes = await mapPool(candidates, 10, (c) => faviconBytes(c.domain));

const toUpdate = [];
const kept = [];
candidates.forEach((c, i) => {
  const b = bytes[i];
  if (b && !isDefaultGlobe(b)) toUpdate.push(c);
  else kept.push(c);
});

console.log(`\n── PLAN ──`);
console.log(`Will set real favicon/logo : ${toUpdate.length}`);
console.log(`Kept as-is (no real favicon found) : ${kept.length}`);
console.log(`\nExamples to update:`);
for (const c of toUpdate.slice(0, 40)) {
  console.log(`  ${c.brand} [${c.r.type}] ${c.domain}`);
}
if (toUpdate.length > 40) console.log(`  … and ${toUpdate.length - 40} more`);
if (kept.length) {
  console.log(`\nKept (examples):`);
  for (const c of kept.slice(0, 15)) console.log(`  ${c.brand} [${c.domain}] — ${c.r.logoUrl || "(none)"}`);
}

if (LIVE) {
  let n = 0, batch = db.batch();
  for (const c of toUpdate) {
    batch.set(col.doc(c.r.id), {
      logoUrl: faviconUrl(c.domain),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: "logo-backfill",
    }, { merge: true });
    if (++n % 400 === 0) { await batch.commit(); batch = db.batch(); console.log(`  committed ${n}…`); }
  }
  await batch.commit();
  console.log(`\n✓ Updated logoUrl on ${n} resources.`);
} else {
  console.log(`\nDRY RUN — nothing written. Re-run with --live to apply.`);
}
process.exit(0);
