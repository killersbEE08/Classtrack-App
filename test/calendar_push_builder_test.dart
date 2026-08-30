import 'package:classtrack/features/calendar/domain/calendar_push_builder.dart';
import 'package:classtrack/features/exams/domain/exam.dart';
import 'package:classtrack/features/schedule/domain/class_session.dart';
import 'package:classtrack/features/subjects/domain/subject.dart';
import 'package:classtrack/features/tasks/domain/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure Google Calendar write-back builders (two-way sync, Pro).
/// No network or OAuth — ClassTrack data in, event-body maps out.
void main() {
  group('stableEventId', () {
    test('is deterministic for the same seed (idempotent upserts)', () {
      expect(stableEventId('exam_abc'), stableEventId('exam_abc'));
    });

    test('differs for different seeds', () {
      expect(stableEventId('exam_a') == stableEventId('exam_b'), isFalse);
    });

    test('uses only Google-legal base32hex chars and is >= 5 long', () {
      final id = stableEventId('class_sub1_sess1');
      expect(id.length, greaterThanOrEqualTo(5));
      expect(RegExp(r'^[a-v0-9]+$').hasMatch(id), isTrue);
    });
  });

  group('nextWeekdayOnOrAfter', () {
    test('returns the same day when it already matches', () {
      // 2026-08-31 is a Monday (weekday0 = 0).
      final d = nextWeekdayOnOrAfter(DateTime(2026, 8, 31), 0);
      expect(d, DateTime(2026, 8, 31));
    });

    test('advances to the next matching weekday', () {
      // From Monday 2026-08-31, next Wednesday (weekday0 = 2) is 2026-09-02.
      final d = nextWeekdayOnOrAfter(DateTime(2026, 8, 31), 2);
      expect(d, DateTime(2026, 9, 2));
    });
  });

  group('examToEvent', () {
    final exam = Exam(
      id: 'e1',
      title: 'Databases Final',
      date: DateTime(2026, 9, 5, 10, 0),
      room: 'Hall A',
      note: 'Chapters 1-6',
    );

    test('builds a timed event with a stable id and metadata', () {
      final ev = examToEvent(exam, timeZone: 'Asia/Kolkata');
      expect(ev['id'], stableEventId('exam_e1'));
      expect(ev['summary'], contains('Databases Final'));
      expect(ev['location'], 'Hall A');
      expect(ev['description'], 'Chapters 1-6');
      expect((ev['start'] as Map)['dateTime'], '2026-09-05T10:00:00');
      expect((ev['start'] as Map)['timeZone'], 'Asia/Kolkata');
      // Default duration is 2h.
      expect((ev['end'] as Map)['dateTime'], '2026-09-05T12:00:00');
      final priv = (ev['extendedProperties'] as Map)['private'] as Map;
      expect(priv['classtrack'], 'exam');
      expect(priv['classtrackId'], 'e1');
    });
  });

  group('taskToEvent', () {
    test('returns null when the task has no due date', () {
      const t = TaskItem(id: 't0', title: 'No due');
      expect(taskToEvent(t, timeZone: 'UTC'), isNull);
    });

    test('a midnight due date becomes an all-day event (exclusive end)', () {
      final t = TaskItem(id: 't1', title: 'Submit essay', dueDate: DateTime(2026, 9, 3));
      final ev = taskToEvent(t, timeZone: 'UTC')!;
      expect((ev['start'] as Map)['date'], '2026-09-03');
      expect((ev['end'] as Map)['date'], '2026-09-04');
      expect(ev.containsKey('start'), isTrue);
      expect((ev['start'] as Map).containsKey('dateTime'), isFalse);
    });

    test('a timed due date becomes a short timed event', () {
      final t = TaskItem(
          id: 't2', title: 'Call advisor', dueDate: DateTime(2026, 9, 3, 15, 30));
      final ev = taskToEvent(t, timeZone: 'Asia/Kolkata')!;
      expect((ev['start'] as Map)['dateTime'], '2026-09-03T15:30:00');
      expect((ev['end'] as Map)['dateTime'], '2026-09-03T16:00:00');
    });
  });

  group('classSessionToEvent', () {
    Subject subject({DateTime? end}) => Subject(
          id: 's1',
          name: 'DBMS',
          colorHex: 0xFF3730A3,
          room: 'Room 204',
          endDate: end,
        );

    test('recurring session builds a weekly RRULE event', () {
      const session = ClassSession(
        id: 'sess1',
        subjectId: 's1',
        recurring: true,
        dayOfWeek: 0, // Monday
        startTime: '09:00',
        endTime: '10:00',
      );
      final ev = classSessionToEvent(
        subject(),
        session,
        firstDate: DateTime(2026, 8, 31), // a Monday
        timeZone: 'Asia/Kolkata',
      )!;
      expect(ev['summary'], 'DBMS');
      expect(ev['location'], 'Room 204');
      expect((ev['start'] as Map)['dateTime'], '2026-08-31T09:00:00');
      final rec = ev['recurrence'] as List;
      expect(rec.single, 'RRULE:FREQ=WEEKLY');
    });

    test('recurring session with a subject end date adds an UNTIL bound', () {
      const session = ClassSession(
        id: 'sess1',
        subjectId: 's1',
        recurring: true,
        dayOfWeek: 0,
        startTime: '09:00',
        endTime: '10:00',
      );
      final ev = classSessionToEvent(
        subject(end: DateTime(2026, 12, 20)),
        session,
        firstDate: DateTime(2026, 8, 31),
        timeZone: 'Asia/Kolkata',
      )!;
      final rule = (ev['recurrence'] as List).single as String;
      expect(rule, startsWith('RRULE:FREQ=WEEKLY;UNTIL='));
      expect(rule, contains('Z'));
    });

    test('one-off session builds a single dated event (no recurrence)', () {
      final session = ClassSession(
        id: 'sess2',
        subjectId: 's1',
        recurring: false,
        specificDate: DateTime(2026, 9, 4),
        startTime: '14:00',
        endTime: '15:30',
      );
      final ev = classSessionToEvent(
        subject(),
        session,
        firstDate: DateTime(2026, 9, 4),
        timeZone: 'UTC',
      )!;
      expect(ev.containsKey('recurrence'), isFalse);
      expect((ev['start'] as Map)['dateTime'], '2026-09-04T14:00:00');
      expect((ev['end'] as Map)['dateTime'], '2026-09-04T15:30:00');
    });

    test('recurring session without a weekday is skipped', () {
      const session = ClassSession(
        id: 'sess3',
        subjectId: 's1',
        recurring: true,
        startTime: '09:00',
        endTime: '10:00',
      );
      final ev = classSessionToEvent(
        subject(),
        session,
        firstDate: DateTime(2026, 8, 31),
        timeZone: 'UTC',
      );
      expect(ev, isNull);
    });
  });
}
