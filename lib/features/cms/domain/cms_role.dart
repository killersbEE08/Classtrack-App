/// ClassTracks CMS — role hierarchy & permissions (client/CMS source of truth).
///
/// Mirrors the server authorization in `functions/roles.js`. The server ALWAYS
/// re-enforces these rules (a client check is only for UX gating), but keeping
/// one canonical matrix here — reused by the Flutter Web CMS — avoids
/// duplicating permission logic across CMS screens.
///
/// A role comes from the Firebase Auth custom claim `role`; a normal student
/// has no claim, represented here as `null` (see [CmsRole.fromClaim]).
///
/// Deliberately Flutter-free so it unit-tests fast under `flutter test`.
enum CmsRole {
  superAdmin('super_admin', 'Super admin', 100),
  admin('admin', 'Admin', 80),
  editor('editor', 'Editor', 50),
  moderator('moderator', 'Moderator', 40),
  marketing('marketing', 'Marketing', 45),
  analyst('analyst', 'Analyst', 20),
  viewer('viewer', 'Viewer', 10);

  const CmsRole(this.key, this.label, this.rank);

  /// Stable claim value.
  final String key;

  /// Human-readable label for CMS UI.
  final String label;

  /// Privilege rank (higher = more power).
  final int rank;

  // ── Permission matrix (used to gate CMS UI) ───────────────────────────────

  bool get canManageUsers => this == superAdmin || this == admin;
  bool get canViewAuditLogs => this == superAdmin || this == admin;

  /// Create/edit/publish opportunities & discounts.
  bool get canEditContent =>
      this == superAdmin || this == admin || this == editor;

  /// Review/report content.
  bool get canModerate =>
      this == superAdmin || this == admin || this == moderator;

  /// Banners, sponsored campaigns and targeted notifications.
  bool get canManageMarketing =>
      this == superAdmin || this == admin || this == marketing;

  /// Every CMS role can at least view analytics.
  bool get canViewAnalytics => true;

  /// Browse the content library. Analysts are analytics-only.
  bool get canViewContent => this != analyst;

  /// Change remotely-configurable settings (e.g. recommendation weights).
  bool get canEditConfig => this == superAdmin || this == admin;

  /// Human-readable list of what this role is allowed to do (for the Users UI).
  List<String> get permissionLabels => [
        if (canEditContent) 'Create & edit content',
        if (canModerate) 'Moderate reports',
        if (canManageMarketing) 'Banners, campaigns & notifications',
        if (canManageUsers) 'Manage users & roles',
        if (canViewAuditLogs) 'View audit logs',
        if (canEditConfig) 'Change settings',
        if (canViewContent) 'Browse content library',
        if (canViewAnalytics) 'View analytics',
      ];

  /// Parse a claim value into a role, or `null` for a student / unknown value.
  static CmsRole? fromClaim(Object? claim) {
    if (claim is! String) return null;
    final v = claim.trim();
    if (v.isEmpty || v == 'none') return null;
    for (final r in CmsRole.values) {
      if (r.key == v) return r;
    }
    return null;
  }

  /// Whether [caller] may assign [target] to a user (`null` target = revoke).
  ///
  /// Mirrors `functions/roles.js#canAssignRole`:
  ///  • only super admins & admins may assign roles;
  ///  • super admin may assign anything (incl. admin/super_admin) and revoke;
  ///  • admin may assign only roles strictly below admin, and revoke — never
  ///    another admin or a super admin.
  static bool canAssign(CmsRole? caller, CmsRole? target) {
    if (caller == null) return false;
    if (caller == superAdmin) return true;
    if (caller == admin) {
      if (target == null) return true; // revoke
      return target.rank < admin.rank;
    }
    return false;
  }
}
