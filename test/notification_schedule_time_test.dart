import 'package:classtrack/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Regression tests for [NotificationService.nextInstanceOfWeekdayTime].
///
/// A weekly class reminder must fire exactly [minutesBefore] before the class
/// on its own weekday, and the returned instant is also the anchor for the
/// weekly repeat (matchDateTimeComponents: dayOfWeekAndTime). Subtracting the
/// lead before aligning the weekday mis-fires for classes near midnight, whose
/// reminder legitimately falls on the *previous* day.
void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
    // Fixed, offset-free zone so the arithmetic is deterministic on any host.
    tz.setLocalLocation(tz.getLocation('UTC'));
  });

  tz.TZDateTime at(int y, int m, int d, int h, int min) =>
      tz.TZDateTime(tz.local, y, m, d, h, min);

  group('nextInstanceOfWeekdayTime', () {
    test('normal daytime class reminds minutesBefore, same weekday', () {
      // 2024-01-01 is a Monday. weekday0 == 0 -> Monday.
      final now = at(2024, 1, 1, 6, 0);
      final r = NotificationService.nextInstanceOfWeekdayTime(
        now: now,
        weekday0: 0,
        hour: 9,
        minute: 0,
        minutesBefore: 10,
      );
      expect(r, at(2024, 1, 1, 8, 50));
      expect(r.weekday, DateTime.monday);
      // Class start = reminder + lead lands on the class weekday.
      expect(r.add(const Duration(minutes: 10)).weekday, DateTime.monday);
    });

    test('near-midnight class reminds on the PREVIOUS day (no 24h drift)', () {
      // Monday 00:05 class, 10-min lead -> reminder Sunday 23:55, NOT Monday.
      final now = at(2024, 1, 1, 0, 0); // Monday 00:00
      final r = NotificationService.nextInstanceOfWeekdayTime(
        now: now,
        weekday0: 0, // Monday
        hour: 0,
        minute: 5,
        minutesBefore: 10,
      );
      // Next Monday 00:05 is 2024-01-08; reminder is Sunday 2024-01-07 23:55.
      expect(r, at(2024, 1, 7, 23, 55));
      expect(r.weekday, DateTime.sunday);
      // The lead still lands precisely on the Monday 00:05 class start.
      expect(r.add(const Duration(minutes: 10)), at(2024, 1, 8, 0, 5));
    });

    test('reschedules to next week when this week has already passed', () {
      // Now is Monday 09:00; the 08:50 reminder for a Monday 09:00 class has
      // already passed, so it must move to next Monday.
      final now = at(2024, 1, 1, 9, 0);
      final r = NotificationService.nextInstanceOfWeekdayTime(
        now: now,
        weekday0: 0,
        hour: 9,
        minute: 0,
        minutesBefore: 10,
      );
      expect(r, at(2024, 1, 8, 8, 50));
      expect(r.weekday, DateTime.monday);
    });
  });
}
