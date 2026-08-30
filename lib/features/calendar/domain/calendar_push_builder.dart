/// Pure builders that turn ClassTrack data (classes, exams, task deadlines)
/// into Google Calendar API v3 `events.insert`/`events.patch` request bodies
/// for the two-way-sync (Pro) write-back.
///
/// Everything here is side-effect free — no network, no OAuth, no clock reads
/// except where a concrete date is passed in — so the whole mapping can be
/// unit-tested. The network layer ([GoogleCalendarService.pushEvents]) just
/// takes these maps and POSTs/PATCHes them.
///
/// IDEMPOTENCY: every event carries a deterministic [stableEventId] derived
/// from the ClassTrack item's id. Re-pushing the same item therefore targets
/// the SAME Google event (insert, or patch on 409 conflict) instead of adding
/// a duplicate — so a user can push as often as they like.
library;

import '../../exams/domain/exam.dart';
import '../../schedule/domain/class_session.dart';
import '../../subjects/domain/subject.dart';
import '../../tasks/domain/task_item.dart';

/// A Google Calendar event id must be 5–1024 chars using base32hex
/// (`a`–`v` and `0`–`9`). Hex encoding a UTF-16 seed yields only `0`–`9a`–`f`,
/// which is a valid subset, and is fully deterministic so the same [seed]
/// always maps to the same id (the key to idempotent upserts).
String stableEventId(String seed) {
  final buf = StringBuffer('ct');
  for (final unit in seed.codeUnits) {
    buf.write(unit.toRadixString(16).padLeft(2, '0'));
  }
  var id = buf.toString();
  // Google caps ids at 1024 chars; stay well under.
  if (id.length > 1000) id = id.substring(0, 1000);
  // Guarantee the 5-char minimum (only relevant for pathologically short seeds).
  while (id.length < 5) {
    id += '0';
  }
  return id;
}

/// Local wall-clock timestamp in the `yyyy-MM-ddTHH:mm:ss` form the Calendar
/// API expects alongside an explicit `timeZone` field.
String localIso(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}'
      'T${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
}

/// Date-only `yyyy-MM-dd` (for all-day events).
String dateOnlyIso(DateTime d) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
}

/// RRULE `UNTIL` value: an inclusive end, expressed as a UTC instant
/// (`yyyyMMddTHHmmssZ`) as required when `DTSTART` is a dateTime.
String rruleUntilUtc(DateTime endOfLastDay) {
  final u = endOfLastDay.toUtc();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${u.year.toString().padLeft(4, '0')}${two(u.month)}${two(u.day)}'
      'T${two(u.hour)}${two(u.minute)}${two(u.second)}Z';
}

/// Parses a `HH:MM` string into (hour, minute); falls back to 09:00.
({int hour, int minute}) parseHm(String hhmm) {
  final parts = hhmm.split(':');
  final h = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 9 : 9;
  final m = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
}

/// The first date on or after [from] that falls on [weekday0] (0=Mon..6=Sun).
DateTime nextWeekdayOnOrAfter(DateTime from, int weekday0) {
  final base = DateTime(from.year, from.month, from.day);
  final target = weekday0 + 1; // DateTime.weekday is 1..7 (Mon..Sun)
  final delta = (target - base.weekday) % 7;
  return base.add(Duration(days: delta < 0 ? delta + 7 : delta));
}

/// Builds the event body for an exam. A timed event of [durationMinutes]
/// (default 2h) anchored at the exam's date+time.
Map<String, dynamic> examToEvent(
  Exam exam, {
  required String timeZone,
  int durationMinutes = 120,
}) {
  final start = exam.date;
  final end = start.add(Duration(minutes: durationMinutes));
  return <String, dynamic>{
    'id': stableEventId('exam_${exam.id}'),
    'summary': '📝 Exam: ${exam.title}',
    if (exam.note != null && exam.note!.trim().isNotEmpty)
      'description': exam.note!.trim(),
    if (exam.room != null && exam.room!.trim().isNotEmpty)
      'location': exam.room!.trim(),
    'start': {'dateTime': localIso(start), 'timeZone': timeZone},
    'end': {'dateTime': localIso(end), 'timeZone': timeZone},
    'extendedProperties': {
      'private': {'classtrack': 'exam', 'classtrackId': exam.id},
    },
  };
}

/// Builds the event body for a task deadline, or null when the task has no due
/// date (nothing to place on a calendar). A midnight due date becomes an
/// all-day event; a timed due date a short [durationMinutes] block.
Map<String, dynamic>? taskToEvent(
  TaskItem task, {
  required String timeZone,
  int durationMinutes = 30,
}) {
  final due = task.dueDate;
  if (due == null) return null;
  final title = task.title.trim();
  if (title.isEmpty) return null;

  final base = <String, dynamic>{
    'id': stableEventId('task_${task.id}'),
    'summary': '✅ ${task.title.trim()}',
    if (task.note != null && task.note!.trim().isNotEmpty)
      'description': task.note!.trim(),
    'extendedProperties': {
      'private': {'classtrack': 'task', 'classtrackId': task.id},
    },
  };

  final allDay = due.hour == 0 && due.minute == 0;
  if (allDay) {
    final endDate = DateTime(due.year, due.month, due.day)
        .add(const Duration(days: 1)); // Google end date is exclusive
    base['start'] = {'date': dateOnlyIso(due)};
    base['end'] = {'date': dateOnlyIso(endDate)};
  } else {
    base['start'] = {'dateTime': localIso(due), 'timeZone': timeZone};
    base['end'] = {
      'dateTime': localIso(due.add(Duration(minutes: durationMinutes))),
      'timeZone': timeZone,
    };
  }
  return base;
}

/// Builds the event body for a class [session] of [subject].
///
/// • Recurring weekly session → a single event starting on [firstDate] (which
///   MUST fall on the session's weekday) with a `RRULE:FREQ=WEEKLY`, optionally
///   bounded by the subject's end date.
/// • One-off session → a single dated event on its [ClassSession.specificDate].
///
/// Returns null when the session lacks the dates it needs (e.g. a recurring
/// session with no weekday, or a one-off with no date).
Map<String, dynamic>? classSessionToEvent(
  Subject subject,
  ClassSession session, {
  required DateTime firstDate,
  required String timeZone,
}) {
  final s = parseHm(session.startTime);
  final e = parseHm(session.endTime);

  DateTime day;
  List<String>? recurrence;

  if (session.recurring) {
    if (session.dayOfWeek == null) return null;
    day = DateTime(firstDate.year, firstDate.month, firstDate.day);
    var rule = 'RRULE:FREQ=WEEKLY';
    final end = subject.endDate;
    if (end != null) {
      final lastMoment = DateTime(end.year, end.month, end.day, 23, 59, 59);
      rule = '$rule;UNTIL=${rruleUntilUtc(lastMoment)}';
    }
    recurrence = [rule];
  } else {
    final d = session.specificDate;
    if (d == null) return null;
    day = DateTime(d.year, d.month, d.day);
  }

  final start = DateTime(day.year, day.month, day.day, s.hour, s.minute);
  var end = DateTime(day.year, day.month, day.day, e.hour, e.minute);
  // Guard against a non-positive duration (bad data) — default to +1h.
  if (!end.isAfter(start)) end = start.add(const Duration(hours: 1));

  return <String, dynamic>{
    'id': stableEventId('class_${session.subjectId}_${session.id}'),
    'summary': subject.name,
    if ((session.room ?? subject.room)?.trim().isNotEmpty ?? false)
      'location': (session.room ?? subject.room)!.trim(),
    if (subject.classLink != null && subject.classLink!.trim().isNotEmpty)
      'description': subject.classLink!.trim(),
    'start': {'dateTime': localIso(start), 'timeZone': timeZone},
    'end': {'dateTime': localIso(end), 'timeZone': timeZone},
    if (recurrence != null) 'recurrence': recurrence,
    'extendedProperties': {
      'private': {'classtrack': 'class', 'classtrackId': session.id},
    },
  };
}
