import '../../../core/constants/app_constants.dart';
import 'parsed_schedule.dart';

/// Converts Google Calendar event JSON (as returned by the Calendar API v3
/// `events.list` endpoint with `singleEvents=true`) into a [ParsedSchedule],
/// ready for the existing review → commit pipeline.
///
/// Events are classified so they land in the right place instead of everything
/// becoming an attendance subject:
///
///  • **Recurring** events (they carry a `recurringEventId`, or the same
///    weekday/time slot repeats across the window) → weekly-recurring classes
///    (subjects + sessions) that drive attendance.
///  • **One-off** events whose title looks like an assignment/deadline
///    (homework, quiz, submit, due, …) → **tasks**, so they never inflate
///    attendance.
///  • Other **one-off** timed events → one-off (date-specific) class sessions
///    that occur ONLY on their actual date — they no longer repeat every week
///    or show up on the day the import was run.
///
/// Only *timed* events are considered — all-day events (which carry a `date`
/// but no `dateTime`) and cancelled instances are skipped.
///
/// Pure and side-effect free so it can be unit-tested without any network or
/// OAuth. Timezone-safe: the wall-clock date and time are read from the RFC3339
/// string exactly as written (the event's own local time), never converted
/// through the device timezone.
ParsedSchedule googleCalendarToSchedule(List<Map<String, dynamic>> events) {
  // Parse all valid timed events, preserving first-seen title order.
  final byTitle = <String, List<_Ev>>{};
  final order = <String>[];

  for (final e in events) {
    if (e['status'] == 'cancelled') continue;

    final start = _parseStamp(_dateTime(e['start']));
    if (start == null) continue; // all-day or malformed -> skip

    final endStamp = _parseStamp(_dateTime(e['end']));
    final endHm = endStamp?.hm ?? _plusOneHour(start.hm);

    final rawTitle = (e['summary'] as String?)?.trim() ?? '';
    final title = rawTitle.isEmpty ? 'Untitled' : rawTitle;

    final rawRoom = (e['location'] as String?)?.trim() ?? '';
    final room = rawRoom.isEmpty ? null : rawRoom;

    final recurringId = (e['recurringEventId'] as String?)?.trim();

    final ev = _Ev(
      weekday0: start.weekday0,
      date: start.date,
      start: start.hm,
      end: endHm,
      room: room,
      link: _extractLink(e),
      hasRecurringId: recurringId != null && recurringId.isNotEmpty,
    );

    byTitle.putIfAbsent(title, () {
      order.add(title);
      return <_Ev>[];
    }).add(ev);
  }

  final subjects = <ParsedSubject>[];
  final tasks = <ParsedTask>[];

  for (final title in order) {
    final evs = byTitle[title]!;

    // Group this title's events by their weekly slot to detect recurrence: a
    // slot seen on 2+ distinct dates (or any instance flagged recurring by the
    // Calendar API) means this is a weekly class.
    final slotDates = <String, Set<String>>{};
    for (final ev in evs) {
      slotDates
          .putIfAbsent(ev.slotKey, () => <String>{})
          .add(ev.dateKey);
    }
    final repeats = slotDates.values.any((dates) => dates.length >= 2);
    final flagged = evs.any((e) => e.hasRecurringId);
    final isRecurring = repeats || flagged;

    if (isRecurring) {
      // One weekly session per distinct slot.
      final sessions = <String, ParsedSession>{};
      for (final ev in evs) {
        sessions.putIfAbsent(
          ev.slotKey,
          () => ParsedSession(
            day: Weekdays.full[ev.weekday0],
            start: ev.start,
            end: ev.end,
            room: ev.room,
          ),
        );
      }
      final list = sessions.values.toList()..sort(_bySession);
      subjects.add(ParsedSubject(
        name: title,
        classLink: _firstLink(evs),
        sessions: list,
      ));
    } else if (_looksLikeTask(title)) {
      // One-off, assignment-like -> tasks (one per instance date).
      for (final ev in evs) {
        tasks.add(ParsedTask(
          title: title,
          link: ev.link,
          due: DateTime(
            ev.date.year,
            ev.date.month,
            ev.date.day,
            ev.startHour,
            ev.startMinute,
          ),
        ));
      }
    } else {
      // One-off class(es) on their specific date — no weekly repeat.
      final sessions = <String, ParsedSession>{};
      for (final ev in evs) {
        final key = '${ev.dateKey}|${ev.slotKey}';
        sessions.putIfAbsent(
          key,
          () => ParsedSession(
            day: Weekdays.full[ev.weekday0],
            start: ev.start,
            end: ev.end,
            room: ev.room,
            date: DateTime(ev.date.year, ev.date.month, ev.date.day),
          ),
        );
      }
      final list = sessions.values.toList()..sort(_bySession);
      subjects.add(ParsedSubject(
        name: title,
        classLink: _firstLink(evs),
        sessions: list,
      ));
    }
  }

  // Calendar data is structured (not AI-guessed), so confidence is always high.
  return ParsedSchedule(subjects: subjects, tasks: tasks, confidence: 'high');
}

int _bySession(ParsedSession a, ParsedSession b) {
  final ad = a.date, bd = b.date;
  if (ad != null && bd != null && !ad.isAtSameMomentAs(bd)) {
    return ad.compareTo(bd);
  }
  final byDay = (a.dayIndex ?? 0).compareTo(b.dayIndex ?? 0);
  return byDay != 0 ? byDay : a.start.compareTo(b.start);
}

/// Case-insensitive keyword match (whole word) that flags one-off events that
/// are really assignments/deadlines rather than classes.
bool _looksLikeTask(String title) {
  final words = title
      .toLowerCase()
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty)
      .toSet();
  const keywords = <String>{
    'assignment',
    'assignments',
    'homework',
    'hw',
    'submit',
    'submission',
    'deadline',
    'due',
    'quiz',
    'todo',
    'task',
    'essay',
    'reading',
    'read',
    'revise',
    'revision',
    'watch',
  };
  return words.intersection(keywords).isNotEmpty;
}

/// Matches the first http(s) URL inside a free-text field.
final RegExp _urlRegex =
    RegExp(r'https?://[^\s<>"\)\]]+', caseSensitive: false);

/// Pulls a usable link out of a calendar event, preferring a real video-call
/// URL: Google Meet (`hangoutLink`), any `conferenceData` entry point, then the
/// first URL found in the location or description text. Returns null when the
/// event carries no link.
String? _extractLink(Map<String, dynamic> e) {
  final hangout = (e['hangoutLink'] as String?)?.trim();
  if (hangout != null && hangout.isNotEmpty) return hangout;

  final conf = e['conferenceData'];
  if (conf is Map) {
    final entryPoints = conf['entryPoints'];
    if (entryPoints is List) {
      for (final ep in entryPoints) {
        if (ep is Map) {
          final uri = (ep['uri'] as String?)?.trim();
          if (uri != null && uri.startsWith('http')) return uri;
        }
      }
    }
  }

  for (final field in const ['location', 'description']) {
    final v = (e[field] as String?) ?? '';
    final m = _urlRegex.firstMatch(v);
    if (m != null) return m.group(0);
  }
  return null;
}

/// First non-empty link across a title's instances (used as the subject's
/// class link so it lands in the subject's "Quick links" area).
String? _firstLink(List<_Ev> evs) {
  for (final ev in evs) {
    final l = ev.link;
    if (l != null && l.trim().isNotEmpty) return l.trim();
  }
  return null;
}

/// A single parsed calendar instance reduced to what the mapper needs.
class _Ev {
  final int weekday0; // 0=Mon..6=Sun
  final DateTime date; // wall-clock date (date-only)
  final String start; // "HH:MM"
  final String end; // "HH:MM"
  final String? room;
  final String? link; // meeting / resource URL pulled from the event
  final bool hasRecurringId;

  const _Ev({
    required this.weekday0,
    required this.date,
    required this.start,
    required this.end,
    required this.room,
    required this.link,
    required this.hasRecurringId,
  });

  /// Weekly slot key (ignores which specific date it fell on).
  String get slotKey => '$weekday0|$start|$end|${room ?? ''}';

  /// Date key "yyyy-mm-dd".
  String get dateKey =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  int get startHour => int.tryParse(start.split(':').first) ?? 9;
  int get startMinute {
    final parts = start.split(':');
    return parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  }
}

/// Extracts the `dateTime` field from a Calendar `start`/`end` node. Returns
/// null for all-day events (which have `date` instead of `dateTime`).
String? _dateTime(dynamic node) {
  if (node is Map) {
    final dt = node['dateTime'];
    if (dt is String && dt.isNotEmpty) return dt;
  }
  return null;
}

/// RFC3339 prefix: `YYYY-MM-DDTHH:MM` (the trailing seconds/offset are ignored
/// on purpose — we want the event's own wall-clock time, not a UTC-converted
/// one).
final RegExp _rfc3339 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})');

/// A calendar timestamp reduced to its wall-clock date, weekday (0=Mon..6=Sun)
/// and "HH:MM".
class _Stamp {
  final int weekday0;
  final DateTime date;
  final String hm;
  const _Stamp(this.weekday0, this.date, this.hm);
}

_Stamp? _parseStamp(String? rfc3339) {
  if (rfc3339 == null) return null;
  final s = rfc3339.trim();

  // Instances returned in UTC (a trailing 'Z') must be converted to the
  // device's local timezone BEFORE the wall clock is read. Google Calendar
  // sometimes returns times in UTC — e.g. '2026-08-05T05:30:00.000Z' for an
  // 11:00 IST class — and reading the literal '05:30' then showed the class
  // 5.5h early. Converting via toLocal() yields the correct 11:00 for a device
  // in IST.
  if (s.endsWith('Z') || s.endsWith('z')) {
    final parsed = DateTime.tryParse(s);
    if (parsed != null) {
      final local = parsed.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      return _Stamp(
        Weekdays.fromDateTime(date),
        date,
        '${_two(local.hour)}:${_two(local.minute)}',
      );
    }
  }

  // Explicit numeric offset (e.g. +05:30) or a floating time: the wall-clock
  // prefix already IS the event's local time, so read it verbatim. This keeps
  // the mapper deterministic and timezone-independent for unit tests.
  final m = _rfc3339.firstMatch(s);
  if (m == null) return null;
  final year = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final day = int.parse(m[3]!);
  final date = DateTime(year, month, day);
  final weekday0 = Weekdays.fromDateTime(date);
  return _Stamp(weekday0, date, '${m[4]}:${m[5]}');
}

String _two(int v) => v.toString().padLeft(2, '0');

/// Fallback end time when an event omits its end: one hour after [hm].
String _plusOneHour(String hm) {
  final parts = hm.split(':');
  final h = int.tryParse(parts.first) ?? 9;
  final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final endH = (h + 1) % 24;
  return '${endH.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}
