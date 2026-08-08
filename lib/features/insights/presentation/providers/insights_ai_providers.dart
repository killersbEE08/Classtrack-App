import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/gemini_provider.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../services/gemini_service.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../focus/presentation/providers/study_providers.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';

/// Waits (briefly) for the Firestore-backed streams to deliver their first
/// value so the AI context reflects real data instead of empty lists.
Future<void> _ensureDataLoaded(Ref ref) async {
  try {
    await Future.wait([
      ref.read(subjectsStreamProvider.future),
      ref.read(tasksStreamProvider.future),
      ref.read(examsStreamProvider.future),
      ref.read(gradesStreamProvider.future),
      ref.read(expensesStreamProvider.future),
      ref.read(studySessionsStreamProvider.future),
    ]).timeout(const Duration(seconds: 6));
  } catch (_) {
    // Fall back to whatever has loaded.
  }
}

/// A compact snapshot of the whole picture — attendance, budget, grades and
/// study — used by the "AI insights" card on the Insights screen.
String buildAnalyticsContext(Ref ref) {
  final sb = StringBuffer();
  final now = DateTime.now();
  sb.writeln('Today is ${DateUtilsX.prettyFullDate(now)}.');

  final profile = ref.read(userProfileProvider).valueOrNull;
  final name = profile?.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    sb.writeln("The student's name is ${name.split(RegExp(r'\s+')).first}. "
        'Address them by their first name where it feels natural, not in every line.');
  }

  final target =
      ref.read(userProfileProvider).valueOrNull?.targetAttendancePercent ??
          AppConstants.defaultTargetAttendance;
  final overall = ref.read(overallStatsProvider);
  sb.writeln('Attendance target: ${target.toStringAsFixed(0)}%.');
  sb.writeln(overall.held == 0
      ? 'Overall attendance: no classes marked yet.'
      : 'Overall attendance: ${overall.percent.toStringAsFixed(0)}% '
          '(${overall.present}/${overall.held} classes attended).');

  final subjects = ref.read(subjectsStreamProvider).valueOrNull ?? const [];
  if (subjects.isNotEmpty) {
    sb.writeln('Attendance by subject:');
    for (final s in subjects.take(20)) {
      final held = s.attended + s.absent;
      sb.writeln('- ${s.name}: ${held == 0 ? "no data" : "${s.percent.toStringAsFixed(0)}% ($held classes)"}.');
    }
  }

  final gpa = ref.read(gpaSummaryProvider);
  if (gpa.gradedSubjects > 0) {
    sb.writeln('GPA: ${gpa.gpa.toStringAsFixed(2)} of ${gpa.maxPoints.toStringAsFixed(0)} '
        '(average ${gpa.averagePercent.toStringAsFixed(0)}% across ${gpa.gradedSubjects} subjects).');
    final gradeLines = <String>[];
    for (final s in subjects) {
      final c = ref.read(courseGradeProvider(s.id));
      if (c.count == 0) continue;
      gradeLines.add('- ${s.name}: ${c.percent.toStringAsFixed(0)}%.');
    }
    if (gradeLines.isNotEmpty) {
      sb.writeln('Grades by subject:');
      gradeLines.forEach(sb.writeln);
    }
  }

  final study = ref.read(studyStatsProvider);
  sb.writeln('Study focus: ${study.weekMinutes} minutes this week, '
      '${study.todayMinutes} today, ${study.streakDays}-day streak.');
  final habitStreak = ref.read(bestHabitStreakProvider);
  if (habitStreak > 0) sb.writeln('Best habit streak: $habitStreak days.');

  final currency = ref.read(currencySymbolProvider);
  final budget = ref.read(monthlyBudgetProvider);
  if (ref.read(expensesStreamProvider).hasValue) {
    final spent = ref.read(monthlyTotalProvider);
    sb.writeln('Spending this month: $currency${spent.toStringAsFixed(0)}'
        '${budget > 0 ? " of $currency${budget.toStringAsFixed(0)} budget" : " (no budget set)"}.');
    final breakdown = ref.read(categoryBreakdownProvider);
    if (breakdown.isNotEmpty) {
      sb.writeln('Spending by category:');
      for (final e in breakdown) {
        sb.writeln('- ${e.key.label}: $currency${e.value.toStringAsFixed(0)}');
      }
    }
  }

  final exams = ref.read(upcomingExamsProvider);
  if (exams.isNotEmpty) {
    sb.writeln('Upcoming exams:');
    for (final e in exams.take(6)) {
      sb.writeln('- ${e.title} on ${DateUtilsX.prettyDate(e.date)} (${e.countdownLabel}).');
    }
  }

  final tasks = ref.read(pendingTasksProvider);
  if (tasks.isNotEmpty) {
    sb.writeln('Pending tasks (${tasks.length}):');
    for (final t in tasks.take(10)) {
      final due = t.dueDate != null ? DateUtilsX.prettyDate(t.dueDate!) : 'no date';
      sb.writeln('- ${t.title} (${t.type.label}, due $due)${t.isOverdue ? " [OVERDUE]" : ""}.');
    }
  }

  return sb.toString().trim();
}

/// A focused snapshot of TODAY for the daily-agenda summary: today's classes,
/// tasks due, upcoming exams and current momentum.
String buildDailyAgendaContext(Ref ref) {
  final sb = StringBuffer();
  final now = DateTime.now();
  sb.writeln('Today is ${DateUtilsX.prettyFullDate(now)}.');

  final name = ref.read(userProfileProvider).valueOrNull?.displayName?.trim();
  if (name != null && name.isNotEmpty) {
    sb.writeln("The student's name is ${name.split(RegExp(r'\s+')).first}.");
  }

  final classes = ref.read(classesForDayProvider(now));
  if (classes.isEmpty) {
    sb.writeln("Today's classes: none scheduled.");
  } else {
    sb.writeln("Today's classes (${classes.length}):");
    for (final c in classes) {
      final room = c.session.room;
      sb.writeln('- ${c.subject.name} ${c.session.startTime}–${c.session.endTime}'
          '${room != null && room.isNotEmpty ? " in $room" : ""}.');
    }
  }

  final tasks = ref.read(pendingTasksProvider);
  if (tasks.isNotEmpty) {
    sb.writeln('Pending tasks (${tasks.length}):');
    for (final t in tasks.take(12)) {
      final due = t.dueDate != null ? DateUtilsX.prettyDate(t.dueDate!) : 'no date';
      sb.writeln('- ${t.title} (${t.type.label}, due $due, ${t.priority.label} priority)'
          '${t.isOverdue ? " [OVERDUE]" : ""}.');
    }
  } else {
    sb.writeln('Pending tasks: none.');
  }

  final exams = ref.read(upcomingExamsProvider);
  if (exams.isNotEmpty) {
    sb.writeln('Upcoming exams:');
    for (final e in exams.take(6)) {
      final room = e.room;
      sb.writeln('- ${e.title} on ${DateUtilsX.prettyDate(e.date)} (${e.countdownLabel})'
          '${room != null && room.isNotEmpty ? ", room $room" : ""}.');
    }
  }

  final target =
      ref.read(userProfileProvider).valueOrNull?.targetAttendancePercent ??
          AppConstants.defaultTargetAttendance;
  final overall = ref.read(overallStatsProvider);
  if (overall.held > 0) {
    sb.writeln('Overall attendance: ${overall.percent.toStringAsFixed(0)}% '
        '(target ${target.toStringAsFixed(0)}%).');
  }

  final study = ref.read(studyStatsProvider);
  sb.writeln('Study momentum: ${study.streakDays}-day streak, '
      '${study.weekMinutes} minutes this week.');

  final habits = ref.read(habitsStreamProvider).valueOrNull ?? const [];
  final pendingHabits = habits.where((h) => !h.doneToday).toList();
  if (pendingHabits.isNotEmpty) {
    sb.writeln('Habits still to do today: '
        '${pendingHabits.take(6).map((h) => h.title).join(", ")}.');
  }

  return sb.toString().trim();
}

/// Shared base for one-shot AI text generations. State is:
/// - null → not generated yet
/// - AsyncLoading → generating
/// - AsyncData(text) → ready
/// - AsyncError → failed
class AiTextController extends StateNotifier<AsyncValue<String>?> {
  AiTextController(this._ref, this._prompt, this._buildContext) : super(null);

  final Ref _ref;
  final String _prompt;
  final String Function(Ref) _buildContext;

  Future<void> generate() async {
    state = const AsyncValue.loading();
    try {
      await _ensureDataLoaded(_ref);
      final gemini = _ref.read(geminiServiceProvider);
      final context = _buildContext(_ref);
      final reply = await gemini.chat(
        [
          {
            'role': 'user',
            'parts': [
              {'text': _prompt}
            ],
          }
        ],
        context: context,
      );
      var text = GeminiService.stripScheduleBlock(reply);
      text = GeminiService.stripActionsBlock(text);
      text = _tidy(text);
      state = AsyncValue.data(text.isEmpty
          ? "I couldn't generate a summary right now. Please try again."
          : text);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Strip stray markdown so the text renders cleanly in plain widgets.
  String _tidy(String s) {
    var t = s;
    t = t.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*', dotAll: true), (m) => m[1]!);
    t = t.replaceAllMapped(RegExp(r'__(.+?)__', dotAll: true), (m) => m[1]!);
    t = t.replaceAllMapped(
        RegExp(r'(?<!\*)\*(?!\*)(.+?)\*(?!\*)', dotAll: true), (m) => m[1]!);
    t = t.replaceAllMapped(RegExp(r'^\s*#{1,6}\s*', multiLine: true), (_) => '');
    t = t.replaceAllMapped(RegExp(r'^\s*[-*]\s+', multiLine: true), (_) => '• ');
    t = t.replaceAll('`', '');
    return t.trim();
  }
}

const _insightsPrompt =
    'Act as my personal academic analyst. Using ONLY my data below, give me a '
    'short, motivating insights briefing in plain text. Address me by my first '
    'name once where it feels natural (e.g. the opening line). Cover: how my '
    'attendance is tracking against my target (and any subject at risk), my '
    'grades/GPA trend, my study momentum, and my spending vs budget if present. '
    'Then finish with a "Focus this week:" section of 3 concrete, personalised '
    'bullet points. Use short paragraphs and "• " bullets. No markdown symbols. '
    'Keep it under 180 words.';

const _agendaPrompt =
    'Write my daily agenda briefing for today in plain text, using ONLY my data '
    'below. Start with a warm one-line greeting that uses my first name. Then, '
    'using "• " bullets, walk through my classes today (with times), what tasks '
    'are due and which to prioritise, and any exams coming up worth preparing '
    'for. End with one short, encouraging focus tip tailored to my data. Use my '
    'first name naturally, not in every sentence. No markdown symbols. Keep it '
    'friendly and under 160 words.';

/// AI insights briefing for the Insights screen (generated on demand).
final aiInsightsControllerProvider =
    StateNotifierProvider.autoDispose<AiTextController, AsyncValue<String>?>(
        (ref) {
  return AiTextController(ref, _insightsPrompt, buildAnalyticsContext);
});

/// AI daily-agenda summary for the Settings → Daily agenda screen.
final dailyAgendaControllerProvider =
    StateNotifierProvider.autoDispose<AiTextController, AsyncValue<String>?>(
        (ref) {
  return AiTextController(ref, _agendaPrompt, buildDailyAgendaContext);
});
