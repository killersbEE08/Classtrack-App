/**
 * Seed StuSave `resources` from the StuSave markdown catalogs.
 *
 * Parses OPPORTUNITIES.md (28) and DISCOUNTS.md (237) and creates every item as
 * a DRAFT document in the `resources` collection so they can be reviewed and
 * activated one-by-one in the CMS. Drafts are invisible to students until an
 * editor publishes them.
 *
 * Usage:
 *   # Verify parsing only — no credentials, no writes:
 *   node seed_resources.mjs --dry-run
 *
 *   # Real write (needs ./serviceAccount.json OR gcloud ADC):
 *   node seed_resources.mjs
 *
 * Optional flags:
 *   --opps <path>       Path to OPPORTUNITIES.md
 *   --discounts <path>  Path to DISCOUNTS.md
 *   --limit <n>         Only process the first n items (per file) — useful for a test run
 *   --dry-run           Parse + validate + print a report, but DO NOT write to Firestore
 *
 * Notes:
 *   - The Admin SDK bypasses Firestore security rules, so draft writes always succeed.
 *   - Re-running is idempotent: a deterministic doc id (seed-<slug>) is used, so
 *     running twice UPDATES the same drafts instead of creating duplicates.
 */

import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));

// ── CLI args ────────────────────────────────────────────────────────────────
function argValue(name, fallback) {
  const i = process.argv.indexOf(name);
  return i !== -1 && process.argv[i + 1] ? process.argv[i + 1] : fallback;
}
const DRY_RUN = process.argv.includes("--dry-run");
const ENRICH = process.argv.includes("--enrich-discounts");
const FIXUPS = process.argv.includes("--fixups");

// ── Fixup data (applied by --fixups), keyed by exact resource title ──────────
// 1) PNG logos to replace SVGs that Flutter's Image.network can't render.
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
  "Microsoft Learn Student Ambassador": "https://img.icons8.com/color/96/microsoft.png",
  "Amazon Future Engineer Scholarship": "https://img.icons8.com/color/96/amazon.png",
};

// 2) Real brand names for entries truncated to the first word by the source.
const BRAND_FIX = {
  "Train Fitness AI": "Train Fitness",
  "Escape Motion": "Escape Motions",
  "Unreal Engine Academic Access": "Unreal Engine",
  "The Escape Game": "The Escape Game",
  "The North Face": "The North Face",
  "Air India": "Air India",
  "National Express": "National Express",
  "Blue Apron": "Blue Apron",
  "Magic Pin": "magicpin",
  "Read AI": "Read AI",
  "Unreal Engine for Students": "Epic Games",
  "Epic for Educators": "Epic",
};

// 5) Country targeting for clearly region-locked offers (empty = global).
const COUNTRY_FIX = {
  // India
  "Air India": ["India"], "IndiGo": ["India"], "Swiggy": ["India"],
  "Magic Pin": ["India"], "Realme": ["India"], "Vivo": ["India"],
  "Oppo": ["India"], "OnePlus": ["India"],
  // United Kingdom
  "Voxi UK Student eSIM": ["United Kingdom"],
  "National Express": ["United Kingdom"],
  "The Escape Game": ["United Kingdom"],
  // United States (services that only operate / offer this in the US)
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

const LIMIT = parseInt(argValue("--limit", "0"), 10) || 0;
const OPPS_PATH = argValue(
  "--opps",
  "C:\\Users\\princ\\Downloads\\stusave fully function vs\\OPPORTUNITIES.md"
);
const DISCOUNTS_PATH = argValue(
  "--discounts",
  "C:\\Users\\princ\\Downloads\\stusave fully function vs\\DISCOUNTS.md"
);

// ── The Resource type enum keys (mirror of resource_type.dart) ───────────────
const KNOWN_TYPES = new Set([
  "scholarship", "internship", "discount", "hackathon", "competition",
  "ambassador", "course", "certification", "research", "event", "job",
  "grant", "exchange", "conference", "startup",
]);
// Types present in the markdown that the app doesn't (yet) model. Mapped to the
// closest supported type for the draft, and the original is preserved as a tag
// so an editor can re-classify during review.
const TYPE_ALIASES = { volunteering: "internship" };

// ── Small helpers ─────────────────────────────────────────────────────────────
function slugify(s) {
  return s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}

/** Repair the common UTF-8 mojibake seen in the discounts file. */
function fixMojibake(s) {
  if (!s) return s;
  return s
    .replace(/â€”/g, "—")
    .replace(/â€“/g, "–")
    .replace(/â€™/g, "’")
    .replace(/â‰ˆ/g, "≈")
    .replace(/Â£/g, "£")
    .replace(/â‚¬/g, "€")
    .replace(/Â¥/g, "¥")
    .replace(/Â/g, "")
    .trim();
}

/** Parse "- **Key:** value" lines within a detail block into a {key: value} map. */
function parseKeyValues(block) {
  const out = {};
  const re = /^-\s*\*\*(.+?):\*\*\s*(.*)$/gm;
  let m;
  while ((m = re.exec(block)) !== null) {
    out[m[1].trim().toLowerCase()] = fixMojibake(m[2].trim());
  }
  return out;
}

/** Split the "## Detailed List (raw URLs)" section into per-item blocks. */
function detailBlocks(md) {
  const idx = md.indexOf("## Detailed List");
  const section = idx !== -1 ? md.slice(idx) : md;
  // Find every "### N. heading" and slice each body up to the next heading.
  const headingRe = /^###\s+\d+\.\s*(.+)$/gm;
  const heads = [];
  let m;
  while ((m = headingRe.exec(section)) !== null) {
    heads.push({ heading: fixMojibake(m[1].trim()), start: m.index, bodyStart: headingRe.lastIndex });
  }
  const blocks = [];
  for (let i = 0; i < heads.length; i++) {
    const end = i + 1 < heads.length ? heads[i + 1].start : section.length;
    blocks.push({ heading: heads[i].heading, body: section.slice(heads[i].bodyStart, end) });
  }
  return blocks;
}

function isoDate(raw) {
  if (!raw) return null;
  const m = raw.match(/^(\d{4})-(\d{2})-(\d{2})/);
  if (!m) return null;
  const d = new Date(Date.UTC(+m[1], +m[2] - 1, +m[3]));
  return isNaN(d.getTime()) ? null : d;
}

// ── Parsers ───────────────────────────────────────────────────────────────────
function parseOpportunities(md) {
  const items = [];
  let n = 0;
  for (const { heading, body } of detailBlocks(md)) {
    n++;
    const kv = parseKeyValues(body);
    const title = heading;
    const organization = kv["organization"] || "";
    const rawType = (kv["type"] || "").toLowerCase();
    const prize = kv["prize"] || "";
    const deadlineRaw = kv["deadline"] || "";
    const link = kv["official link"] || "";
    const logo = kv["logo link"] || "";

    const tags = [];
    let type = rawType;
    if (!KNOWN_TYPES.has(type)) {
      if (TYPE_ALIASES[type]) {
        tags.push(type); // preserve the original label for the editor
        type = TYPE_ALIASES[type];
      } else {
        type = "scholarship"; // safe fallback (matches ResourceType.fromKey)
      }
    }

    const deadline = isoDate(deadlineRaw);
    const descParts = [];
    if (prize) descParts.push(prize);
    if (!deadline && deadlineRaw) descParts.push(`Deadline: ${deadlineRaw}`);

    items.push({
      _slug: slugify(`${organization}-${title}`),
      _src: "opp",
      _index: n,
      type,
      title,
      organization,
      description: descParts.join(" · "),
      benefits: prize || null,
      eligibility: !deadline && deadlineRaw ? deadlineRaw : null,
      applicationUrl: link || null,
      logoUrl: logo || null,
      deadline, // Date | null
      tags,
      categories: [],
      company: null,
      discountText: null,
    });
  }
  return items;
}

function parseDiscounts(md) {
  const items = [];
  for (const { heading, body } of detailBlocks(md)) {
    // Heading form: "Brand — Offer Title"
    const parts = heading.split(/\s+—\s+/);
    const brand = (parts[0] || "").trim();
    const title = (parts.slice(1).join(" — ") || brand).trim();
    const kv = parseKeyValues(body);
    const rawDiscount = kv["discount"] || "";
    const discount = normalizeOffer(rawDiscount);
    const category = kv["category"] || "";
    const link = kv["official link"] || "";
    const logo = kv["logo link"] || "";

    items.push({
      _slug: slugify(`${brand}-${title}`),
      _src: "disc",
      _index: items.length + 1,
      _rawDiscount: rawDiscount,
      type: "discount",
      title,
      organization: brand,
      company: brand,
      description: discount ? `Student offer: ${discount}` : "",
      discountText: discount || null,
      applicationUrl: link || null,
      logoUrl: logo || null,
      deadline: null,
      benefits: null,
      eligibility: null,
      tags: [],
      categories: category ? [category] : [],
    });
  }
  return items;
}

// ── Discount content generators (template-based) ─────────────────────────────
// Short, category-aware "About" + generic "How to redeem" text for discounts.
// Deliberately avoids inventing brand-specific redemption flows that could be
// wrong; every draft is still reviewed before it goes live.

const CATEGORY_INFO = {
  ai: "an AI-powered tool that helps with tasks like writing, coding, research, or content creation",
  software: "a software tool used widely for work and study",
  "design & dev": "a tool used for design, development, and engineering work",
  "office & productivity": "a productivity tool for organizing your work, notes, and projects",
  education: "an online learning platform with courses and study material",
  academic: "a tool used for academic study and research",
  "cloud services": "a cloud platform offering hosting, storage, or compute for your projects",
  entertainment: "an entertainment and streaming service",
  gadgets: "a brand offering laptops, phones, and consumer electronics",
  fashion: "a clothing and lifestyle brand",
  food: "a food and meal-delivery service",
  travel: "a travel service for booking flights, trains, or trips",
};

// Brand tokens that are truncated/generic in the source data — prefer the full
// title as the display name in those cases (e.g. "The" → "The North Face").
const GENERIC_BRAND = new Set([
  "the", "air", "blue", "read", "train", "epic", "magic", "national",
  "escape", "unreal", "b&h",
]);

/** Best display name for a discount: the brand unless it's truncated/generic. */
function displayName(it) {
  const brand = (it.organization || "").trim();
  const title = (it.title || "").trim();
  if (!brand || brand.length < 4 || GENERIC_BRAND.has(brand.toLowerCase())) {
    return title || brand;
  }
  return brand;
}

// What a student is paying for, per category — keeps wording natural for both
// subscriptions (software) and one-off purchases (retail/travel/food).
const SPEND_NOUN = {
  fashion: "order",
  gadgets: "purchase",
  food: "order",
  travel: "booking",
};
function spendNoun(cat) {
  return SPEND_NOUN[cat] || "subscription";
}

/**
 * Normalize the offer text so it always carries a unit:
 *   - percentages gain "Off"      ("40%" → "40% Off", "15-20%" → "15-20% Off")
 *   - bare currency amounts gain "/year"  ("$80" → "$80/year", "¥81" → "¥81/year")
 * Anything already qualified (has Off / % Off / /mo / /year / credit / over N
 * months / total / a word) is left exactly as-is.
 */
function normalizeOffer(raw) {
  const s = (raw || "").trim();
  if (!s) return s;
  if (s.includes("%")) {
    // Already says Off / waiver / discount(s) → leave it.
    if (/off|waiver|discount/i.test(s)) return s;
    return `${s} Off`;
  }
  // Pure currency amount, no period or trailing words (e.g. "$80", "¥81", "$4.99").
  if (/^[$€£¥]\s?\d[\d.,]*$/.test(s)) return `${s}/year`;
  return s;
}

/** Classify the raw discount text into a redemption "shape". */
function offerShape(raw) {
  const s = (raw || "").toLowerCase();
  if (/free|waiver|no direct cash/.test(s)) return "free";
  if (/credit/.test(s)) return "credit";
  if (/%|off/.test(s)) return "percent";
  if (/\$|€|£|¥|\/mo|\/month|\/yr|\/year|fares|price/.test(s)) return "price";
  return "generic";
}

/** True when the discount text is too vague to quote literally. */
function isVagueOffer(raw) {
  const s = (raw || "").trim().toLowerCase();
  return (
    !s ||
    ["exclusive", "varies", "discounted", "% off", "special fares",
     "student price", "discount", "free/discount"].includes(s)
  );
}

/** ~90–200 word "About" write-up describing the product and the discount. */
function aboutText(it) {
  const name = displayName(it);
  const cat = (it.categories[0] || "").toLowerCase();
  const catDesc = CATEGORY_INFO[cat] || "a service that students use regularly";
  const shape = offerShape(it.discountText);
  const vague = isVagueOffer(it.discountText);
  const dt = it.discountText;

  const p1 = `${name} is ${catDesc}.`;

  let p2;
  switch (shape) {
    case "free":
      p2 = `With this student deal, you can use the premium version for free while you're a verified student — the paid features are unlocked at no cost, so you get the full experience without the usual subscription fee.`;
      break;
    case "credit":
      p2 = vague
        ? `As a student, you get free credits to spend on the platform, so you can try the paid features without putting in your own money first.`
        : `As a student, you get ${dt} to spend on the platform, so you can try the paid features without putting in your own money first.`;
      break;
    case "percent":
      p2 = vague
        ? `As a student, you get a discount on your ${spendNoun(cat)}, bringing the cost below the standard price.`
        : `The student discount gives you ${dt} on your ${spendNoun(cat)}, bringing the cost below the standard price.`;
      break;
    case "price":
      p2 = vague
        ? `Students pay a reduced rate instead of the full price.`
        : `Students pay a reduced rate of ${dt} instead of the full price for the same ${spendNoun(cat)}.`;
      break;
    default:
      p2 = `Students get access to an exclusive discount that isn't offered at the regular price.`;
  }

  const p3 =
    `To claim it, you'll need to confirm that you're a currently enrolled student. ` +
    `Pricing, availability, and terms are set by ${name} and can change or vary by country, so check the official page for the latest details before you sign up.`;

  let text = [p1, p2, p3].join("\n\n");
  const words = text.split(/\s+/);
  if (words.length > 250) text = words.slice(0, 250).join(" ") + "…";
  return text;
}

/** Generic, template-based "How to redeem" steps tailored by offer shape. */
function redeemText(it) {
  const name = displayName(it);
  const shape = offerShape(it.discountText);
  const applyLine =
    shape === "free"
      ? `Once verified, activate the free student plan — no payment is needed while your student status is valid.`
      : shape === "credit"
      ? `Once verified, the student credits are added to your account automatically.`
      : `Once verified, the student price is applied to the eligible plan or at checkout.`;

  return [
    `1. Open the official ${name} student page (the link on this listing).`,
    `2. Sign in or create an account, using your student email if possible.`,
    `3. Verify that you're a student. This is usually done through SheerID, UNiDAYS, or Student Beans, or by using your institutional (.edu / college) email address.`,
    `4. ${applyLine}`,
    `5. Re-verify when prompted (often once a year) to keep the offer active. Terms are set by ${name} and may vary by country.`,
  ].join("\n");
}

// ── Publish-readiness (mirrors CmsResourceRepository.validateForPublish) ──────
function publishErrors(it) {
  const errs = [];
  if (!it.title || !it.title.trim()) errs.push("missing title");
  if (!it.organization || !it.organization.trim())
    errs.push("missing organization");
  const hasLink =
    (it.applicationUrl && it.applicationUrl.trim()) ||
    (it.affiliateUrl && it.affiliateUrl.trim());
  if (!hasLink) errs.push("missing link");
  return errs;
}

// ── Firebase Admin init (service account OR gcloud ADC) ──────────────────────
async function initDb() {
  const { initializeApp, cert, applicationDefault } = await import("firebase-admin/app");
  const { getFirestore, FieldValue, Timestamp } = await import("firebase-admin/firestore");
  let credential;
  const saPath = resolve(__dirname, "serviceAccount.json");
  try {
    const sa = JSON.parse(readFileSync(saPath, "utf8"));
    credential = cert(sa);
    console.log(`\nUsing service account: ${saPath}`);
  } catch {
    credential = applicationDefault();
    console.log("\nUsing application default credentials (gcloud ADC).");
  }
  initializeApp({ credential });
  return { db: getFirestore(), FieldValue, Timestamp };
}

// ── Main ──────────────────────────────────────────────────────────────────────
async function main() {
  const oppsMd = readFileSync(resolve(OPPS_PATH), "utf8");
  const discMd = readFileSync(resolve(DISCOUNTS_PATH), "utf8");

  let opps = parseOpportunities(oppsMd);
  let discounts = parseDiscounts(discMd);
  if (LIMIT > 0) {
    opps = opps.slice(0, LIMIT);
    discounts = discounts.slice(0, LIMIT);
  }
  const all = [...opps, ...discounts];

  // Report
  const byType = {};
  for (const it of all) byType[it.type] = (byType[it.type] || 0) + 1;
  const notPublishable = all
    .map((it) => ({ it, errs: publishErrors(it) }))
    .filter((x) => x.errs.length);
  const aliased = all.filter((it) => it.tags && it.tags.length);
  const ids = all.map((it) => `seed-${it._src}-${String(it._index).padStart(3, "0")}-${it._slug}`);
  const dupSlugs = ids.filter((s, i) => ids.indexOf(s) !== i);

  console.log("── StuSave resource seed ─────────────────────────────");
  console.log(`Opportunities parsed : ${opps.length}`);
  console.log(`Discounts parsed     : ${discounts.length}`);
  console.log(`TOTAL                : ${all.length}`);
  console.log("By type              :", JSON.stringify(byType));
  console.log(
    `Publish-ready        : ${all.length - notPublishable.length}/${all.length}`
  );
  if (notPublishable.length) {
    console.log(`\nNOT publish-ready (${notPublishable.length}):`);
    for (const { it, errs } of notPublishable)
      console.log(`  - [${it.type}] ${it.title} → ${errs.join(", ")}`);
  }
  if (aliased.length) {
    console.log(
      `\nRe-typed from an unmodeled type (${aliased.length}) — review in CMS:`
    );
    for (const it of aliased)
      console.log(`  - "${it.title}" → type=${it.type} (was: ${it.tags.join(",")})`);
  }
  if (dupSlugs.length) {
    console.log(`\n⚠ Duplicate doc ids (would merge): ${[...new Set(dupSlugs)].join(", ")}`);
  }

  // ── Fixups mode: logos (SVG→PNG), real brands, verification, country target ──
  if (FIXUPS) {
    const docId = (it) => `seed-${it._src}-${String(it._index).padStart(3, "0")}-${it._slug}`;
    const byTitle = new Map(all.map((it) => [it.title, it]));

    // Detect any map key that doesn't match a resource (typo guard).
    const unmatched = [];
    for (const key of new Set([
      ...Object.keys(LOGO_FIX), ...Object.keys(BRAND_FIX), ...Object.keys(COUNTRY_FIX),
    ])) {
      if (!byTitle.has(key)) unmatched.push(key);
    }
    if (unmatched.length) {
      console.log(`\n⚠ ${unmatched.length} fix key(s) matched no resource — check spelling:`);
      unmatched.forEach((k) => console.log(`  - "${k}"`));
    }

    // Build per-doc update objects.
    const updates = [];
    for (const it of all) {
      const u = {};
      if (LOGO_FIX[it.title]) u.logoUrl = LOGO_FIX[it.title];
      if (BRAND_FIX[it.title]) { u.organization = BRAND_FIX[it.title]; u.company = BRAND_FIX[it.title]; }
      if (COUNTRY_FIX[it.title]) u.countries = COUNTRY_FIX[it.title];
      if (it.type === "discount") u.verificationRequired = true;
      if (Object.keys(u).length) updates.push({ it, u });
    }

    const nLogo = updates.filter((x) => x.u.logoUrl).length;
    const nBrand = updates.filter((x) => x.u.organization).length;
    const nCountry = updates.filter((x) => x.u.countries).length;
    const nVerif = updates.filter((x) => x.u.verificationRequired).length;
    console.log(`\nFixups to apply:`);
    console.log(`  logos (SVG→PNG)     : ${nLogo}`);
    console.log(`  brand names fixed   : ${nBrand}`);
    console.log(`  country-targeted    : ${nCountry}`);
    console.log(`  verificationRequired: ${nVerif}`);

    if (DRY_RUN) {
      console.log("\nBrand fixes:");
      updates.filter((x) => x.u.organization)
        .forEach((x) => console.log(`  - "${x.it.title}" org → "${x.u.organization}"`));
      console.log("\nCountry targeting:");
      updates.filter((x) => x.u.countries)
        .forEach((x) => console.log(`  - "${x.it.title}" → ${x.u.countries.join(", ")}`));
      console.log("\n--dry-run: no data written.");
      return;
    }

    const { db, FieldValue } = await initDb();
    const col = db.collection("resources");
    let n = 0;
    let batch = db.batch();
    for (const { it, u } of updates) {
      batch.set(col.doc(docId(it)), { ...u, updatedAt: FieldValue.serverTimestamp(), updatedBy: "seed-import" }, { merge: true });
      n++;
      if (n % 400 === 0) { await batch.commit(); batch = db.batch(); console.log(`  committed ${n}…`); }
    }
    await batch.commit();
    console.log(`\n✓ Applied fixups to ${n} resources (logos ${nLogo}, brands ${nBrand}, countries ${nCountry}, verification ${nVerif}).`);
    process.exit(0);
  }

  // ── Enrich mode: fill About + How-to-redeem on the 237 discount drafts only ──
  if (ENRICH) {
    const docId = (it) => `seed-${it._src}-${String(it._index).padStart(3, "0")}-${it._slug}`;
    const enriched = discounts.map((it) => ({
      it,
      docId: docId(it),
      about: aboutText(it),
      redeem: redeemText(it),
    }));
    const wc = enriched.map((e) => e.about.split(/\s+/).length);
    console.log(`\nEnrich target        : ${enriched.length} discount drafts`);
    console.log(
      `About word count     : min ${Math.min(...wc)}, max ${Math.max(...wc)}, avg ${Math.round(wc.reduce((a, b) => a + b, 0) / wc.length)}`
    );

    // Report offer-text normalizations (bare "$80" → "$80/year", "40%" → "40% Off").
    const changed = discounts.filter((it) => it._rawDiscount !== it.discountText);
    if (changed.length) {
      console.log(`\nOffer text normalized (${changed.length}) — verify the /year guesses:`);
      for (const it of changed)
        console.log(`  - ${it.title}: "${it._rawDiscount}" → "${it.discountText}"`);
    }

    if (DRY_RUN) {
      const e = enriched[0];
      console.log(`\nSample (${e.docId}) — ${e.it.title}`);
      console.log(`\n[discountText] ${e.it.discountText}`);
      console.log(`\n[description] (${e.about.split(/\s+/).length} words)\n${e.about}`);
      console.log(`\n[redemptionInstructions]\n${e.redeem}`);
      console.log("\n--dry-run: no data written.");
      return;
    }

    const { db, FieldValue } = await initDb();
    const col = db.collection("resources");
    let n = 0;
    let batch = db.batch();
    for (const e of enriched) {
      batch.set(
        col.doc(e.docId),
        {
          description: e.about,
          fullDescription: null,
          redemptionInstructions: e.redeem,
          discountText: e.it.discountText,
          updatedAt: FieldValue.serverTimestamp(),
          updatedBy: "seed-import",
        },
        { merge: true }
      );
      n++;
      if (n % 400 === 0) {
        await batch.commit();
        batch = db.batch();
        console.log(`  committed ${n}…`);
      }
    }
    await batch.commit();
    console.log(`\n✓ Enriched ${n} discount drafts (description + redemption + offer text).`);
    process.exit(0);
  }

  if (DRY_RUN) {
    const sample = (it) => ({
      docId: `seed-${it._src}-${String(it._index).padStart(3, "0")}-${it._slug}`,
      type: it.type, title: it.title, organization: it.organization,
      company: it.company, description: it.description,
      discountText: it.discountText, categories: it.categories,
      deadline: it.deadline ? it.deadline.toISOString().slice(0, 10) : null,
      applicationUrl: it.applicationUrl, logoUrl: it.logoUrl,
      benefits: it.benefits, eligibility: it.eligibility, tags: it.tags,
    });
    console.log("\nSample opportunity:\n", JSON.stringify(sample(opps[2]), null, 2));
    console.log("\nSample discount:\n", JSON.stringify(sample(discounts[0]), null, 2));
    console.log("\n--dry-run: no data written. Re-run without --dry-run to seed.");
    return;
  }

  // ── Real write ──────────────────────────────────────────────────────────────
  const { db, FieldValue, Timestamp } = await initDb();
  const col = db.collection("resources");

  let written = 0;
  let batch = db.batch();
  for (const it of all) {
    const docId = `seed-${it._src}-${String(it._index).padStart(3, "0")}-${it._slug}`;
    const data = {
      type: it.type,
      title: it.title,
      organization: it.organization,
      description: it.description || "",
      countries: [],
      eligibility: it.eligibility || null,
      startDate: null,
      deadline: it.deadline ? Timestamp.fromDate(it.deadline) : null,
      applicationUrl: it.applicationUrl || null,
      imageUrl: null,
      tags: it.tags || [],
      status: "draft",
      featured: false,
      sponsored: false,
      priority: 0,
      remote: null,
      paid: null,
      verified: false,
      slug: null,
      company: it.company || null,
      logoUrl: it.logoUrl || null,
      discountText: it.discountText || null,
      redemptionInstructions: null,
      verificationRequired: false,
      affiliateUrl: null,
      terms: null,
      categories: it.categories || [],
      targetDegrees: [],
      targetDepartments: [],
      targetInterests: [],
      targetCareerGoals: [],
      targetAcademicYears: [],
      fullDescription: null,
      officialWebsite: null,
      benefits: it.benefits || null,
      howToApply: null,
      requirements: null,
      discountCode: null,
      discountPercent: null,
      redemptionUrl: null,
      scheduledPublishAt: null,
      scheduledUnpublishAt: null,
      homepageEligible: false,
      recommendationEligible: true,
      relatedResourceIds: [],
      publishedAt: null,
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: "seed-import",
      seedSource: it.type === "discount" ? "DISCOUNTS.md" : "OPPORTUNITIES.md",
    };
    batch.set(col.doc(docId), data, { merge: true });
    written++;
    if (written % 400 === 0) {
      await batch.commit();
      batch = db.batch();
      console.log(`  committed ${written}…`);
    }
  }
  await batch.commit();
  console.log(`\n✓ Wrote ${written} draft resources to 'resources'.`);
  console.log("Open the CMS → Resources, filter by status = Draft, and activate one-by-one.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Seed failed:", e);
  process.exit(1);
});
