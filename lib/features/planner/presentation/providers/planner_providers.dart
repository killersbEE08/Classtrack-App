import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/date_utils.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../domain/planner_engine.dart';
import '../../domain/planner_prompt.dart';
import '../../domain/weekly_plan.dart';

/// How many days ahead the planner schedules.
const int kPlannerHorizonDays = 7;

/// UI state for the weekly planner.
class WeeklyPlannerState {
  final bool loading;
  final WeeklyPlan? plan;
  final String? error;

  const WeeklyPlannerState({this.loading = false, this.plan, this.error});

  WeeklyPlannerState copyWith({bool? loading, WeeklyPlan? plan, String? error}) =>
      WeeklyPlannerState(
        loading: loading ?? this.loading,
        plan: plan ?? this.plan,
        error: error,
      );
}

class WeeklyPlannerController extends StateNotifier<WeeklyPlannerState> {
  WeeklyPlannerController(this._ref) : super(const WeeklyPlannerState());

  final Ref _ref;

  /// Builds (or rebuilds) the plan on-device from the user's current data.
  Future<void> generate() async {
    state = state.copyWith(loading: true, error: null);
    try {
      await _ensureDataLoaded();

      final now = DateTime.now();
      final exams = _examInfos();
      final tasks = _taskInfos();
      final freeWindows = _freeWindowsByDay(now);

      if (exams.isEmpty && tasks.isEmpty) {
        state = const WeeklyPlannerState(
          error:
              "You're all caught up! Add some exams or tasks and I'll plan "
              'study time around your classes.',
        );
        return;
      }

      final plan = buildDeterministicPlan(
        now: now,
        exams: exams,
        tasks: tasks,
        freeWindowsByDay: freeWindows,
        horizonDays: kPlannerHorizonDays,
      );

      if (plan.isEmpty) {
        state = const WeeklyPlannerState(
          error:
              'I couldn\'t find free time in the next 7 days between your '
              'classes. Try freeing up a slot or extending your day.',
        );
        return;
      }

      state = WeeklyPlannerState(plan: plan);
    } catch (_) {
      state = const WeeklyPlannerState(
        error: 'Something went wrong building your plan. Please try again.',
      );
    }
  }

  /// Adds the plan's study/revision/review/task blocks to the Tasks list as
  /// dated to-dos. Skips pure breaks. Returns how many were added.
  Future<int> addToTasks() async {
    final plan = state.plan;
    if (plan == null) return 0;
    final ctrl = _ref.read(taskControllerProvider);
    var added = 0;
    for (final b in plan.blocks) {
      if (b.kind == PlanBlockKind.breakTime) continue;
      final date = b.date;
      if (date == null) continue;
      final time = DateUtilsX.parseTime24(b.start);
      final due = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 9,
        time?.minute ?? 0,
      );
      await ctrl.add(TaskItem(
        id: '',
        title: b.title,
        note: b.reason,
        dueDate: due,
        subjectId: _subjectIdByName(b.subject),
      ));
      added++;
    }
    return added;
  }

  // ── Data gathering ──────────────────────────────────────────────────────

  List<PlannerExamInfo> _examInfos() {
    final out = <PlannerExamInfo>[];
    for (final e in _ref.read(upcomingExamsProvider)) {
      if (e.daysUntil > kPlannerHorizonDays + 7) continue;
      out.add(PlannerExamInfo(
        title: e.title,
        date: e.date,
        daysUntil: e.daysUntil,
        readinessPercent: e.hasTopics ? (e.readiness * 100).round() : null,
        topicsRemaining: e.hasTopics ? (e.topics.length - e.topicsDone) : null,
      ));
    }
    return out;
  }

  List<PlannerTaskInfo> _taskInfos() {
    final subjectsById = _ref.read(subjectsByIdProvider);
    final out = <PlannerTaskInfo>[];
    for (final t in _ref.read(pendingTasksProvider)) {
      out.add(PlannerTaskInfo(
        title: t.title,
        due: t.dueDate,
        priority: t.priority.label,
        overdue: t.isOverdue,
        subject: t.subjectId != null ? subjectsById[t.subjectId]?.name : null,
      ));
    }
    return out;
  }

  /// Free (class-free) windows for each day in the horizon, as
  /// (startMinute, endMinute) pairs within a waking day (08:00–22:00).
  Map<String, List<(int, int)>> _freeWindowsByDay(DateTime now) {
    final map = <String, List<(int, int)>>{};
    for (var i = 0; i < kPlannerHorizonDays; i++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: i));
      final classes = _ref.read(classesForDayProvider(day));
      final busy = classes
          .map((c) => (
                DateUtilsX.minutesOfDay(c.session.startTime),
                DateUtilsX.minutesOfDay(c.session.endTime),
              ))
          .toList();
      final windows = freeWindowsFromBusy(busy);
      if (windows.isNotEmpty) map[DateUtilsX.dateId(day)] = windows;
    }
    return map;
  }

  String? _subjectIdByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final q = name.toLowerCase().trim();
    final subjects = _ref.read(subjectsStreamProvider).valueOrNull ?? const [];
    for (final s in subjects) {
      if (s.name.toLowerCase() == q) return s.id;
    }
    for (final s in subjects) {
      final n = s.name.toLowerCase();
      if (n.contains(q) || q.contains(n)) return s.id;
    }
    return null;
  }

  Future<void> _ensureDataLoaded() async {
    try {
      await Future.wait([
        _ref.read(subjectsStreamProvider.future),
        _ref.read(tasksStreamProvider.future),
        _ref.read(examsStreamProvider.future),
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Proceed with whatever has loaded.
    }
  }
}

/// Free windows within a waking day (08:00–22:00) after removing [busy] class
/// intervals. Pure helper, shared with the engine's tests.
List<(int, int)> freeWindowsFromBusy(
  List<(int, int)> busy, {
  int dayStart = 8 * 60,
  int dayEnd = 22 * 60,
  int minGap = 30,
}) {
  final sorted = [...busy]..sort((a, b) => a.$1.compareTo(b.$1));
  final out = <(int, int)>[];
  var cursor = dayStart;
  for (final b in sorted) {
    final s = b.$1.clamp(dayStart, dayEnd);
    final e = b.$2.clamp(dayStart, dayEnd);
    if (s - cursor >= minGap) out.add((cursor, s));
    if (e > cursor) cursor = e;
  }
  if (dayEnd - cursor >= minGap) out.add((cursor, dayEnd));
  return out;
}

final weeklyPlannerControllerProvider =
    StateNotifierProvider<WeeklyPlannerController, WeeklyPlannerState>((ref) {
  return WeeklyPlannerController(ref);
});
