import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/firebase_providers.dart';

/// Writes append-only engagement events to `events/{id}`, which a Cloud
/// Function folds into queryable CMS counters. Fire-and-forget and crash-proof
/// so analytics can never break a student flow.
///
/// Canonical events: 'view', 'click', 'apply', 'save', 'share'. This is
/// complementary to [AnalyticsService] (Firebase Analytics) — GA events aren't
/// queryable from the CMS, these counters are.
class MetricsService {
  final FirebaseFirestore _db;
  final String? _uid;
  MetricsService(this._db, this._uid);

  Future<void> record({
    required String resourceId,
    required String event,
    String? type,
    String? title,
  }) async {
    if (_uid == null || resourceId.isEmpty) return;
    try {
      await _db.collection(AppConstants.eventsCollection).add({
        'resourceId': resourceId,
        'event': event,
        if (type != null) 'type': type,
        if (title != null) 'title': title,
        'uid': _uid,
        'at': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Analytics must never surface as an app error.
    }
  }
}

final metricsServiceProvider = Provider<MetricsService>((ref) {
  return MetricsService(
    ref.watch(firestoreProvider),
    ref.watch(currentUidProvider),
  );
});
