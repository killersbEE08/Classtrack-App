import 'package:classtrack/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the after-class "attendance check-in" notification: the id scheme
/// (band 8, distinct from every other reminder band) and the Present/Absent
/// action payload parsing that HomeShell uses to mark the class.
void main() {
  group('NotificationService.attendanceCheckId', () {
    test('is deterministic so re-scheduling overwrites (no duplicates)', () {
      final a =
          NotificationService.attendanceCheckId('math', 0, '09:00', '10:00');
      final b =
          NotificationService.attendanceCheckId('math', 0, '09:00', '10:00');
      expect(a, equals(b));
    });

    test('different class slots on the same weekday -> distinct ids', () {
      final morning =
          NotificationService.attendanceCheckId('math', 0, '09:00', '10:00');
      final afternoon =
          NotificationService.attendanceCheckId('math', 0, '14:00', '15:00');
      expect(morning, isNot(equals(afternoon)));
    });

    test('stays in its own band (8) — never collides with class reminders', () {
      const bandStart = 8 * 2000000;
      const bandEnd = bandStart + 1048576;
      for (final slot in const [
        ('00:00', '01:00'),
        ('09:00', '10:00'),
        ('23:00', '23:59'),
      ]) {
        for (var d = 0; d < 7; d++) {
          final id = NotificationService.attendanceCheckId(
              'subject-$d', d, slot.$1, slot.$2);
          expect(id, greaterThanOrEqualTo(bandStart));
          expect(id, lessThan(bandEnd));
        }
      }

      // And it must not land in the class-reminder band (1 * 2_000_000).
      final checkId =
          NotificationService.attendanceCheckId('math', 0, '09:00', '10:00');
      final classId = NotificationService.classReminderId('math', 0, '09:00');
      expect(checkId, isNot(equals(classId)));
    });
  });

  group('NotificationService.parseAttendanceMark', () {
    test('parses a present action payload with a slot', () {
      final r = NotificationService.parseAttendanceMark(
          'attendance_mark|present|subj123|09:00');
      expect(r, isNotNull);
      expect(r!.status, 'present');
      expect(r.subjectId, 'subj123');
      expect(r.slot, '09:00');
    });

    test('parses an absent action payload', () {
      final r = NotificationService.parseAttendanceMark(
          'attendance_mark|absent|abc|14:30');
      expect(r!.status, 'absent');
      expect(r.subjectId, 'abc');
      expect(r.slot, '14:30');
    });

    test('tolerates a missing slot', () {
      final r = NotificationService.parseAttendanceMark(
          'attendance_mark|present|abc');
      expect(r, isNotNull);
      expect(r!.slot, '');
    });

    test('returns null for the plain check-in (deep-link) payload', () {
      expect(
        NotificationService.parseAttendanceMark('attendance_checkin|abc|09:00'),
        isNull,
      );
    });

    test('returns null for unrelated payloads and bad statuses', () {
      expect(NotificationService.parseAttendanceMark('daily_agenda'), isNull);
      expect(
          NotificationService.parseAttendanceMark('attendance_mark|maybe|abc'),
          isNull);
      expect(NotificationService.parseAttendanceMark('attendance_mark|present|'),
          isNull);
    });
  });
}
