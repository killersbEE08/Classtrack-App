import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/subject_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/url_launcher_util.dart';
import '../../../../services/reminder_scheduler.dart';
import '../../../../services/analytics_service.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../exams/presentation/screens/exams_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../focus/presentation/providers/study_providers.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../grades/presentation/screens/grades_screen.dart';
import '../../../habits/presentation/providers/habit_providers.dart';
import '../../../habits/presentation/screens/habits_screen.dart';
import '../../../moments/presentation/screens/moments_screen.dart';
import '../../../notes/presentation/screens/notes_screen.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final overall = ref.watch(overallStatsProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayClasses = ref.watch(classesForDayProvider(today));
    final pending = ref.watch(pendingTasksProvider);
    final nextExam = ref.watch(nextExamProvider);
    final gpa = ref.watch(gpaSummaryProvider);
    final firstName = profile?.displayName?.split(' ').first ?? 'there';

    final examValue = nextExam == null
        ? '—'
        : (nextExam.daysUntil <= 0 ? 'Today' : '${nextExam.daysUntil}');
    final examUnit = nextExam == null
        ? 'No exams'
        : (nextExam.daysUntil <= 0
            ? 'Next exam'
            : (nextExam.daysUntil == 1 ? 'day left' : 'days left'));
    final gpaValue =
        gpa.gradedSubjects == 0 ? '—' : gpa.gpa.toStringAsFixed(2);
    final gpaUnit = gpa.gradedSubjects == 0
        ? 'No grades'
        : 'of ${gpa.maxPoints >= 10 ? '10' : '4.0'}';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            _header(context, theme, firstName)
                .animate()
                .fadeIn(duration: 350.ms),
            const SizedBox(height: 22),
            RichText(
              text: TextSpan(
                style: theme.textTheme.displaySmall,
                children: [
                  const TextSpan(
                    text: 'Stay ',
                    style: TextStyle(color: AppColors.primary),
                  ),
                  TextSpan(
                    text: 'on track\ntoday.',
                    style: TextStyle(color: theme.textTheme.displaySmall?.color),
                  ),
                ],
              ),
            ).animate().fadeIn(duration: 400.ms).slideX(
                begin: -0.06, curve: Curves.easeOutCubic),
            const SizedBox(height: 22),
            _statGrid(context, todayClasses.length, overall.percent,
                    overall.held, examValue, examUnit, gpaValue, gpaUnit)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.08, curve: Curves.easeOut),
            const SizedBox(height: 22),
            const _WeeklyInsights(),
            const SizedBox(height: 24),
            const RemindersBanner(),
            const _StudyToolsRow(),
            const SizedBox(height: 24),
            _TodayClasses(today: today),
            const SizedBox(height: 26),
            SectionHeader(
              title: 'Upcoming tasks',
              actionLabel: pending.isEmpty ? null : 'View all',
              onAction: () => _push(context, const TasksScreen()),
            ),
            const SizedBox(height: 12),
            if (pending.isEmpty)
              _emptyTile(
                context,
                icon: Icons.task_alt_rounded,
                text: "No pending tasks. You're all caught up! 🎉",
              )
            else
              ...[
                for (var i = 0; i < pending.take(3).length; i++)
                  _taskCard(context, ref, pending[i])
                      .animate()
                      .fadeIn(delay: (i * 70).ms, duration: 320.ms)
                      .slideX(begin: 0.08, curve: Curves.easeOutCubic),
              ],
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, ThemeData theme, String firstName) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open settings',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _push(context, const SettingsScreen()),
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.primaryLight, AppColors.primary],
                      ),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      firstName.isNotEmpty ? firstName[0].toUpperCase() : '?',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hey, $firstName 👋',
                            style: theme.textTheme.titleMedium),
                        Text('Let’s check your day',
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        RoundIconButton(
          icon: Icons.auto_awesome_rounded,
          background: AppColors.primary,
          iconColor: Colors.white,
          onTap: () => _push(context, const ChatScreen()),
        ),
      ],
    );
  }

  Widget _statGrid(BuildContext context, int classesToday, double pct, int held,
      String examValue, String examUnit, String gpaValue, String gpaUnit) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                icon: Icons.calendar_today_rounded,
                label: 'Today',
                value: '$classesToday',
                unit: classesToday == 1 ? 'Class' : 'Classes',
                bg: AppColors.lavenderTint,
                onTap: () => _push(context, const ScheduleScreen()),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                context,
                icon: Icons.pie_chart_rounded,
                label: 'Attendance',
                value: held == 0 ? '—' : '${pct.toStringAsFixed(0)}%',
                unit: held == 0 ? 'No data' : 'Overall',
                bg: AppColors.peachSoft,
                onTap: () => _push(context, const AttendanceScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _statCard(
                context,
                icon: Icons.event_note_rounded,
                label: 'Next exam',
                value: examValue,
                unit: examUnit,
                bg: AppColors.lavenderTint,
                onTap: () => _push(context, const ExamsScreen()),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: _statCard(
                context,
                icon: Icons.school_rounded,
                label: 'GPA',
                value: gpaValue,
                unit: gpaUnit,
                bg: AppColors.peachSoft,
                onTap: () => _push(context, const GradesScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required String unit,
    required Color bg,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final card = Container(
      height: 132,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 18, color: AppColors.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(label,
                    style: theme.textTheme.labelMedium
                        ?.copyWith(color: AppColors.ink),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const Spacer(),
          Text(value,
              style: theme.textTheme.displaySmall?.copyWith(
                color: AppColors.ink,
                fontWeight: FontWeight.w700,
                height: 1,
              )),
          const SizedBox(height: 2),
          Text(unit,
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.inkSoft)),
        ],
      ),
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: card,
      ),
    );
  }

  Widget _emptyTile(BuildContext context,
      {required IconData icon, required String text}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  Widget _taskCard(BuildContext context, WidgetRef ref, TaskItem t) {
    final theme = Theme.of(context);
    final due = t.dueDate;
    String? dueLabel;
    if (due != null) {
      final now = DateTime.now();
      if (DateUtilsX.isSameDay(due, now)) {
        dueLabel = 'Today';
      } else if (DateUtilsX.isSameDay(due, now.add(const Duration(days: 1)))) {
        dueLabel = 'Tomorrow';
      } else {
        dueLabel = DateUtilsX.prettyDate(due);
      }
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: softCard(context),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => ref.read(taskControllerProvider).toggle(t),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: t.done ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: t.done ? AppColors.primary : theme.dividerColor,
                  width: 2,
                ),
              ),
              child: t.done
                  ? const Icon(Icons.check_rounded,
                      size: 16, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => _push(context, const TasksScreen()),
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      decoration:
                          t.done ? TextDecoration.lineThrough : null,
                      color: t.done ? theme.hintColor : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(t.type.icon, size: 13, color: t.type.color),
                      const SizedBox(width: 6),
                      if (dueLabel != null)
                        Text(
                          dueLabel,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: t.isOverdue ? AppColors.danger : null,
                            fontWeight:
                                t.isOverdue ? FontWeight.w600 : null,
                          ),
                        )
                      else
                        Text('No due date', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 4,
            height: 34,
            decoration: BoxDecoration(
              color: t.priority.color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Today's classes" section that lets each class card fly off-screen when it
/// is marked present/absent (or when "Mark all present" is tapped).
class _TodayClasses extends ConsumerStatefulWidget {
  final DateTime today;
  const _TodayClasses({required this.today});

  @override
  ConsumerState<_TodayClasses> createState() => _TodayClassesState();
}

class _TodayClassesState extends ConsumerState<_TodayClasses> {
  /// Keys of classes that have finished their exit animation and are hidden
  /// for the remainder of this session.
  final Set<String> _dismissed = {};
  bool _exitingAll = false;

  String _keyOf(ScheduledClass c) => '${c.subject.id}-${c.session.startTime}';

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(classesForDayProvider(widget.today));
    final markedToday = ref.watch(todayStatusProvider);
    // Show only classes that are NOT yet marked for today. Because the mark is
    // persisted per-date, a handled class stays out of this list even after a
    // rebuild or tab switch (the previous bug where it "came back").
    final visible = all
        .where((c) =>
            !_dismissed.contains(_keyOf(c)) &&
            !markedToday.containsKey(
                attendanceOccurrenceKey(c.subject.id, c.session.startTime)))
        .toList();

    final cards = <Widget>[];
    for (final c in visible) {
      final key = _keyOf(c);
      cards.add(
        _ExitableClassCard(
          key: ValueKey(key),
          scheduled: c,
          exitAll: _exitingAll,
          onGone: () {
            if (!mounted) return;
            setState(() => _dismissed.add(key));
          },
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          title: "Today's classes",
          actionLabel: visible.isEmpty ? null : 'Mark all present',
          onAction: visible.isEmpty
              ? null
              : () {
                  final ctrl = ref.read(attendanceControllerProvider);
                  final now = DateTime.now();
                  for (final c in visible) {
                    ctrl.setForOccurrence(c.subject.id, now,
                        c.session.startTime, AttendanceStatus.present);
                  }
                  final n = visible.length;
                  setState(() => _exitingAll = true);
                  _snack('Marked all $n classes present ✓');
                },
        ),
        const SizedBox(height: 12),
        if (visible.isEmpty)
          _EmptyTile(
            icon: Icons.free_breakfast_rounded,
            text: markedToday.isEmpty
                ? 'No classes today. Enjoy your day!'
                : "All done — today's classes are marked ✓",
          )
        else
          ...cards,
      ],
    );
  }
}

/// A single "today" class card that animates out (slides right, fades, then
/// collapses its space) when marked, then notifies its parent via [onGone].
class _ExitableClassCard extends ConsumerStatefulWidget {
  final ScheduledClass scheduled;
  final bool exitAll;
  final VoidCallback onGone;

  const _ExitableClassCard({
    super.key,
    required this.scheduled,
    required this.exitAll,
    required this.onGone,
  });

  @override
  ConsumerState<_ExitableClassCard> createState() =>
      _ExitableClassCardState();
}

class _ExitableClassCardState extends ConsumerState<_ExitableClassCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 460),
  );
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(1.15, 0),
  ).animate(CurvedAnimation(
      parent: _ctrl, curve: const Interval(0.0, 0.7, curve: Curves.easeInCubic)));
  late final Animation<double> _fade = Tween<double>(begin: 1, end: 0)
      .animate(CurvedAnimation(parent: _ctrl, curve: const Interval(0.0, 0.6)));
  late final Animation<double> _size = Tween<double>(begin: 1, end: 0).animate(
      CurvedAnimation(
          parent: _ctrl, curve: const Interval(0.5, 1.0, curve: Curves.easeInOut)));

  bool _gone = false;

  @override
  void initState() {
    super.initState();
    if (widget.exitAll) _leave();
  }

  @override
  void didUpdateWidget(covariant _ExitableClassCard old) {
    super.didUpdateWidget(old);
    if (!old.exitAll && widget.exitAll) _leave();
  }

  void _leave() {
    if (_ctrl.isAnimating || _ctrl.isCompleted) return;
    _ctrl.forward().then((_) {
      if (mounted && !_gone) {
        _gone = true;
        widget.onGone();
      }
    });
  }

  void _mark(AttendanceStatus status) {
    final ctrl = ref.read(attendanceControllerProvider);
    final subject = widget.scheduled.subject;
    final messenger = ScaffoldMessenger.of(context);
    // The write is applied to the local cache synchronously, so dismissing the
    // card immediately is honest — the mark is durably saved on-device even
    // offline and will sync automatically. We still attach an error handler so
    // a genuine server rejection (e.g. permissions) surfaces instead of being
    // silently swallowed.
    ctrl
        .setForOccurrence(subject.id, DateTime.now(),
            widget.scheduled.session.startTime, status)
        .catchError((_) {
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(
        content: Text("Couldn't sync that mark — we'll retry automatically."),
      ));
    });
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1500),
      content: Text('${status.label} · ${subject.name}'),
    ));
    _leave();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      child: FadeTransition(
        opacity: _fade,
        child: SlideTransition(
          position: _slide,
          child: _card(context),
        ),
      ),
    );
  }

  Widget _card(BuildContext context) {
    final theme = Theme.of(context);
    final c = widget.scheduled;
    final color = Color(c.subject.colorHex);
    final hasRoom = c.session.room != null && c.session.room!.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            alignment: Alignment.center,
            child: Icon(SubjectIcons.resolve(c.subject.iconKey),
                color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.subject.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.schedule_rounded,
                        size: 13, color: theme.hintColor),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        '${DateUtilsX.displayTime(context, c.session.startTime)} – ${DateUtilsX.displayTime(context, c.session.endTime)}',
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasRoom) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text('· ${c.session.room}',
                            style: theme.textTheme.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          _miniAction(
            icon: Icons.check_rounded,
            color: AppColors.success,
            tooltip: 'Present',
            onTap: () => _mark(AttendanceStatus.present),
          ),
          const SizedBox(width: 6),
          _miniAction(
            icon: Icons.close_rounded,
            color: AppColors.danger,
            tooltip: 'Absent',
            onTap: () => _mark(AttendanceStatus.absent),
          ),
          const SizedBox(width: 6),
          _miniAction(
            icon: Icons.event_busy_rounded,
            color: AppColors.cancelled,
            tooltip: 'Cancelled',
            onTap: () => _mark(AttendanceStatus.cancelled),
          ),
            ],
          ),
          if (c.subject.classLink != null &&
              c.subject.classLink!.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => openUrl(context, c.subject.classLink),
                icon: const Icon(Icons.videocam_rounded, size: 18),
                label: const Text('Join class'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: AppColors.info,
                  side: const BorderSide(color: AppColors.info),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _miniAction({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: color.withValues(alpha: 0.14),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icon, size: 20, color: color),
          ),
        ),
      ),
    );
  }
}

/// Small informational tile used when there is nothing to show.
class _EmptyTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const _EmptyTile({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}



/// Horizontal quick-access row to the study tools (Grades, Focus, Exams,
/// Notes, Calendar).
class _StudyToolsRow extends ConsumerWidget {
  const _StudyToolsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    void go(Widget screen) => Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));

    final tools = <_Tool>[
      _Tool('Grades', Icons.school_rounded, AppColors.primary,
          () => go(const GradesScreen())),
      _Tool('Focus', Icons.timer_rounded, AppColors.success,
          () => go(const FocusScreen())),
      _Tool('Exams', Icons.event_note_rounded, AppColors.danger,
          () => go(const ExamsScreen())),
      _Tool('Notes', Icons.sticky_note_2_rounded, AppColors.info,
          () => go(const NotesScreen())),
      _Tool('Habits', Icons.local_fire_department_rounded, AppColors.coral,
          () => go(const HabitsScreen())),
      _Tool('Expenses', Icons.account_balance_wallet_rounded,
          AppColors.success, () => go(const ExpensesScreen())),
      _Tool('Calendar', Icons.calendar_month_rounded, AppColors.accent,
          () => go(const CalendarScreen())),
      _Tool('Moments', Icons.auto_awesome_motion_rounded, AppColors.coral,
          () => go(const MomentsScreen())),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Study tools', style: theme.textTheme.titleLarge),
        const SizedBox(height: 12),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: tools.length,
            physics: const BouncingScrollPhysics(),
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final t = tools[i];
              return GestureDetector(
                onTap: () {
                  ref.read(analyticsProvider).openFeature(t.label);
                  t.onTap();
                },
                child: Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: softCard(context),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: t.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(t.icon, color: t.color, size: 21),
                      ),
                      const SizedBox(height: 8),
                      Text(t.label,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Tool {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _Tool(this.label, this.icon, this.color, this.onTap);
}


/// "This week" insights: weekly attendance %, focus hours, best streak, pending.
class _WeeklyInsights extends ConsumerWidget {
  const _WeeklyInsights();

  static String _hm(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final week = ref.watch(weeklyAttendanceProvider);
    final study = ref.watch(studyStatsProvider);
    final streak = ref.watch(bestHabitStreakProvider);
    final pending = ref.watch(pendingTasksProvider).length;

    Widget stat(IconData icon, String value, String label, Color color) {
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800)),
            ),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 11)),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('This week',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              stat(
                  Icons.pie_chart_rounded,
                  week.held == 0 ? '—' : '${week.percent.toStringAsFixed(0)}%',
                  'Attendance',
                  AppColors.primary),
              stat(Icons.timer_rounded, _hm(study.weekMinutes), 'Focus',
                  AppColors.success),
              stat(Icons.local_fire_department_rounded, '${streak}d', 'Streak',
                  AppColors.coral),
              stat(Icons.check_circle_outline_rounded, '$pending', 'To-do',
                  AppColors.info),
            ],
          ),
        ],
      ),
    );
  }
}
