import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/cms_metrics.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

Resource _r({
  required String id,
  ResourceType type = ResourceType.scholarship,
  ResourceStatus status = ResourceStatus.active,
  DateTime? startDate,
  DateTime? deadline,
  bool sponsored = false,
}) =>
    Resource(
      id: id,
      type: type,
      title: 'T$id',
      organization: 'Org',
      status: status,
      startDate: startDate,
      deadline: deadline,
      sponsored: sponsored,
    );

void main() {
  group('slugify', () {
    test('lowercases, hyphenates and trims', () {
      expect(slugify('Google Summer of Code 2026!'),
          'google-summer-of-code-2026');
    });
    test('collapses runs of separators and strips edges', () {
      expect(slugify('  --Hello,   World!!  '), 'hello-world');
    });
    test('empty / symbol-only input yields empty slug', () {
      expect(slugify('   '), '');
      expect(slugify('@@@'), '');
    });
  });

  group('isValidHttpUrl', () {
    test('accepts http and https absolute URLs', () {
      expect(isValidHttpUrl('https://example.com/a.png'), isTrue);
      expect(isValidHttpUrl('http://x.io'), isTrue);
    });
    test('rejects empty, relative, or non-http schemes', () {
      expect(isValidHttpUrl(''), isFalse);
      expect(isValidHttpUrl('   '), isFalse);
      expect(isValidHttpUrl('example.com'), isFalse);
      expect(isValidHttpUrl('ftp://x.io'), isFalse);
      expect(isValidHttpUrl('https://'), isFalse);
    });
  });

  group('computeContentMetrics', () {
    final now = DateTime(2026, 6, 1, 12);

    test('counts totals, drafts, archived and sponsored', () {
      final list = [
        _r(id: '1', status: ResourceStatus.active),
        _r(id: '2', status: ResourceStatus.draft),
        _r(id: '3', status: ResourceStatus.archived),
        _r(id: '4', status: ResourceStatus.active, sponsored: true),
      ];
      final m = computeContentMetrics(list, now: now);
      expect(m.total, 4);
      expect(m.drafts, 1);
      expect(m.archived, 1);
      expect(m.sponsored, 1);
    });

    test('applies date-driven lifecycle for effective buckets', () {
      final list = [
        // starts in the future -> opening soon
        _r(id: '1', status: ResourceStatus.active, startDate: now.add(const Duration(days: 5))),
        // deadline passed -> applications closed
        _r(id: '2', status: ResourceStatus.active, deadline: now.subtract(const Duration(days: 1))),
        // open now
        _r(id: '3', status: ResourceStatus.active, deadline: now.add(const Duration(days: 30))),
      ];
      final m = computeContentMetrics(list, now: now);
      expect(m.openingSoon, 1);
      expect(m.closedOrExpired, 1);
      expect(m.active, 1);
      expect(m.published, m.active + m.openingSoon);
    });

    test('expiringSoon counts active items within the window only', () {
      final list = [
        _r(id: '1', status: ResourceStatus.active, deadline: now.add(const Duration(days: 3))),
        _r(id: '2', status: ResourceStatus.active, deadline: now.add(const Duration(days: 20))),
        _r(id: '3', status: ResourceStatus.active, deadline: now.subtract(const Duration(days: 2))),
      ];
      final m = computeContentMetrics(list, now: now, expiringWindowDays: 7);
      expect(m.expiringSoon, 1);
    });

    test('byType / topTypes aggregate and sort by count', () {
      final list = [
        _r(id: '1', type: ResourceType.discount),
        _r(id: '2', type: ResourceType.discount),
        _r(id: '3', type: ResourceType.internship),
      ];
      final m = computeContentMetrics(list, now: now);
      expect(m.byType[ResourceType.discount], 2);
      expect(m.byType[ResourceType.internship], 1);
      expect(m.topTypes.first.key, ResourceType.discount);
    });
  });
}
