import 'package:classtrack/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Regression tests for the class-reminder notification id scheme.
///
/// The previous scheme keyed a class reminder by subject + weekday only, so two
/// classes for the same subject on the same weekday (e.g. a 09:00 and a 14:00
/// slot) produced the SAME id and the second silently overwrote the first — the
/// student only ever got one of the two reminders. Ids now also fold in the
/// class start time, so each slot gets its own reminder.
void main() {
  group('NotificationService.classReminderId', () {
    test('is byte-stable (FNV-1a golden values, not String.hashCode)', () {
      // Locks the id math to an explicit, cross-restart-stable hash. If this
      // ever reverts to String.hashCode (whose value the Dart spec does not
      // guarantee across executions) these goldens change and previously
      // scheduled reminders would become un-cancellable after a cold start.
      expect(NotificationService.classReminderId('math', 0, '09:00'), 2045920);
      expect(NotificationService.classReminderId('phy', 2, '11:30'), 2479277);
    });

    test('same subject + weekday but different start times -> distinct ids', () {
      final morning = NotificationService.classReminderId('math', 0, '09:00');
      final afternoon = NotificationService.classReminderId('math', 0, '14:00');
      expect(morning, isNot(equals(afternoon)),
          reason: 'two classes on the same weekday must not share one reminder');
    });

    test('deterministic across calls so re-scheduling overwrites (no dupes)',
        () {
      final a = NotificationService.classReminderId('phy', 2, '11:30');
      final b = NotificationService.classReminderId('phy', 2, '11:30');
      expect(a, equals(b));
    });

    test('distinct weekdays at the same time yield distinct ids', () {
      final ids = <int>{
        for (var d = 0; d < 7; d++)
          NotificationService.classReminderId('chem', d, '10:00'),
      };
      expect(ids.length, 7);
    });

    test('ids stay in the class band and never reach the task band', () {
      // Class band = 1 * 2_000_000; per-entity hash is masked to 20 bits
      // (< 1_048_576), so every class id falls in
      // [2_000_000, 2_000_000 + 1_048_576) — strictly below the task band at
      // 4_000_000, so a class reminder can never collide with a task/exam/etc.
      const bandStart = 2000000;
      const bandEnd = 2000000 + 1048576;
      for (final time in const ['00:00', '08:00', '23:59']) {
        for (var d = 0; d < 7; d++) {
          final id = NotificationService.classReminderId('subject-$d', d, time);
          expect(id, greaterThanOrEqualTo(bandStart));
          expect(id, lessThan(bandEnd));
        }
      }
    });
  });
}
