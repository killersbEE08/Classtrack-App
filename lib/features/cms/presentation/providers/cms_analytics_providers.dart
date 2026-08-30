import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/utils/firestore_parsing.dart';
import '../../domain/cms_analytics.dart';

/// Global per-day engagement totals (most recent ~120 days) for windowed
/// funnels. Written by the backend; readable by any CMS role.
final cmsDailyMetricsProvider = StreamProvider<List<DailyMetric>>((ref) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection(AppConstants.metricsDailyCollection)
      .orderBy('day', descending: true)
      .limit(120)
      .snapshots()
      .map((snap) => parseDocsSafely(snap.docs, DailyMetric.fromMap,
          context: 'metricsDaily'));
});

/// Per-resource all-time engagement totals for Top Content.
final cmsResourceMetricsProvider = StreamProvider<List<ResourceMetric>>((ref) {
  final db = ref.watch(firestoreProvider);
  return db
      .collection(AppConstants.resourceMetricsCollection)
      .limit(500)
      .snapshots()
      .map((snap) => parseDocsSafely(snap.docs, ResourceMetric.fromMap,
          context: 'resourceMetrics'));
});
