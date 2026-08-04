import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/firebase_providers.dart';
import '../../../../core/providers/gemini_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../services/gemini_service.dart';
import '../../../../services/analytics_service.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../exams/domain/exam.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../focus/presentation/providers/study_providers.dart';
import '../../../grades/domain/grade_item.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../habits/domain/habit.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../notes/domain/note.dart';
import '../../../notes/presentation/providers/note_providers.dart';
import '../../../schedule/domain/class_session.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/domain/subject.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../subscription/domain/pro_constants.dart';
import '../../../subscription/presentation/providers/subscription_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../domain/chat_message.dart';
import '../../data/chat_repository.dart';
import '../../domain/chat_session.dart';
import 'chat_usage_providers.dart';

class ChatState {
  final List<ChatMessage> messages;
  final bool sending;
  const ChatState({this.messages = const [], this.sending = false});

  ChatState copyWith({List<ChatMessage>? messages, bool? sending}) => ChatState(
        messages: messages ?? this.messages,
        sending: sending ?? this.sending,
      );
}

const _welcome = ChatMessage(
  role: ChatRole.assistant,
  text: "Hi! I'm your ClassTrack assistant. 👋\n\n"
      "Tell me your timetable in plain words (e.g. \"Mon & Wed 9–10 DBMS in Room 204, "
      "Tue 11–12 Maths\") or attach a photo of it, and I'll build your schedule. "
      "You can also ask me for study or attendance tips.",
);

/// A restorable AI deletion: a human label plus a closure that re-creates the
/// deleted item when the user taps Undo.
class PendingUndo {
  final String label;
  final Future<void> Function() restore;
  const PendingUndo(this.label, this.restore);
}

class ChatController extends StateNotifier<ChatState> {
  final GeminiService _gemini;
  final Ref _ref;
  final List<Map<String, dynamic>> _history = [];

  /// Firestore id of the conversation currently being edited. Null until the
  /// first real exchange is saved (or after starting a new chat).
  String? _sessionId;

  /// The most recent AI deletion, kept so the UI can offer a one-tap Undo.
  PendingUndo? _pendingUndo;

  /// Returns and clears the pending undo (consumed by the chat screen).
  PendingUndo? takePendingUndo() {
    final u = _pendingUndo;
    _pendingUndo = null;
    return u;
  }

  /// Set when a free user hits the monthly AI limit; the chat screen reads this
  /// to present the paywall.
  bool _needsPaywall = false;
  bool takeNeedsPaywall() {
    final v = _needsPaywall;
    _needsPaywall = false;
    return v;
  }

  ChatController(this._gemini, this._ref)
      : super(const ChatState(messages: [_welcome]));

  bool get isConfigured => _gemini.isConfigured;

  /// Strip stray markdown so the plain-text chat bubble reads cleanly.
  String _cleanMarkdown(String s) {
    var t = s;
    t = t.replaceAllMapped(
        RegExp(r'\*\*(.+?)\*\*', dotAll: true), (m) => m[1]!);
    t = t.replaceAllMapped(RegExp(r'__(.+?)__', dotAll: true), (m) => m[1]!);
    t = t.replaceAllMapped(
        RegExp(r'(?<!\*)\*(?!\*)(.+?)\*(?!\*)', dotAll: true), (m) => m[1]!);
    t = t.replaceAllMapped(
        RegExp(r'^\s*#{1,6}\s*', multiLine: true), (_) => '');
    t = t.replaceAllMapped(
        RegExp(r'^\s*[-*]\s+', multiLine: true), (_) => '• ');
    t = t.replaceAll('`', '');
    return t.trim();
  }

  /// Compact snapshot of the user's data so the assistant can answer questions
  /// about their attendance, tasks, exams, GPA, expenses, study and habits.
  String _buildContext() {
    final sb = StringBuffer();
    final now = DateTime.now();
    sb.writeln(
        'Today is ${DateUtilsX.prettyFullDate(now)} (${DateUtilsX.dateId(now)}).');
    final profileName =
        _ref.read(userProfileProvider).valueOrNull?.displayName?.trim();
    if (profileName != null && profileName.isNotEmpty) {
      final first = profileName.split(RegExp(r'\s+')).first;
      sb.writeln(
          "The student's name is $first. Greet or address them by their first "
          "name occasionally when it feels natural (for example in a greeting) "
          "— not in every message.");
    }
    final subjects = _ref.read(subjectsStreamProvider).valueOrNull ?? const [];
    final overall = _ref.read(overallStatsProvider);
    final target = _ref.read(userProfileProvider).valueOrNull?.targetAttendancePercent ??
        AppConstants.defaultTargetAttendance;
    if (subjects.isNotEmpty) {
      sb.writeln(
          'Overall attendance: ${overall.held == 0 ? "no data" : "${overall.percent.toStringAsFixed(0)}% (${overall.present}/${overall.held})"}.');
      sb.writeln('Attendance target: ${target.toStringAsFixed(0)}%.');
      final week = _ref.read(weeklyAttendanceProvider);
      if (week.held > 0) {
        sb.writeln(
            'Attendance this week: ${week.percent.toStringAsFixed(0)}% (${week.present}/${week.held} classes; ${week.cancelled} cancelled).');
      }
      sb.writeln('Subjects:');
      for (final s in subjects.take(20)) {
        final held = s.attended + s.absent;
        sb.writeln(
            '- ${s.name}: ${held == 0 ? "no classes marked" : "${s.percent.toStringAsFixed(0)}% (${s.attended}/$held)"}${s.cancelled > 0 ? ", ${s.cancelled} cancelled" : ""}.');
      }
    }
    // Today's classes so the assistant can answer "how many classes today?".
    final todayClasses = _ref.read(classesForDayProvider(now));
    if (todayClasses.isEmpty) {
      sb.writeln("Today's classes: none scheduled.");
    } else {
      sb.writeln("Today's classes (${todayClasses.length}):");
      for (final c in todayClasses) {
        final room = c.session.room;
        sb.writeln(
            '- ${c.subject.name} ${c.session.startTime}–${c.session.endTime}'
            '${room != null && room.isNotEmpty ? " in $room" : ""}.');
      }
    }
    // Full weekly recurring timetable, grouped by weekday, so the assistant
    // can plan the week and reason about the schedule on any day.
    final recurring = _ref
        .read(allSessionsProvider)
        .where((c) => c.session.recurring && c.session.dayOfWeek != null)
        .toList();
    if (recurring.isNotEmpty) {
      sb.writeln('Weekly timetable:');
      for (var d = 0; d < 7; d++) {
        final dayClasses = recurring
            .where((c) => c.session.dayOfWeek == d)
            .toList()
          ..sort((a, b) => DateUtilsX.minutesOfDay(a.session.startTime)
              .compareTo(DateUtilsX.minutesOfDay(b.session.startTime)));
        if (dayClasses.isEmpty) continue;
        final parts = dayClasses
            .map((c) =>
                '${c.subject.name} ${c.session.startTime}–${c.session.endTime}')
            .join(', ');
        sb.writeln('- ${Weekdays.full[d]}: $parts');
      }
    }
    final gpa = _ref.read(gpaSummaryProvider);
    if (gpa.gradedSubjects > 0) {
      sb.writeln(
          'GPA: ${gpa.gpa.toStringAsFixed(2)} of ${gpa.maxPoints >= 10 ? "10" : "4.0"} (avg ${gpa.averagePercent.toStringAsFixed(0)}%).');
    }
    final tasks = _ref.read(pendingTasksProvider);
    if (tasks.isNotEmpty) {
      sb.writeln('Pending tasks:');
      for (final t in tasks.take(15)) {
        final due =
            t.dueDate != null ? DateUtilsX.prettyDate(t.dueDate!) : 'no date';
        sb.writeln(
            '- ${t.title} (${t.type.label}, due $due, ${t.priority.label})${t.isOverdue ? " [OVERDUE]" : ""}.');
      }
    }
    // Task totals + completed list so the assistant can answer "how many have
    // I completed?" (pendingTasksProvider only exposes not-done items).
    final allTasks = _ref.read(tasksStreamProvider).valueOrNull ?? const [];
    if (allTasks.isNotEmpty) {
      final completed = allTasks.where((t) => t.done).toList();
      sb.writeln(
          'Task totals: ${allTasks.length} total, ${allTasks.length - completed.length} pending, ${completed.length} completed.');
      if (completed.isNotEmpty) {
        sb.writeln('Completed tasks:');
        for (final t in completed.take(15)) {
          sb.writeln('- ${t.title} (${t.type.label}).');
        }
      }
    }
    final exams = _ref.read(upcomingExamsProvider);
    if (exams.isNotEmpty) {
      sb.writeln('Upcoming exams:');
      for (final e in exams.take(10)) {
        final room = e.room;
        sb.writeln(
            '- ${e.title} on ${DateUtilsX.prettyDate(e.date)} (${e.countdownLabel})${room != null && room.isNotEmpty ? ", room $room" : ""}.');
      }
    }
    final pastExams = _ref.read(pastExamsProvider);
    if (pastExams.isNotEmpty) {
      sb.writeln('Past exams:');
      for (final e in pastExams.take(10)) {
        sb.writeln('- ${e.title} on ${DateUtilsX.prettyDate(e.date)}.');
      }
    }
    final study = _ref.read(studyStatsProvider);
    final allStudy =
        _ref.read(studySessionsStreamProvider).valueOrNull ?? const [];
    final allStudyMin = allStudy.fold<int>(0, (a, s) => a + s.minutes);
    sb.writeln(
        'Study focus: ${study.todayMinutes} min today, ${study.weekMinutes} min this week, ${study.streakDays}-day streak, $allStudyMin min all-time across ${allStudy.length} sessions.');
    final habitStreak = _ref.read(bestHabitStreakProvider);
    if (habitStreak > 0) sb.writeln('Best habit streak: $habitStreak days.');
    final currency = _ref.read(currencySymbolProvider);
    final budget = _ref.read(monthlyBudgetProvider);
    // Only state a spending figure once the expenses stream has actually
    // loaded. While it's still syncing valueOrNull is empty (→ 0), which must
    // NOT be reported as a real "you spent 0".
    if (!_ref.read(expensesStreamProvider).hasValue) {
      sb.writeln(
          'Expenses this month: still syncing — do NOT claim the total is 0; '
          'if asked, tell the user their data is loading and to ask again in a moment.');
    } else {
      final spent = _ref.read(monthlyTotalProvider);
      sb.writeln(
          'Expenses this month: $currency${spent.toStringAsFixed(0)}${budget > 0 ? " of $currency${budget.toStringAsFixed(0)} budget" : ""}.');
      // Category-wise breakdown so the assistant can answer "how much on food?".
      final breakdown = _ref.read(categoryBreakdownProvider);
      if (breakdown.isNotEmpty) {
        sb.writeln('Spending by category this month:');
        for (final e in breakdown) {
          sb.writeln(
              '- ${e.key.label}: $currency${e.value.toStringAsFixed(0)}');
        }
      }
      final monthExpenses = _ref.read(thisMonthExpensesProvider);
      if (monthExpenses.isNotEmpty) {
        sb.writeln('Recent expenses:');
        for (final e in monthExpenses.take(10)) {
          sb.writeln(
              '- ${e.title} ($currency${e.amount.toStringAsFixed(0)}, ${e.category.label}, ${DateUtilsX.prettyDate(e.date)}).');
        }
      }
      // Historical months so the assistant can answer about LAST MONTH and
      // earlier (not just the current month). Computed from the full expense
      // history, most recent first.
      final allExpenses =
          _ref.read(expensesStreamProvider).valueOrNull ?? const [];
      final now2 = DateTime.now();
      String monthKey(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}';
      final byMonth = <String, double>{};
      final catByMonth = <String, Map<ExpenseCategory, double>>{};
      for (final e in allExpenses) {
        final key = monthKey(e.date);
        byMonth[key] = (byMonth[key] ?? 0) + e.amount;
        (catByMonth[key] ??= <ExpenseCategory, double>{})[e.category] =
            ((catByMonth[key]?[e.category]) ?? 0) + e.amount;
      }
      final currentKey = monthKey(now2);
      final pastKeys = byMonth.keys.where((k) => k != currentKey).toList()
        ..sort((a, b) => b.compareTo(a));
      if (pastKeys.isNotEmpty) {
        sb.writeln('Expense history (previous months, spend per month):');
        for (final k in pastKeys.take(6)) {
          final cats = (catByMonth[k] ?? const {}).entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          final top = cats.isNotEmpty
              ? ', top: ${cats.first.key.label} $currency${cats.first.value.toStringAsFixed(0)}'
              : '';
          sb.writeln('- $k: $currency${byMonth[k]!.toStringAsFixed(0)}$top');
        }
        // Explicit last-month category breakdown (a very common question).
        final lastMonth = DateTime(now2.year, now2.month - 1, 1);
        final lastCats = catByMonth[monthKey(lastMonth)];
        if (lastCats != null && lastCats.isNotEmpty) {
          final entries = lastCats.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value));
          sb.writeln('Last month by category:');
          for (final e in entries) {
            sb.writeln(
                '- ${e.key.label}: $currency${e.value.toStringAsFixed(0)}');
          }
        }
      }
    }
    // Per-subject grades.
    if (subjects.isNotEmpty) {
      final gradeLines = <String>[];
      for (final s in subjects) {
        final course = _ref.read(courseGradeProvider(s.id));
        if (course.count == 0) continue;
        gradeLines.add(
            '- ${s.name}: ${course.percent.toStringAsFixed(0)}% (${course.count} graded items).');
      }
      if (gradeLines.isNotEmpty) {
        sb.writeln('Grades by subject:');
        gradeLines.forEach(sb.writeln);
      }
    }
    final gradeItems = _ref.read(gradesStreamProvider).valueOrNull ?? const [];
    if (gradeItems.isNotEmpty) {
      sb.writeln('Individual grades:');
      for (final g in gradeItems.take(15)) {
        sb.writeln(
            '- ${g.title}: ${g.score.toStringAsFixed(0)}/${g.maxScore.toStringAsFixed(0)} (${g.percent.toStringAsFixed(0)}%).');
      }
    }
    // Notes.
    final notes = _ref.read(notesStreamProvider).valueOrNull ?? const [];
    if (notes.isNotEmpty) {
      sb.writeln('Notes (${notes.length}):');
      for (final n in notes.take(15)) {
        final t = n.title.trim().isEmpty ? 'Untitled note' : n.title.trim();
        final preview = n.preview.trim();
        sb.writeln(
            '- $t${preview.isNotEmpty ? ": $preview" : ""}${n.linkedExamId != null ? " [linked to an exam]" : ""}.');
      }
    }
    // Habits.
    final habits = _ref.read(habitsStreamProvider).valueOrNull ?? const [];
    if (habits.isNotEmpty) {
      sb.writeln('Habits:');
      for (final h in habits.take(12)) {
        sb.writeln(
            '- ${h.title} (${h.streak}-day streak, ${h.doneToday ? "done today" : "not done today"}).');
      }
    }
    return sb.toString().trim();
  }

  void _append(ChatMessage m) =>
      state = state.copyWith(messages: [...state.messages, m]);

  /// The assistant answers data questions from a snapshot built in
  /// [_buildContext]. That snapshot reads several Firestore-backed streams,
  /// which may not have delivered their first value the instant the chat
  /// opens — and a still-loading stream reads as an EMPTY list. That's how the
  /// assistant could once say "you spent 0" moments before the real figure
  /// arrived. Awaiting the first emission (with a safety timeout) guarantees
  /// the context reflects real data. A slow/failing stream never blocks the
  /// chat — we just proceed with whatever has loaded.
  Future<void> _ensureDataLoaded() async {
    Future<void> first(Future<dynamic> f) async {
      await f;
    }

    try {
      await Future.wait([
        first(_ref.read(expensesStreamProvider.future)),
        first(_ref.read(subjectsStreamProvider.future)),
        first(_ref.read(tasksStreamProvider.future)),
        first(_ref.read(gradesStreamProvider.future)),
        first(_ref.read(notesStreamProvider.future)),
        first(_ref.read(habitsStreamProvider.future)),
        first(_ref.read(examsStreamProvider.future)),
        first(_ref.read(studySessionsStreamProvider.future)),
      ]).timeout(const Duration(seconds: 5));
    } catch (_) {
      // Ignore — fall back to whatever data is already available.
    }
  }

  Future<void> send(String text, {Uint8List? image}) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty && image == null) return;

    _append(ChatMessage(role: ChatRole.user, text: trimmed, image: image));

    // Feature-usage analytics (never blocks the chat).
    _ref.read(analyticsProvider).aiMessage(hasImage: image != null);

    if (!_gemini.isConfigured) {
      _append(const ChatMessage(
        role: ChatRole.assistant,
        text: "I need a Gemini API key to chat. Add a free one in "
            "Settings → AI assistant, then come back. 🙂",
      ));
      return;
    }

    // Enforce the free monthly AI limit (unlimited for Pro). The server also
    // enforces this; the client check gives instant feedback + a paywall.
    final isPro = _ref.read(isProProvider);
    final usageRepo = _ref.read(chatUsageRepositoryProvider);
    if (!isPro) {
      final used = usageRepo == null ? 0 : await usageRepo.currentCount();
      if (used >= ProConstants.freeMonthlyChatLimit) {
        _append(ChatMessage(
          role: ChatRole.assistant,
          text: "You've used all ${ProConstants.freeMonthlyChatLimit} free AI "
              "messages this month. Upgrade to ClassTrack Pro for unlimited "
              "chats. 💜",
        ));
        _needsPaywall = true;
        return;
      }
    }

    state = state.copyWith(sending: true);
    try {
      final parts = <Map<String, dynamic>>[
        {'text': trimmed.isEmpty ? 'Here is my timetable.' : trimmed},
        if (image != null)
          {
            'inlineData': {
              'data': base64Encode(image),
              'mimeType': 'image/jpeg',
            }
          },
      ];
      _history.add({'role': 'user', 'parts': parts});

      // Make sure the user's data streams have loaded before we snapshot them
      // into the assistant's context — otherwise a still-loading stream looks
      // empty and the assistant answers with wrong zeros.
      await _ensureDataLoaded();

      final reply = await _gemini.chat(_history, context: _buildContext());
      _history.add({
        'role': 'model',
        'parts': [
          {'text': reply}
        ]
      });

      final schedule = GeminiService.extractScheduleFromReply(reply);
      if (schedule != null) {
        _ref.read(analyticsProvider).scheduleImport('chat');
      }
      final actions = GeminiService.extractActionsFromReply(reply);
      if (actions.isNotEmpty) {
        // When the assistant also proposes a reviewable schedule, the user
        // confirms and commits it from the review card. Auto-executing
        // `subject`/`class` create-actions here would add those same items a
        // first time, producing duplicates once the user taps
        // "Review & add to calendar". So drop them and let the review card be
        // the single source of truth for the schedule. Other action types
        // (exam, task, expense, …) are unrelated and still run.
        final toRun = schedule == null
            ? actions
            : actions.where((a) {
                final t = (a['type'] as String?)?.trim();
                return t != 'subject' && t != 'class';
              }).toList();
        if (toRun.isNotEmpty) await _executeActions(toRun);
      }
      var cleaned = GeminiService.stripScheduleBlock(reply);
      cleaned = GeminiService.stripActionsBlock(cleaned);
      final prose = _cleanMarkdown(cleaned);
      _append(ChatMessage(
        role: ChatRole.assistant,
        text: prose.isEmpty
            ? (schedule != null
                ? 'I put together a schedule below — tap to review it.'
                : (actions.isNotEmpty ? 'Done — updated for you. ✅' : 'Okay!'))
            : prose,
        schedule: schedule,
      ));
      // Count this successful message toward the free monthly limit.
      if (!isPro) {
        try {
          await usageRepo?.increment();
        } catch (_) {/* never let usage bookkeeping surface as a chat error */}
      }
      // Save the conversation so the user can revisit it from history.
      await _persistSession();
    } catch (e) {
      final s = e.toString().toLowerCase();
      final limited =
          s.contains('resource-exhausted') || s.contains('usage limit');
      _append(ChatMessage(
        role: ChatRole.assistant,
        text: limited
            ? "You've reached today's AI usage limit. Please try again "
                "tomorrow. 🙏"
            : 'Something went wrong reaching the assistant. Please check your '
                'connection and try again.',
      ));
    } finally {
      state = state.copyWith(sending: false);
    }
  }

  // --- Invisible function calling --------------------------------------------

  /// Runs the structured actions the assistant emitted, updating Firestore/UI
  /// silently. Failures are swallowed so a bad action never derails the chat.
  Future<void> _executeActions(List<Map<String, dynamic>> actions) async {
    for (final a in actions) {
      final type = a['type']?.toString().trim();
      try {
        switch (type) {
          case 'expense':
            await _addExpense(a);
            break;
          case 'exam':
            await _addExam(a);
            break;
          case 'task':
            await _addTask(a);
            break;
          case 'linkNote':
            await _linkNote(a);
            break;
          case 'attendance':
            await _markAttendance(a);
            break;
          case 'note':
            await _addNote(a);
            break;
          case 'budget':
            await _setBudget(a);
            break;
          case 'subject':
            await _addSubject(a);
            break;
          case 'grade':
            await _addGrade(a);
            break;
          case 'class':
            await _addClass(a);
            break;
          case 'habit':
            await _addHabit(a);
            break;
          case 'habitCheck':
            await _checkHabit(a);
            break;
          case 'study':
            await _addStudy(a);
            break;
          case 'update':
            await _updateEntity(a);
            break;
          case 'delete':
            await _deleteEntity(a);
            break;
        }
      } catch (_) {
        // Invisible automation shouldn't surface stack traces to the user.
      }
    }
  }

  DateTime? _parseDate(String? s) {
    if (s == null || s.trim().isEmpty) return null;
    try {
      return DateUtilsX.fromDateId(s.trim());
    } catch (_) {
      return DateTime.tryParse(s.trim());
    }
  }

  /// Coerce a JSON value to a double, tolerating numbers the model sent as
  /// strings (e.g. "20"). Returns null when it isn't a usable number — so an
  /// action degrades gracefully instead of throwing a ClassCastException that
  /// would silently abort the write while the UI still says "Done ✅".
  double? _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v.trim());
    return null;
  }

  int? _toInt(dynamic v) => _toDouble(v)?.round();

  String? _findSubjectIdByName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final q = name.toLowerCase().trim();
    final subjects = _ref.read(subjectsStreamProvider).valueOrNull ?? const [];
    for (final s in subjects) {
      final n = s.name.toLowerCase();
      if (n == q || n.contains(q) || q.contains(n)) return s.id;
    }
    return null;
  }

  Future<void> _addExpense(Map<String, dynamic> a) async {
    final amount = _toDouble(a['amount']);
    if (amount == null || amount <= 0) return;
    final category = ExpenseCategoryX.parse(a['category'] as String?);
    final title = (a['title'] as String?)?.trim();
    await _ref.read(expenseControllerProvider).add(Expense(
          id: '',
          title: (title == null || title.isEmpty) ? category.label : title,
          amount: amount,
          category: category,
          date: DateTime.now(),
        ));
  }

  Future<void> _addExam(Map<String, dynamic> a) async {
    final title = (a['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    final date = _parseDate(a['date'] as String?) ?? DateTime.now();
    final time = DateUtilsX.parseTime24((a['time'] as String?) ?? '');
    final dt = DateTime(
        date.year, date.month, date.day, time?.hour ?? 9, time?.minute ?? 0);
    String? clean(String? v) =>
        (v == null || v.trim().isEmpty) ? null : v.trim();
    await _ref.read(examControllerProvider).add(Exam(
          id: '',
          title: title,
          subjectId: _findSubjectIdByName(a['subject'] as String?),
          date: dt,
          room: clean(a['room'] as String?),
          note: clean(a['note'] as String?),
        ));
  }

  Future<void> _addTask(Map<String, dynamic> a) async {
    final title = (a['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    await _ref.read(taskControllerProvider).add(TaskItem(
          id: '',
          title: title,
          dueDate: _parseDate(a['dueDate'] as String?),
          priority: TaskPriorityX.parse(a['priority'] as String?),
          type: TaskTypeX.parse(a['taskType'] as String?),
          subjectId: _findSubjectIdByName(a['subject'] as String?),
        ));
  }

  Future<void> _linkNote(Map<String, dynamic> a) async {
    final noteQ = (a['noteTitle'] as String?)?.toLowerCase().trim();
    final examQ = (a['examTitle'] as String?)?.toLowerCase().trim();
    if (noteQ == null || noteQ.isEmpty || examQ == null || examQ.isEmpty) {
      return;
    }
    final notes = _ref.read(notesStreamProvider).valueOrNull ?? const [];
    final exams = _ref.read(examsStreamProvider).valueOrNull ?? const [];

    Note? note;
    for (final n in notes) {
      final t = n.title.toLowerCase();
      if (t.contains(noteQ) || noteQ.contains(t)) {
        note = n;
        break;
      }
    }
    Exam? exam;
    for (final e in exams) {
      final t = e.title.toLowerCase();
      if (t.contains(examQ) || examQ.contains(t)) {
        exam = e;
        break;
      }
    }
    if (note == null || exam == null) return;
    await _ref.read(noteControllerProvider).update(
          note.copyWith(linkedExamId: exam.id, updatedAt: DateTime.now()),
        );
  }

  Future<void> _markAttendance(Map<String, dynamic> a) async {
    final subjectId = _findSubjectIdByName(a['subject'] as String?);
    if (subjectId == null) return;
    final status = switch ((a['status'] as String?)?.toLowerCase().trim()) {
      'present' => AttendanceStatus.present,
      'absent' => AttendanceStatus.absent,
      'cancelled' || 'canceled' => AttendanceStatus.cancelled,
      _ => null,
    };
    if (status == null) return;
    final date = _parseDate(a['date'] as String?) ?? DateTime.now();
    await _ref
        .read(attendanceControllerProvider)
        .setForDate(subjectId, date, status);
  }

  Future<void> _addNote(Map<String, dynamic> a) async {
    final title = (a['title'] as String?)?.trim() ?? '';
    final body = (a['body'] as String?)?.trim() ?? '';
    if (title.isEmpty && body.isEmpty) return;
    await _ref.read(noteControllerProvider).add(Note(
          id: 'new',
          title: title,
          body: body,
          subjectId: _findSubjectIdByName(a['subject'] as String?),
          updatedAt: DateTime.now(),
        ));
  }

  Future<void> _setBudget(Map<String, dynamic> a) async {
    final amount = _toDouble(a['amount']);
    if (amount == null || amount < 0) return;
    await _ref.read(expenseSettingsProvider).setBudget(amount);
  }

  // --- Generic matching + create/update/delete across all entities ----------

  /// Finds the item whose title/name best matches [q] (exact first, then
  /// contains). Returns null when nothing reasonably matches.
  T? _match<T>(List<T> items, String? q, String Function(T) name) {
    if (q == null || q.trim().isEmpty) return null;
    final query = q.toLowerCase().trim();
    for (final it in items) {
      if (name(it).toLowerCase() == query) return it;
    }
    for (final it in items) {
      final t = name(it).toLowerCase();
      if (t.isNotEmpty && (t.contains(query) || query.contains(t))) return it;
    }
    return null;
  }

  /// Finds the expense the user means, using any combination of amount,
  /// category and title. "delete the 20 rupees food transaction" carries an
  /// amount and a category but often no real title, so title-only matching
  /// fails — this narrows by amount/category first, then title.
  Expense? _matchExpense(
    List<Expense> items,
    String? q,
    num? amount,
    String? categoryName,
  ) {
    final category = (categoryName != null && categoryName.trim().isNotEmpty)
        ? ExpenseCategoryX.parse(categoryName.trim())
        : null;

    var pool = items;
    if (amount != null) {
      final target = amount.toDouble();
      final byAmount =
          items.where((e) => (e.amount - target).abs() < 0.01).toList();
      if (byAmount.isNotEmpty) pool = byAmount;
    }
    if (category != null) {
      final byCat = pool.where((e) => e.category == category).toList();
      if (byCat.isNotEmpty) pool = byCat;
    }

    // Prefer a title match inside the narrowed pool.
    final byTitle = _match(pool, q, (x) => x.title);
    if (byTitle != null) return byTitle;

    // If we narrowed by amount/category, return the most recent candidate.
    // Sort a COPY — never mutate the stream-backed list other widgets read.
    if ((amount != null || category != null) && pool.isNotEmpty) {
      final sorted = [...pool]..sort((a, b) => b.date.compareTo(a.date));
      return sorted.first;
    }

    // Fall back to a plain title search across everything.
    return _match(items, q, (x) => x.title);
  }

  int _pickColor(String? c) {
    if (c != null && c.trim().isNotEmpty) {
      var s = c.trim();
      if (s.startsWith('#')) s = s.substring(1);
      final v = int.tryParse(s, radix: 16);
      if (v != null) return v <= 0xFFFFFF ? (0xFF000000 | v) : v;
    }
    final palette = AppColors.subjectPalette;
    return palette[DateTime.now().microsecondsSinceEpoch % palette.length]
        .toARGB32();
  }

  String? _clean(String? v) => (v == null || v.trim().isEmpty) ? null : v.trim();

  Future<void> _addSubject(Map<String, dynamic> a) async {
    final name = (a['name'] as String?)?.trim();
    if (name == null || name.isEmpty) return;
    final repo = _ref.read(subjectRepositoryProvider);
    if (repo == null) return;
    await repo.create(Subject(
      id: '',
      name: name,
      colorHex: _pickColor(a['color'] as String?),
      iconKey: a['icon'] as String?,
      startDate: _parseDate(a['startDate'] as String?),
      endDate: _parseDate(a['endDate'] as String?),
    ));
  }

  Future<void> _addGrade(Map<String, dynamic> a) async {
    final title = (a['title'] as String?)?.trim();
    final score = _toDouble(a['score']);
    final maxScore = _toDouble(a['maxScore']);
    if (title == null || title.isEmpty || score == null || maxScore == null ||
        maxScore <= 0) {
      return;
    }
    await _ref.read(gradeControllerProvider).add(GradeItem(
          id: '',
          title: title,
          score: score,
          maxScore: maxScore,
          weight: _toDouble(a['weight']),
          subjectId: _findSubjectIdByName(a['subject'] as String?),
          date: DateTime.now(),
        ));
  }

  Future<void> _addClass(Map<String, dynamic> a) async {
    final subjectId = _findSubjectIdByName(a['subject'] as String?);
    if (subjectId == null) return;
    final repo = _ref.read(sessionRepositoryProvider);
    if (repo == null) return;
    final day = Weekdays.parse((a['day'] as String?) ?? '');
    final start = (a['start'] as String?) ?? '09:00';
    final end =
        DateUtilsX.normalizeEndTime24(start, (a['end'] as String?) ?? '10:00');
    await repo.add(
      subjectId,
      ClassSession(
        id: '',
        subjectId: subjectId,
        recurring: day != null,
        dayOfWeek: day,
        specificDate: day == null ? _parseDate(a['date'] as String?) : null,
        startTime: start,
        endTime: end,
        room: _clean(a['room'] as String?),
      ),
    );
  }

  Future<void> _addHabit(Map<String, dynamic> a) async {
    final title = (a['title'] as String?)?.trim();
    if (title == null || title.isEmpty) return;
    await _ref.read(habitControllerProvider).add(Habit(
          id: 'new',
          title: title,
          colorHex: _pickColor(a['color'] as String?),
        ));
  }

  /// Logs a focus/study session (minutes, optional subject + date).
  Future<void> _addStudy(Map<String, dynamic> a) async {
    final minutes = _toInt(a['minutes']);
    if (minutes == null || minutes <= 0) return;
    await _ref.read(studyControllerProvider).logSession(
          minutes: minutes,
          subjectId: _findSubjectIdByName(a['subject'] as String?),
          startedAt: _parseDate(a['date'] as String?),
        );
  }

  /// Marks the matching habit done for today (idempotent — never un-checks).
  Future<void> _checkHabit(Map<String, dynamic> a) async {    final q = (a['match'] ?? a['title'] ?? a['name']) as String?;
    final habits = _ref.read(habitsStreamProvider).valueOrNull ?? const [];
    final h = _match(habits, q, (x) => x.title);
    if (h == null || h.doneToday) return;
    await _ref.read(habitControllerProvider).toggleToday(h);
  }

  Future<void> _updateEntity(Map<String, dynamic> a) async {
    final entity = (a['entity'] as String?)?.toLowerCase().trim();
    final q = (a['match'] ?? a['title'] ?? a['name']) as String?;
    switch (entity) {
      case 'task':
        final t = _match(_ref.read(tasksStreamProvider).valueOrNull ?? const [],
            q, (x) => x.title);
        if (t == null) return;
        await _ref.read(taskControllerProvider).update(t.copyWith(
              title: _clean(a['newTitle'] as String?),
              note: _clean(a['note'] as String?),
              dueDate: _parseDate(a['dueDate'] as String?),
              priority: a['priority'] != null
                  ? TaskPriorityX.parse(a['priority'] as String?)
                  : null,
              type: a['taskType'] != null
                  ? TaskTypeX.parse(a['taskType'] as String?)
                  : null,
              done: a['done'] as bool?,
            ));
        break;
      case 'exam':
        final e = _match(_ref.read(examsStreamProvider).valueOrNull ?? const [],
            q, (x) => x.title);
        if (e == null) return;
        DateTime? newDate;
        final d = _parseDate(a['date'] as String?);
        if (d != null) {
          final tod = DateUtilsX.parseTime24((a['time'] as String?) ?? '');
          newDate = DateTime(d.year, d.month, d.day, tod?.hour ?? e.date.hour,
              tod?.minute ?? e.date.minute);
        }
        await _ref.read(examControllerProvider).update(e.copyWith(
              title: _clean(a['newTitle'] as String?),
              date: newDate,
              room: _clean(a['room'] as String?),
              note: _clean(a['note'] as String?),
            ));
        break;
      case 'expense':
        final ex = _matchExpense(
            _ref.read(expensesStreamProvider).valueOrNull ?? const [],
            q,
            _toDouble(a['amount']),
            a['category'] as String?);
        if (ex == null) return;
        await _ref.read(expenseControllerProvider).update(ex.copyWith(
              title: _clean(a['newTitle'] as String?),
              amount: _toDouble(a['newAmount']),
              category: a['newCategory'] != null
                  ? ExpenseCategoryX.parse(a['newCategory'] as String?)
                  : null,
            ));
        break;
      case 'note':
        final n = _match(_ref.read(notesStreamProvider).valueOrNull ?? const [],
            q, (x) => x.title);
        if (n == null) return;
        await _ref.read(noteControllerProvider).update(n.copyWith(
              title: _clean(a['newTitle'] as String?),
              body: _clean(a['body'] as String?),
              updatedAt: DateTime.now(),
            ));
        break;
      case 'grade':
        final g = _match(
            _ref.read(gradesStreamProvider).valueOrNull ?? const [],
            q,
            (x) => x.title);
        if (g == null) return;
        await _ref.read(gradeControllerProvider).update(g.copyWith(
              title: _clean(a['newTitle'] as String?),
              score: _toDouble(a['score']),
              maxScore: _toDouble(a['maxScore']),
              weight: _toDouble(a['weight']),
            ));
        break;
      case 'subject':
        final repo = _ref.read(subjectRepositoryProvider);
        final s = _match(
            _ref.read(subjectsStreamProvider).valueOrNull ?? const [],
            q,
            (x) => x.name);
        if (s == null || repo == null) return;
        await repo.update(s.copyWith(
          name: _clean(a['newName'] as String?),
          colorHex: a['color'] != null ? _pickColor(a['color'] as String?) : null,
          iconKey: a['icon'] as String?,
          startDate: _parseDate(a['startDate'] as String?),
          endDate: _parseDate(a['endDate'] as String?),
        ));
        break;
      case 'class':
        final subjectId = _findSubjectIdByName(a['subject'] as String?);
        final repo = _ref.read(sessionRepositoryProvider);
        if (subjectId == null || repo == null) return;
        final sessions =
            _ref.read(sessionsForSubjectProvider(subjectId)).valueOrNull ??
                const [];
        final day = Weekdays.parse((a['day'] as String?) ?? '');
        if (day == null) return; // need a specific day to pick the right class
        ClassSession? target;
        for (final s in sessions) {
          if (s.dayOfWeek == day) {
            target = s;
            break;
          }
        }
        if (target == null) return;
        final newStart = _clean(a['start'] as String?);
        final newEndRaw = _clean(a['end'] as String?);
        final newDay = Weekdays.parse((a['newDay'] as String?) ?? '');
        final effStart = newStart ?? target.startTime;
        await repo.update(target.copyWith(
          startTime: newStart,
          endTime: newEndRaw != null
              ? DateUtilsX.normalizeEndTime24(effStart, newEndRaw)
              : null,
          dayOfWeek: newDay,
          room: _clean(a['room'] as String?),
        ));
        break;
      case 'habit':
        final h = _match(
            _ref.read(habitsStreamProvider).valueOrNull ?? const [],
            q,
            (x) => x.title);
        if (h == null) return;
        await _ref.read(habitControllerProvider).update(h.copyWith(
              title: _clean(a['newTitle'] as String?),
              colorHex:
                  a['color'] != null ? _pickColor(a['color'] as String?) : null,
            ));
        break;
    }
  }

  Future<void> _deleteEntity(Map<String, dynamic> a) async {
    final entity = (a['entity'] as String?)?.toLowerCase().trim();
    final q = (a['match'] ?? a['title'] ?? a['name']) as String?;
    switch (entity) {
      case 'task':
        final t = _match(_ref.read(tasksStreamProvider).valueOrNull ?? const [],
            q, (x) => x.title);
        if (t != null) {
          await _ref.read(taskControllerProvider).delete(t.id);
          _pendingUndo = PendingUndo('Deleted "${t.title}"',
              () => _ref.read(taskControllerProvider).add(t));
        }
        break;
      case 'exam':
        final e = _match(_ref.read(examsStreamProvider).valueOrNull ?? const [],
            q, (x) => x.title);
        if (e != null) {
          await _ref.read(examControllerProvider).delete(e.id);
          _pendingUndo = PendingUndo('Deleted "${e.title}"',
              () => _ref.read(examControllerProvider).add(e));
        }
        break;
      case 'expense':
        final ex = _matchExpense(
            _ref.read(expensesStreamProvider).valueOrNull ?? const [],
            q,
            _toDouble(a['amount']),
            a['category'] as String?);
        if (ex != null) {
          await _ref.read(expenseControllerProvider).delete(ex.id);
          _pendingUndo = PendingUndo(
              'Deleted "${ex.title.isEmpty ? ex.category.label : ex.title}"',
              () => _ref.read(expenseControllerProvider).add(ex));
        }
        break;
      case 'note':
        final n = _match(_ref.read(notesStreamProvider).valueOrNull ?? const [],
            q, (x) => x.title);
        if (n != null) {
          await _ref.read(noteControllerProvider).delete(n.id);
          _pendingUndo = PendingUndo(
              'Deleted note "${n.title.isEmpty ? 'Untitled' : n.title}"',
              () => _ref.read(noteControllerProvider).add(n));
        }
        break;
      case 'grade':
        final g = _match(
            _ref.read(gradesStreamProvider).valueOrNull ?? const [],
            q,
            (x) => x.title);
        if (g != null) {
          await _ref.read(gradeControllerProvider).delete(g.id);
          _pendingUndo = PendingUndo('Deleted "${g.title}"',
              () => _ref.read(gradeControllerProvider).add(g));
        }
        break;
      case 'subject':
        final repo = _ref.read(subjectRepositoryProvider);
        final s = _match(
            _ref.read(subjectsStreamProvider).valueOrNull ?? const [],
            q,
            (x) => x.name);
        if (s != null && repo != null) {
          await repo.delete(s.id);
          _pendingUndo = PendingUndo(
              'Deleted "${s.name}"', () => repo.create(s));
        }
        break;
      case 'class':
        final subjectId = _findSubjectIdByName(a['subject'] as String?);
        final repo = _ref.read(sessionRepositoryProvider);
        if (subjectId == null || repo == null) return;
        final sessions =
            _ref.read(sessionsForSubjectProvider(subjectId)).valueOrNull ??
                const [];
        final day = Weekdays.parse((a['day'] as String?) ?? '');
        if (day == null) return; // need a specific day to pick the right class
        ClassSession? target;
        for (final s in sessions) {
          if (s.dayOfWeek == day) {
            target = s;
            break;
          }
        }
        if (target != null) {
          final t = target;
          await repo.delete(subjectId, t.id);
          _pendingUndo = PendingUndo(
              'Deleted a class', () => repo.add(subjectId, t));
        }
        break;
      case 'habit':
        final h = _match(
            _ref.read(habitsStreamProvider).valueOrNull ?? const [],
            q,
            (x) => x.title);
        if (h != null) {
          await _ref.read(habitControllerProvider).delete(h.id);
          _pendingUndo = PendingUndo('Deleted "${h.title}"',
              () => _ref.read(habitControllerProvider).add(h));
        }
        break;
    }
  }

  /// Persists the current conversation to Firestore so it appears in history.
  /// No-op until there's at least one real user message.
  Future<void> _persistSession() async {
    final repo = _ref.read(chatRepositoryProvider);
    if (repo == null) return;
    final stored = state.messages
        .where((m) =>
            m.text.trim().isNotEmpty &&
            !(m.role == ChatRole.assistant && m.text == _welcome.text))
        .toList();
    if (!stored.any((m) => m.isUser)) return;
    _sessionId ??= repo.newId();
    final firstUser = stored.firstWhere((m) => m.isUser);
    final rawTitle = firstUser.text.trim();
    final title =
        rawTitle.length > 60 ? '${rawTitle.substring(0, 60)}…' : rawTitle;
    try {
      await repo.save(ChatSession(
        id: _sessionId!,
        title: title,
        messages: stored,
        updatedAt: DateTime.now(),
      ));
    } catch (_) {
      // History is a convenience; never let a save failure break the chat.
    }
  }

  /// Loads a saved conversation into the live chat, rebuilding the Gemini
  /// context so the assistant can continue where it left off.
  void loadSession(ChatSession session) {
    _sessionId = session.id;
    _history.clear();
    final msgs = <ChatMessage>[];
    for (final m in session.messages) {
      msgs.add(m);
      if (m.text.trim().isNotEmpty) {
        _history.add({
          'role': m.role == ChatRole.user ? 'user' : 'model',
          'parts': [
            {'text': m.text}
          ],
        });
      }
    }
    state = ChatState(messages: msgs.isEmpty ? const [_welcome] : msgs);
  }

  void reset() {
    _history.clear();
    _sessionId = null; // start a fresh conversation; the old one is saved
    state = const ChatState(messages: [_welcome]);
  }
}

final chatControllerProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) {
  // Recreate a fresh (empty) controller whenever the signed-in user changes,
  // so one account can NEVER see another account's in-memory conversation.
  // The saved history in Firestore is already per-uid; this resets the live,
  // in-memory chat + Gemini history on sign-out / account switch.
  ref.watch(currentUidProvider);
  return ChatController(ref.watch(geminiServiceProvider), ref);
});

/// Persistence layer for saved chat conversations (null when signed out).
final chatRepositoryProvider = Provider<ChatRepository?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return null;
  return ChatRepository(db: ref.watch(firestoreProvider), uid: uid);
});

/// Live list of the user's saved conversations, newest first.
final chatSessionsProvider = StreamProvider<List<ChatSession>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  if (repo == null) return Stream.value(const []);
  return repo.watchSessions();
});
