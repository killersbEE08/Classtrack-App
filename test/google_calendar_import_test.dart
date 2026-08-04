import 'package:classtrack/features/import/domain/google_calendar_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure Google Calendar -> weekly-schedule mapper. No network or
/// OAuth involved — just event JSON in, [ParsedSchedule] out.
///
/// Calendar dates used: 2026-08-03 is a Monday, 2026-08-05 a Wednesday,
/// 2026-08-10 / 2026-08-17 the following Mondays.
Map<String, dynamic> event({
  String? summary,
  String? start,
  String? end,
  String? location,
  String? status,
}) =>
    <String, dynamic>{
      if (summary != null) 'summary': summary,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
      if (start != null) 'start': {'dateTime': start},
      if (end != null) 'end': {'dateTime': end},
    };

void main() {
  group('googleCalendarToSchedule', () {
    test('empty input -> empty schedule', () {
      final s = googleCalendarToSchedule(const []);
      expect(s.isEmpty, isTrue);
      expect(s.confidence, 'high');
    });

    test('collapses repeated weekly instances into a single session', () {
      // Same DBMS class on three consecutive Mondays -> one weekly session.
      final s = googleCalendarToSchedule([
        event(
            summary: 'DBMS',
            start: '2026-08-03T09:00:00+05:30',
            end: '2026-08-03T10:00:00+05:30',
            location: 'Room 204'),
        event(
            summary: 'DBMS',
            start: '2026-08-10T09:00:00+05:30',
            end: '2026-08-10T10:00:00+05:30',
            location: 'Room 204'),
        event(
            summary: 'DBMS',
            start: '2026-08-17T09:00:00+05:30',
            end: '2026-08-17T10:00:00+05:30',
            location: 'Room 204'),
      ]);
      expect(s.subjects.length, 1);
      final dbms = s.subjects.single;
      expect(dbms.name, 'DBMS');
      expect(dbms.sessions.length, 1);
      final sess = dbms.sessions.single;
      expect(sess.day, 'Monday');
      expect(sess.start, '09:00');
      expect(sess.end, '10:00');
      expect(sess.room, 'Room 204');
    });

    test('keeps distinct weekday/time slots as separate sessions', () {
      final s = googleCalendarToSchedule([
        event(summary: 'DBMS', start: '2026-08-03T09:00:00+05:30', end: '2026-08-03T10:00:00+05:30'),
        event(summary: 'DBMS', start: '2026-08-05T14:00:00+05:30', end: '2026-08-05T15:00:00+05:30'),
      ]);
      expect(s.subjects.length, 1);
      final sessions = s.subjects.single.sessions;
      expect(sessions.length, 2);
      // Sorted by weekday then start: Monday first, Wednesday second.
      expect(sessions[0].day, 'Monday');
      expect(sessions[0].start, '09:00');
      expect(sessions[1].day, 'Wednesday');
      expect(sessions[1].start, '14:00');
    });

    test('groups different titles into different subjects (order preserved)', () {
      final s = googleCalendarToSchedule([
        event(summary: 'DBMS', start: '2026-08-03T09:00:00+05:30', end: '2026-08-03T10:00:00+05:30'),
        event(summary: 'OS Lab', start: '2026-08-03T11:00:00+05:30', end: '2026-08-03T13:00:00+05:30'),
      ]);
      expect(s.subjects.map((e) => e.name).toList(), ['DBMS', 'OS Lab']);
    });

    test('skips all-day events (date, no dateTime)', () {
      final s = googleCalendarToSchedule([
        {
          'summary': 'Holiday',
          'start': {'date': '2026-08-03'},
          'end': {'date': '2026-08-04'},
        },
      ]);
      expect(s.isEmpty, isTrue);
    });

    test('skips cancelled instances', () {
      final s = googleCalendarToSchedule([
        event(
            summary: 'DBMS',
            start: '2026-08-03T09:00:00+05:30',
            end: '2026-08-03T10:00:00+05:30',
            status: 'cancelled'),
      ]);
      expect(s.isEmpty, isTrue);
    });

    test('uses the event wall-clock time, not a UTC-converted one', () {
      // 01:00 on Mon 2026-08-03 at +05:30 is Sunday 19:30 UTC. A correct mapper
      // reports Monday 01:00 (the time as written), not Sunday.
      final s = googleCalendarToSchedule([
        event(
            summary: 'Early Lab',
            start: '2026-08-03T01:00:00+05:30',
            end: '2026-08-03T02:00:00+05:30'),
      ]);
      final sess = s.subjects.single.sessions.single;
      expect(sess.day, 'Monday');
      expect(sess.start, '01:00');
    });

    test('missing summary -> Untitled; missing end -> +1 hour', () {
      final s = googleCalendarToSchedule([
        event(start: '2026-08-03T09:00:00+05:30'),
      ]);
      final subject = s.subjects.single;
      expect(subject.name, 'Untitled');
      expect(subject.sessions.single.end, '10:00');
    });
  });
}
