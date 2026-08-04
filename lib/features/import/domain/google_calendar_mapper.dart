import '../../../core/constants/app_constants.dart';
import 'parsed_schedule.dart';

/// Converts Google Calendar event JSON (as returned by the Calendar API v3
/// `events.list` endpoint with `singleEvents=true`) into a [ParsedSchedule] of
/// weekly-recurring subjects, ready for the existing review → commit pipeline.
///
/// `singleEvents=true` expands recurring events into individual instances across
/// the requested window, so the same weekly class shows up several times. We
/// group instances by event title (the subject) and collapse them to one weekly
/// session per distinct (weekday, start, end, room) slot.
///
/// Only *timed* events are considered — all-day events (which carry a `date`
/// but no `dateTime`) and cancelled instances are skipped, since a class
/// timetable is defined by times of day.
///
/// Pure and side-effect free so it can be unit-tested without any network or
/// OAuth. Timezone-safe: the wall-clock date and time are read from the RFC3339
/// string exactly as written (the event's own local time), never converted
/// through the device timezone — a 09:00 class stays 09:00 regardless of where
/// the import runs.
ParsedSchedule googleCalendarToSchedule(List<Map<String, dynamic>> events) {
  // subjectName -> (sessionKey -> ParsedSession), plus first-seen order.
  final bySubject = <String, Map<String, ParsedSession>>{};
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

    final session = ParsedSession(
      day: Weekdays.full[start.weekday0],
      start: start.hm,
      end: endHm,
      room: room,
    );
    final key = '${start.weekday0}|${session.start}|${session.end}|${room ?? ''}';

    final sessions = bySubject.putIfAbsent(title, () {
      order.add(title);
      return <String, ParsedSession>{};
    });
    sessions.putIfAbsent(key, () => session);
  }

  final subjects = <ParsedSubject>[];
  for (final name in order) {
    final sessions = bySubject[name]!.values.toList()
      ..sort((a, b) {
        final byDay = (a.dayIndex ?? 0).compareTo(b.dayIndex ?? 0);
        return byDay != 0 ? byDay : a.start.compareTo(b.start);
      });
    subjects.add(ParsedSubject(name: name, sessions: sessions));
  }

  // Calendar data is structured (not AI-guessed), so confidence is always high.
  return ParsedSchedule(subjects: subjects, confidence: 'high');
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

/// A calendar timestamp reduced to the weekday (0=Mon..6=Sun) and "HH:MM" of
/// its own local time.
class _Stamp {
  final int weekday0;
  final String hm;
  const _Stamp(this.weekday0, this.hm);
}

_Stamp? _parseStamp(String? rfc3339) {
  if (rfc3339 == null) return null;
  final m = _rfc3339.firstMatch(rfc3339);
  if (m == null) return null;
  final year = int.parse(m[1]!);
  final month = int.parse(m[2]!);
  final day = int.parse(m[3]!);
  final weekday0 = Weekdays.fromDateTime(DateTime(year, month, day));
  return _Stamp(weekday0, '${m[4]}:${m[5]}');
}

/// Fallback end time when an event omits its end: one hour after [hm].
String _plusOneHour(String hm) {
  final parts = hm.split(':');
  final h = int.tryParse(parts.first) ?? 9;
  final min = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final endH = (h + 1) % 24;
  return '${endH.toString().padLeft(2, '0')}:${min.toString().padLeft(2, '0')}';
}
