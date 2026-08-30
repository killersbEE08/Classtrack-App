import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/content_report.dart';

void main() {
  group('ReportReason / ReportStatus', () {
    test('keys round-trip and unknown falls back', () {
      for (final r in ReportReason.values) {
        expect(ReportReason.fromKey(r.key), r);
      }
      expect(ReportReason.fromKey('bogus'), ReportReason.other);
      for (final s in ReportStatus.values) {
        expect(ReportStatus.fromKey(s.key), s);
      }
      expect(ReportStatus.fromKey(null), ReportStatus.open);
    });

    test('active statuses are open + under_review', () {
      expect(ReportStatus.open.isActive, isTrue);
      expect(ReportStatus.underReview.isActive, isTrue);
      expect(ReportStatus.resolved.isActive, isFalse);
      expect(ReportStatus.dismissed.isActive, isFalse);
    });
  });

  group('ContentReport.fromMap / toCreateMap', () {
    test('parses fields and defaults status to open', () {
      final r = ContentReport.fromMap('rep1', {
        'resourceId': 'res1',
        'resourceTitle': 'Google Internship',
        'reporterUid': 'u1',
        'reason': 'broken_link',
      });
      expect(r.resourceId, 'res1');
      expect(r.resourceTitle, 'Google Internship');
      expect(r.reason, ReportReason.brokenLink);
      expect(r.status, ReportStatus.open);
    });

    test('create payload forces open status and includes reason key', () {
      const r = ContentReport(
        id: '',
        resourceId: 'res1',
        resourceTitle: 'T',
        reporterUid: 'u1',
        reason: ReportReason.deadlinePassed,
        message: '  the deadline was last week  ',
      );
      final m = r.toCreateMap();
      expect(m['status'], 'open');
      expect(m['reason'], 'deadline_passed');
      expect(m['reporterUid'], 'u1');
      expect(m['message'], 'the deadline was last week'); // trimmed
    });

    test('empty message is omitted from the create payload', () {
      const r = ContentReport(
        id: '',
        resourceId: 'res1',
        resourceTitle: 'T',
        reporterUid: 'u1',
        reason: ReportReason.other,
        message: '   ',
      );
      expect(r.toCreateMap().containsKey('message'), isFalse);
    });
  });

  group('activeReportCountsByResource', () {
    test('counts only open/under-review per resource', () {
      const base = {
        'resourceTitle': 'T',
        'reporterUid': 'u',
      };
      final reports = [
        ContentReport.fromMap('1', {...base, 'resourceId': 'a', 'status': 'open'}),
        ContentReport.fromMap('2', {...base, 'resourceId': 'a', 'status': 'under_review'}),
        ContentReport.fromMap('3', {...base, 'resourceId': 'a', 'status': 'resolved'}),
        ContentReport.fromMap('4', {...base, 'resourceId': 'b', 'status': 'open'}),
        ContentReport.fromMap('5', {...base, 'resourceId': 'b', 'status': 'dismissed'}),
      ];
      final counts = activeReportCountsByResource(reports);
      expect(counts['a'], 2);
      expect(counts['b'], 1);
    });
  });
}
