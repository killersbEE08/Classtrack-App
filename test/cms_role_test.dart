import 'package:classtrack/features/cms/domain/cms_role.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CmsRole.fromClaim', () {
    test('maps known keys, null/unknown → null (student)', () {
      expect(CmsRole.fromClaim('super_admin'), CmsRole.superAdmin);
      expect(CmsRole.fromClaim('editor'), CmsRole.editor);
      expect(CmsRole.fromClaim('viewer'), CmsRole.viewer);
      expect(CmsRole.fromClaim('none'), isNull);
      expect(CmsRole.fromClaim(''), isNull);
      expect(CmsRole.fromClaim('bogus'), isNull);
      expect(CmsRole.fromClaim(null), isNull);
      expect(CmsRole.fromClaim(42), isNull);
    });
  });

  group('permission matrix', () {
    test('user management restricted to admins', () {
      expect(CmsRole.superAdmin.canManageUsers, isTrue);
      expect(CmsRole.admin.canManageUsers, isTrue);
      expect(CmsRole.editor.canManageUsers, isFalse);
      expect(CmsRole.marketing.canManageUsers, isFalse);
      expect(CmsRole.viewer.canManageUsers, isFalse);
    });

    test('content editing for super_admin/admin/editor only', () {
      expect(CmsRole.superAdmin.canEditContent, isTrue);
      expect(CmsRole.admin.canEditContent, isTrue);
      expect(CmsRole.editor.canEditContent, isTrue);
      expect(CmsRole.moderator.canEditContent, isFalse);
      expect(CmsRole.marketing.canEditContent, isFalse);
      expect(CmsRole.analyst.canEditContent, isFalse);
      expect(CmsRole.viewer.canEditContent, isFalse);
    });

    test('marketing tools for super_admin/admin/marketing', () {
      expect(CmsRole.marketing.canManageMarketing, isTrue);
      expect(CmsRole.admin.canManageMarketing, isTrue);
      expect(CmsRole.superAdmin.canManageMarketing, isTrue);
      expect(CmsRole.editor.canManageMarketing, isFalse);
      expect(CmsRole.analyst.canManageMarketing, isFalse);
    });

    test('analyst is analytics-only (cannot browse content)', () {
      expect(CmsRole.analyst.canViewContent, isFalse);
      expect(CmsRole.analyst.canViewAnalytics, isTrue);
      expect(CmsRole.viewer.canViewContent, isTrue);
    });

    test('audit logs visible only to admins', () {
      expect(CmsRole.superAdmin.canViewAuditLogs, isTrue);
      expect(CmsRole.admin.canViewAuditLogs, isTrue);
      expect(CmsRole.editor.canViewAuditLogs, isFalse);
      expect(CmsRole.moderator.canViewAuditLogs, isFalse);
    });
  });

  group('canAssign (anti-escalation, mirrors server)', () {
    test('non-admins cannot assign roles', () {
      expect(CmsRole.canAssign(null, CmsRole.viewer), isFalse);
      expect(CmsRole.canAssign(CmsRole.editor, CmsRole.viewer), isFalse);
      expect(CmsRole.canAssign(CmsRole.marketing, CmsRole.editor), isFalse);
      expect(CmsRole.canAssign(CmsRole.viewer, CmsRole.viewer), isFalse);
    });

    test('admin assigns below admin + revoke, never admin/super_admin', () {
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.editor), isTrue);
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.moderator), isTrue);
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.marketing), isTrue);
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.analyst), isTrue);
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.viewer), isTrue);
      expect(CmsRole.canAssign(CmsRole.admin, null), isTrue); // revoke
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.admin), isFalse);
      expect(CmsRole.canAssign(CmsRole.admin, CmsRole.superAdmin), isFalse);
    });

    test('super_admin assigns anything and revokes', () {
      for (final r in CmsRole.values) {
        expect(CmsRole.canAssign(CmsRole.superAdmin, r), isTrue);
      }
      expect(CmsRole.canAssign(CmsRole.superAdmin, null), isTrue);
    });
  });
}
