import 'package:classtrack/features/attendance/presentation/providers/attendance_providers.dart';
import 'package:classtrack/features/schedule/domain/class_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('nextAttendanceSlot (per-session marking target)', () {
    test('no scheduled classes -> subject-level record (empty slot)', () {
      expect(nextAttendanceSlot(const [], <String>{}), '');
    });

    test('one class, none marked -> that class', () {
      expect(nextAttendanceSlot(const ['09:00'], <String>{}), '09:00');
    });

    test('one class already marked -> re-affirms the same (idempotent)', () {
      // All sessions marked -> returns last, so a re-tap corrects rather than
      // creating a second attendance for a single-class day.
      expect(nextAttendanceSlot(const ['09:00'], {'09:00'}), '09:00');
    });

    test('two classes: first tap marks the first', () {
      expect(nextAttendanceSlot(const ['09:00', '13:00'], <String>{}), '09:00');
    });

    test('two classes: second tap marks the second', () {
      expect(nextAttendanceSlot(const ['09:00', '13:00'], {'09:00'}), '13:00');
    });

    test('two classes both marked -> returns last (cannot exceed real count)',
        () {
      expect(
          nextAttendanceSlot(const ['09:00', '13:00'], {'09:00', '13:00'}),
          '13:00');
    });
  });

  group('attendanceOccurrenceKey', () {
    test('combines subject id and slot uniquely', () {
      expect(attendanceOccurrenceKey('subjA', '09:00'), 'subjA#09:00');
      // Same subject, different session -> different keys (tracked separately).
      expect(attendanceOccurrenceKey('subjA', '09:00') ==
          attendanceOccurrenceKey('subjA', '13:00'), isFalse);
    });
  });

  group('ClassSession.occursOn (recurring weekday match)', () {
    ClassSession recurringOn(int day, String start) => ClassSession(
          id: 'x',
          subjectId: 's',
          recurring: true,
          dayOfWeek: day, // 0=Mon .. 6=Sun
          startTime: start,
          endTime: '10:00',
        );

    test('recurring Monday session occurs on a Monday', () {
      final monday = DateTime(2026, 7, 20); // 2026-07-20 is a Monday
      expect(monday.weekday, DateTime.monday);
      expect(recurringOn(0, '09:00').occursOn(monday), isTrue);
    });

    test('recurring Monday session does NOT occur on a Tuesday', () {
      final tuesday = DateTime(2026, 7, 21);
      expect(recurringOn(0, '09:00').occursOn(tuesday), isFalse);
    });

    test('recurring Saturday session occurs on a Saturday', () {
      final saturday = DateTime(2026, 7, 25);
      expect(saturday.weekday, DateTime.saturday);
      expect(recurringOn(5, '12:05').occursOn(saturday), isTrue);
    });
  });

  group('ClassSession.signature (duplicate detection)', () {
    ClassSession s({int day = 0, String start = '09:00', String? room}) =>
        ClassSession(
          id: 'irrelevant',
          subjectId: 's',
          recurring: true,
          dayOfWeek: day,
          startTime: start,
          endTime: '10:00',
          room: room,
        );

    test('two identical sessions share a signature (dedup will drop one)', () {
      expect(s().signature, s().signature);
    });

    test('different day/time/room yields different signatures', () {
      expect(s(day: 0).signature == s(day: 2).signature, isFalse);
      expect(s(start: '09:00').signature == s(start: '11:00').signature,
          isFalse);
      expect(s(room: 'A').signature == s(room: 'B').signature, isFalse);
    });
  });
}
