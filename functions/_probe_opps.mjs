import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
const __dirname = dirname(fileURLToPath(import.meta.url));
const { initializeApp, cert } = await import("firebase-admin/app");
const { getFirestore } = await import("firebase-admin/firestore");
const sa = JSON.parse(readFileSync(resolve(__dirname, "serviceAccount.json"), "utf8"));
initializeApp({ credential: cert(sa) });
const db = getFirestore();
const now = new Date();
const snap = await db.collection("resources").get();
const opps = [];
const byStatus = {};
snap.forEach((d) => {
  const r = d.data();
  if (r.type === "discount") return;
  byStatus[r.status] = (byStatus[r.status] || 0) + 1;
  const dl = r.deadline?.toDate ? r.deadline.toDate() : null;
  opps.push({
    id: d.id, type: r.type, status: r.status, title: r.title,
    org: r.organization,
    deadline: dl ? dl.toISOString().slice(0, 10) : null,
    expired: dl ? dl < now : false,
    countries: (r.countries || []).join("/") || "(global)",
    link: r.applicationUrl || r.affiliateUrl || null,
    hasBenefits: !!(r.benefits && r.benefits.trim()),
    hasHowTo: !!(r.howToApply && r.howToApply.trim()),
    priority: r.priority ?? 0,
  });
});
opps.sort((a, b) => (a.status + a.type).localeCompare(b.status + b.type));
console.log("Non-discount resources by status:", JSON.stringify(byStatus));
console.log(`Total non-discount: ${opps.length}\n`);
const drafts = opps.filter((o) => o.status === "draft");
console.log(`DRAFT opportunities: ${drafts.length}`);
for (const o of drafts) {
  console.log(`  [${o.type}] ${o.title} | org=${o.org} | deadline=${o.deadline}${o.expired ? " (EXPIRED)" : ""} | ${o.countries} | link=${o.link ? "yes" : "MISSING"} | benefits=${o.hasBenefits} howTo=${o.hasHowTo}`);
}
console.log(`\nAlready-visible (active/opening_soon) non-discounts:`);
for (const o of opps.filter((o) => o.status === "active" || o.status === "opening_soon")) {
  console.log(`  [${o.type}] ${o.title} | ${o.status} | deadline=${o.deadline}${o.expired ? " (EXPIRED)" : ""} | prio=${o.priority}`);
}
process.exit(0);
