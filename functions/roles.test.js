import { test } from "node:test";
import assert from "node:assert/strict";
import {
  normalizeRole,
  roleRank,
  isPrivileged,
  canAssignRole,
  buildAuditEntry,
  CMS_ROLES,
} from "./roles.js";

test("normalizeRole collapses unknown values to none", () => {
  assert.equal(normalizeRole("editor"), "editor");
  assert.equal(normalizeRole("super_admin"), "super_admin");
  assert.equal(normalizeRole("bogus"), "none");
  assert.equal(normalizeRole(null), "none");
  assert.equal(normalizeRole(123), "none");
  assert.equal(normalizeRole("none"), "none");
});

test("roleRank orders privileges; unknown is 0", () => {
  assert.ok(roleRank("super_admin") > roleRank("admin"));
  assert.ok(roleRank("admin") > roleRank("editor"));
  assert.ok(roleRank("editor") > roleRank("viewer"));
  assert.equal(roleRank("bogus"), 0);
  assert.equal(roleRank("none"), 0);
});

test("isPrivileged is true only for real CMS roles", () => {
  for (const r of CMS_ROLES) assert.equal(isPrivileged(r), true);
  assert.equal(isPrivileged("none"), false);
  assert.equal(isPrivileged("student"), false);
});

test("students/editors cannot assign roles", () => {
  assert.equal(canAssignRole("none", "viewer"), false);
  assert.equal(canAssignRole("editor", "viewer"), false);
  assert.equal(canAssignRole("marketing", "editor"), false);
  assert.equal(canAssignRole("analyst", "viewer"), false);
  assert.equal(canAssignRole("viewer", "viewer"), false);
});

test("admin may assign roles below admin and revoke, but never admin/super_admin", () => {
  assert.equal(canAssignRole("admin", "editor"), true);
  assert.equal(canAssignRole("admin", "moderator"), true);
  assert.equal(canAssignRole("admin", "marketing"), true);
  assert.equal(canAssignRole("admin", "analyst"), true);
  assert.equal(canAssignRole("admin", "viewer"), true);
  assert.equal(canAssignRole("admin", "none"), true); // revoke
  // No privilege escalation / peer creation:
  assert.equal(canAssignRole("admin", "admin"), false);
  assert.equal(canAssignRole("admin", "super_admin"), false);
});

test("super_admin may assign any role including admin/super_admin and revoke", () => {
  for (const r of [...CMS_ROLES, "none"]) {
    assert.equal(canAssignRole("super_admin", r), true, `should allow ${r}`);
  }
});

test("buildAuditEntry normalizes fields and defaults safely", () => {
  const e = buildAuditEntry({
    actorUid: "u1",
    actorRole: "admin",
    action: "set_user_role",
    targetType: "user",
    targetId: "u2",
    details: { from: "none", to: "editor" },
  });
  assert.deepEqual(e, {
    actorUid: "u1",
    actorRole: "admin",
    action: "set_user_role",
    targetType: "user",
    targetId: "u2",
    details: { from: "none", to: "editor" },
  });

  const bad = buildAuditEntry({
    actorRole: "hacker",
    details: "not-an-object",
  });
  assert.equal(bad.actorUid, "unknown");
  assert.equal(bad.actorRole, "none");
  assert.equal(bad.action, "unknown");
  assert.equal(bad.targetType, "unknown");
  assert.equal(bad.targetId, "");
  assert.deepEqual(bad.details, {});
});
