/**
 * Publish draft student discounts in the `resources` collection.
 *
 * Enforces the requirements:
 *   - dedupe (within drafts AND against already-published discounts)
 *   - every published discount must have a renderable (non-SVG) image
 *   - link must resolve AND point to a real student/offer page (not a bare
 *     homepage) — otherwise it is skipped
 *   - country targeting applied (curated map + ccTLD inference)
 *
 * Modes:
 *   node publish_discounts.mjs            # DRY RUN (reads live DB + checks URLs, writes nothing)
 *   node publish_discounts.mjs --live     # applies fixes + sets status=active
 *
 * Options:
 *   --limit <n>     only process first n draft discounts (for a quick test)
 *   --no-http       skip live URL checks (classify from the stored URL only)
 */

import { readFileSync, writeFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

const LIVE = process.argv.includes("--live");
const NO_HTTP = process.argv.includes("--no-http");
const argValue = (name, fb) => {
  const i = process.argv.indexOf(name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fb;
};
const LIMIT = parseInt(argValue("--limit", "0"), 10) || 0;

// ── Curated fixups (from seed_resources.mjs) ─────────────────────────────────
const LOGO_FIX = {
  "Apple Education": "https://logo.clearbit.com/apple.com",
  "GitHub Student Developer Pack": "https://img.icons8.com/fluency/96/github.png",
  "Adobe Creative Suite": "https://img.icons8.com/color/96/adobe-creative-cloud.png",
  "Udemy": "https://img.icons8.com/color/96/udemy.png",
  "Nike Student Discount": "https://img.icons8.com/ios-filled/100/nike.png",
  "Microsoft 365 for Students": "https://img.icons8.com/color/96/microsoft.png",
  "Delta Airlines": "https://logo.clearbit.com/delta.com",
  "Skillshare": "https://logo.clearbit.com/skillshare.com",
  "Adidas": "https://img.icons8.com/color/96/adidas.png",
  "HP Store": "https://img.icons8.com/color/96/hp.png",
  "Gemini Pro for Students": "https://logo.clearbit.com/google.com",
  "Unreal Engine Academic Access": "https://img.icons8.com/color/96/unreal-engine.png",
  "Coursera": "https://logo.clearbit.com/coursera.org",
};

const COUNTRY_FIX = {
  "Air India": ["India"], "IndiGo": ["India"], "Swiggy": ["India"],
  "Magic Pin": ["India"], "Realme": ["India"], "Vivo": ["India"],
  "Oppo": ["India"], "OnePlus": ["India"],
  "Voxi UK Student eSIM": ["United Kingdom"],
  "National Express": ["United Kingdom"],
  "The Escape Game": ["United Kingdom"],
  "Hulu": ["United States"], "Peacock": ["United States"],
  "Paramount+": ["United States"], "Regal Cinemas": ["United States"],
  "AMC Theatres": ["United States"], "DoorDash": ["United States"],
  "Chick-fil-A": ["United States"], "Amtrak": ["United States"],
  "Zipcar": ["United States"], "EveryPlate": ["United States"],
  "Blue Apron": ["United States"],
  "Nintendo Switch Online via Prime Student": ["United States"],
  "Razer Student Discount (US)": ["United States"],
  "Dell Education Discount": ["United States"],
  "Samsung Student Store (US)": ["United States"],
  "B&H Photo Video EDU Account": ["United States"],
  "Fujifilm US Student Discount": ["United States"],
};

// ── Repaired links (researched real student/education pages), keyed by title ──
// Each is re-verified at runtime: applied only if it is alive AND classifies as
// an official student/edu page. Dead or non-official candidates are auto-dropped.
const URL_FIX = {
  "Uber Eats": "https://www.uber.com/uber-one/student/",
  "ChatGPT Plus for Students": "https://chatgpt.com/students/2026/",
  "Voxi UK Student eSIM": "https://www.voxi.co.uk/acquisition/students",
  "Typeless for Students": "https://www.typeless.com/students",
  "Kiro AI Code Editor for Students": "https://kiro.dev/students/",
  "V0 by Vercel for Students": "https://v0.app/students",
  "Dify Education Plan": "https://dify.ai/education",
  "Notta AI Transcription": "https://www.notta.ai/education-plan",
  "Udio Student Plan": "https://help.udio.com/en/articles/10739207-obtaining-a-student-discount-on-your-subscription",
  "Manus AI Agent for Students": "https://manus.im/edu",
  "RaiDrive for Students": "https://www.raidrive.com/together/education",
  "Shodan for Academics": "https://help.shodan.io/the-basics/academic-upgrade",
  "Zed for Students": "https://zed.dev/education",
  "Tower Git Client for Students": "https://www.git-tower.com/students",
  "Navicat for Students": "https://navicat.com/sponsorship/education/student",
  "Divisare for Students": "https://divisare.com/subscriptions",
  "CST Studio Suite Student Edition": "https://www.3ds.com/edu/education/students/solutions/cst-le",
  "Altium Designer Student License": "https://www.altium.com/education/students",
  "DBeaver Pro for Students": "https://dbeaver.com/academic-license/",
  "Cargo.Site for Students": "https://cargo.site/students",
  "ANSYS Simulation for Students": "https://www.ansys.com/academic/students",
  "OriginLab for Students": "https://www.originlab.com/index.aspx?go=Products/OriginStudentVersion",
  "Mobbin Student Pro": "https://help.mobbin.com/en/articles/693312",
  "Qt for Students": "https://www.qt.io/development/qt-educational-license",
  "Proton Unlimited for Students": "https://proton.me/student",
  "LastPass for Education": "https://www.lastpass.com/solutions/education",
  "Obsidian for Students": "https://obsidian.md/help/discounts",
  "Think-Cell for Students": "https://www.think-cell.com/en/academics/free-think-cell-student-license",
  "iLovePDF for Students": "https://www.ilovepdf.com/education",
  "RoboForm for Students": "https://www.roboform.com/promotions/college",
  "Mathpix for Students": "https://mathpix.com/docs/snip/educational-plan",
  "Otter.ai for Students": "https://help.otter.ai/hc/en-us/articles/4402467517847-Student-Teacher-discount-program-for-the-Pro-plan",
  "Glossika Language Learning": "https://ai.glossika.com/student-plan",
  "HGMD Academic Access": "https://www.hgmd.cf.ac.uk/ac/introduction.php",
  "Kanopy via Library": "https://lib.kanopy.com/",
  "B&H Photo Video EDU Account": "https://www.bhphotovideo.com/a/pages/edu",
  "MarginNote 3 for Students": "https://forum.marginnote.com/t/40-off-edu-code-for-marginnote-3-application-guide/239",
  "Capture One Pro Student Discount": "https://www.captureone.com/en/education/capture-one-for-students",
  "Setapp for Students": "https://app.setapp.com/educational-discount",
  "Curiosity AI": "https://docs.curiosity.ai/app/settings/account/how-to-get-a-studenteducator-discount",
  "Airtable": "https://support.airtable.com/articles/4920135568-applying-for-non-profit-education-and-student-airtable-plans",
  "Puma": "https://uk.puma.com/uk/en/student-discount",
  "Wispr Flow for Students": "https://wisprflow.ai/students",
  "ChemDraw Student License": "https://support.revvitysignals.com/hc/en-us/articles/39632645717396-How-to-get-started-with-ChemDraw-as-a-University-Student",
  "Razer Student Discount (US)": "https://www.razer.com/education",
  "UNiDAYS Student Discounts": "https://www.myunidays.com/US/en-US/content/register",
  "Focusee Education Discount": "https://focusee.imobie.com/education-discount.htm",
};

// Weak links the user asked to drop (generic upgrade/overview pages), and a
// same-destination duplicate of an already-publishing Unreal entry.
const EXCLUDE_TITLES = new Set([
  "Quizlet", "Intel", "Pandora", "Unreal Engine for Students",
  "Blue Apron", "SmartGit for Students",
]);

// ── Helpers ──────────────────────────────────────────────────────────────────
const norm = (s) => (s || "").toLowerCase().normalize("NFKD").replace(/[^a-z0-9]+/g, "");
const dedupeKey = (r) => `${norm(r.organization || r.company)}|${norm(r.title)}`;

function isRenderableImage(url) {
  if (!url || typeof url !== "string") return false;
  const u = url.trim().toLowerCase();
  if (!/^https?:\/\//.test(u)) return false;
  const path = u.split("?")[0].split("#")[0];
  if (path.endsWith(".svg")) return false; // Flutter Image.network can't render SVG
  return true;
}

function hostOf(url) {
  try { return new URL(url).host.toLowerCase(); } catch { return ""; }
}
function domainFor(url) {
  const h = hostOf(url).replace(/^www\./, "");
  return h;
}

// Words in a URL that indicate a genuine student/offer page.
const STUDENT_HINTS = [
  "student", "students", "education", "edu", "academic", "campus",
  "university", "unidays", "studentbeans", "github-student", "githubstudent",
  "discount", "edu-offer", "classroom", "learners",
];

// Status codes that mean the *specific page* is genuinely gone/dead.
const DEAD_STATUS = new Set([404, 410, 451, 522, 523, 525, 530]);

// Classify the STORED url (what the app opens for the student), combined with a
// liveness signal. Bot-blocks (403/429/503/timeout) are NOT treated as dead —
// they mean the host answered but refused our datacenter request.
function classifyUrl(storedUrl, check) {
  if (!storedUrl) return { verdict: "broken", reason: "no link" };
  let u;
  try { u = new URL(storedUrl); } catch { return { verdict: "broken", reason: "invalid URL" }; }

  // Liveness
  if (check.dnsFail) return { verdict: "broken", reason: "DNS/connection failure" };
  if (check.status && DEAD_STATUS.has(check.status)) {
    return { verdict: "broken", reason: `HTTP ${check.status} (page gone)` };
  }
  const blocked = check.status === 403 || check.status === 429 || check.status === 503 || check.timedOut;

  const full = storedUrl.toLowerCase();
  const bareHome = (u.pathname === "/" || u.pathname === "");
  const hasHint = STUDENT_HINTS.some((k) => full.includes(k));

  if (bareHome && !hasHint) return { verdict: "homepage", reason: "bare homepage — not the offer page" };
  if (hasHint) {
    return blocked
      ? { verdict: "official", reason: `student/edu page (host bot-protected, HTTP ${check.status || "timeout"})` }
      : { verdict: "official", reason: "student/edu page" };
  }
  return { verdict: "review", reason: blocked ? `path present, no student keyword (bot-protected)` : "path present, no student keyword" };
}

// Fetch with redirect-follow + timeout. Distinguishes dead (DNS/conn fail) from
// bot-blocked (host answered with 4xx/5xx).
async function checkUrl(url) {
  if (!url) return { ok: false, status: 0, finalUrl: "", dnsFail: true };
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 15000);
  // Realistic browser headers to reduce (not eliminate) bot-walls.
  const headers = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
    "Accept-Language": "en-US,en;q=0.9",
  };
  try {
    let res;
    try {
      res = await fetch(url, { method: "GET", redirect: "follow", signal: ac.signal, headers });
    } catch (e) {
      const name = String(e.name || e);
      const timedOut = name.includes("Abort");
      // Abort = slow/likely-protected host; otherwise DNS/connection failure.
      return { ok: false, status: 0, finalUrl: url, dnsFail: !timedOut, timedOut };
    }
    return { ok: res.ok, status: res.status, finalUrl: res.url || url };
  } finally {
    clearTimeout(t);
  }
}

async function mapPool(items, size, fn) {
  const out = new Array(items.length);
  let i = 0;
  async function worker() {
    while (i < items.length) {
      const idx = i++;
      out[idx] = await fn(items[idx], idx);
    }
  }
  await Promise.all(Array.from({ length: Math.min(size, items.length) }, worker));
  return out;
}

// ── Firebase ─────────────────────────────────────────────────────────────────
async function initDb() {
  const { initializeApp, cert } = await import("firebase-admin/app");
  const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
  const sa = JSON.parse(readFileSync(resolve(__dirname, "serviceAccount.json"), "utf8"));
  initializeApp({ credential: cert(sa) });
  return { db: getFirestore(), FieldValue, projectId: sa.project_id };
}

// ── Main ─────────────────────────────────────────────────────────────────────
const { db, FieldValue, projectId } = await initDb();
console.log(`Project: ${projectId}   Mode: ${LIVE ? "LIVE WRITE" : "DRY RUN"}${NO_HTTP ? " (no-http)" : ""}\n`);

const col = db.collection("resources");
const snap = await col.where("type", "==", "discount").get();

const published = []; // active / opening_soon / etc (visible)
let drafts = [];
snap.forEach((d) => {
  const r = { id: d.id, ...d.data() };
  if (r.status === "draft") drafts.push(r);
  else if (r.status !== "hidden" && r.status !== "archived") published.push(r);
});
drafts.sort((a, b) => (a.id < b.id ? -1 : 1));
if (LIMIT > 0) drafts = drafts.slice(0, LIMIT);

console.log(`Draft discounts: ${drafts.length}   Already-published discounts: ${published.length}\n`);

// Dedupe sets
const publishedKeys = new Set(published.map(dedupeKey));
const seenDraftKeys = new Set();

// Resolve image + country decisions first (no network).
for (const r of drafts) {
  // repaired link (researched student/edu page) — re-verified below
  if (URL_FIX[r.title]) { r.applicationUrl = URL_FIX[r.title]; r._repaired = true; }

  // image
  let img = r.imageUrl && isRenderableImage(r.imageUrl) ? r.imageUrl
          : (r.logoUrl && isRenderableImage(r.logoUrl) ? r.logoUrl : null);
  let imgSource = img ? "existing" : null;
  if (!img && LOGO_FIX[r.title]) { img = LOGO_FIX[r.title]; imgSource = "logo_fix"; }
  if (!img) {
    const dom = domainFor(r.applicationUrl || r.affiliateUrl || "");
    if (dom) { img = `https://logo.clearbit.com/${dom}`; imgSource = "clearbit_guess"; }
  }
  r._image = img; r._imageSource = imgSource;

  // country
  let countries = Array.isArray(r.countries) && r.countries.length ? r.countries : null;
  let cSource = countries ? "existing" : null;
  if (!countries && COUNTRY_FIX[r.title]) { countries = COUNTRY_FIX[r.title]; cSource = "country_fix"; }
  if (!countries) {
    const h = hostOf(r.applicationUrl || "");
    if (h.endsWith(".co.uk")) { countries = ["United Kingdom"]; cSource = "cctld"; }
  }
  r._countries = countries || []; r._countrySource = cSource || "global";
}

// Link checks (network) unless --no-http
const linkTargets = drafts.map((r) => r.applicationUrl || r.affiliateUrl || "");
let linkResults;
if (NO_HTTP) {
  linkResults = linkTargets.map((u) => ({ ok: !!u, status: 0, finalUrl: u }));
} else {
  process.stdout.write(`Checking ${drafts.length} links…`);
  linkResults = await mapPool(linkTargets, 12, (u) => checkUrl(u));
  process.stdout.write(" done\n\n");
}

// Decide each draft
const seenUrls = new Set(published.map((p) => norm(p.applicationUrl || p.affiliateUrl)));
const decisions = drafts.map((r, i) => {
  const link = linkResults[i];
  const storedUrl = r.applicationUrl || r.affiliateUrl || "";
  const cls = classifyUrl(storedUrl, link);
  const key = dedupeKey(r);
  const reasons = [];

  // explicit exclusions (weak/duplicate pages the user asked to drop)
  if (EXCLUDE_TITLES.has(r.title)) reasons.push("excluded-weak");

  // dedupe (brand+title AND destination URL)
  let dup = null;
  if (publishedKeys.has(key)) dup = "already-published";
  else if (seenDraftKeys.has(key)) dup = "duplicate-draft";
  else seenDraftKeys.add(key);
  if (dup) reasons.push(`dedupe:${dup}`);
  const uKey = norm(storedUrl);
  if (uKey) {
    if (seenUrls.has(uKey)) reasons.push("dedupe:same-url");
    else seenUrls.add(uKey);
  }

  // image
  if (!r._image) reasons.push("no-image");

  // link
  if (cls.verdict === "broken") reasons.push(`link-broken:${cls.reason}`);
  else if (cls.verdict === "homepage") reasons.push("link-homepage");
  // a REPAIRED link must positively classify as an official student/edu page
  else if (r._repaired && cls.verdict !== "official") reasons.push(`repair-unconfirmed:${cls.verdict}`);

  const willPublish = reasons.length === 0;
  return {
    id: r.id, title: r.title, brand: r.organization || r.company,
    repaired: !!r._repaired,
    link: r.applicationUrl || r.affiliateUrl || "", finalUrl: link.finalUrl,
    httpStatus: link.status, linkVerdict: cls.verdict, linkReason: cls.reason,
    image: r._image, imageSource: r._imageSource,
    countries: r._countries, countrySource: r._countrySource,
    willPublish, reasons, review: cls.verdict === "review" && willPublish,
  };
});

// ── Report ───────────────────────────────────────────────────────────────────
const willPublish = decisions.filter((d) => d.willPublish);
const skipped = decisions.filter((d) => !d.willPublish);
const reviewFlag = willPublish.filter((d) => d.review);

const countBy = (arr, f) => arr.reduce((m, x) => { const k = f(x); m[k] = (m[k] || 0) + 1; return m; }, {});

console.log("══════════════ SUMMARY ══════════════");
console.log(`Would PUBLISH : ${willPublish.length}`);
console.log(`Would SKIP    : ${skipped.length}`);
console.log(`  skip reasons:`, JSON.stringify(countBy(skipped, (d) => d.reasons[0])));
console.log(`Link verdicts :`, JSON.stringify(countBy(decisions, (d) => d.linkVerdict)));
console.log(`Image sources :`, JSON.stringify(countBy(decisions, (d) => d.imageSource || "none")));
console.log(`Country tags  :`, JSON.stringify(countBy(decisions, (d) => d.countrySource)));

const show = (title, arr) => {
  console.log(`\n── ${title} (${arr.length}) ──`);
  for (const d of arr) console.log(`  [${d.linkVerdict}] ${d.brand} — ${d.title}\n       ${d.finalUrl || d.link}  ${d.reasons.length ? "→ " + d.reasons.join(", ") : ""}`);
};

show("SKIP: broken links", skipped.filter((d) => d.reasons.some((r) => r.startsWith("link-broken"))));
show("SKIP: homepage-only links (need real student page)", skipped.filter((d) => d.reasons.includes("link-homepage")));
show("SKIP: repair attempted but not confirmed official", skipped.filter((d) => d.reasons.some((r) => r.startsWith("repair-unconfirmed"))));
show("SKIP: excluded (weak/duplicate page)", skipped.filter((d) => d.reasons.includes("excluded-weak")));
show("SKIP: no usable image", skipped.filter((d) => d.reasons.includes("no-image")));
show("SKIP: duplicates", skipped.filter((d) => d.reasons.some((r) => r.startsWith("dedupe"))));
show("PUBLISH via REPAIRED link", willPublish.filter((d) => d.repaired));
show("PUBLISH but REVIEW link (path present, no student keyword)", reviewFlag);

// Write full plan to disk for inspection / the live run.
const planPath = resolve(__dirname, "publish_plan.json");
writeFileSync(planPath, JSON.stringify(decisions, null, 2));
console.log(`\nFull plan written to ${planPath}`);

// ── Live write ───────────────────────────────────────────────────────────────
if (LIVE) {
  console.log(`\nApplying LIVE write for ${willPublish.length} discounts…`);
  let n = 0;
  let batch = db.batch();
  for (const d of willPublish) {
    const update = {
      status: "active",
      countries: d.countries,
      verificationRequired: true,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: "publish-script",
      publishedAt: FieldValue.serverTimestamp(),
    };
    // Only set imageUrl when we supplied a fix (don't clobber an existing good image).
    if (d.imageSource && d.imageSource !== "existing") update.imageUrl = d.image;
    // Only overwrite the link when we repaired it to a real student page.
    if (d.repaired) update.applicationUrl = d.link;
    batch.set(col.doc(d.id), update, { merge: true });
    n++;
    if (n % 400 === 0) { await batch.commit(); batch = db.batch(); console.log(`  committed ${n}…`); }
  }
  await batch.commit();
  console.log(`\n✓ Published ${n} discounts (status=active).`);
} else {
  console.log(`\nDRY RUN — nothing written. Re-run with --live to publish the ${willPublish.length} qualifying discounts.`);
}
process.exit(0);
