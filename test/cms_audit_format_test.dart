import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/audit_format.dart';
import 'package:classtrack/features/cms/domain/audit_log.dart';

AuditLogEntry _e(String action,
        {Map<String, dynamic> details = const {},
        String actorUid = 'u1',
        String actorRole = 'admin',
        String? actorEmail,
        String targetType = 'resource',
        String targetId = 'r1'}) =>
    AuditLogEntry(
      id: 'a',
      actorUid: actorUid,
      actorRole: actorRole,
      actorEmail: actorEmail,
      action: action,
      targetType: targetType,
      targetId: targetId,
      details: details,
    );

void main() {
  group('auditHeadline', () {
    test('draft → active reads as Published with title', () {
      final e = _e('resource_update', details: {
        'statusFrom': 'draft',
        'statusTo': 'active',
        'title': 'Google Internship',
      });
      expect(auditHeadline(e), 'Published "Google Internship"');
    });

    test('create/update/delete verbs', () {
      expect(auditHeadline(_e('resource_create', details: {'title': 'X'})),
          'Created "X"');
      expect(
          auditHeadline(_e('banner_update',
              targetType: 'banner', details: {'title': 'B'})),
          'Updated "B"');
      expect(auditHeadline(_e('campaign_delete', targetType: 'campaign')),
          'Deleted campaign r1');
    });

    test('role + notification actions', () {
      expect(auditHeadline(_e('set_user_role', details: {'to': 'editor'})),
          'Set role to Editor');
      expect(auditHeadline(_e('set_user_role', details: {'to': 'none'})),
          'Revoked CMS role');
      expect(
          auditHeadline(_e('notification_sent',
              targetType: 'notification', details: {'title': 'Hi'})),
          'Sent notification "Hi"');
    });
  });

  group('auditStatusTransition', () {
    test('renders labelled transition', () {
      expect(
          auditStatusTransition(_e('resource_update',
              details: {'statusFrom': 'draft', 'statusTo': 'active'})),
          'Draft → Active');
    });
    test('null when unchanged or absent', () {
      expect(
          auditStatusTransition(_e('resource_update',
              details: {'statusFrom': 'active', 'statusTo': 'active'})),
          isNull);
      expect(auditStatusTransition(_e('set_user_role')), isNull);
    });
  });

  group('auditActor', () {
    test('prefers email, falls back to role, handles system', () {
      expect(auditActor(_e('x', actorEmail: 'prince@x.com')), 'prince@x.com');
      expect(auditActor(_e('x', actorUid: 'system')), 'System');
      expect(auditActor(_e('x', actorUid: 'abcdef123', actorRole: 'editor')),
          'Editor · abcdef');
    });
  });
}
