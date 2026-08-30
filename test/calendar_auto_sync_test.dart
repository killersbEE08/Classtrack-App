import 'package:classtrack/core/constants/app_constants.dart';
import 'package:classtrack/core/utils/date_utils.dart';
import 'package:classtrack/services/calendar_auto_sync.dart';
import 'package:classtrack/services/google_calendar_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure gate that decides whether the daily 7 PM Google
/// Calendar/Tasks auto-sync should run, and for the pure "past 7 days only"
/// query window. No prefs, network or OAuth involved.
void main() {
  group('shouldAutoSync', () {
    // A moment at/after 7 PM local, used as the "eligible" baseline.
    final evening = DateTime(2026, 8, 30, 19, 0);

    test('does not run for a non-Pro user (auto-sync is a Pro perk)', () {
      expect(
        shouldAutoSync(
            isPro: false,
            enabled: true,
            connected: true,
            now: evening,
            lastSyncYmd: null),
        isFalse,
      );
    });

    test('does not run when the feature is disabled', () {
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: false,
            connected: true,
            now: evening,
            lastSyncYmd: null),
        isFalse,
      );
    });

    test('does not run when Google was never connected', () {
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: false,
            now: evening,
            lastSyncYmd: null),
        isFalse,
      );
    });

    test('does not run before 7 PM', () {
      final afternoon = DateTime(2026, 8, 30, 18, 59);
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: true,
            now: afternoon,
            lastSyncYmd: null),
        isFalse,
      );
    });

    test('runs at exactly 7 PM when Pro, enabled, connected and never synced', () {
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: true,
            now: evening,
            lastSyncYmd: null),
        isTrue,
      );
    });

    test('runs later in the evening too', () {
      final late = DateTime(2026, 8, 30, 23, 30);
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: true,
            now: late,
            lastSyncYmd: null),
        isTrue,
      );
    });

    test('does not run twice on the same day', () {
      final today = DateUtilsX.dateId(evening);
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: true,
            now: evening,
            lastSyncYmd: today),
        isFalse,
      );
    });

    test('runs again the next day after a previous sync', () {
      final yesterday =
          DateUtilsX.dateId(evening.subtract(const Duration(days: 1)));
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: true,
            now: evening,
            lastSyncYmd: yesterday),
        isTrue,
      );
    });

    test('honours a custom trigger hour', () {
      final at9pm = DateTime(2026, 8, 30, 21, 0);
      // With the trigger pushed to 22:00, 21:00 is too early.
      expect(
        shouldAutoSync(
            isPro: true,
            enabled: true,
            connected: true,
            now: at9pm,
            lastSyncYmd: null,
            hour: 22),
        isFalse,
      );
    });
  });

  group('calendarWindow (past 7 days only)', () {
    test('defaults reach exactly 7 days back and 60 days ahead', () {
      final now = DateTime.utc(2026, 8, 30, 12, 0);
      final w = calendarWindow(now: now);

      final min = DateTime.parse(w.timeMin);
      final max = DateTime.parse(w.timeMax);

      expect(now.toUtc().difference(min).inDays, AppConstants.googleImportBackDays);
      expect(now.toUtc().difference(min).inDays, 7);
      expect(max.difference(now.toUtc()).inDays,
          AppConstants.googleImportForwardDays);
    });

    test('never reaches back more than 7 days from now', () {
      final now = DateTime.now();
      final w = calendarWindow(now: now);
      final min = DateTime.parse(w.timeMin);
      // timeMin must not be older than 7 days before now.
      expect(now.toUtc().difference(min).inDays, lessThanOrEqualTo(7));
    });
  });
}
