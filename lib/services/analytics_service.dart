import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide access to [AnalyticsService].
final analyticsProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

/// Thin, crash-proof wrapper around Firebase Analytics so feature code can log
/// usage without touching the SDK directly — and so a logging failure can
/// NEVER break the app (every call is guarded).
///
/// We use a small set of high-signal events to answer "which features do users
/// actually use": tab switches, feature-screen opens, quick-add usage, AI
/// messages and schedule imports. View them in Firebase Console → Analytics
/// (DebugView for live testing from a single device).
class AnalyticsService {
  FirebaseAnalytics get _fa => FirebaseAnalytics.instance;

  /// Logs a custom event. Parameter values must be String or num (no bools).
  Future<void> log(String name, [Map<String, Object>? params]) async {
    try {
      await _fa.logEvent(name: name, parameters: params);
    } catch (_) {
      // Analytics must never surface as an app error.
    }
  }

  /// Logs a screen/feature view.
  Future<void> screen(String name) async {
    try {
      await _fa.logScreenView(screenName: name);
    } catch (_) {}
  }

  // --- Convenience helpers for the events we care about --------------------

  Future<void> tab(String name) => log('tab_select', {'tab': name});

  Future<void> openFeature(String name) =>
      log('open_feature', {'feature': name});

  Future<void> quickAdd(String type) => log('quick_add', {'type': type});

  Future<void> aiMessage({bool hasImage = false}) =>
      log('ai_message', {'has_image': hasImage ? 1 : 0});

  Future<void> scheduleImport(String source) =>
      log('schedule_import', {'source': source});
}
