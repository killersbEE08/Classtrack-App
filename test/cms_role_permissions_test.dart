import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/cms_role.dart';

void main() {
  group('CmsRole.permissionLabels', () {
    test('super admin has the full set incl. user management & settings', () {
      final labels = CmsRole.superAdmin.permissionLabels;
      expect(labels, contains('Create & edit content'));
      expect(labels, contains('Manage users & roles'));
      expect(labels, contains('Change settings'));
      expect(labels, contains('Moderate reports'));
    });

    test('editor can edit content but not manage users or settings', () {
      final labels = CmsRole.editor.permissionLabels;
      expect(labels, contains('Create & edit content'));
      expect(labels, isNot(contains('Manage users & roles')));
      expect(labels, isNot(contains('Change settings')));
    });

    test('analyst is analytics-only (no content browse/edit)', () {
      final labels = CmsRole.analyst.permissionLabels;
      expect(labels, contains('View analytics'));
      expect(labels, isNot(contains('Create & edit content')));
      expect(labels, isNot(contains('Browse content library')));
    });

    test('every role can at least view analytics', () {
      for (final r in CmsRole.values) {
        expect(r.permissionLabels, contains('View analytics'),
            reason: '$r should list analytics');
      }
    });
  });
}
