import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/cms_analytics.dart';

void main() {
  group('MetricTotals', () {
    test('fromMap parses and rates compute correctly', () {
      final t = MetricTotals.fromMap(
          {'views': 100, 'clicks': 25, 'applies': 5, 'saves': 10, 'shares': 2});
      expect(t.views, 100);
      expect(t.clickRate, closeTo(0.25, 1e-9));
      expect(t.applyRate, closeTo(0.2, 1e-9));
    });

    test('rates are zero-safe', () {
      const t = MetricTotals();
      expect(t.clickRate, 0);
      expect(t.applyRate, 0);
    });

    test('addition combines totals', () {
      const a = MetricTotals(views: 10, clicks: 2);
      const b = MetricTotals(views: 5, clicks: 3, applies: 1);
      final c = a + b;
      expect(c.views, 15);
      expect(c.clicks, 5);
      expect(c.applies, 1);
    });
  });

  group('sumDailyWithinDays', () {
    final now = DateTime.utc(2026, 8, 8, 12);
    List<DailyMetric> daily() => [
          DailyMetric(dayIdFor(now), const MetricTotals(views: 10, clicks: 4)),
          DailyMetric(dayIdFor(now.subtract(const Duration(days: 3))),
              const MetricTotals(views: 20, clicks: 5)),
          DailyMetric(dayIdFor(now.subtract(const Duration(days: 20))),
              const MetricTotals(views: 100, clicks: 50)),
        ];

    test('7-day window excludes the 20-day-old bucket', () {
      final t = sumDailyWithinDays(daily(), 7, now: now);
      expect(t.views, 30); // 10 + 20
      expect(t.clicks, 9);
    });

    test('30-day window includes all', () {
      final t = sumDailyWithinDays(daily(), 30, now: now);
      expect(t.views, 130);
    });
  });

  group('topResourcesBy', () {
    final list = [
      const ResourceMetric(
          id: '1', title: 'A', type: 'internship', totals: MetricTotals(views: 5)),
      const ResourceMetric(
          id: '2', title: 'B', type: 'discount', totals: MetricTotals(views: 50)),
      const ResourceMetric(
          id: '3', title: 'C', type: 'internship', totals: MetricTotals(views: 0)),
    ];

    test('ranks by selector descending and drops zeros', () {
      final top = topResourcesBy(list, (t) => t.views);
      expect(top.map((r) => r.id).toList(), ['2', '1']); // '3' has 0 views
    });
  });
}
