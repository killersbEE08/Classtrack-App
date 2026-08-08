/// Converts Google **Tasks** JSON (from the Google Tasks API v1
/// `tasks.list` endpoint) into plain task items for ClassTrack's Tasks list.
///
/// Google Tasks are the user's to-dos (separate from calendar events): each has
/// a title, optional notes, an optional date-only due date, a done flag and a
/// stable id. Pure and side-effect free so it can be unit-tested without any
/// network or OAuth.
library;

/// A single Google Task reduced to what the importer needs.
class GoogleTaskItem {
  final String title;
  final String? note;

  /// Date-only due date (midnight) or null. Google Tasks due dates carry no
  /// meaningful time, so this is always at midnight and treated as "all day".
  final DateTime? due;

  final bool done;
  final String? link;

  /// Stable Google Task id, used to skip re-importing the same task.
  final String? sourceId;

  const GoogleTaskItem({
    required this.title,
    this.note,
    this.due,
    this.done = false,
    this.link,
    this.sourceId,
  });
}

/// Maps raw Google Task maps into [GoogleTaskItem]s, skipping deleted/hidden
/// entries and de-duplicating within the response by id.
List<GoogleTaskItem> googleTasksToItems(List<Map<String, dynamic>> tasks) {
  final out = <GoogleTaskItem>[];
  final seen = <String>{};

  for (final t in tasks) {
    if (t['deleted'] == true || t['hidden'] == true) continue;

    final rawTitle = (t['title'] as String?)?.trim() ?? '';
    final title = rawTitle.isEmpty ? 'Untitled task' : rawTitle;

    final rawNote = (t['notes'] as String?)?.trim();
    final note = (rawNote == null || rawNote.isEmpty) ? null : rawNote;

    final done = (t['status'] as String?) == 'completed';
    final due = _dueDate(t['due']);
    final id = (t['id'] as String?)?.trim();
    final sourceId = (id == null || id.isEmpty) ? null : id;

    final dedupeKey = sourceId ?? '${title.toLowerCase()}|${due ?? ''}';
    if (!seen.add(dedupeKey)) continue;

    out.add(GoogleTaskItem(
      title: title,
      note: note,
      due: due,
      done: done,
      link: _firstLink(t['links']),
      sourceId: sourceId,
    ));
  }

  return out;
}

final RegExp _dateOnly = RegExp(r'^(\d{4})-(\d{2})-(\d{2})');

/// Google Tasks `due` is an RFC3339 timestamp whose time is always midnight
/// UTC and carries no meaning. Read the calendar date straight from the string
/// (never timezone-convert it, which could shift the day backwards).
DateTime? _dueDate(dynamic due) {
  if (due is! String || due.isEmpty) return null;
  final m = _dateOnly.firstMatch(due.trim());
  if (m == null) return null;
  return DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
}

/// First attached link URL on the task, if any.
String? _firstLink(dynamic links) {
  if (links is List) {
    for (final l in links) {
      if (l is Map) {
        final link = (l['link'] as String?)?.trim();
        if (link != null && link.startsWith('http')) return link;
      }
    }
  }
  return null;
}
