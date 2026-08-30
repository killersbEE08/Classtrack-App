import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/audience_counts.dart';

void main() {
  group('AudienceCounts', () {
    final counts = AudienceCounts.fromMap({
      'total': 1200,
      'country': {'India': 800, 'USA': 150, 'Zero': 0},
    });

    test('fromMap parses total and drops zero buckets', () {
      expect(counts.total, 1200);
      expect(counts.byCountry['India'], 800);
      expect(counts.byCountry.containsKey('Zero'), isFalse);
    });

    test('estimate: null country → total (everyone)', () {
      expect(counts.estimate(), 1200);
      expect(counts.estimate(country: ''), 1200);
    });

    test('estimate: country → that bucket, unknown → 0', () {
      expect(counts.estimate(country: 'India'), 800);
      expect(counts.estimate(country: 'Narnia'), 0);
    });

    test('empty aggregate is safe', () {
      const empty = AudienceCounts();
      expect(empty.estimate(), 0);
      expect(empty.estimate(country: 'India'), 0);
    });
  });
}
