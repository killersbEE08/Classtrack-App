import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/subject_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/url_launcher_util.dart';
import '../../../../services/reminder_scheduler.dart';
import '../../../../services/analytics_service.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../attendance/presentation/screens/attendance_screen.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../auth/presentation/screens/edit_profile_screen.dart';
import '../../../calendar/presentation/screens/calendar_screen.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../exams/presentation/screens/exams_screen.dart';
import '../../../expenses/presentation/screens/expenses_screen.dart';
import '../../../focus/presentation/screens/focus_screen.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../grades/presentation/screens/grades_screen.dart';
import '../../../habits/presentation/screens/habits_screen.dart';
import '../../../moments/presentation/screens/moments_screen.dart';
import '../../../notes/presentation/screens/notes_screen.dart';
import '../../../opportunities/presentation/providers/opportunities_providers.dart';
import '../../../opportunities/presentation/screens/discounts_screen.dart';
import '../../../opportunities/presentation/screens/opportunities_screen.dart';
import '../../../opportunities/presentation/screens/resource_detail_screen.dart';
import '../../../opportunities/presentation/widgets/resource_card.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../schedule/presentation/screens/schedule_screen.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../widgets/home_banner.dart';

/// Home dashboard. Answers "what matters to me today?" with a concise overview
/// strip, today's timeline, three focused cards (attendance / next exam /
/// today's focus), a personalised opportunities slot and quick tools.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final firstName = profile?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            _Header(firstName: firstName)
                .animate()
                .fadeIn(duration: 350.ms),
            const SizedBox(height: 20),
            const _TodayOverview().animate().fadeIn(duration: 350.ms).slideY(
                begin: 0.06, curve: Curves.easeOut),
            const SizedBox(height: 22),
            const HomeBanner(),
            SectionHeader(
              title: "Today's timeline",
              actionLabel: 'View full day',
              onAction: () => _push(context, const ScheduleScreen()),
            ),
            const SizedBox(height: 12),
            const _TodayTimeline(),
            const SizedBox(height: 22),
            const _FocusCardsRow(),
            const SizedBox(height: 22),
            const RemindersBanner(),
            const _RecommendedForYou(),
            const SizedBox(height: 24),
            const _QuickTools(),
          ],
        ),
      ),
    );
  }
}

/// Greeting header: avatar → Settings, greeting + subtitle, notifications bell,
/// AI assistant button.
class _Header extends StatelessWidget {
  final String firstName;
  const _Header({required this.firstName});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                        Text('$_greeting, $firstName 👋',
                            style: theme.textTheme.titleMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text("Let's make today productive.",
                            style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.notifications_none_rounded,
          onTap: () => _showNotifications(context),
        ),
        const SizedBox(width: 8),
        RoundIconButton(
          icon: Icons.auto_awesome_rounded,
          background: AppColors.primary,
          iconColor: Colors.white,
          onTap: () => _push(context, const ChatScreen()),
        ),
      ],
    );
  }

  void _showNotifications(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 42, color: theme.hintColor),
                const SizedBox(height: 12),
                Text('No new notifications', style: theme.textTheme.titleMedium),
                const SizedBox(height: 6),
                Text(
                  "We'll let you know about class reminders, deadlines and "
                  'matched opportunities here.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Concise "Today's overview" strip: classes, tasks due, attendance, next exam,
/// GPA. Horizontally scrollable so it never overflows on small screens.
class _TodayOverview extends ConsumerWidget {
  const _TodayOverview();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classes = ref.watch(classesForDayProvider(today));
    final pending = ref.watch(pendingTasksProvider);
    final overall = ref.watch(overallStatsProvider);
    final nextExam = ref.watch(nextExamProvider);
    final gpa = ref.watch(gpaSummaryProvider);
    final atRisk = ref.watch(_atRiskSubjectProvider);

    // Next class start time (first class listed today).
    final String? nextClassLabel = classes.isEmpty
        ? null
        : 'Next: ${DateUtilsX.displayTime(context, classes.first.session.startTime)}';

    final dueToday = pending
        .where((t) =>
            t.dueDate != null &&
            (DateUtilsX.isSameDay(t.dueDate!, now) || t.isOverdue))
        .length;

    final items = <Widget>[
      _OverviewItem(
        icon: Icons.menu_book_rounded,
        color: AppColors.primary,
        value: '${classes.length}',
        title: classes.length == 1 ? 'Class today' : 'Classes today',
        subtitle: nextClassLabel ?? 'None left',
      ),
      _OverviewItem(
        icon: Icons.check_circle_outline_rounded,
        color: AppColors.success,
        value: '$dueToday',
        title: dueToday == 1 ? 'Task due' : 'Tasks due',
        subtitle: dueToday == 0 ? 'All clear' : 'Due today',
      ),
      _OverviewItem(
        icon: atRisk != null
            ? Icons.warning_amber_rounded
            : Icons.pie_chart_rounded,
        color: atRisk != null ? AppColors.warning : AppColors.success,
        value: overall.held == 0 ? '—' : '${overall.percent.toStringAsFixed(0)}%',
        title: atRisk != null ? 'At risk' : 'Attendance',
        subtitle: atRisk != null ? atRisk.name : 'On track',
      ),
      _OverviewItem(
        icon: Icons.event_note_rounded,
        color: AppColors.info,
        value: nextExam == null
            ? '—'
            : (nextExam.daysUntil <= 0 ? 'Today' : '${nextExam.daysUntil}d'),
        title: nextExam == null ? 'No exam' : 'Next exam',
        subtitle: nextExam?.title ?? 'Nothing soon',
      ),
      _OverviewItem(
        icon: Icons.school_rounded,
        color: AppColors.coral,
        value: gpa.gradedSubjects == 0 ? '—' : gpa.gpa.toStringAsFixed(2),
        title: 'GPA',
        subtitle: gpa.gradedSubjects == 0 ? 'No grades' : 'This term',
      ),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text("Today's overview",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChatScreen())),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome_rounded,
                          size: 14, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text('AI summary',
                          style: theme.textTheme.labelMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++) ...[
                  if (i != 0)
                    Container(
                      width: 1,
                      height: 58,
                      margin: const EdgeInsets.symmetric(horizontal: 14),
                      color: theme.dividerColor.withValues(alpha: 0.4),
                    ),
                  items[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OverviewItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String title;
  final String subtitle;
  const _OverviewItem({
    required this.icon,
    required this.color,
    required this.value,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 92,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              maxLines: 1,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800)),
          Text(title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
          Text(subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 11, color: theme.hintColor)),
        ],
      ),
    );
  }
}

/// The subject furthest below its effective attendance target (or null when
/// none is at risk). Powers the "At risk" indicators on Home.
final _atRiskSubjectProvider = Provider<_AtRisk?>((ref) {
  final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
  final profile = ref.watch(userProfileProvider).valueOrNull;
  final fallback = profile?.targetAttendancePercent ?? 75.0;
  _AtRisk? worst;
  for (final s in subjects) {
    if (s.held == 0) continue;
    final t = s.effectiveTarget(fallback);
    if (s.percent < t) {
      final shortfall = t - s.percent;
      if (worst == null || shortfall > worst.shortfall) {
        worst = _AtRisk(s.name, s.percent, shortfall);
      }
    }
  }
  return worst;
});

class _AtRisk {
  final String name;
  final double percent;
  final double shortfall;
  const _AtRisk(this.name, this.percent, this.shortfall);
}

/// Today's timeline: every class today with a time gutter, a "Now" badge for
/// the class in progress, and quick present/absent/cancelled marking for
/// classes that haven't been marked yet. ~15% taller rows than the old cards.
class _TodayTimeline extends ConsumerWidget {
  const _TodayTimeline();

  static int _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length < 2) return 0;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classes = ref.watch(classesForDayProvider(today));
    final markedToday = ref.watch(todayStatusProvider);

    if (classes.isEmpty) {
      return _EmptyTile(
        icon: Icons.free_breakfast_rounded,
        text: markedToday.isEmpty
            ? 'No classes today. Enjoy your day!'
            : "You're all set — today's classes are marked ✓",
      );
    }

    final nowMinutes = now.hour * 60 + now.minute;
    return Column(
      children: [
        for (final c in classes)
          _TimelineRow(
            scheduled: c,
            isNow: nowMinutes >= _minutes(c.session.startTime) &&
                nowMinutes < _minutes(c.session.endTime),
            status: markedToday[
                attendanceOccurrenceKey(c.subject.id, c.session.startTime)],
          ),
      ],
    );
  }
}

class _TimelineRow extends ConsumerWidget {
  final ScheduledClass scheduled;
  final bool isNow;
  final AttendanceStatus? status;
  const _TimelineRow({
    required this.scheduled,
    required this.isNow,
    required this.status,
  });

  void _mark(BuildContext context, WidgetRef ref, AttendanceStatus s) {
    final c = scheduled;
    final messenger = ScaffoldMessenger.of(context);
    ref.read(attendanceControllerProvider).setForOccurrence(
        c.subject.id, DateTime.now(), c.session.startTime, s);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(milliseconds: 1400),
      content: Text('${s.label} · ${c.subject.name}'),
    ));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = scheduled;
    final color = Color(c.subject.colorHex);
    final hasRoom = c.session.room != null && c.session.room!.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: softCard(context),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time gutter
              SizedBox(
                width: 62,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      DateUtilsX.displayTime(context, c.session.startTime),
                      style: theme.textTheme.labelMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '– ${DateUtilsX.displayTime(context, c.session.endTime)}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontSize: 11, color: theme.hintColor),
                    ),
                  ],
                ),
              ),
              // Timeline dot
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(SubjectIcons.resolve(c.subject.iconKey),
                    color: color, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.subject.name,
                        style: theme.textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    if (hasRoom) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined,
                              size: 13, color: theme.hintColor),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text('${c.session.room}',
                                style: theme.textTheme.bodySmall,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _trailing(theme),
            ],
          ),
          if (status == null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                _markButton(context, ref, Icons.check_rounded,
                    AppColors.success, 'Present', AttendanceStatus.present),
                const SizedBox(width: 8),
                _markButton(context, ref, Icons.close_rounded, AppColors.danger,
                    'Absent', AttendanceStatus.absent),
                const SizedBox(width: 8),
                _markButton(context, ref, Icons.event_busy_rounded,
                    AppColors.cancelled, 'Cancelled', AttendanceStatus.cancelled),
              ],
            ),
          ],
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

  Widget _trailing(ThemeData theme) {
    if (isNow) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Text('Now',
            style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700)),
      );
    }
    if (status != null) {
      final (label, color) = switch (status!) {
        AttendanceStatus.present => ('Present', AppColors.success),
        AttendanceStatus.absent => ('Absent', AppColors.danger),
        AttendanceStatus.cancelled => ('Cancelled', AppColors.cancelled),
        AttendanceStatus.unmarked => ('', theme.hintColor),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _markButton(BuildContext context, WidgetRef ref, IconData icon,
      Color color, String label, AttendanceStatus s) {
    return Expanded(
      child: Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _mark(context, ref, s),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 5),
                Text(label,
                    style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The three focused cards: Attendance (ring), Next exam (countdown) and
/// Today's focus (priorities). Replaces the old Study Streak card.
class _FocusCardsRow extends ConsumerWidget {
  const _FocusCardsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _AttendanceCard()),
          SizedBox(width: 12),
          Expanded(child: _NextExamCard()),
          SizedBox(width: 12),
          Expanded(child: _TodayFocusCard()),
        ],
      ),
    );
  }
}

class _AttendanceCard extends ConsumerWidget {
  const _AttendanceCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final overall = ref.watch(overallStatsProvider);
    final atRisk = ref.watch(_atRiskSubjectProvider);
    final pct = overall.held == 0 ? 0.0 : overall.percent;

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AttendanceScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Attendance', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            Center(
              child: AnimatedProgressRing(
                percent: pct,
                size: 82,
                strokeWidth: 8,
                centerLabel: overall.held == 0 ? '—' : '${pct.toStringAsFixed(0)}%',
                subLabel: 'Overall',
              ),
            ),
            const SizedBox(height: 12),
            if (overall.held == 0)
              Text('No data yet',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor))
            else if (atRisk != null)
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 14, color: AppColors.danger),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('At risk: ${atRisk.name}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              )
            else
              Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      size: 14, color: AppColors.success),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('On track',
                        style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _NextExamCard extends ConsumerWidget {
  const _NextExamCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final exam = ref.watch(nextExamProvider);

    return GestureDetector(
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const ExamsScreen())),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softCard(context),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Next exam', style: theme.textTheme.labelLarge),
            const SizedBox(height: 12),
            if (exam == null) ...[
              Text('—',
                  style: theme.textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text('No exams scheduled',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
            ] else ...[
              Text(exam.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(exam.countdownLabel,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.hintColor)),
              const SizedBox(height: 10),
              _Countdown(date: exam.date),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_rounded,
                      size: 12, color: theme.hintColor),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(DateUtilsX.prettyDate(exam.date),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A compact days/hours/mins countdown to [date].
class _Countdown extends StatelessWidget {
  final DateTime date;
  const _Countdown({required this.date});

  @override
  Widget build(BuildContext context) {
    final diff = date.difference(DateTime.now());
    final total = diff.isNegative ? Duration.zero : diff;
    final days = total.inDays;
    final hours = total.inHours % 24;
    final mins = total.inMinutes % 60;

    Widget unit(String v, String label) {
      final theme = Theme.of(context);
      return Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 7),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(v.padLeft(2, '0'),
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 3),
          Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(fontSize: 10, color: theme.hintColor)),
        ],
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        unit('$days', 'Days'),
        unit('$hours', 'Hrs'),
        unit('$mins', 'Min'),
      ],
    );
  }
}

/// "Today's focus" — up to three prioritised academic actions derived from
/// at-risk attendance, the next exam and pending tasks. (AI-generated focus can
/// slot in here in a later phase.)
class _TodayFocusCard extends ConsumerWidget {
  const _TodayFocusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final atRisk = ref.watch(_atRiskSubjectProvider);
    final exam = ref.watch(nextExamProvider);
    final pending = ref.watch(pendingTasksProvider);

    final priorities = <(String, Color)>[];
    if (atRisk != null) {
      priorities.add(('Boost attendance in ${atRisk.name}', AppColors.danger));
    }
    if (exam != null && exam.daysUntil <= 14) {
      priorities.add(('Prepare for ${exam.title}', AppColors.info));
    }
    for (final TaskItem t in pending.take(3)) {
      if (priorities.length >= 3) break;
      priorities.add(('Complete ${t.title}', AppColors.primary));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('Today\'s focus',
                      style: theme.textTheme.labelLarge)),
              Text('${priorities.length}',
                  style: theme.textTheme.titleMedium?.copyWith(
                      color: AppColors.primary, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          if (priorities.isEmpty)
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text("You're all set 🎉",
                      style: theme.textTheme.bodySmall),
                ),
              ],
            )
          else
            for (final (label, color) in priorities)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(top: 5, right: 8),
                      decoration:
                          BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                    Expanded(
                      child: Text(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall),
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

/// Personalised opportunities slot. Until the Opportunities backend lands
/// (Phase 3) this nudges the student to complete their profile / explore the
/// new tab, rather than showing a fabricated listing.
class _RecommendedForYou extends ConsumerWidget {
  const _RecommendedForYou();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(userProfileProvider).valueOrNull;
    final hasDetails = profile?.hasAnyProfileDetails ?? false;
    final feed = ref.watch(opportunitiesFeedProvider);
    final top = feed.isNotEmpty ? feed.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        SectionHeader(
          title: 'Recommended for you',
          actionLabel: 'View all',
          onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const OpportunitiesScreen())),
        ),
        const SizedBox(height: 12),
        if (top != null)
          ResourceCard(
            resource: top,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ResourceDetailScreen(resource: top))),
          )
        else
          GestureDetector(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => hasDetails
                    ? const OpportunitiesScreen()
                    : const EditProfileScreen())),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: softCard(context),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                        hasDetails
                            ? Icons.workspace_premium_rounded
                            : Icons.person_add_alt_1_rounded,
                        color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            hasDetails
                                ? 'Personalised opportunities'
                                : 'Get matched opportunities',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          hasDetails
                              ? 'Scholarships, internships & deals picked for you — coming soon.'
                              : 'Add your country, degree & interests to unlock personalised matches.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.hintColor),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Quick tools — every study tool one tap away, including Tasks (moved here
/// from the bottom navigation).
class _QuickTools extends ConsumerWidget {
  const _QuickTools();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    void go(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    final tools = <_Tool>[
      _Tool('Tasks', Icons.check_circle_outline_rounded, AppColors.success,
          () => go(const TasksScreen())),
      _Tool('Discounts', Icons.local_offer_rounded, AppColors.success,
          () => go(const DiscountsScreen())),
      _Tool('Grades', Icons.school_rounded, AppColors.primary,
          () => go(const GradesScreen())),
      _Tool('Exams', Icons.event_note_rounded, AppColors.danger,
          () => go(const ExamsScreen())),
      _Tool('Notes', Icons.sticky_note_2_rounded, AppColors.info,
          () => go(const NotesScreen())),
      _Tool('Expenses', Icons.account_balance_wallet_rounded, AppColors.success,
          () => go(const ExpensesScreen())),
      _Tool('Habits', Icons.local_fire_department_rounded, AppColors.coral,
          () => go(const HabitsScreen())),
      _Tool('Focus', Icons.timer_rounded, AppColors.success,
          () => go(const FocusScreen())),
      _Tool('Calendar', Icons.calendar_month_rounded, AppColors.accent,
          () => go(const CalendarScreen())),
      _Tool('Moments', Icons.auto_awesome_motion_rounded, AppColors.coral,
          () => go(const MomentsScreen())),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick tools', style: theme.textTheme.titleLarge),
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
