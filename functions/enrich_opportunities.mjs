/**
 * Consolidate + enrich the older `OPPORTUNITIES.md` opportunity drafts.
 *
 * Option 2 (chosen by the owner):
 *   1. DELETE the older drafts that duplicate a richer entry created by
 *      seed_opportunities.mjs.
 *   2. ENRICH the remaining unique older drafts so they match the quality of
 *      the new set: full "About" (fullDescription), benefits, eligibility,
 *      howToApply, a working PNG logo (icon.horse) and a category hero image.
 *      A few miscategorized types are corrected too.
 *
 * Every target stays a DRAFT (we never publish here). Writes MERGE, so nothing
 * else on the doc is touched.
 *
 *   node enrich_opportunities.mjs           # DRY RUN — verify links, print plan
 *   node enrich_opportunities.mjs --live    # apply deletes + enrichment
 *   node enrich_opportunities.mjs --no-check # skip live URL verification
 */
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";

const __dirname = dirname(fileURLToPath(import.meta.url));
const LIVE = process.argv.includes("--live");
const NO_CHECK = process.argv.includes("--no-check");

const iconhorse = (domain) => `https://icon.horse/icon/${domain}`;
const UNSPLASH = (id) => `https://images.unsplash.com/photo-${id}?w=1200&q=80&auto=format&fit=crop`;
const HERO_BY_TYPE = {
  scholarship: UNSPLASH("1541339907198-e08756dedf3f"),
  course: UNSPLASH("1516321318423-f06f85e504b3"),
  certification: UNSPLASH("1454165804606-c3d57bc86b40"),
  internship: UNSPLASH("1497215728101-856f4ea42174"),
  job: UNSPLASH("1521737711867-e3b97375f902"),
  hackathon: UNSPLASH("1504384308090-c894fdcc538d"),
  competition: UNSPLASH("1567427017947-545c5f8d16ad"),
  ambassador: UNSPLASH("1522071820081-009f0129c71c"),
  research: UNSPLASH("1532094349884-543bc11b234d"),
  event: UNSPLASH("1505373877841-8d25f7d46678"),
  conference: UNSPLASH("1540575467063-178a50c2df87"),
  grant: UNSPLASH("1554224155-6726b3ff858f"),
  startup: UNSPLASH("1559136555-9303baea8ebd"),
  exchange: UNSPLASH("1488646953014-85cb44e25828"),
};
const heroFor = (type) => HERO_BY_TYPE[type] || HERO_BY_TYPE.scholarship;

// ── Duplicates to delete (older doc → richer new equivalent) ─────────────────
const DELETE = [
  "seed-opp-003-google-google-summer-of-code-2026",              // ↔ seed-opp-021 (GSoC)
  "seed-opp-004-microsoft-microsoft-learn-student-ambassador",   // ↔ seed-opp-002
  "seed-opp-012-github-education-github-campus-experts",         // ↔ seed-opp-003
  "seed-opp-017-amazon-amazon-future-engineer-scholarship",      // ↔ seed-opp-007
];

// ── Enrichment, keyed by doc id ──────────────────────────────────────────────
// domain: optional logo-domain override (else derived from the doc's URL host).
// type/countries: set only when we're correcting the stored value.
const ENRICH = {
  "seed-opp-001-microsoft-microsoft-fabric-analytics-engineer-certification-free-for-students": {
    domain: "microsoft.com",
    fullDescription:
      "Microsoft Fabric is Microsoft's unified analytics platform. This program lets students prepare for and take the Fabric Analytics Engineer certification at no cost, validating skills in data modelling, transformation, and analytics with Power BI and Fabric — a credential recognised by employers hiring for data and analytics roles.",
    benefits: "Free certification exam voucher, official Microsoft Learn training paths, and an industry-recognised Analytics Engineer credential.",
    eligibility: "Verified students enrolled at an accredited institution (via Microsoft's student verification).",
    howToApply: "Sign in on the Microsoft campaign page, complete the Microsoft Learn training, claim your free exam voucher, and schedule the exam.",
  },
  "seed-opp-002-microsoft-microsoft-ai-agent-skills-sweepstakes": {
    domain: "microsoft.com",
    fullDescription:
      "A Microsoft program where students earn the 'Build AI agents' Applied Skills credential and enter a sweepstakes for prizes. It validates hands-on ability to build AI agents with Microsoft Copilot Studio and Azure AI, combining a résumé-boosting credential with a chance to win rewards.",
    benefits: "Free Applied Skills credential, hands-on AI-agent training, and entry into a prize sweepstakes.",
    eligibility: "Eligible students who complete the qualifying Microsoft Applied Skills assessment (check official terms for region eligibility).",
    howToApply: "Complete the listed Microsoft Applied Skills assessment on Microsoft Learn during the sweepstakes window to earn the credential and an entry.",
  },
  "seed-opp-005-anthropic-claude-campus-ambassador-program": {
    domain: "claude.com",
    fullDescription:
      "Anthropic's Claude Campus Ambassador program empowers students to lead AI communities on campus. Ambassadors run events and workshops introducing peers to Claude and responsible AI, get early access to features and mentorship from Anthropic, and earn swag while building leadership and AI skills.",
    benefits: "Claude credits/early access, event support and swag, mentorship from Anthropic, and a global ambassador community.",
    eligibility: "Currently enrolled students passionate about AI and community building.",
    howToApply: "Apply on the Claude campus program page; selected ambassadors complete onboarding and run campus activities.",
  },
  "seed-opp-006-perplexity-ai-perplexity-campus-partner-program": {
    domain: "perplexity.ai",
    fullDescription:
      "Perplexity's Campus Partner program selects students to grow Perplexity's presence on their campus. Partners host events, share Perplexity for research and study, and drive sign-ups, earning perks like Perplexity Pro, swag, and direct access to the Perplexity team.",
    benefits: "Free Perplexity Pro, campaign perks and swag, mentorship, and a partner community.",
    eligibility: "Enrolled students with strong campus networks and an interest in AI and search tools.",
    howToApply: "Apply on the Perplexity Campus Partners page and complete onboarding if selected.",
  },
  "seed-opp-007-major-league-hacking-mlh-hackathon-season-2026": {
    domain: "mlh.io",
    fullDescription:
      "The official Major League Hacking event calendar for the 2026 season — hundreds of weekend hackathons worldwide, both in-person and online. Students browse and register for events, build projects in 24–48 hours, win sponsor prizes, and join a global community of student developers.",
    benefits: "Access to hundreds of hackathons, sponsor prizes, workshops, swag, and a global community.",
    eligibility: "Students and early-career developers of all levels; most events welcome beginners.",
    howToApply: "Browse the MLH 2026 season events page and register for the hackathons you want to attend.",
  },
  "seed-opp-008-major-league-hacking-global-hack-week": {
    domain: "mlh.io",
    fullDescription:
      "Global Hack Week (GHW) by MLH is a week-long online event packed with workshops, mini-challenges, and team activities around a theme such as AI or Data. It's beginner-friendly, helping students learn new skills, ship small projects daily, and earn digital badges and prizes.",
    benefits: "Daily workshops and challenges, digital badges, prizes, and a welcoming online community.",
    eligibility: "Open to all students and aspiring developers worldwide, beginners included.",
    howToApply: "Register for the upcoming Global Hack Week on the GHW site and join the online sessions.",
  },
  "seed-opp-009-mit-hackathon-hackmit-2026": {
    domain: "hackmit.org",
    countries: ["United States"],
    fullDescription:
      "HackMIT is MIT's flagship annual student hackathon, bringing together talented students worldwide for a weekend of building innovative software and hardware projects. Participants get mentorship, sponsor APIs, workshops, and compete for prizes, with travel reimbursement often available for admitted hackers.",
    benefits: "Mentorship, sponsor prizes, workshops, meals, and possible travel reimbursement.",
    eligibility: "Undergraduate (and some high-school/graduate) students; admission by application/lottery.",
    howToApply: "Apply on the HackMIT site during the admissions window; admitted hackers confirm and attend.",
  },
  "seed-opp-011-u-s-department-of-state-fulbright-u-s-student-program-2027-2028": {
    domain: "fulbrightonline.org",
    countries: ["United States"],
    fullDescription:
      "The Fulbright U.S. Student Program funds U.S. citizens to study, research, or teach English abroad for an academic year in over 140 countries. Grants cover travel, living, and program costs, offering a life-changing cultural exchange and a prestigious credential for future careers.",
    benefits: "Funded year abroad (travel, living stipend, program costs), health benefits, and a global alumni network.",
    eligibility: "U.S. citizens holding a bachelor's degree by the grant start; requirements vary by country/award.",
    howToApply: "Apply through your university's Fulbright Program Adviser or as an at-large applicant during the annual cycle.",
  },
  "seed-opp-013-usa-computing-olympiad-usaco-programming-contest-2026": {
    domain: "usaco.org",
    fullDescription:
      "The USA Computing Olympiad (USACO) runs free online algorithmic programming contests across four divisions (Bronze to Platinum). Students solve challenging problems in C++, Java, or Python and promote up divisions by performance, with top U.S. students advancing toward the IOI training camp.",
    benefits: "Free competitive-programming practice, a clear promotion ladder, and a pathway toward the IOI (for U.S. students).",
    eligibility: "Open to students worldwide (contests are open); the U.S. IOI-team pathway is for U.S. students.",
    howToApply: "Register free on usaco.org and compete during the scheduled online contest windows.",
  },
  "seed-opp-014-major-league-hacking-mlh-fellowship": {
    domain: "mlh.io",
    type: "internship",
    fullDescription:
      "The MLH Fellowship is a 12-week remote program that's an alternative to a traditional internship. Fellows contribute to real open-source projects or build software with peers under experienced mentors, gaining production experience, a strong portfolio, and a stipend in some tracks.",
    benefits: "Remote real-world software experience, mentorship, a strong portfolio, and a stipend (track-dependent).",
    eligibility: "Students and early-career developers aged 18+ with basic programming experience.",
    howToApply: "Apply on the MLH Fellowship site for an upcoming batch and complete the interview process.",
  },
  "seed-opp-015-smithsonian-institution-smithsonian-internships": {
    domain: "si.edu",
    type: "internship",
    url: "https://internships.si.edu/",
    fullDescription:
      "The Smithsonian Institution offers internships across its museums, research centers, and the National Zoo in fields from science and history to art and administration. Interns work alongside experts on real projects, with many placements offering stipends and a prestigious addition to any resume.",
    benefits: "Hands-on experience with Smithsonian experts, many stipended placements, and strong networking.",
    eligibility: "Students (high school through graduate) and recent grads; requirements vary by placement.",
    howToApply: "Search opportunities and apply through the Smithsonian Online Academic Appointment (SOLAA) system.",
  },
  "seed-opp-016-national-institutes-of-health-nih-summer-internship-program": {
    domain: "nih.gov",
    type: "internship",
    countries: ["United States"],
    fullDescription:
      "The NIH Summer Internship Program places students in biomedical research labs at the National Institutes of Health for 8–10 weeks. Interns conduct cutting-edge research alongside leading scientists, receive a stipend, and gain experience ideal for future medical or research careers.",
    benefits: "Paid summer research stipend, mentorship from NIH scientists, and a strong research credential.",
    eligibility: "Students aged 18+ enrolled at (or accepted to) an accredited institution; U.S. citizens/permanent residents primarily.",
    howToApply: "Create a profile and apply through the NIH student application portal by the deadline.",
  },
  "seed-opp-018-u-s-department-of-state-u-s-department-of-state-student-internship": {
    domain: "state.gov",
    type: "internship",
    countries: ["United States"],
    fullDescription:
      "The U.S. Department of State Student Internship Program offers (often paid) internships at embassies and domestic offices, immersing students in diplomacy and foreign affairs. Interns support real policy and consular work, gaining insight into international careers and public service.",
    benefits: "Paid internship experience in diplomacy/foreign affairs, mentorship, and a pathway to Foreign Service careers.",
    eligibility: "U.S. citizens enrolled at least half-time at an accredited institution; must pass a background check.",
    howToApply: "Apply via USAJOBS / careers.state.gov during the internship window and complete security clearance.",
  },
  "seed-opp-019-university-of-waterloo-hack-the-north-2026": {
    domain: "hackthenorth.com",
    countries: ["Canada"],
    fullDescription:
      "Hack the North is Canada's largest hackathon, hosted at the University of Waterloo. Over a weekend, 1,000+ students from around the world build hardware and software projects, attend workshops, meet sponsors and recruiters, and compete for prizes, with travel support for many attendees.",
    benefits: "Sponsor prizes, workshops, mentorship, recruiter access, meals, and travel support for many hackers.",
    eligibility: "Students worldwide (and recent grads); admission by application.",
    howToApply: "Apply on the Hack the North site during the admissions window and confirm your spot if accepted.",
  },
  "seed-opp-020-university-of-central-florida-knight-hacks-viii": {
    domain: "knighthacks.org",
    countries: ["United States"],
    fullDescription:
      "Knight Hacks is the University of Central Florida's flagship hackathon, welcoming students from across the region for a weekend of building projects, learning from workshops, and competing for prizes. It's beginner-friendly with mentorship, sponsor challenges, and a vibrant community.",
    benefits: "Sponsor prizes and challenges, workshops, mentorship, meals, and swag.",
    eligibility: "Current students (beginner-friendly); admission by registration/application.",
    howToApply: "Register on the Knight Hacks site for the current season and attend.",
  },
  "seed-opp-021-university-of-texas-at-dallas-hackutd": {
    domain: "hackutd.co",
    countries: ["United States"],
    fullDescription:
      "HackUTD is the University of Texas at Dallas's hackathon and one of the largest in Texas. Students form teams to build projects over a weekend, tackle sponsor challenges, attend tech workshops, and compete for prizes, with a strong focus on welcoming first-time hackers.",
    benefits: "Sponsor prizes and challenges, workshops, mentorship, meals, and swag.",
    eligibility: "Students of all levels; admission by registration.",
    howToApply: "Register on the HackUTD site for the current event and participate.",
  },
  "seed-opp-022-coca-cola-foundation-coca-cola-scholars-program": {
    domain: "coca-colascholarsfoundation.org",
    countries: ["United States"],
    fullDescription:
      "The Coca-Cola Scholars Program is a prestigious achievement-based scholarship awarding $20,000 to 150 graduating U.S. high school seniors each year. It recognises leadership, service, and impact, and connects scholars to a lifelong network of changemakers.",
    benefits: "$20,000 scholarship and access to the Coca-Cola Scholars alumni leadership network.",
    eligibility: "U.S. high school seniors planning to pursue a degree, meeting GPA and citizenship requirements.",
    howToApply: "Apply online during the fall application window (typically August–October) of your senior year.",
  },
  "seed-opp-023-lockheed-martin-lockheed-martin-code-quest-2026": {
    domain: "lockheedmartin.com",
    countries: ["United States"],
    fullDescription:
      "Code Quest is Lockheed Martin's annual team coding competition for high school students. Teams solve a set of programming challenges of increasing difficulty within a time limit, sharpening algorithmic and teamwork skills while connecting with STEM mentors from Lockheed Martin.",
    benefits: "Competitive coding experience, STEM mentorship, prizes, and exposure to engineering careers.",
    eligibility: "High school students (in teams), typically at participating Lockheed Martin event locations.",
    howToApply: "Register your team through the Lockheed Martin Code Quest site when registration opens.",
  },
  "seed-opp-024-iarcs-ioi-international-olympiad-in-informatics-2026": {
    domain: "ioinformatics.org",
    fullDescription:
      "The International Olympiad in Informatics (IOI) is the most prestigious algorithmic programming competition for secondary-school students. National teams of up to four compete on challenging algorithmic problems over two contest days, earning medals and global recognition among the world's best young programmers.",
    benefits: "World-class recognition, medals, and a launchpad to top universities and tech careers.",
    eligibility: "Secondary-school students selected through their national olympiad (e.g. USACO, INOI).",
    howToApply: "Qualify via your country's national informatics olympiad, which selects the IOI team.",
  },
  "seed-opp-025-york-university-ellehacks-2026": {
    domain: "ellehacks.com",
    countries: ["Canada"],
    fullDescription:
      "ElleHacks is a hackathon at York University for women and non-binary students, and one of Canada's largest. It offers a supportive weekend of building projects, workshops, and mentorship, aiming to close the gender gap in tech while competing for prizes.",
    benefits: "Beginner-friendly workshops, mentorship, prizes, meals, and a supportive community.",
    eligibility: "Women and non-binary post-secondary (and some high-school) students.",
    howToApply: "Apply/register on the ElleHacks site for the current edition.",
  },
  "seed-opp-026-habitat-for-humanity-habitat-for-humanity-collegiate-challenge": {
    domain: "habitat.org",
    url: "https://www.habitat.org/volunteer",
    fullDescription:
      "The Collegiate Challenge is Habitat for Humanity's alternative-break program where student groups travel to volunteer on home-building projects. Participants gain hands-on construction and teamwork experience while making a tangible community impact during school breaks.",
    benefits: "Meaningful service experience, teamwork and construction skills, and real community impact.",
    eligibility: "Students aged 16+ (group trips); groups organise their own travel and dates.",
    howToApply: "Register your group on the Habitat Collegiate Challenge page and choose a host site and dates.",
  },
  "seed-opp-027-develop-for-good-develop-for-good-tech-volunteering": {
    domain: "developforgood.org",
    fullDescription:
      "Develop for Good is a nonprofit that matches student technologists with real projects for other nonprofits. Fellows work in teams on software, data, or design deliverables over a semester or summer, gaining portfolio-worthy experience and mentorship while creating social impact.",
    benefits: "Real, portfolio-worthy project experience, mentorship from industry professionals, and social impact.",
    eligibility: "Students in tech, design, data, or product fields who can commit part-time to a cohort.",
    howToApply: "Apply on the Develop for Good students page for an upcoming cohort.",
  },
  "seed-opp-028-special-olympics-special-olympics-volunteer-program": {
    domain: "specialolympics.org",
    fullDescription:
      "Special Olympics offers volunteer opportunities supporting athletes with intellectual disabilities at events and programs worldwide. Volunteers help with coaching, event operations, and community outreach, building leadership and empathy while making a real difference.",
    benefits: "Leadership and event experience, community, and meaningful volunteer service hours.",
    eligibility: "Volunteers of all backgrounds; some roles have age/training requirements by region.",
    howToApply: "Find your local program on the Special Olympics volunteer page and sign up.",
  },
};

// ── URL check ────────────────────────────────────────────────────────────────
const DEAD = new Set([400, 404, 410, 500, 522, 523, 525, 530]);
const UA = { "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36" };
async function checkUrl(u) {
  if (!u) return { skip: true };
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 15000);
  try {
    const r = await fetch(u, { method: "GET", redirect: "follow", signal: ac.signal, headers: UA });
    return { status: r.status, dead: DEAD.has(r.status) };
  } catch (e) {
    const to = String(e.name || e).includes("Abort");
    return { status: 0, dead: !to, to };
  } finally { clearTimeout(t); }
}
function hostDomain(u) {
  try { return new URL(u).host.toLowerCase().replace(/^www\./, ""); } catch { return null; }
}

async function main() {
  const sa = JSON.parse(readFileSync(resolve(__dirname, "serviceAccount.json"), "utf8"));
  const { initializeApp, cert } = await import("firebase-admin/app");
  const { getFirestore, FieldValue } = await import("firebase-admin/firestore");
  initializeApp({ credential: cert(sa) });
  const db = getFirestore();
  const col = db.collection("resources");

  console.log(`Project: ${sa.project_id}   Mode: ${LIVE ? "LIVE WRITE" : "DRY RUN"}`);
  console.log(`Delete (duplicates): ${DELETE.length}   Enrich: ${Object.keys(ENRICH).length}\n`);

  // Load the enrichment targets to derive logo domain + hero + verify link.
  const plan = [];
  for (const [id, e] of Object.entries(ENRICH)) {
    const snap = await col.doc(id).get();
    if (!snap.exists) { console.log(`⚠ MISSING (skip): ${id}`); continue; }
    const cur = snap.data();
    const type = e.type || cur.type;
    const url = e.url || cur.applicationUrl;
    const domain = e.domain || hostDomain(url);
    plan.push({
      id, url, type,
      logoUrl: iconhorse(domain),
      imageUrl: heroFor(type),
      countries: e.countries || cur.countries || [],
      body: e,
    });
  }

  let dead = 0;
  if (!NO_CHECK) {
    console.log("Verifying enrichment links…");
    for (const p of plan) {
      const c = await checkUrl(p.url);
      const note = c.dead ? `DEAD(${c.status})` : `ok(${c.status || (c.to ? "timeout" : "?")})`;
      if (c.dead) dead++;
      console.log(`  ${note.padEnd(12)} ${p.id.slice(0, 60)}`);
    }
    console.log(dead ? `\n⚠ ${dead} link(s) look dead — review above.\n` : `\n✓ All ${plan.length} links OK.\n`);
  }

  if (!LIVE) {
    console.log("DRY RUN — no writes. Re-run with --live to apply.");
    console.log("\nWould DELETE:"); DELETE.forEach((d) => console.log("  - " + d));
    process.exit(0);
  }

  // Deletes
  let batch = db.batch();
  for (const id of DELETE) batch.delete(col.doc(id));
  await batch.commit();
  console.log(`✓ Deleted ${DELETE.length} duplicate drafts.`);

  // Enrichment (merge)
  batch = db.batch();
  let n = 0;
  for (const p of plan) {
    const u = {
      fullDescription: p.body.fullDescription,
      benefits: p.body.benefits,
      eligibility: p.body.eligibility,
      howToApply: p.body.howToApply,
      logoUrl: p.logoUrl,
      imageUrl: p.imageUrl,
      countries: p.countries,
      recommendationEligible: true,
      updatedAt: FieldValue.serverTimestamp(),
      updatedBy: "enrich-opportunities",
    };
    if (p.body.type) u.type = p.body.type;
    if (p.body.url) { u.applicationUrl = p.body.url; u.officialWebsite = p.body.url; }
    batch.set(col.doc(p.id), u, { merge: true });
    n++;
    if (n % 400 === 0) { await batch.commit(); batch = db.batch(); }
  }
  await batch.commit();
  console.log(`✓ Enriched ${n} drafts (About + benefits + eligibility + howToApply + logo + hero).`);
  process.exit(0);
}

main().catch((e) => { console.error("Enrich failed:", e); process.exit(1); });
