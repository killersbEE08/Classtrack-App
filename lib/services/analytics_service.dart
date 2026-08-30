import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App-wide access to [AnalyticsService].
final analyticsProvider = Provider<AnalyticsService>(
  (ref) => AnalyticsService(),
);

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

  // --- Import funnel -------------------------------------------------------
  // A step-by-step funnel so we can see exactly where users drop off in the AI
  // timetable import: opened → method chosen → parse started → succeeded/failed
  // (with a reason) → reviewed & saved. View in Firebase → Analytics → Funnels.

  /// The AI import screen was opened. [source] is where it was launched from
  /// (e.g. 'attendance_onboarding' or 'schedule').
  Future<void> importOpened(String source) =>
      log('import_opened', {'source': source});

  /// A specific upload method was chosen: 'camera' | 'gallery' | 'pdf' | 'text'.
  Future<void> importMethodSelected(String method) =>
      log('import_method_selected', {'method': method});

  /// The parse request was sent to the backend.
  Future<void> importParseStarted(String method) =>
      log('import_parse_started', {'method': method});

  /// The parse returned usable results.
  Future<void> importParseSucceeded(
    String method, {
    required int subjects,
    required String confidence,
  }) => log('import_parse_succeeded', {
    'method': method,
    'subjects': subjects,
    'confidence': confidence,
  });

  /// The parse failed or returned nothing. [reason] is a coarse category, e.g.
  /// 'empty' | 'not_a_timetable' | 'limit_reached' | 'network' | 'unknown'.
  Future<void> importParseFailed(String method, String reason) =>
      log('import_parse_failed', {'method': method, 'reason': reason});

  /// The reviewed schedule was committed to the app.
  Future<void> importReviewSaved({
    required int subjects,
    required int sessions,
    required int tasks,
  }) => log('import_review_saved', {
    'subjects': subjects,
    'sessions': sessions,
    'tasks': tasks,
  });
}
