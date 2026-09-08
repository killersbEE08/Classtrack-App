/**
 * Seed REAL, currently-active student opportunities into the `resources`
 * collection as ready-to-publish DRAFTS.
 *
 * Every item is a genuine program (fellowships, scholarships, hackathons,
 * ambassador programs, grants, competitions, internships, startup programs,
 * research, courses, exchanges, conferences) with its official application
 * link and a working brand logo. Each is written with status = "draft", so it
 * is invisible to students until an editor reviews it in the CMS and hits
 * Publish. The categories map to `ResourceType`, which drives the category
 * filter chips on the Opportunities screen.
 *
 * Usage:
 *   node seed_opportunities.mjs               # DRY RUN — parse, verify every
 *                                             # official link + logo, write NOTHING
 *   node seed_opportunities.mjs --live        # write the drafts to Firestore
 *   node seed_opportunities.mjs --limit 5     # only the first 5 (test)
 *   node seed_opportunities.mjs --no-check     # skip the live URL/logo checks
 *
 * Notes:
 *   - Needs ./serviceAccount.json (present) OR gcloud ADC.
 *   - Idempotent: a deterministic doc id (seed-opp-NNN-slug) is used, so
 *     re-running UPDATES the same drafts instead of creating duplicates.
 *   - Image guarantee: logoUrl uses Clearbit; if that logo is dead at seed time
 *     it is swapped for Google's favicon service so every draft has an image.
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
const LIVE = process.argv.includes("--live");
const NO_CHECK = process.argv.includes("--no-check");
const LIMIT = parseInt(argValue("--limit", "0"), 10) || 0;

// ── Valid ResourceType keys (mirror of resource_type.dart) ───────────────────
const KNOWN_TYPES = new Set([
  "scholarship", "internship", "discount", "hackathon", "competition",
  "ambassador", "course", "certification", "research", "event", "job",
  "grant", "exchange", "conference", "startup",
]);

// ── Helpers ──────────────────────────────────────────────────────────────────
function slugify(s) {
  return s
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "")
    .slice(0, 80);
}
// Clearbit's public logo API was retired in 2025. We use icon.horse as the
// primary brand image — it returns a real PNG for every domain (PNG matters:
// Flutter's Image.network can't render SVG), with Google's favicon service as a
// fallback. Every draft is guaranteed a working PNG image.
const iconhorse = (domain) => `https://icon.horse/icon/${domain}`;
const favicon = (domain) => `https://www.google.com/s2/favicons?domain=${domain}&sz=128`;

// Category-themed hero banners (distinct from the brand logo), keyed by
// ResourceType. Real, verified Unsplash CDN photos (free to hot-link). This
// gives every draft a proper wide hero image while logoUrl stays the brand mark.
const UNSPLASH = (id) =>
  `https://images.unsplash.com/photo-${id}?w=1200&q=80&auto=format&fit=crop`;
const HERO_BY_TYPE = {
  scholarship: UNSPLASH("1541339907198-e08756dedf3f"), // graduation
  course: UNSPLASH("1516321318423-f06f85e504b3"),       // online study
  certification: UNSPLASH("1454165804606-c3d57bc86b40"),// desk / work
  internship: UNSPLASH("1497215728101-856f4ea42174"),   // office
  job: UNSPLASH("1521737711867-e3b97375f902"),           // team working
  hackathon: UNSPLASH("1504384308090-c894fdcc538d"),     // coding
  competition: UNSPLASH("1567427017947-545c5f8d16ad"),   // trophy
  ambassador: UNSPLASH("1522071820081-009f0129c71c"),    // community
  research: UNSPLASH("1532094349884-543bc11b234d"),      // lab / science
  event: UNSPLASH("1505373877841-8d25f7d46678"),         // event stage
  conference: UNSPLASH("1540575467063-178a50c2df87"),    // conference audience
  grant: UNSPLASH("1554224155-6726b3ff858f"),            // funding / finance
  startup: UNSPLASH("1559136555-9303baea8ebd"),          // startup meeting
  exchange: UNSPLASH("1488646953014-85cb44e25828"),      // travel / world
};
const heroFor = (type) => HERO_BY_TYPE[type] || HERO_BY_TYPE.scholarship;

// ── The dataset — real, live programs (Sept 2026) ────────────────────────────
// Each: { type, title, organization, domain, countries[], url, website?,
//         description, fullDescription, benefits, eligibility, howToApply,
//         requirements?, tags[], categories[], interests[] }
// `domain` powers the logo. `countries` empty => global. deadline is left null
// on purpose (recurring programs) so an editor sets it at publish time.
const DATA = [
  // ── AMBASSADOR / CAMPUS LEADER / FELLOWS ──────────────────────────────────
  {
    type: "ambassador",
    title: "Databricks Student Fellows",
    organization: "Databricks",
    domain: "databricks.com",
    countries: [],
    url: "https://www.databricks.com/university/student-fellows",
    description:
      "An exclusive program for university students passionate about computer science, AI, and data engineering to become recognised leaders on their campus.",
    fullDescription:
      "Databricks Student Fellows recognises students for exceptional contributions — impactful data and AI projects, building campus communities, and sharing knowledge with peers. Fellows are the campus catalysts who run hackathons, lead developer clubs, and mentor other students. Selected from thousands of applicants worldwide, fellows gain access to Databricks, mentorship, exclusive events, and a global community that connects academic learning with real-world data and AI work.",
    benefits:
      "Recognition as a campus leader, mentorship from Databricks, access to Databricks tools and training, exclusive community and events, and career-building opportunities in data and AI.",
    eligibility:
      "At least 18 years old and currently enrolled at an accredited educational institution. Passionate about computer science, AI, and data engineering. Not a Databricks employee/contractor.",
    howToApply:
      "Open the official Databricks Student Fellows page, review the program terms, and submit the application form when the cohort window is open.",
    tags: ["fellowship", "ai", "data-engineering", "campus-leader"],
    categories: ["Ambassador", "AI & Data"],
    interests: ["AI", "Data Science", "Computer Science", "Leadership"],
  },
  {
    type: "ambassador",
    title: "Microsoft Learn Student Ambassadors",
    organization: "Microsoft",
    domain: "microsoft.com",
    countries: [],
    url: "https://mvp.microsoft.com/studentambassadors",
    description:
      "A global community of students who lead in their local tech communities, build technical and leadership skills, and get exclusive Microsoft benefits.",
    fullDescription:
      "The Microsoft Learn Student Ambassadors program is a global community of students who collaborate, learn, and lead. Ambassadors develop technical and leadership skills by working on AI-driven projects, writing blogs, creating tutorials, hosting workshops, and organising events. As you complete milestones you unlock certificates, badges, and benefits, connecting with peers, Microsoft employees, and MVPs worldwide.",
    benefits:
      "Microsoft 365, Visual Studio Enterprise, monthly Azure credits, program certificates and badges, mentorship, and a global community of ambassadors, Microsoft employees, and MVPs.",
    eligibility:
      "Enrolled full-time at an accredited academic institution, aged 16+, passionate about technology and community building.",
    howToApply:
      "Apply through the Microsoft Learn Student Ambassadors site, complete onboarding, then advance milestones to unlock benefits.",
    tags: ["ambassador", "azure", "community", "leadership"],
    categories: ["Ambassador", "Cloud"],
    interests: ["Cloud", "Software Development", "Leadership", "AI"],
  },
  {
    type: "ambassador",
    title: "GitHub Campus Experts",
    organization: "GitHub Education",
    domain: "github.com",
    countries: [],
    url: "https://education.github.com/experts",
    description:
      "Student leaders who build inclusive tech communities on campus by running events, meetups, hackathons, and open-source projects.",
    fullDescription:
      "GitHub Campus Experts are student leaders who build diverse and inclusive spaces to learn, share experiences, and build projects together. With training and support from GitHub, Campus Experts lead conferences, meetups, and hackathons, maintain open-source projects, and grow their public speaking, organisational, and technical skills while helping peers build career skills.",
    benefits:
      "Official GitHub Campus Expert training, GitHub swag and credits, mentorship from GitHub staff, and a global network of student leaders.",
    eligibility:
      "Students aged 18+ enrolled at a degree-granting institution, active in their campus tech community.",
    howToApply:
      "Complete the GitHub Campus Experts application and the training curriculum at education.github.com/experts.",
    tags: ["ambassador", "open-source", "community", "campus-leader"],
    categories: ["Ambassador", "Open Source"],
    interests: ["Open Source", "Software Development", "Leadership"],
  },
  {
    type: "ambassador",
    title: "Postman Student Program",
    organization: "Postman",
    domain: "postman.com",
    countries: [],
    url: "https://www.postman.com/company/student-program/",
    description:
      "Learn and teach API skills as a Postman Student Leader or Student Expert, with resources, certification, and community support.",
    fullDescription:
      "The Postman Student Program helps students learn API development and share those skills on campus. Student Leaders host workshops and build API communities, while the Student Expert track certifies your API fundamentals. Participants get learning resources, Postman swag, and recognition that strengthens their resume for API and backend roles.",
    benefits:
      "Student Expert certification, workshop kits, Postman swag, mentorship, and community recognition.",
    eligibility:
      "Currently enrolled students interested in APIs, backend, and developer tooling.",
    howToApply:
      "Apply on the Postman Student Program page and complete the Student Expert training to get certified.",
    tags: ["ambassador", "api", "community", "certification"],
    categories: ["Ambassador", "Developer Tools"],
    interests: ["APIs", "Backend", "Software Development"],
  },
  {
    type: "ambassador",
    title: "Google Developer Groups on Campus",
    organization: "Google for Developers",
    domain: "google.com",
    countries: [],
    url: "https://developers.google.com/community/gdg",
    description:
      "University-based developer communities where students learn Google technologies, build projects, and lead events with peer support.",
    fullDescription:
      "Google Developer Groups (GDG) on Campus are university-based communities for students who want to learn about Google developer technologies. As an organiser or lead, you host workshops, study jams, and build events, growing your technical and leadership skills while connecting with a global Google developer community and mentors.",
    benefits:
      "Access to Google developer resources and events, leadership experience, mentorship, and a global student developer community.",
    eligibility:
      "University students interested in software development and community building.",
    howToApply:
      "Find or start a chapter and apply to become an organiser through the Google Developer Groups community site.",
    tags: ["ambassador", "community", "campus-leader"],
    categories: ["Ambassador", "Developer Community"],
    interests: ["Software Development", "Leadership", "AI", "Cloud"],
  },

  // ── SCHOLARSHIP ───────────────────────────────────────────────────────────
  {
    type: "scholarship",
    title: "Generation Google Scholarship",
    organization: "Google",
    domain: "google.com",
    countries: [],
    url: "https://buildyourfuture.withgoogle.com/scholarships",
    description:
      "Financial support for aspiring computer scientists from historically excluded groups who are committed to excelling in tech and becoming leaders.",
    fullDescription:
      "The Generation Google Scholarship helps aspiring computer scientists excel in technology and become leaders in the field. Recipients receive financial support toward their education plus an invitation to a virtual retreat with community-building, development sessions, and connections to Googlers. Multiple regional versions exist (North America, EMEA, Asia Pacific).",
    benefits:
      "Financial award toward tuition (e.g. USD 10,000 in the US / CAD 5,000 in Canada, varies by region) and access to a Google scholars community and retreat.",
    eligibility:
      "Current or incoming undergraduate/graduate students studying computer science or a closely related field, with a strong academic record and demonstrated leadership.",
    howToApply:
      "Apply on Google's Build Your Future scholarships page during the annual application window with transcripts and short essays.",
    tags: ["scholarship", "diversity", "computer-science"],
    categories: ["Scholarship", "Computer Science"],
    interests: ["Computer Science", "Software Development", "Leadership"],
  },
  {
    type: "scholarship",
    title: "Amazon Future Engineer Scholarship",
    organization: "Amazon",
    domain: "amazon.com",
    countries: ["United States"],
    url: "https://www.amazonfutureengineer.com/scholarships",
    description:
      "Up to $40,000 for students from underserved communities pursuing computer science, plus a guaranteed paid Amazon internship offer.",
    fullDescription:
      "The Amazon Future Engineer Scholarship supports students from underserved communities pursuing computer science degrees with up to $10,000 per year for four years and a paid summer internship at Amazon. It is part of Amazon Future Engineer, a childhood-to-career program that increases access to computer science education.",
    benefits:
      "Up to $10,000/year for four years (up to $40,000 total) and a guaranteed paid summer internship offer at Amazon.",
    eligibility:
      "High school seniors from underserved communities in the US, planning to pursue a computer science or related bachelor's degree, with financial need.",
    howToApply:
      "Apply on the Amazon Future Engineer scholarships page during the annual cycle; sign up for the newsletter to be notified when it reopens.",
    tags: ["scholarship", "computer-science", "internship"],
    categories: ["Scholarship", "Computer Science"],
    interests: ["Computer Science", "Software Development"],
  },
  {
    type: "scholarship",
    title: "Reliance Foundation Undergraduate Scholarships",
    organization: "Reliance Foundation",
    domain: "reliancefoundation.org",
    countries: ["India"],
    url: "https://scholarships.reliancefoundation.org/UG_Scholarship.aspx",
    description:
      "Merit-cum-means scholarships for first-year undergraduate students in India across any stream, with awards up to ₹2 lakh.",
    fullDescription:
      "The Reliance Foundation Undergraduate Scholarships support talented first-year undergraduate students in India from households earning under ₹15 lakh, across any subject stream. The program supports 5,000 undergraduate scholars annually and actively encourages applications from girls and specially-abled students, as part of Reliance Foundation's mission to nurture India's next generation of leaders and innovators.",
    benefits:
      "Scholarship grant up to ₹2,00,000 over the course, plus access to a scholar network and development opportunities.",
    eligibility:
      "First-year undergraduate students in India (any stream) with a household income under ₹15 lakh. Girls and specially-abled students especially encouraged.",
    howToApply:
      "Register and apply on the Reliance Foundation Scholarships portal, complete the aptitude assessment, and upload the required documents.",
    tags: ["scholarship", "india", "undergraduate", "need-based"],
    categories: ["Scholarship", "India"],
    interests: ["Higher Education", "STEM"],
  },
  {
    type: "scholarship",
    title: "Reliance Foundation Postgraduate Scholarships",
    organization: "Reliance Foundation",
    domain: "reliancefoundation.org",
    countries: ["India"],
    url: "https://scholarships.reliancefoundation.org/PG_Scholarship.aspx",
    description:
      "Scholarships for postgraduate students in India in science and technology fields, nurturing future scientists and technologists.",
    fullDescription:
      "The Reliance Foundation Postgraduate Scholarship aims to nurture a new generation of scientists, technologists, and changemakers who will lead India forward. It supports 100 postgraduate scholars annually across priority science and technology disciplines with substantial financial awards and access to a scholar community.",
    benefits:
      "Scholarship grant up to ₹6,00,000 over the program, plus mentorship and a scholar network.",
    eligibility:
      "Students enrolled in eligible postgraduate programmes in India in specified science/technology disciplines. Study abroad is not eligible.",
    howToApply:
      "Apply through the Reliance Foundation Scholarships portal, complete the assessment, and submit academic documents.",
    tags: ["scholarship", "india", "postgraduate", "stem"],
    categories: ["Scholarship", "India"],
    interests: ["STEM", "Research", "Higher Education"],
  },
  {
    type: "scholarship",
    title: "Adobe Research Women-in-Technology Scholarship",
    organization: "Adobe Research",
    domain: "adobe.com",
    countries: ["United States", "Canada", "Mexico"],
    url: "https://research.adobe.com/scholarship/why-apply/",
    description:
      "Recognises outstanding female undergraduate and master's students in AI/ML, data science, CS, and web/mobile development in North America.",
    fullDescription:
      "The Adobe Research Women-in-Technology Scholarship recognises outstanding undergraduate and master's female students studying artificial intelligence / machine learning, data science, computer science, or mobile/web development at North American universities. It reflects Adobe's commitment to enhancing gender diversity in technology and offers financial support plus connections to Adobe researchers.",
    benefits:
      "Cash scholarship award, an Adobe Creative Cloud subscription, mentorship, and an invitation to connect with Adobe Research.",
    eligibility:
      "Female undergraduate and master's students in AI/ML, data science, computer science, or web/mobile development at a North American university.",
    howToApply:
      "Submit the online application on the Adobe Research scholarship page with essays, a resume, and recommendation letters during the annual window.",
    tags: ["scholarship", "women-in-tech", "ai", "diversity"],
    categories: ["Scholarship", "Women in Tech"],
    interests: ["AI", "Computer Science", "Data Science"],
  },
  {
    type: "scholarship",
    title: "Knight-Hennessy Scholars",
    organization: "Stanford University",
    domain: "stanford.edu",
    countries: [],
    url: "https://knight-hennessy.stanford.edu/",
    description:
      "A fully funded graduate fellowship at Stanford developing a community of future global leaders across all disciplines.",
    fullDescription:
      "Knight-Hennessy Scholars is a highly selective, fully funded graduate scholarship at Stanford University. Scholars pursue graduate degrees across any of Stanford's schools while participating in the King Global Leadership Program, which builds the knowledge, skills, and character to lead in a complex world. It is open to citizens of all countries.",
    benefits:
      "Full funding for up to three years of a Stanford graduate degree (tuition, stipend, travel) plus a global leadership development program.",
    eligibility:
      "Applicants of any nationality who have earned their first/bachelor's degree recently and are applying to (or enrolling in) a full-time Stanford graduate program.",
    howToApply:
      "Submit the Knight-Hennessy application and separately apply to a Stanford graduate program within the same admissions year.",
    tags: ["fellowship", "graduate", "leadership", "fully-funded"],
    categories: ["Scholarship", "Graduate"],
    interests: ["Leadership", "Research", "Higher Education"],
  },
  {
    type: "scholarship",
    title: "Rise (Schmidt Futures & Rhodes Trust)",
    organization: "Rise",
    domain: "risefortheworld.org",
    countries: [],
    url: "https://www.risefortheworld.org/",
    description:
      "A global program finding brilliant 15–17 year olds and supporting them for life with scholarships, mentorship, and funding.",
    fullDescription:
      "Rise is the anchor program of a $1 billion commitment from Schmidt Futures and the Rhodes Trust. It finds talented young people aged 15–17 who need opportunity and supports them for life as they work to serve others. Benefits can include scholarships, mentorship, access to funding, career development, and a global network of peers.",
    benefits:
      "Need-based scholarships, mentorship, career development, access to funding for ventures, technology, and a lifelong global network.",
    eligibility:
      "Young people aged 15–17 (at time of application) from anywhere in the world who demonstrate promise and a commitment to serving others.",
    howToApply:
      "Complete the Rise challenge and submit a project/portfolio through the Rise for the World platform during the annual cycle.",
    tags: ["scholarship", "teens", "mentorship", "global"],
    categories: ["Scholarship", "Global"],
    interests: ["Leadership", "Social Impact", "STEM"],
  },

  // ── RESEARCH / PhD FELLOWSHIPS ────────────────────────────────────────────
  {
    type: "research",
    title: "Google PhD Fellowship Program",
    organization: "Google Research",
    domain: "google.com",
    countries: [],
    url: "https://research.google/programs-and-events/phd-fellowship/",
    description:
      "Recognises and funds outstanding graduate students doing innovative research in computer science and related fields.",
    fullDescription:
      "The Google PhD Fellowship Program recognises outstanding graduate students doing exceptional and innovative research in areas relevant to computer science and related fields. It supports promising PhD candidates of all backgrounds who seek to influence the future of technology, providing funding and mentorship from a Google researcher.",
    benefits:
      "Financial support covering tuition and a stipend (varies by region), plus mentorship from a Google Research mentor.",
    eligibility:
      "PhD students (typically having completed some graduate study) nominated by their university in eligible research areas.",
    howToApply:
      "Applications are submitted by universities that nominate their students during the annual regional application windows.",
    tags: ["fellowship", "phd", "research", "ai"],
    categories: ["Research", "AI"],
    interests: ["Research", "AI", "Computer Science"],
  },
  {
    type: "research",
    title: "Microsoft Research PhD Fellowship",
    organization: "Microsoft Research",
    domain: "microsoft.com",
    countries: [],
    url: "https://www.microsoft.com/en-us/research/academic-program/phd-fellowship/",
    description:
      "A fellowship supporting outstanding PhD students conducting research aligned with Microsoft Research's mission.",
    fullDescription:
      "The Microsoft Research PhD Fellowship supports exceptional doctoral students engaged in innovative, high-impact research in computing-related fields such as AI, systems, security, and human-computer interaction. Fellows receive financial support and the opportunity to connect with Microsoft researchers, and are often considered for research internships.",
    benefits:
      "Tuition and fees covered plus an annual stipend for up to two years, and connections to Microsoft researchers and potential internships.",
    eligibility:
      "PhD students (typically in their early years) at eligible universities, nominated by their institution in relevant research areas.",
    howToApply:
      "Applications are submitted by universities that nominate students; check the Microsoft Research fellowship page for your region's process and window.",
    tags: ["fellowship", "phd", "research", "computing"],
    categories: ["Research", "Computing"],
    interests: ["Research", "AI", "Computer Science"],
  },
  {
    type: "research",
    title: "MITACS Globalink Research Internship",
    organization: "Mitacs",
    domain: "mitacs.ca",
    countries: [],
    url: "https://www.mitacs.ca/our-programs/globalink-research-internship-students/",
    description:
      "A 12-week research internship in Canada for top international undergraduates, working with a university professor.",
    fullDescription:
      "The Mitacs Globalink Research Internship is a competitive initiative for top international undergraduate students from select countries. Interns spend 12 weeks over the summer at a Canadian university working on a research project under a faculty supervisor, gaining hands-on research experience and a pathway to future graduate studies in Canada.",
    benefits:
      "Funded 12-week research placement at a Canadian university, travel and living support, faculty mentorship, and a pathway to Canadian graduate programs.",
    eligibility:
      "International undergraduates from eligible countries (incl. India, Brazil, France, Germany, etc.) meeting the year-of-study and GPA requirements.",
    howToApply:
      "Apply through the Mitacs Globalink portal, ranking preferred research projects and supervisors during the annual call.",
    tags: ["research", "internship", "canada", "global"],
    categories: ["Research", "Internship"],
    interests: ["Research", "STEM", "Higher Education"],
  },
  {
    type: "research",
    title: "Caltech Summer Undergraduate Research Fellowships (SURF)",
    organization: "Caltech",
    domain: "caltech.edu",
    countries: [],
    url: "https://www.surf.caltech.edu/",
    description:
      "A 10-week paid summer research program pairing undergraduates with Caltech faculty mentors on cutting-edge projects.",
    fullDescription:
      "Caltech's Summer Undergraduate Research Fellowships (SURF) invite undergraduates to experience the process of research. Students collaborate with a faculty mentor to define a project, write a proposal, conduct the work over about 10 weeks in the summer, and present their results — mirroring the full arc of scientific research.",
    benefits:
      "Paid summer research stipend, close faculty mentorship, and experience presenting original research at a seminar day.",
    eligibility:
      "Undergraduate students (Caltech and visiting students from other institutions) in science and engineering fields.",
    howToApply:
      "Identify a Caltech mentor and project, then submit a research proposal through the SURF application by the deadline.",
    tags: ["research", "internship", "summer", "stem"],
    categories: ["Research", "Internship"],
    interests: ["Research", "STEM", "Engineering"],
  },

  // ── FELLOWSHIPS -> mapped types ───────────────────────────────────────────
  {
    type: "internship",
    title: "KP Fellows (Kleiner Perkins Fellowship)",
    organization: "Kleiner Perkins",
    domain: "kleinerperkins.com",
    countries: ["United States"],
    url: "https://www.kleinerperkins.com/fellows/",
    description:
      "A summer fellowship placing top engineering, design, and product students at leading venture-backed startups.",
    fullDescription:
      "The KP Fellows Program places outstanding engineering, design, and product students in paid summer roles at top venture-backed companies. Fellows work on real products at startups like Figma, Harvey, and Nooks, while joining a curated community, mentorship sessions, and events with founders and investors — a launchpad for the next generation of builders and founders.",
    benefits:
      "Paid summer role at a leading startup, a cohort community, mentorship from founders and Kleiner Perkins partners, and exclusive events.",
    eligibility:
      "Undergraduate and graduate students pursuing engineering, design, or product management, typically based in or able to work in the US.",
    howToApply:
      "Apply on the KP Fellows site when applications open (typically January); select engineering, design, or product track.",
    tags: ["fellowship", "startup", "internship", "product"],
    categories: ["Internship", "Startup"],
    interests: ["Software Development", "Design", "Product Management"],
  },
  {
    type: "startup",
    title: "Z Fellows",
    organization: "Z Fellows",
    domain: "zfellows.com",
    countries: [],
    url: "https://www.zfellows.com/",
    description:
      "A one-week program plus $10,000 that fast-tracks ambitious builders into the Silicon Valley startup network.",
    fullDescription:
      "Z Fellows is a one-week experience that brings together a small group of builders with founders of billion-dollar companies. Fellows receive a $10,000 grant (structured as a small investment) and lifelong support for their company. It runs frequent cohorts and is open to students, dropouts, and early founders worldwide.",
    benefits:
      "$10,000 grant, a one-week intensive with top founders, and ongoing support and introductions for the life of your company.",
    eligibility:
      "Ambitious builders — students, researchers, or early founders — anywhere in the world with a project or startup idea.",
    howToApply:
      "Submit the short application on the Z Fellows site; cohorts run on a rolling basis throughout the year.",
    tags: ["fellowship", "startup", "grant", "founders"],
    categories: ["Startup", "Grant"],
    interests: ["Entrepreneurship", "Startups", "Software Development"],
  },
  {
    type: "startup",
    title: "Thiel Fellowship",
    organization: "Thiel Foundation",
    domain: "thielfellowship.org",
    countries: [],
    url: "https://thielfellowship.org/",
    description:
      "$100,000 over two years for young people who want to build new things instead of sitting in a classroom.",
    fullDescription:
      "Founded by Peter Thiel in 2011, the Thiel Fellowship is a two-year program that gives 20–25 young people $100,000 each to skip or leave college and work on a company, research, or a technical project. Fellows join a network of founders, investors, and scientists and receive mentorship as they build.",
    benefits:
      "$100,000 grant over two years, mentorship, and access to the Thiel Foundation's network of founders and investors.",
    eligibility:
      "Young people (typically 22 or under) anywhere in the world with an ambitious idea they want to build full-time.",
    howToApply:
      "Apply on the Thiel Fellowship site with details of your project; applications are reviewed on a rolling basis.",
    tags: ["fellowship", "startup", "grant", "founders"],
    categories: ["Startup", "Grant"],
    interests: ["Entrepreneurship", "Startups", "Research"],
  },
  {
    type: "job",
    title: "OpenAI Residency",
    organization: "OpenAI",
    domain: "openai.com",
    countries: ["United States"],
    url: "https://openai.com/residency/",
    description:
      "A paid, full-time pathway into AI research for exceptional people from non-traditional or adjacent backgrounds.",
    fullDescription:
      "The OpenAI Residency is a six-month, paid, full-time program that offers a pathway into working in AI for people who are not currently working in the field — including researchers in other domains (physics, neuroscience, math) and strong engineers. Residents work alongside OpenAI's teams and many convert to full-time roles.",
    benefits:
      "Competitive salary for six months, mentorship from OpenAI researchers and engineers, and a strong chance of a full-time offer.",
    eligibility:
      "Exceptional individuals from adjacent technical fields or engineering backgrounds looking to transition into AI; based in or able to relocate to the US.",
    howToApply:
      "Apply through the OpenAI Residency page with your resume and background; roles open periodically.",
    tags: ["fellowship", "ai", "research", "residency"],
    categories: ["Job", "AI"],
    interests: ["AI", "Research", "Software Development"],
  },

  // ── INTERNSHIP / OPEN SOURCE ──────────────────────────────────────────────
  {
    type: "internship",
    title: "Google Summer of Code",
    organization: "Google Open Source",
    domain: "google.com",
    countries: [],
    url: "https://summerofcode.withgoogle.com/",
    description:
      "A global, paid, online program that pairs new contributors with open-source organisations for a 12+ week project.",
    fullDescription:
      "Google Summer of Code (GSoC) is a global, online program focused on bringing new contributors into open-source software development. Participants work with an open-source organisation on a 12+ week programming project under the guidance of experienced mentors, receiving a stipend upon completing milestones.",
    benefits:
      "A stipend (amount varies by country), real open-source experience, mentorship, and a lasting network in the open-source community.",
    eligibility:
      "Open to new open-source contributors aged 18+, including students and beginners to open source.",
    howToApply:
      "Browse participating organisations, engage with a community, then submit a project proposal during the annual application window.",
    tags: ["internship", "open-source", "coding", "stipend"],
    categories: ["Internship", "Open Source"],
    interests: ["Open Source", "Software Development"],
  },
  {
    type: "internship",
    title: "Outreachy",
    organization: "Software Freedom Conservancy",
    domain: "outreachy.org",
    countries: [],
    url: "https://www.outreachy.org/",
    description:
      "Paid, remote open-source internships for people subject to systemic bias and underrepresented in tech.",
    fullDescription:
      "Outreachy provides paid, remote, three-month internships in open source and open science to people who are subject to systemic bias and impacted by underrepresentation in the technical industry. Interns work with experienced mentors on real projects and join a supportive alumni community.",
    benefits:
      "USD 7,000 internship stipend, a remote three-month project with mentorship, and a travel/conference stipend.",
    eligibility:
      "Anyone (student or not) facing underrepresentation or systemic bias in tech in their region, available for a full-time remote internship.",
    howToApply:
      "Apply during the Outreachy initial application period, then complete contributions to a chosen project before final selection.",
    tags: ["internship", "open-source", "diversity", "remote"],
    categories: ["Internship", "Open Source"],
    interests: ["Open Source", "Software Development", "Diversity"],
  },
  {
    type: "internship",
    title: "LFX Mentorship",
    organization: "The Linux Foundation",
    domain: "linuxfoundation.org",
    countries: [],
    url: "https://mentorship.lfx.linuxfoundation.org/",
    description:
      "Paid remote mentorships helping developers contribute to major open-source projects like Kubernetes and CNCF.",
    fullDescription:
      "LFX Mentorship from the Linux Foundation offers paid, remote mentorships (typically 12 weeks) that help new developers gain hands-on experience contributing to critical open-source projects across cloud native, networking, security, and more. Mentees are guided by experienced maintainers and build a public contribution record.",
    benefits:
      "Mentorship stipend, remote work with expert maintainers, and real contributions to widely used open-source projects.",
    eligibility:
      "Developers new to a project — students and early-career contributors welcome; requirements set per mentorship.",
    howToApply:
      "Browse open mentorships on the LFX platform and apply to specific projects during their application windows.",
    tags: ["internship", "open-source", "cloud-native", "remote"],
    categories: ["Internship", "Open Source"],
    interests: ["Open Source", "Cloud", "Software Development"],
  },
  {
    type: "internship",
    title: "Summer of Bitcoin",
    organization: "Summer of Bitcoin",
    domain: "summerofbitcoin.org",
    countries: [],
    url: "https://www.summerofbitcoin.org/",
    description:
      "A global summer program introducing students to open-source Bitcoin and Lightning development with stipends.",
    fullDescription:
      "Summer of Bitcoin is a global, online summer program that introduces university students to Bitcoin open-source development and design. Accepted students train, then contribute to real Bitcoin and Lightning projects under experienced mentors, earning a stipend and building a portfolio in one of the most in-demand areas of software.",
    benefits:
      "Stipend, structured training, mentorship from Bitcoin developers, and real open-source contribution experience.",
    eligibility:
      "University students (and recent grads in some cases) with programming or design skills interested in Bitcoin/open source.",
    howToApply:
      "Apply on the Summer of Bitcoin site, complete the qualification tasks, and get matched with a project and mentor.",
    tags: ["internship", "open-source", "bitcoin", "stipend"],
    categories: ["Internship", "Open Source"],
    interests: ["Open Source", "Blockchain", "Software Development"],
  },

  // ── HACKATHON ─────────────────────────────────────────────────────────────
  {
    type: "hackathon",
    title: "Major League Hacking (MLH)",
    organization: "Major League Hacking",
    domain: "mlh.io",
    countries: [],
    url: "https://mlh.io/",
    description:
      "The official student hackathon league — hundreds of weekend hackathons and fellowships for developers worldwide.",
    fullDescription:
      "Major League Hacking (MLH) is the official student hackathon league. Every year, MLH powers hundreds of weekend-long invention competitions that inspire innovation, build community, and teach skills. Students can attend member hackathons, join the MLH Fellowship for remote open-source and software engineering experience, and win sponsor prizes.",
    benefits:
      "Access to a global calendar of hackathons, prizes and sponsor challenges, workshops, swag, and the MLH Fellowship program.",
    eligibility:
      "Students and early-career developers of all skill levels; most events welcome beginners.",
    howToApply:
      "Browse upcoming events on mlh.io and register for individual hackathons or apply to the MLH Fellowship.",
    tags: ["hackathon", "community", "coding", "fellowship"],
    categories: ["Hackathon", "Community"],
    interests: ["Software Development", "Hackathons", "Open Source"],
  },
  {
    type: "hackathon",
    title: "Smart India Hackathon",
    organization: "Government of India (Ministry of Education)",
    domain: "sih.gov.in",
    countries: ["India"],
    url: "https://www.sih.gov.in/",
    description:
      "India's nationwide hackathon where student teams solve real problem statements from ministries and industry.",
    fullDescription:
      "Smart India Hackathon (SIH) is a nationwide initiative by the Government of India to engage students in solving pressing problems faced by ministries, departments, and industries. Teams tackle real problem statements in software and hardware editions, with grand finales held across the country and significant cash prizes.",
    benefits:
      "Cash prizes (e.g. ₹1,00,000 per winning team per problem statement), national recognition, mentorship, and pathways to internships and incubation.",
    eligibility:
      "Teams of students from recognised Indian institutions (AICTE/UGC), registered through their college's SPOC.",
    howToApply:
      "Register your team through your institution's Single Point of Contact (SPOC) and submit ideas against published problem statements.",
    tags: ["hackathon", "india", "government", "competition"],
    categories: ["Hackathon", "India"],
    interests: ["Software Development", "Hackathons", "Innovation"],
  },
  {
    type: "hackathon",
    title: "Devpost Hackathons",
    organization: "Devpost",
    domain: "devpost.com",
    countries: [],
    url: "https://devpost.com/hackathons",
    description:
      "The largest directory of online and in-person hackathons, with prizes from top tech companies year-round.",
    fullDescription:
      "Devpost is the home for hackathons — a continuously updated directory of online and in-person events hosted by companies and communities worldwide. Students can filter by theme (AI, web3, health), join solo or in teams, submit projects, and win cash and hardware prizes while building a public project portfolio.",
    benefits:
      "Year-round access to hundreds of hackathons, cash and hardware prizes, a public project portfolio, and recruiter visibility.",
    eligibility:
      "Open to developers, designers, and students worldwide; individual event rules vary.",
    howToApply:
      "Create a Devpost account, browse open hackathons, register, and submit your project before each event's deadline.",
    tags: ["hackathon", "online", "prizes", "portfolio"],
    categories: ["Hackathon", "Community"],
    interests: ["Software Development", "Hackathons", "AI"],
  },

  // ── COMPETITION ───────────────────────────────────────────────────────────
  {
    type: "competition",
    title: "Microsoft Imagine Cup",
    organization: "Microsoft",
    domain: "microsoft.com",
    countries: [],
    url: "https://imaginecup.microsoft.com/",
    description:
      "Microsoft's premier global student startup competition, turning tech ideas into real ventures with mentorship and prizes.",
    fullDescription:
      "The Imagine Cup is Microsoft's flagship global competition for student founders. Student teams build technology solutions (increasingly AI-powered on Azure) to real-world challenges, progress through rounds with mentorship, and compete for major cash prizes, Azure credits, and a mentoring session with Microsoft's CEO in the World Championship.",
    benefits:
      "Cash prizes up to USD 100,000, Azure credits, mentorship, and global visibility for your startup idea.",
    eligibility:
      "Students aged 16+ enrolled in an accredited institution, competing individually or in teams of up to four.",
    howToApply:
      "Register your team on the Imagine Cup site and submit your project to enter the current season's rounds.",
    tags: ["competition", "startup", "ai", "azure"],
    categories: ["Competition", "Startup"],
    interests: ["Entrepreneurship", "AI", "Software Development"],
  },
  {
    type: "competition",
    title: "Samsung Solve for Tomorrow (India)",
    organization: "Samsung",
    domain: "samsung.com",
    countries: ["India"],
    url: "https://www.samsung.com/in/solvefortomorrow/",
    description:
      "A nationwide innovation contest for young Indians (14–22) to build tech solutions for real community problems.",
    fullDescription:
      "Samsung Solve for Tomorrow is a global CSR initiative present in 60+ countries; in India it empowers people aged 14–22 to identify pressing community challenges and build STEM/AI-based solutions through design thinking, mentorship, and incubation. The 2026 edition offers incubation grants worth ₹2 crore to top teams with support at IIT Delhi.",
    benefits:
      "Incubation grants (₹2 crore pool for top teams in 2026), mentorship, design-thinking training, and incubation support at IIT Delhi.",
    eligibility:
      "Indian residents aged 14–22, applying individually or in teams of up to three with an original tech/social-impact concept.",
    howToApply:
      "Register and submit your idea on the Samsung Solve for Tomorrow India website during the open application window.",
    tags: ["competition", "india", "innovation", "social-impact"],
    categories: ["Competition", "India"],
    interests: ["Innovation", "STEM", "Social Impact"],
  },
  {
    type: "competition",
    title: "ICPC — International Collegiate Programming Contest",
    organization: "ICPC Foundation",
    domain: "icpc.global",
    countries: [],
    url: "https://icpc.global/",
    description:
      "The world's oldest and most prestigious competitive programming contest for university teams.",
    fullDescription:
      "The International Collegiate Programming Contest (ICPC) is the premier global algorithmic programming contest for universities. Teams of three students solve complex algorithmic problems against the clock, advancing from regional contests to the World Finals. ICPC is a proven springboard to top engineering roles worldwide.",
    benefits:
      "Global recognition, a path from regionals to the World Finals, scholarships/awards, and strong visibility to top tech recruiters.",
    eligibility:
      "Teams of three enrolled university students meeting ICPC eligibility (year/age limits), registered via their institution.",
    howToApply:
      "Form a team of three and register through your regional ICPC contest on icpc.global.",
    tags: ["competition", "programming", "algorithms", "teams"],
    categories: ["Competition", "Programming"],
    interests: ["Competitive Programming", "Algorithms", "Software Development"],
  },
  {
    type: "competition",
    title: "Kaggle Competitions",
    organization: "Kaggle (Google)",
    domain: "kaggle.com",
    countries: [],
    url: "https://www.kaggle.com/competitions",
    description:
      "Real-world machine learning competitions with cash prizes, ranking points, and a global data science community.",
    fullDescription:
      "Kaggle hosts machine learning and data science competitions where participants build models to solve real problems posted by companies and researchers. Students can compete for cash prizes, climb the global rankings toward Kaggle Master/Grandmaster status, and learn from public notebooks and a large community.",
    benefits:
      "Cash prizes on featured competitions, ranking points and medals, free GPUs/TPUs, and a portfolio recognised by ML recruiters.",
    eligibility:
      "Open to anyone with a Kaggle account; most competitions welcome beginners and students.",
    howToApply:
      "Create a free Kaggle account, join an open competition, and submit your model predictions before the deadline.",
    tags: ["competition", "machine-learning", "data-science", "prizes"],
    categories: ["Competition", "AI & Data"],
    interests: ["Machine Learning", "Data Science", "AI"],
  },

  // ── STARTUP PROGRAMS ──────────────────────────────────────────────────────
  {
    type: "startup",
    title: "Microsoft for Startups Founders Hub",
    organization: "Microsoft",
    domain: "microsoft.com",
    countries: [],
    url: "https://www.microsoft.com/startups",
    description:
      "Free Azure credits, AI models, and expert guidance for early founders — no funding required to join.",
    fullDescription:
      "Microsoft for Startups Founders Hub gives early-stage founders free access to leading AI models through Azure (including OpenAI models), up to $150,000 in Azure credits, developer tools like GitHub, and one-on-one guidance from Microsoft experts. It is open to anyone building a startup — no external funding required.",
    benefits:
      "Up to $150,000 in Azure credits, free access to AI models, GitHub Enterprise, developer tools, and mentorship.",
    eligibility:
      "Founders building a software-based startup; no incorporation or funding threshold required to start.",
    howToApply:
      "Sign up on the Microsoft for Startups Founders Hub portal and unlock benefits in tiers as your startup grows.",
    tags: ["startup", "cloud", "ai", "credits"],
    categories: ["Startup", "Cloud"],
    interests: ["Entrepreneurship", "Cloud", "AI"],
  },
  {
    type: "startup",
    title: "NVIDIA Inception",
    organization: "NVIDIA",
    domain: "nvidia.com",
    countries: [],
    url: "https://www.nvidia.com/en-us/startups/",
    description:
      "A free accelerator for AI and data-science startups, with hardware discounts, cloud credits, and technical support.",
    fullDescription:
      "NVIDIA Inception is a free program that nurtures startups building in AI, data science, and accelerated computing. Members get hardware and software discounts, cloud credits from partners, technical training and support, go-to-market help, and exposure to NVIDIA's investor network — with no equity taken.",
    benefits:
      "Hardware and DGX Cloud discounts, partner cloud credits, technical training, VC introductions, and co-marketing — no equity required.",
    eligibility:
      "Startups incorporated and building in AI/ML, data science, or accelerated computing (any stage).",
    howToApply:
      "Apply on the NVIDIA Inception page with your company details to be reviewed and onboarded.",
    tags: ["startup", "ai", "accelerator", "credits"],
    categories: ["Startup", "AI"],
    interests: ["Entrepreneurship", "AI", "Deep Learning"],
  },
  {
    type: "startup",
    title: "AWS Activate",
    organization: "Amazon Web Services",
    domain: "aws.amazon.com",
    countries: [],
    url: "https://aws.amazon.com/activate/",
    description:
      "Up to $100,000 in AWS credits plus technical support and training for eligible startups.",
    fullDescription:
      "AWS Activate provides startups with free tools, resources, and up to $100,000 in AWS credits (tier depends on eligibility and accelerator/VC affiliation), along with technical support, training, and architecture guidance to build and scale on AWS.",
    benefits:
      "Up to $100,000 in AWS credits, AWS support credits, training, and hands-on architectural guidance.",
    eligibility:
      "Early-stage startups; higher credit tiers require affiliation with an AWS Activate Provider (accelerator, incubator, or VC).",
    howToApply:
      "Apply through the AWS Activate portal (Founders tier is self-serve; Portfolio tier via a provider organisation).",
    tags: ["startup", "cloud", "credits"],
    categories: ["Startup", "Cloud"],
    interests: ["Entrepreneurship", "Cloud", "Software Development"],
  },
  {
    type: "startup",
    title: "Y Combinator",
    organization: "Y Combinator",
    domain: "ycombinator.com",
    countries: [],
    url: "https://www.ycombinator.com/apply",
    description:
      "The world's most famous startup accelerator — funding, mentorship, and a legendary founder network twice a year.",
    fullDescription:
      "Y Combinator funds early-stage startups twice a year and works intensively with them for three months to get into the best possible shape. YC invests a standard deal, provides world-class mentorship and weekly group sessions, culminates in Demo Day in front of investors, and offers a lifelong founder network. Student and recent-grad founders are strongly represented.",
    benefits:
      "Standard YC investment (USD 500,000), three months of intensive mentorship, Demo Day exposure to investors, and the YC alumni network.",
    eligibility:
      "Startup founders at any stage worldwide, including students and recent graduates with a co-founding team or strong solo profile.",
    howToApply:
      "Submit the YC application before the batch deadline; late applications are still reviewed on a rolling basis.",
    tags: ["startup", "accelerator", "funding", "founders"],
    categories: ["Startup", "Accelerator"],
    interests: ["Entrepreneurship", "Startups", "Software Development"],
  },
  {
    type: "startup",
    title: "Google for Startups",
    organization: "Google",
    domain: "google.com",
    countries: [],
    url: "https://startup.google.com/",
    description:
      "Programs, Cloud credits, and mentorship for founders — including dedicated accelerators for AI, women, and more.",
    fullDescription:
      "Google for Startups connects founders with Google's people, products, and best practices. It runs equity-free accelerators (including AI-first and Women Founders tracks), offers Google Cloud credits, and provides mentorship, technical training, and community, helping startups grow at every stage.",
    benefits:
      "Google Cloud credits, equity-free accelerator programs, mentorship from Googlers, and access to Google's partner network.",
    eligibility:
      "Startups from pre-seed to growth stage; specific accelerators have their own regional and stage criteria.",
    howToApply:
      "Explore programs on the Google for Startups site and apply to the accelerator or offer that matches your stage and region.",
    tags: ["startup", "accelerator", "cloud", "credits"],
    categories: ["Startup", "Accelerator"],
    interests: ["Entrepreneurship", "Cloud", "AI"],
  },

  // ── GRANT ─────────────────────────────────────────────────────────────────
  {
    type: "grant",
    title: "Fund My Crazy 2.0 with Google Gemini",
    organization: "Google",
    domain: "fundmycrazy.com",
    countries: ["India"],
    url: "https://fundmycrazy.com/",
    description:
      "A student-first national contest in India funding the boldest ideas built with Gemini — win funding up to ₹1 crore.",
    fullDescription:
      "Fund My Crazy is a Google Gemini initiative launched as a student-first national contest in India to reward and fund the most innovative ideas — from solving everyday campus problems to reimagining the future of cities. Students use Gemini as a thinking partner to develop their concept, and the top ideas win funding of up to ₹1 crore. The first edition drew tens of thousands of entries across India.",
    benefits:
      "Funding of up to ₹1 crore for winning ideas, national recognition, and mentorship using Google Gemini.",
    eligibility:
      "Students based in India (individuals or teams) with an original innovative idea developed using Google Gemini.",
    howToApply:
      "Submit your idea on the Fund My Crazy site during the open contest window, showing how you used Gemini to develop it.",
    tags: ["grant", "india", "gemini", "competition", "funding"],
    categories: ["Grant", "India"],
    interests: ["Innovation", "AI", "Entrepreneurship"],
  },

  // ── COURSE / CERTIFICATION (free for students) ────────────────────────────
  {
    type: "course",
    title: "freeCodeCamp",
    organization: "freeCodeCamp",
    domain: "freecodecamp.org",
    countries: [],
    url: "https://www.freecodecamp.org/",
    description:
      "Thousands of hours of free coding lessons and free developer certifications, all open to everyone.",
    fullDescription:
      "freeCodeCamp is a nonprofit offering a full, free curriculum covering web development, data analysis, machine learning, and more. Learners build projects and earn free verified certifications (e.g. Responsive Web Design, JavaScript Algorithms, Data Analysis with Python) while working through an interactive, self-paced platform.",
    benefits:
      "Completely free curriculum, free verified developer certifications, hands-on projects, and a large learner community — no cost ever.",
    eligibility:
      "Open to everyone, worldwide, at any skill level.",
    howToApply:
      "Create a free account on freecodecamp.org and start any certification track immediately.",
    tags: ["course", "free", "coding", "certification"],
    categories: ["Course", "Web Development"],
    interests: ["Software Development", "Web Development", "Data Science"],
  },
  {
    type: "course",
    title: "Kaggle Learn",
    organization: "Kaggle (Google)",
    domain: "kaggle.com",
    countries: [],
    url: "https://www.kaggle.com/learn",
    description:
      "Free, fast, hands-on micro-courses in Python, machine learning, and data science with certificates.",
    fullDescription:
      "Kaggle Learn offers free, practical micro-courses that teach the exact skills needed for data science and machine learning — Python, pandas, data visualisation, intro and intermediate ML, deep learning, and more. Each course is hands-on in the browser and awards a free certificate on completion.",
    benefits:
      "Free bite-sized courses, in-browser coding, completion certificates, and a direct path into Kaggle competitions.",
    eligibility:
      "Open to anyone with a free Kaggle account.",
    howToApply:
      "Sign in to Kaggle and start any Learn micro-course — no application needed.",
    tags: ["course", "free", "data-science", "machine-learning"],
    categories: ["Course", "AI & Data"],
    interests: ["Data Science", "Machine Learning", "Python"],
  },
  {
    type: "certification",
    title: "Google Career Certificates",
    organization: "Google (Grow with Google)",
    domain: "google.com",
    countries: [],
    url: "https://grow.google/certificates/",
    description:
      "Industry-recognised certificates in high-growth fields like data analytics, IT support, UX, and cybersecurity.",
    fullDescription:
      "Google Career Certificates are job-ready programs on Coursera that prepare learners for in-demand roles in data analytics, IT support, project management, UX design, cybersecurity, and digital marketing — no degree or experience required. They are self-paced (typically 3–6 months) and connect graduates to an employer consortium.",
    benefits:
      "Industry-recognised certificate, job-ready skills, access to an employer hiring consortium, and financial aid/scholarships in many regions.",
    eligibility:
      "Open to everyone; no prior degree or experience required. Financial aid available for eligible learners.",
    howToApply:
      "Enrol on the Grow with Google / Coursera page; check for scholarships or employer/nonprofit sponsorships to study free.",
    tags: ["certification", "career", "data-analytics", "self-paced"],
    categories: ["Certification", "Career"],
    interests: ["Data Analytics", "UX Design", "Cybersecurity", "IT"],
  },
  {
    type: "course",
    title: "AWS Educate",
    organization: "Amazon Web Services",
    domain: "aws.amazon.com",
    countries: [],
    url: "https://aws.amazon.com/education/awseducate/",
    description:
      "Free cloud learning for students — hundreds of hours of self-paced training and hands-on labs, no credit card needed.",
    fullDescription:
      "AWS Educate provides students new to cloud with free, self-paced training on AWS Cloud fundamentals, machine learning, and more. It includes hands-on labs in a sandbox environment, skill badges, and a jobs board — all with no AWS account or credit card required, making it an easy first step into cloud careers.",
    benefits:
      "Free self-paced cloud courses, hands-on labs, digital badges, and access to an AWS Educate job board.",
    eligibility:
      "Students aged 13+ (varies by region) new to cloud computing; no AWS account required.",
    howToApply:
      "Register with an email on the AWS Educate site and start courses and labs immediately.",
    tags: ["course", "free", "cloud", "badges"],
    categories: ["Course", "Cloud"],
    interests: ["Cloud", "Machine Learning", "Software Development"],
  },
  {
    type: "course",
    title: "Cisco Networking Academy",
    organization: "Cisco",
    domain: "netacad.com",
    countries: [],
    url: "https://www.netacad.com/",
    description:
      "Free courses in networking, cybersecurity, Python, and IT — many with a pathway to industry certifications.",
    fullDescription:
      "Cisco Networking Academy (NetAcad) offers free and low-cost courses in networking, cybersecurity, programming (Python), and IT essentials. Interactive labs and simulations (Packet Tracer) build practical skills, and many courses align with industry certifications such as CCNA and CyberOps, connecting learners to career resources.",
    benefits:
      "Free courses, hands-on labs and simulations, digital badges, and preparation toward Cisco industry certifications.",
    eligibility:
      "Open to learners worldwide; some instructor-led courses are offered via partner institutions.",
    howToApply:
      "Sign up on netacad.com and enrol in self-paced courses, or join an instructor-led course at a partner academy.",
    tags: ["course", "free", "networking", "cybersecurity"],
    categories: ["Course", "Networking"],
    interests: ["Networking", "Cybersecurity", "Python", "IT"],
  },

  // ── EXCHANGE ──────────────────────────────────────────────────────────────
  {
    type: "exchange",
    title: "Fulbright Foreign Student Program",
    organization: "U.S. Department of State",
    domain: "fulbrightonline.org",
    countries: [],
    url: "https://foreign.fulbrightonline.org/",
    description:
      "Fully funded grants for international students to pursue a master's or PhD or conduct research in the United States.",
    fullDescription:
      "The Fulbright Foreign Student Program enables graduate students, young professionals, and artists from more than 160 countries to study and conduct research in the United States. Grants typically fund a master's or PhD, or non-degree research, and include tuition, living stipend, airfare, and health benefits, administered through in-country Fulbright commissions.",
    benefits:
      "Full funding for graduate study or research in the US: tuition, living stipend, airfare, and health coverage.",
    eligibility:
      "Citizens of participating countries with a bachelor's degree; criteria and fields vary by home country commission.",
    howToApply:
      "Apply through the Fulbright commission or U.S. Embassy in your home country during their annual cycle.",
    tags: ["exchange", "fully-funded", "graduate", "research"],
    categories: ["Exchange", "Graduate"],
    interests: ["Higher Education", "Research", "Study Abroad"],
  },
  {
    type: "exchange",
    title: "Erasmus+",
    organization: "European Commission",
    domain: "europa.eu",
    countries: [],
    url: "https://erasmus-plus.ec.europa.eu/",
    description:
      "The EU program funding study, training, and exchange abroad for students across Europe and partner countries.",
    fullDescription:
      "Erasmus+ is the European Union's flagship program for education, training, youth, and sport. For students it funds study periods and traineeships abroad at partner universities and organisations, providing grants toward travel and living costs and a recognised international experience. It includes global mobility with partner countries beyond Europe.",
    benefits:
      "Monthly mobility grant, tuition waived at the host university, credit recognition, and international study/traineeship experience.",
    eligibility:
      "Students enrolled at a participating higher-education institution; some actions open to partner (non-EU) countries.",
    howToApply:
      "Apply through your home university's international/Erasmus office — they manage nominations and grant agreements.",
    tags: ["exchange", "europe", "study-abroad", "grant"],
    categories: ["Exchange", "Europe"],
    interests: ["Study Abroad", "Higher Education"],
  },

  // ── CONFERENCE / EVENT ────────────────────────────────────────────────────
  {
    type: "conference",
    title: "Grace Hopper Celebration",
    organization: "AnitaB.org",
    domain: "anitab.org",
    countries: [],
    url: "https://ghc.anitab.org/",
    description:
      "The world's largest gathering of women and non-binary technologists, with scholarships and a major career fair.",
    fullDescription:
      "The Grace Hopper Celebration (GHC), produced by AnitaB.org, is the world's largest gathering of women and non-binary technologists. It features technical sessions, keynotes from industry leaders, and one of the biggest tech career fairs anywhere. Student scholarships cover registration and travel, and many attendees receive internship and full-time offers on-site.",
    benefits:
      "Access to a huge career fair and recruiters, technical and career sessions, community, and student scholarships covering registration/travel.",
    eligibility:
      "Women and non-binary technologists and allies; student scholarship track for those enrolled in tech programs.",
    howToApply:
      "Register on the GHC site, and apply separately for a student scholarship during its application window.",
    tags: ["conference", "women-in-tech", "career-fair", "scholarship"],
    categories: ["Conference", "Women in Tech"],
    interests: ["Networking", "Software Development", "Careers"],
  },
  {
    type: "event",
    title: "Google I/O",
    organization: "Google",
    domain: "google.com",
    countries: [],
    url: "https://io.google/",
    description:
      "Google's flagship developer event revealing the latest in Android, AI, web, and cloud — free to join online.",
    fullDescription:
      "Google I/O is Google's annual developer conference where the company unveils its newest platforms and tools across Android, AI (Gemini), web, and cloud. The event streams free online with technical sessions, codelabs, and workshops, and local I/O Extended community events run worldwide — a great way for students to learn the latest and connect with developers.",
    benefits:
      "Free online access to technical sessions, codelabs, and product announcements, plus local I/O Extended networking events.",
    eligibility:
      "Open to everyone; developers and students worldwide can join online for free.",
    howToApply:
      "Register for free on the Google I/O site to watch live, or find a nearby I/O Extended community event.",
    tags: ["event", "developer", "ai", "android"],
    categories: ["Event", "Developer"],
    interests: ["AI", "Android", "Web Development", "Cloud"],
  },
];

// ── URL health check (reused pattern) ────────────────────────────────────────
const DEAD_STATUS = new Set([400, 404, 410, 500, 522, 523, 525, 530]);
async function checkUrl(url) {
  if (!url) return { skip: true };
  const ac = new AbortController();
  const t = setTimeout(() => ac.abort(), 12000);
  try {
    const res = await fetch(url, {
      method: "GET",
      redirect: "follow",
      signal: ac.signal,
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36",
      },
    });
    return { status: res.status, dead: DEAD_STATUS.has(res.status) };
  } catch (e) {
    const timedOut = String(e.name || e).includes("Abort");
    // A network error that isn't a timeout is treated as dead.
    return { status: 0, dead: !timedOut, timedOut };
  } finally {
    clearTimeout(t);
  }
}

// ── Publish-readiness (mirrors CmsResourceRepository.validateForPublish) ─────
function publishErrors(it) {
  const errs = [];
  if (!it.title || !it.title.trim()) errs.push("missing title");
  if (!it.organization || !it.organization.trim()) errs.push("missing organization");
  if (!it.url || !it.url.trim()) errs.push("missing link");
  if (!KNOWN_TYPES.has(it.type)) errs.push(`unknown type '${it.type}'`);
  return errs;
}

// ── Firebase Admin init ──────────────────────────────────────────────────────
async function initDb() {
  const { initializeApp, cert, applicationDefault } = await import("firebase-admin/app");
  const { getFirestore, FieldValue, Timestamp } = await import("firebase-admin/firestore");
  let credential, projectId;
  const saPath = resolve(__dirname, "serviceAccount.json");
  try {
    const sa = JSON.parse(readFileSync(saPath, "utf8"));
    credential = cert(sa);
    projectId = sa.project_id;
    console.log(`Using service account: ${saPath}`);
  } catch {
    credential = applicationDefault();
    console.log("Using application default credentials (gcloud ADC).");
  }
  initializeApp({ credential });
  return { db: getFirestore(), FieldValue, Timestamp, projectId };
}

// ── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  let items = DATA.slice();
  if (LIMIT > 0) items = items.slice(0, LIMIT);

  // Assign index + doc id + logo.
  items.forEach((it, i) => {
    it._index = i + 1;
    it._slug = slugify(`${it.organization}-${it.title}`);
    it._docId = `seed-opp-${String(it._index).padStart(3, "0")}-${it._slug}`;
    it._logo = iconhorse(it.domain);
    it._hero = heroFor(it.type);
  });

  // Report basics.
  const byType = {};
  for (const it of items) byType[it.type] = (byType[it.type] || 0) + 1;
  const ids = items.map((it) => it._docId);
  const dupIds = ids.filter((s, i) => ids.indexOf(s) !== i);
  const notPublishable = items
    .map((it) => ({ it, errs: publishErrors(it) }))
    .filter((x) => x.errs.length);

  console.log("\n── Opportunity seed (real, live programs) ─────────────");
  console.log(`Mode                 : ${LIVE ? "LIVE WRITE" : "DRY RUN"}`);
  console.log(`Total opportunities  : ${items.length}`);
  console.log("By category (type)   :", JSON.stringify(byType));
  console.log(`Publish-ready        : ${items.length - notPublishable.length}/${items.length}`);
  if (notPublishable.length) {
    console.log(`\nNOT publish-ready (${notPublishable.length}):`);
    for (const { it, errs } of notPublishable)
      console.log(`  - [${it.type}] ${it.title} → ${errs.join(", ")}`);
  }
  if (dupIds.length) {
    console.log(`\n⚠ Duplicate doc ids (would merge): ${[...new Set(dupIds)].join(", ")}`);
  }

  // Verify every official link + logo unless skipped.
  const deadLinks = [];
  if (!NO_CHECK) {
    console.log(`\nVerifying ${items.length} official links + logos (live)…\n`);
    for (const it of items) {
      const linkChk = await checkUrl(it.url);
      const logoChk = await checkUrl(it._logo);
      // Guarantee a working PNG: if icon.horse is unavailable, fall back to favicon.
      let logoNote = "icon.horse✓";
      if (logoChk.dead || logoChk.status === 0) {
        const alt = favicon(it.domain);
        const altChk = await checkUrl(alt);
        if (!altChk.dead && altChk.status !== 0) {
          it._logo = alt;
          logoNote = "icon.horse✗→favicon";
        } else {
          logoNote = "icon.horse✗(kept)";
        }
      }
      const linkNote = linkChk.dead
        ? `DEAD(${linkChk.status})`
        : `ok(${linkChk.status || (linkChk.timedOut ? "timeout" : "?")})`;
      console.log(
        `  [${String(it._index).padStart(2, "0")}] ${it.title.padEnd(46).slice(0, 46)} link:${linkNote.padEnd(12)} logo:${logoNote}`
      );
      if (linkChk.dead) deadLinks.push({ it, status: linkChk.status });
    }
    if (deadLinks.length) {
      console.log(`\n⚠ ${deadLinks.length} official link(s) look DEAD — fix before publishing:`);
      for (const { it, status } of deadLinks) console.log(`  - ${it.title}: ${it.url} (${status})`);
    } else {
      console.log(`\n✓ All ${items.length} official links responded OK.`);
    }
  } else {
    console.log("\n--no-check: skipped live URL/logo verification.");
  }

  if (!LIVE) {
    // Show one fully-built sample document.
    const s = items[0];
    console.log("\nSample draft document:");
    console.log(
      JSON.stringify(
        {
          docId: s._docId,
          type: s.type,
          title: s.title,
          organization: s.organization,
          countries: s.countries,
          status: "draft",
          applicationUrl: s.url,
          officialWebsite: s.url,
          logoUrl: s._logo,
          imageUrl: s._hero,
          categories: s.categories,
          tags: s.tags,
          benefits: s.benefits,
          eligibility: s.eligibility,
          howToApply: s.howToApply,
          description: s.description,
          targetInterests: s.interests,
        },
        null,
        2
      )
    );
    console.log("\nDRY RUN — nothing written. Re-run with --live to create the drafts.");
    return;
  }

  // ── Real write ──────────────────────────────────────────────────────────────
  const { db, FieldValue, Timestamp, projectId } = await initDb();
  console.log(`Project: ${projectId}\n`);
  const col = db.collection("resources");

  let written = 0;
  let batch = db.batch();
  for (const it of items) {
    const data = {
      type: it.type,
      title: it.title,
      organization: it.organization,
      description: it.description || "",
      countries: it.countries || [],
      eligibility: it.eligibility || null,
      startDate: null,
      deadline: null, // recurring — editor sets the live cycle's deadline at publish
      applicationUrl: it.url || null,
      imageUrl: it._hero, // wide category-themed hero banner (distinct from logo)
      tags: it.tags || [],
      status: "draft",
      featured: false,
      sponsored: false,
      priority: 0,
      remote: null,
      paid: null,
      verified: false,
      slug: null,
      company: null,
      logoUrl: it._logo,
      discountText: null,
      redemptionInstructions: null,
      verificationRequired: false,
      affiliateUrl: null,
      terms: null,
      categories: it.categories || [],
      regionalVariants: [],
      targetDegrees: [],
      targetDepartments: [],
      targetInterests: it.interests || [],
      targetCareerGoals: [],
      targetAcademicYears: [],
      fullDescription: it.fullDescription || null,
      officialWebsite: it.url || null,
      benefits: it.benefits || null,
      howToApply: it.howToApply || null,
      requirements: it.requirements || null,
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
      updatedBy: "seed-opportunities",
      seedSource: "seed_opportunities.mjs",
    };
    batch.set(col.doc(it._docId), data, { merge: true });
    written++;
    if (written % 400 === 0) {
      await batch.commit();
      batch = db.batch();
      console.log(`  committed ${written}…`);
    }
  }
  await batch.commit();
  console.log(`\n✓ Wrote ${written} DRAFT opportunities to 'resources'.`);
  console.log("Open the CMS → Resources, filter status = Draft, review, and Publish.");
  process.exit(0);
}

main().catch((e) => {
  console.error("Seed failed:", e);
  process.exit(1);
});
