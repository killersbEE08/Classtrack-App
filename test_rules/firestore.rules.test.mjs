/**
 * Firestore security-rules tests for the ClassTracks CMS backend.
 *
 * ⚠️ Requires the Firebase Firestore emulator (which needs Java). Run locally
 * or in CI — NOT in a plain sandbox:
 *
 *   cd test_rules
 *   npm install
 *   npm test            # spins up the emulator via firebase emulators:exec
 *
 * Covers PRD §27: students can never read hidden content or write CMS content;
 * editors can create valid resources but cannot publish incomplete ones; only
 * admins can read audit logs; nobody but the backend writes them.
 */
import { readFileSync } from "node:fs";
import { test, before, after, beforeEach } from "node:test";
import {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { setDoc, getDoc, doc, deleteDoc } from "firebase/firestore";

let env;

const PROJECT_ID = "classtracks-rules-test";

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(new URL("../firestore.rules", import.meta.url), "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
  });
});

after(async () => {
  if (env) await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
});

// Contexts
const student = () => env.authenticatedContext("student1").firestore();
const editor = () =>
  env.authenticatedContext("editor1", { role: "editor" }).firestore();
const admin = () =>
  env.authenticatedContext("admin1", { role: "admin" }).firestore();

function validResource(uid, overrides = {}) {
  return {
    type: "internship",
    title: "Summer Internship",
    organization: "Acme",
    status: "active",
    applicationUrl: "https://acme.example/apply",
    priority: 10,
    updatedBy: uid,
    ...overrides,
  };
}

// Seed a doc bypassing rules.
async function seed(path, data) {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await setDoc(doc(ctx.firestore(), path), data);
  });
}

test("student CANNOT read a draft/hidden resource", async () => {
  await seed("resources/r1", validResource("editor1", { status: "draft" }));
  await assertFails(getDoc(doc(student(), "resources/r1")));
});

test("student CAN read an active resource", async () => {
  await seed("resources/r2", validResource("editor1", { status: "active" }));
  await assertSucceeds(getDoc(doc(student(), "resources/r2")));
});

test("student CANNOT create/modify a resource", async () => {
  await assertFails(
    setDoc(doc(student(), "resources/r3"), validResource("student1"))
  );
  await seed("resources/r4", validResource("editor1"));
  await assertFails(
    setDoc(doc(student(), "resources/r4"), validResource("student1")))
  ;
});

test("editor CAN create a valid resource stamped with their uid", async () => {
  await assertSucceeds(
    setDoc(doc(editor(), "resources/r5"), validResource("editor1"))
  );
});

test("editor CANNOT create a resource stamped with someone else's uid", async () => {
  await assertFails(
    setDoc(doc(editor(), "resources/r6"), validResource("someone-else"))
  );
});

test("editor CANNOT publish an incomplete resource (visible status, no link)", async () => {
  await assertFails(
    setDoc(
      doc(editor(), "resources/r7"),
      validResource("editor1", { applicationUrl: "", affiliateUrl: "" })
    )
  );
});

test("editor CAN save an incomplete DRAFT (not published)", async () => {
  await assertSucceeds(
    setDoc(
      doc(editor(), "resources/r8"),
      validResource("editor1", {
        status: "draft",
        applicationUrl: "",
        organization: "",
      })
    )
  );
});

test("student CANNOT read audit logs; admin CAN", async () => {
  await seed("auditLogs/a1", {
    actorUid: "admin1",
    action: "set_user_role",
    at: Date.now(),
  });
  await assertFails(getDoc(doc(student(), "auditLogs/a1")));
  await assertSucceeds(getDoc(doc(admin(), "auditLogs/a1")));
});

test("nobody (even admin) may write audit logs from a client", async () => {
  await assertFails(
    setDoc(doc(admin(), "auditLogs/a2"), { action: "spoof" })
  );
});

test("a user's private tree stays private to them", async () => {
  await seed("users/student1/subjects/s1", { name: "Maths" });
  const other = env.authenticatedContext("student2").firestore();
  await assertFails(getDoc(doc(other, "users/student1/subjects/s1")));
  await assertSucceeds(getDoc(doc(student(), "users/student1/subjects/s1")));
});
