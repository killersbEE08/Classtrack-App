/**
 * ClassTracks CMS — role hierarchy & authorization (server-side, pure logic).
 *
 * Kept dependency-free so it can be unit-tested with `node --test` without the
 * Firebase emulator. The mobile/CMS client mirrors this matrix in Dart
 * (lib/features/cms/domain/cms_role.dart); the server ALWAYS re-checks here so
 * a client can never grant itself or others a role it isn't allowed to.
 */

/** All CMS roles, lowest → highest privilege. `none` = a normal student. */
export const CMS_ROLES = [
  "viewer",
  "analyst",
  "moderator",
  "marketing",
  "editor",
  "admin",
  "super_admin",
];

/** Privilege rank. Higher = more power. `none` (student) is 0. */
export const ROLE_RANK = {
  none: 0,
  viewer: 10,
  analyst: 20,
  moderator: 40,
  marketing: 45,
  editor: 50,
  admin: 80,
  super_admin: 100,
};

/** Normalizes an arbitrary claim value to a known role, or `none`. */
export function normalizeRole(role) {
  if (typeof role !== "string") return "none";
  const r = role.trim();
  if (r === "none") return "none";
  return CMS_ROLES.includes(r) ? r : "none";
}

export function roleRank(role) {
  return ROLE_RANK[normalizeRole(role)] ?? 0;
}

/** True for any CMS role (i.e. not a plain student). */
export function isPrivileged(role) {
  return normalizeRole(role) !== "none";
}

/**
 * Whether a caller with [callerRole] may assign [targetRole] to a user.
 *
 * Rules (anti-privilege-escalation):
 *  • Only super_admin and admin may assign roles at all.
 *  • super_admin may assign ANY role, including admin/super_admin, and may
 *    revoke (assign `none`).
 *  • admin may assign only roles strictly BELOW admin (editor/moderator/
 *    marketing/analyst/viewer) and may revoke (`none`). An admin can never
 *    mint another admin or a super_admin.
 *  • The target role must be a known role or `none`.
 */
export function canAssignRole(callerRole, targetRole) {
  const caller = normalizeRole(callerRole);
  const target = normalizeRole(targetRole);

  // Only admins and super admins manage roles.
  if (caller !== "super_admin" && caller !== "admin") return false;

  // super_admin can do anything (including revoke).
  if (caller === "super_admin") return true;

  // admin: may revoke, or assign roles strictly below admin.
  if (target === "none") return true;
  return roleRank(target) < ROLE_RANK.admin;
}

/**
 * Builds the deterministic part of an audit-log entry. The caller adds the
 * server timestamp (`at`) when writing to Firestore.
 */
export function buildAuditEntry({
  actorUid,
  actorRole,
  action,
  targetType,
  targetId,
  details,
}) {
  return {
    actorUid: typeof actorUid === "string" ? actorUid : "unknown",
    actorRole: normalizeRole(actorRole),
    action: typeof action === "string" ? action : "unknown",
    targetType: typeof targetType === "string" ? targetType : "unknown",
    targetId: typeof targetId === "string" ? targetId : "",
    details: details && typeof details === "object" ? details : {},
  };
}
