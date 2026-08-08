import 'package:classtrack/features/import/data/import_repository.dart';
import 'package:classtrack/features/import/domain/calendar_event_mapper.dart';
import 'package:classtrack/features/tasks/domain/task_item.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tests for the pure Google Calendar -> event-task mapper and the re-import
/// de-duplication. No network or OAuth: event JSON in, tasks out.
///
/// 2026-08-05 is a Wednesday.
Map<String, dynamic> event({
  String? id,
  String? summary,
  String? start,
  String? end,
  String? startDate,
  String? location,
  String? status,
  String? hangoutLink,
  String? description,
}) =>
    <String, dynamic>{
      if (id != null) 'id': id,
      if (summary != null) 'summary': summary,
      if (location != null) 'location': location,
      if (status != null) 'status': status,
      if (hangoutLink != null) 'hangoutLink': hangoutLink,
      if (description != null) 'description': description,
      if (start != null) 'start': {'dateTime': start},
      if (startDate != null) 'start': {'date': startDate},
      if (end != null) 'end': {'dateTime': end},
    };

void main() {
  group('googleCalendarToEventTasks', () {
    test('empty input -> no tasks', () {
      expect(googleCalendarToEventTasks(const []), isEmpty);
    });

    test('a timed event becomes an event task with its start time', () {
      final tasks = googleCalendarToEventTasks([
        event(
          id: 'evt1',
          summary: 'Team standup',
          start: '2026-08-05T10:30:00+05:30',
          end: '2026-08-05T11:00:00+05:30',
        ),
      ]);
      expect(tasks.length, 1);
      final t = tasks.single;
      expect(t.title, 'Team standup');
      expect(t.allDay, isFalse);
      expect(t.start, DateTime(2026, 8, 5, 10, 30));
      expect(t.due, DateTime(2026, 8, 5, 10, 30));
      expect(t.sourceId, 'evt1');
    });

    test('an all-day event is flagged all-day with a midnight due date', () {
      final tasks = googleCalendarToEventTasks([
        event(id: 'h1', summary: 'Holiday', startDate: '2026-08-05'),
      ]);
      expect(tasks.length, 1);
      final t = tasks.single;
      expect(t.allDay, isTrue);
      expect(t.due, DateTime(2026, 8, 5)); // midnight -> "all day"
    });

    test('cancelled instances are skipped', () {
      final tasks = googleCalendarToEventTasks([
        event(
          id: 'c1',
          summary: 'Cancelled class',
          start: '2026-08-05T09:00:00+05:30',
          status: 'cancelled',
        ),
      ]);
      expect(tasks, isEmpty);
    });

    test('missing summary -> Untitled', () {
      final tasks = googleCalendarToEventTasks([
        event(id: 'x', start: '2026-08-05T09:00:00+05:30'),
      ]);
      expect(tasks.single.title, 'Untitled');
    });

    test('UTC (Z) instants are converted to device local time', () {
      final tasks = googleCalendarToEventTasks([
        event(
          id: 'z1',
          summary: 'Webinar',
          start: '2026-08-05T05:30:00.000Z',
        ),
      ]);
      expect(tasks.single.start,
          DateTime.parse('2026-08-05T05:30:00.000Z').toLocal());
    });

    test('location is captured and a hangout link is extracted', () {
      final tasks = googleCalendarToEventTasks([
        event(
          id: 'm1',
          summary: 'DBMS',
          start: '2026-08-05T09:00:00+05:30',
          location: 'Room 204',
          hangoutLink: 'https://meet.google.com/abc-defg-hij',
        ),
      ]);
      final t = tasks.single;
      expect(t.location, 'Room 204');
      expect(t.link, 'https://meet.google.com/abc-defg-hij');
    });

    test('a URL in the description is used as the link', () {
      final tasks = googleCalendarToEventTasks([
        event(
          id: 'd1',
          summary: 'Lecture',
          start: '2026-08-05T09:00:00+05:30',
          description: 'Join: https://zoom.us/j/123456789 see you',
        ),
      ]);
      expect(tasks.single.link, 'https://zoom.us/j/123456789');
    });

    test('duplicate ids within one response collapse to one', () {
      final tasks = googleCalendarToEventTasks([
        event(id: 'same', summary: 'Class', start: '2026-08-05T09:00:00+05:30'),
        event(id: 'same', summary: 'Class', start: '2026-08-05T09:00:00+05:30'),
      ]);
      expect(tasks.length, 1);
    });
  });

  group('ImportRepository.filterNewEventTasks (re-import de-dup)', () {
    CalendarEventTask ev({
      required String title,
      String? sourceId,
      DateTime? start,
      bool allDay = false,
    }) =>
        CalendarEventTask(
          title: title,
          start: start ?? DateTime(2026, 8, 5, 9, 0),
          allDay: allDay,
          sourceId: sourceId,
        );

    TaskItem task({
      required String title,
      String? sourceId,
      DateTime? due,
    }) =>
        TaskItem(id: 'x', title: title, sourceId: sourceId, dueDate: due);

    test('first import: everything is new', () {
      final fresh = ImportRepository.filterNewEventTasks(
        [ev(title: 'A', sourceId: 'a1'), ev(title: 'B', sourceId: 'b1')],
        const [],
      );
      expect(fresh.length, 2);
    });

    test('second import of the same events adds nothing (source id match)', () {
      final incoming = [
        ev(title: 'A', sourceId: 'a1'),
        ev(title: 'B', sourceId: 'b1'),
      ];
      // Simulate what the first import saved.
      final existing = [
        task(title: 'A', sourceId: 'a1', due: DateTime(2026, 8, 5, 9, 0)),
        task(title: 'B', sourceId: 'b1', due: DateTime(2026, 8, 5, 9, 0)),
      ];
      final fresh = ImportRepository.filterNewEventTasks(incoming, existing);
      expect(fresh, isEmpty);
    });

    test('renamed calendar event with same id is still a duplicate', () {
      final fresh = ImportRepository.filterNewEventTasks(
        [ev(title: 'New name', sourceId: 'a1')],
        [task(title: 'Old name', sourceId: 'a1', due: DateTime(2026, 8, 5, 9))],
      );
      expect(fresh, isEmpty);
    });

    test('matches a source-less existing task by title + date + time', () {
      // An item created by hand (no sourceId) should not be re-added.
      final fresh = ImportRepository.filterNewEventTasks(
        [ev(title: 'Gym', sourceId: 'g1', start: DateTime(2026, 8, 5, 18, 0))],
        [task(title: 'Gym', due: DateTime(2026, 8, 5, 18, 0))],
      );
      expect(fresh, isEmpty);
    });

    test('same title + day but different time are kept as separate events', () {
      final fresh = ImportRepository.filterNewEventTasks(
        [
          ev(title: 'Lab', sourceId: 's1', start: DateTime(2026, 8, 5, 10, 0)),
          ev(title: 'Lab', sourceId: 's2', start: DateTime(2026, 8, 5, 14, 0)),
        ],
        const [],
      );
      expect(fresh.length, 2);
    });

    test('a brand-new event is added on a later import', () {
      final fresh = ImportRepository.filterNewEventTasks(
        [ev(title: 'A', sourceId: 'a1'), ev(title: 'C', sourceId: 'c1')],
        [task(title: 'A', sourceId: 'a1', due: DateTime(2026, 8, 5, 9, 0))],
      );
      expect(fresh.map((e) => e.title), ['C']);
    });
  });
}
