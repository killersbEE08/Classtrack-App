/// Pure prompt/context builder for the AI Smart Weekly Planner (Pro).
///
/// The controller collects the user's exams, tasks and timetable into the plain
/// data classes below, then [buildPlannerPrompt] turns them into a single
/// instruction string for the `chat` Cloud Function. Kept pure (no Riverpod, no
/// clock beyond the [now] passed in) so the prompt can be unit-tested.
library;

import '../../../core/utils/date_utils.dart';

/// Minimal exam info the planner needs.
class PlannerExamInfo {
  final String title;
  final DateTime date;
  final int daysUntil;

  /// Revision readiness 0..100 (from the exam's topic checklist), or null.
  final int? readinessPercent;

  /// Number of revision topics still unchecked, or null when no checklist.
  final int? topicsRemaining;

  const PlannerExamInfo({
    required this.title,
    required this.date,
    required this.daysUntil,
    this.readinessPercent,
    this.topicsRemaining,
  });
}

/// Minimal task info the planner needs.
class PlannerTaskInfo {
  final String title;
  final DateTime? due;
  final String priority; // Low / Medium / High
  final bool overdue;
  final String? subject;

  const PlannerTaskInfo({
    required this.title,
    this.due,
    required this.priority,
    this.overdue = false,
    this.subject,
  });
}

/// Builds the full planner instruction.
///
/// [timetableLines] are human-readable weekly class lines (e.g.
/// "Monday: DBMS 09:00–10:00, OS 11:00–12:00"). [freeGapsByDay] maps a
/// `yyyy-MM-dd` date to a human list of free windows on that day
/// (e.g. "12:00–14:00, 16:00–18:00"). The model is told to place study/revision
/// blocks ONLY inside those free windows.
String buildPlannerPrompt({
  required DateTime now,
  required List<PlannerExamInfo> exams,
  required List<PlannerTaskInfo> tasks,
  required List<String> timetableLines,
  required Map<String, String> freeGapsByDay,
  int horizonDays = 7,
}) {
  final sb = StringBuffer();
  final today = DateTime(now.year, now.month, now.day);
  final end = today.add(Duration(days: horizonDays - 1));

  sb.writeln(
      'You are ClassTrack\'s study planner. Build a realistic, motivating '
      'study & revision plan for the next $horizonDays days '
      '(${DateUtilsX.dateId(today)} to ${DateUtilsX.dateId(end)}).');
  sb.writeln(
      'Today is ${DateUtilsX.prettyFullDate(now)} (${DateUtilsX.dateId(now)}).');
  sb.writeln();

  // Exams — the main driver of urgency.
  if (exams.isEmpty) {
    sb.writeln('Upcoming exams: none in the planning window.');
  } else {
    sb.writeln('Upcoming exams (prioritise the soonest and least-prepared):');
    for (final e in exams) {
      final parts = <String>[
        '${e.title} on ${DateUtilsX.dateId(e.date)} (in ${e.daysUntil} day${e.daysUntil == 1 ? '' : 's'})'
      ];
      if (e.readinessPercent != null) {
        parts.add('${e.readinessPercent}% revised');
      }
      if (e.topicsRemaining != null && e.topicsRemaining! > 0) {
        parts.add('${e.topicsRemaining} topics left');
      }
      sb.writeln('- ${parts.join(', ')}.');
    }
  }
  sb.writeln();

  // Tasks / deadlines.
  if (tasks.isEmpty) {
    sb.writeln('Pending tasks/deadlines: none.');
  } else {
    sb.writeln('Pending tasks & deadlines:');
    for (final t in tasks) {
      final due = t.due != null ? 'due ${DateUtilsX.dateId(t.due!)}' : 'no due date';
      sb.writeln(
          '- ${t.title} ($due, ${t.priority} priority${t.overdue ? ', OVERDUE' : ''}'
          '${t.subject != null ? ', ${t.subject}' : ''}).');
    }
  }
  sb.writeln();

  // Fixed classes (do not schedule over these).
  if (timetableLines.isEmpty) {
    sb.writeln('Weekly classes: none recorded.');
  } else {
    sb.writeln('Fixed weekly classes (never schedule study over these):');
    for (final line in timetableLines) {
      sb.writeln('- $line');
    }
  }
  sb.writeln();

  // Free windows per day — the only slots the plan may use.
  if (freeGapsByDay.isEmpty) {
    sb.writeln(
        'Free windows: not provided per day — assume typical free time in the '
        'evenings (roughly 17:00–22:00) on days with classes, and daytime on '
        'free days, but avoid clashing with the classes listed above.');
  } else {
    sb.writeln('Free windows available each day (place blocks ONLY here):');
    final keys = freeGapsByDay.keys.toList()..sort();
    for (final k in keys) {
      sb.writeln('- $k: ${freeGapsByDay[k]}');
    }
  }
  sb.writeln();

  // Rules + strict output contract.
  sb.writeln('Rules:');
  sb.writeln('- Prioritise exams that are soonest and least revised.');
  sb.writeln('- Break big topics into focused 45–90 minute blocks.');
  sb.writeln('- Add short breaks between long study sessions.');
  sb.writeln('- Cover overdue and high-priority tasks early.');
  sb.writeln('- Keep it realistic: don\'t overload any single day.');
  sb.writeln('- Use 24-hour HH:MM times and yyyy-MM-dd dates.');
  sb.writeln();
  sb.writeln(
      'Respond with a ONE-sentence encouraging summary, then ONLY a single '
      'fenced code block labelled plan containing JSON in exactly this shape '
      '(no extra keys, no comments):');
  sb.writeln('```plan');
  sb.writeln('{');
  sb.writeln('  "summary": "short motivating overview",');
  sb.writeln('  "blocks": [');
  sb.writeln(
      '    {"day": "yyyy-MM-dd", "start": "HH:MM", "end": "HH:MM", "title": "what to do", "type": "study|revision|task|review|break", "subject": "optional subject", "reason": "short why"}');
  sb.writeln('  ]');
  sb.writeln('}');
  sb.writeln('```');
  return sb.toString().trim();
}
