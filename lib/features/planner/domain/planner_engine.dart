/// Deterministic, on-device engine for the Smart Weekly Planner (Pro).
///
/// The planner originally routed through the shared `chat` Cloud Function, but
/// that function's fixed system prompt forces plain-text replies and forbids
/// any custom JSON code block — so a structured plan could never come back and
/// the screen always errored. This engine builds the plan locally from the
/// user's real data instead: it is reliable, instant, works offline and costs
/// no AI quota, while still being "smart" — it prioritises the soonest and
/// least-prepared exams and the most urgent tasks, and places focused study
/// blocks ONLY inside the genuine free windows between the user's classes.
///
/// Pure and side-effect free (all inputs passed in, [now] included) so it is
/// fully unit-testable.
library;

import '../../../core/utils/date_utils.dart';
import 'planner_prompt.dart';
import 'weekly_plan.dart';

class _Candidate {
  final String title;
  final PlanBlockKind kind;
  final String? subject;
  final String? reason;
  final int urgency;
  const _Candidate({
    required this.title,
    required this.kind,
    this.subject,
    this.reason,
    required this.urgency,
  });
}

String _fmtMinutes(int m) {
  final h = (m ~/ 60).toString().padLeft(2, '0');
  final mm = (m % 60).toString().padLeft(2, '0');
  return '$h:$mm';
}

/// Builds a study/revision plan for the next [horizonDays] days.
///
/// [freeWindowsByDay] maps a `yyyy-MM-dd` date to that day's free intervals as
/// (startMinuteOfDay, endMinuteOfDay) pairs — the only times a block may be
/// placed. Study blocks are [blockMinutes] long, separated by [breakMinutes],
/// capped at [maxBlocksPerDay] per day.
WeeklyPlan buildDeterministicPlan({
  required DateTime now,
  required List<PlannerExamInfo> exams,
  required List<PlannerTaskInfo> tasks,
  required Map<String, List<(int, int)>> freeWindowsByDay,
  int horizonDays = 7,
  int blockMinutes = 55,
  int breakMinutes = 10,
  int maxBlocksPerDay = 4,
}) {
  final today = DateTime(now.year, now.month, now.day);
  final blocks = <PlanBlock>[];

  int taskDueOffset(PlannerTaskInfo t) {
    if (t.due == null) return horizonDays - 1;
    final d = DateTime(t.due!.year, t.due!.month, t.due!.day);
    return d.difference(today).inDays;
  }

  for (var offset = 0; offset < horizonDays; offset++) {
    final day = today.add(Duration(days: offset));
    final ymd = DateUtilsX.dateId(day);
    final windows = freeWindowsByDay[ymd] ?? const <(int, int)>[];
    if (windows.isEmpty) continue;

    // ── Candidates eligible for THIS day ──────────────────────────────────
    final cands = <_Candidate>[];

    for (final e in exams) {
      final daysBefore = e.daysUntil - offset;
      if (daysBefore < 0) continue; // exam already happened by this day
      if (daysBefore > 6) continue; // too far out — revise closer to the exam
      final readiness = e.readinessPercent ?? 50;
      final urgency = 200 - e.daysUntil * 8 + (100 - readiness);
      final ready = e.readinessPercent != null ? ' · ${e.readinessPercent}% revised' : '';
      cands.add(_Candidate(
        title: 'Revise ${e.title}',
        kind: PlanBlockKind.revision,
        reason: e.daysUntil == 0
            ? 'Exam today$ready'
            : 'Exam in ${e.daysUntil} day${e.daysUntil == 1 ? '' : 's'}$ready',
        urgency: urgency,
      ));
    }

    for (final t in tasks) {
      final due = taskDueOffset(t);
      // Skip tasks already past their due date (unless still flagged overdue).
      if (!t.overdue && due < offset) continue;
      // Keep non-urgent tasks close to their deadline to avoid early clutter.
      if (!t.overdue && t.priority != 'High' && due > offset + 2) continue;
      final base = t.overdue
          ? 220
          : t.priority == 'High'
              ? 140
              : t.priority == 'Medium'
                  ? 90
                  : 60;
      final urgency = base - (due - offset).clamp(0, 30) * 3;
      final dueLabel = t.due != null ? ' · due ${DateUtilsX.dateId(t.due!)}' : '';
      cands.add(_Candidate(
        title: 'Work on ${t.title}',
        kind: PlanBlockKind.task,
        subject: t.subject,
        reason: t.overdue ? 'Overdue' : '${t.priority} priority$dueLabel',
        urgency: urgency,
      ));
    }

    if (cands.isEmpty) continue;
    cands.sort((a, b) => b.urgency.compareTo(a.urgency));

    // ── Concrete time slots from the day's free windows ───────────────────
    final slots = <int>[]; // start minute-of-day for each block
    for (final w in windows) {
      var s = w.$1;
      while (s + blockMinutes <= w.$2 && slots.length < maxBlocksPerDay) {
        slots.add(s);
        s += blockMinutes + breakMinutes;
      }
      if (slots.length >= maxBlocksPerDay) break;
    }

    // ── Assign top candidates to slots (one block each, priority order) ────
    final count = slots.length < cands.length ? slots.length : cands.length;
    for (var i = 0; i < count; i++) {
      final start = slots[i];
      final end = start + blockMinutes;
      final c = cands[i];
      blocks.add(PlanBlock(
        day: ymd,
        start: _fmtMinutes(start),
        end: _fmtMinutes(end),
        title: c.title,
        kind: c.kind,
        subject: c.subject,
        reason: c.reason,
      ));
      // A short break, but only when the next block is truly contiguous
      // (same window) — never across a long gap between windows.
      final hasContiguousNext =
          i < count - 1 && slots[i + 1] == end + breakMinutes;
      if (hasContiguousNext) {
        blocks.add(PlanBlock(
          day: ymd,
          start: _fmtMinutes(end),
          end: _fmtMinutes(end + breakMinutes),
          title: 'Short break',
          kind: PlanBlockKind.breakTime,
        ));
      }
    }
  }

  return WeeklyPlan(
    summary: _summary(exams: exams, tasks: tasks, empty: blocks.isEmpty),
    blocks: blocks,
  );
}

String _summary({
  required List<PlannerExamInfo> exams,
  required List<PlannerTaskInfo> tasks,
  required bool empty,
}) {
  if (empty) return 'Nothing urgent to schedule right now — enjoy the breather!';
  final soon = exams.where((e) => e.daysUntil >= 0).toList()
    ..sort((a, b) => a.daysUntil.compareTo(b.daysUntil));
  if (soon.isNotEmpty) {
    final e = soon.first;
    final when = e.daysUntil == 0
        ? 'today'
        : e.daysUntil == 1
            ? 'tomorrow'
            : 'in ${e.daysUntil} days';
    return 'Focused on ${e.title} ($when) and your key deadlines — one block at a time. You\'ve got this! 💪';
  }
  if (tasks.isNotEmpty) {
    return 'Built around your deadlines — steady blocks with short breaks. Keep the momentum going! 🚀';
  }
  return 'Here\'s a focused week of study blocks around your classes.';
}
