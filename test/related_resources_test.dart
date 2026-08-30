import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/opportunities/data/resource_repository.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

Resource _r(String id,
        {ResourceType type = ResourceType.internship,
        ResourceStatus status = ResourceStatus.active,
        List<String> related = const []}) =>
    Resource(
      id: id,
      type: type,
      title: 'T$id',
      organization: 'Org',
      status: status,
      relatedResourceIds: related,
    );

void main() {
  group('ResourceQueries.related', () {
    test('manually-curated related come first, in order', () {
      final current = _r('1', related: ['3', '2']);
      final all = [current, _r('2'), _r('3'), _r('4')];
      final rel = ResourceQueries.related(current, all, limit: 4);
      expect(rel.take(2).map((r) => r.id).toList(), ['3', '2']);
    });

    test('auto-fills with same-type active resources after curated ones', () {
      final current = _r('1', type: ResourceType.internship, related: ['2']);
      final all = [
        current,
        _r('2', type: ResourceType.scholarship), // curated (any type kept)
        _r('3', type: ResourceType.internship), // auto same-type
        _r('4', type: ResourceType.discount), // different type, skipped
      ];
      final rel = ResourceQueries.related(current, all, limit: 4);
      expect(rel.map((r) => r.id).toList(), ['2', '3']);
    });

    test('never includes self and respects the limit', () {
      final current = _r('1', related: ['1', '2', '3']);
      final all = [current, _r('2'), _r('3'), _r('4'), _r('5')];
      final rel = ResourceQueries.related(current, all, limit: 2);
      expect(rel.length, 2);
      expect(rel.any((r) => r.id == '1'), isFalse);
    });

    test('auto-fill excludes non-active resources', () {
      final current = _r('1');
      final all = [
        current,
        _r('2', status: ResourceStatus.applicationsClosed),
        _r('3', status: ResourceStatus.active),
      ];
      final rel = ResourceQueries.related(current, all, limit: 4);
      expect(rel.map((r) => r.id).toList(), ['3']); // 2 is not in active feed
    });
  });
}
