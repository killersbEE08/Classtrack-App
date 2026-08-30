// Pure analytics aggregation for the CMS, over the backend-written counters
// (`metricsDaily` global per-day totals, `resourceMetrics` per-resource
// all-time totals). Flutter/Firestore-free so it's unit-testable.

class MetricTotals {
  final int views;
  final int clicks;
  final int applies;
  final int saves;
  final int shares;

  const MetricTotals({
    this.views = 0,
    this.clicks = 0,
    this.applies = 0,
    this.saves = 0,
    this.shares = 0,
  });

  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  factory MetricTotals.fromMap(Map<String, dynamic> m) => MetricTotals(
        views: _i(m['views']),
        clicks: _i(m['clicks']),
        applies: _i(m['applies']),
        saves: _i(m['saves']),
        shares: _i(m['shares']),
      );

  MetricTotals operator +(MetricTotals o) => MetricTotals(
        views: views + o.views,
        clicks: clicks + o.clicks,
        applies: applies + o.applies,
        saves: saves + o.saves,
        shares: shares + o.shares,
      );

  /// Clicks ÷ views (0..1).
  double get clickRate => views == 0 ? 0 : clicks / views;

  /// Applies ÷ clicks (0..1).
  double get applyRate => clicks == 0 ? 0 : applies / clicks;
}

/// UTC yyyymmdd bucket id — MUST match the Cloud Function's `dayId`.
String dayIdFor(DateTime date) {
  final d = date.toUtc();
  final m = d.month.toString().padLeft(2, '0');
  final day = d.day.toString().padLeft(2, '0');
  return '${d.year}$m$day';
}

/// A single day's global totals.
class DailyMetric {
  final String day; // yyyymmdd
  final MetricTotals totals;
  const DailyMetric(this.day, this.totals);

  factory DailyMetric.fromMap(String id, Map<String, dynamic> m) =>
      DailyMetric((m['day'] as String?) ?? id, MetricTotals.fromMap(m));
}

/// Per-resource all-time totals (for Top Content).
class ResourceMetric {
  final String id;
  final String title;
  final String? type;
  final MetricTotals totals;
  const ResourceMetric(
      {required this.id,
      required this.title,
      required this.type,
      required this.totals});

  factory ResourceMetric.fromMap(String id, Map<String, dynamic> m) =>
      ResourceMetric(
        id: id,
        title: (m['title'] as String?) ?? '($id)',
        type: m['type'] as String?,
        totals: MetricTotals.fromMap(m),
      );
}

/// Sums the daily totals for the last [days] days (inclusive of today, UTC).
MetricTotals sumDailyWithinDays(List<DailyMetric> daily, int days,
    {DateTime? now}) {
  final cutoff =
      dayIdFor((now ?? DateTime.now()).subtract(Duration(days: days - 1)));
  var total = const MetricTotals();
  for (final d in daily) {
    if (d.day.compareTo(cutoff) >= 0) total = total + d.totals;
  }
  return total;
}

/// Top [n] resources by the metric selected via [selector], descending.
List<ResourceMetric> topResourcesBy(
    List<ResourceMetric> list, int Function(MetricTotals) selector,
    {int n = 5}) {
  final filtered = list.where((r) => selector(r.totals) > 0).toList()
    ..sort((a, b) => selector(b.totals).compareTo(selector(a.totals)));
  return filtered.take(n).toList();
}
