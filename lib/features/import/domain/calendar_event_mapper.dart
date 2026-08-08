/// Converts Google Calendar event JSON (as returned by the Calendar API v3
/// `events.list` endpoint with `singleEvents=true`) into a flat list of
/// [CalendarEventTask]s that the Tasks importer saves as `event`-type tasks.
///
/// Unlike [googleCalendarToSchedule] (which reconstructs a weekly timetable for
/// attendance), this mapper keeps EVERY event as its own dated item so the full
/// calendar — classes, meetings, webinars, all-day events — lands in the Tasks
/// list exactly as it appears in the calendar.
///
/// Pure and side-effect free so it can be unit-tested without any network or
/// OAuth. Timezone-safe: a timestamp written with an explicit offset (or no
/// zone) is read as its own wall-clock time; a UTC (`Z`) instant is converted
/// to the device's local time first.
library;

/// A single Google Calendar event reduced to what the Tasks importer needs.
class CalendarEventTask {
  final String title;

  /// Local wall-clock start. For an all-day event this is the date at midnight.
  final DateTime start;

  /// Local wall-clock end (optional).
  final DateTime? end;

  /// True for all-day events (a `date`, not a `dateTime`).
  final bool allDay;

  final String? location;
  final String? link;

  /// Stable per-instance id used to recognise the event on a later re-import
  /// and skip it instead of adding a duplicate. Null when the event carries no
  /// id.
  final String? sourceId;

  const CalendarEventTask({
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.location,
    this.link,
    this.sourceId,
  });

  /// The due date stored on the task: keeps the time-of-day for timed events,
  /// midnight (an "all day" item) for all-day events.
  DateTime get due =>
      allDay ? DateTime(start.year, start.month, start.day) : start;
}

/// Maps raw calendar event maps into [CalendarEventTask]s, skipping cancelled
/// instances and de-duplicating within the response.
List<CalendarEventTask> googleCalendarToEventTasks(
  List<Map<String, dynamic>> events,
) {
  final out = <CalendarEventTask>[];
  final seen = <String>{};

  for (final e in events) {
    if (e['status'] == 'cancelled') continue;

    final start = _parse(e['start']);
    if (start == null) continue; // malformed / no start -> skip

    final end = _parse(e['end']);

    final rawTitle = (e['summary'] as String?)?.trim() ?? '';
    final title = rawTitle.isEmpty ? 'Untitled' : rawTitle;

    final rawLoc = (e['location'] as String?)?.trim();
    final location = (rawLoc == null || rawLoc.isEmpty) ? null : rawLoc;

    final sourceId = _sourceId(e);

    // Defensive de-dup inside a single response (a well-formed response should
    // already be unique, but guard against repeats).
    final dedupeKey =
        sourceId ?? '${title.toLowerCase()}|${start.value.toIso8601String()}';
    if (!seen.add(dedupeKey)) continue;

    out.add(CalendarEventTask(
      title: title,
      start: start.value,
      end: end?.value,
      allDay: start.allDay,
      location: location,
      link: _extractLink(e),
      sourceId: sourceId,
    ));
  }

  return out;
}

// ── Parsing ─────────────────────────────────────────────────────────────────

class _Parsed {
  final DateTime value;
  final bool allDay;
  const _Parsed(this.value, this.allDay);
}

/// Reads a Calendar `start`/`end` node into a local wall-clock [DateTime].
/// Returns null when the node is missing or malformed.
_Parsed? _parse(dynamic node) {
  if (node is! Map) return null;

  final dt = node['dateTime'];
  if (dt is String && dt.isNotEmpty) {
    final v = _parseLocalDateTime(dt);
    return v == null ? null : _Parsed(v, false);
  }

  final d = node['date'];
  if (d is String && d.isNotEmpty) {
    final m = _dateOnly.firstMatch(d);
    if (m == null) return null;
    return _Parsed(
      DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      true,
    );
  }

  return null;
}

final RegExp _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');
final RegExp _rfc3339 = RegExp(r'^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})');

DateTime? _parseLocalDateTime(String raw) {
  final s = raw.trim();

  // A UTC instant ('...Z') must be converted to the device's local time before
  // its wall clock is read.
  if (s.endsWith('Z') || s.endsWith('z')) {
    return DateTime.tryParse(s)?.toLocal();
  }

  // Explicit numeric offset (e.g. +05:30) or a floating time: the wall-clock
  // prefix already IS the event's own local time, so read it verbatim.
  final m = _rfc3339.firstMatch(s);
  if (m == null) return null;
  return DateTime(
    int.parse(m[1]!),
    int.parse(m[2]!),
    int.parse(m[3]!),
    int.parse(m[4]!),
    int.parse(m[5]!),
  );
}

/// With `singleEvents=true` each occurrence carries a unique `id`, so it is the
/// most reliable per-occurrence key. Falls back to `iCalUID` when absent.
String? _sourceId(Map<String, dynamic> e) {
  final id = (e['id'] as String?)?.trim();
  if (id != null && id.isNotEmpty) return id;
  final ical = (e['iCalUID'] as String?)?.trim();
  if (ical != null && ical.isNotEmpty) return ical;
  return null;
}

final RegExp _urlRegex =
    RegExp(r'https?://[^\s<>"\)\]]+', caseSensitive: false);

/// Pulls a usable link from an event, preferring a real video-call URL: Google
/// Meet (`hangoutLink`), any `conferenceData` entry point, then the first URL
/// found in the location or description text. Null when none is present.
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
