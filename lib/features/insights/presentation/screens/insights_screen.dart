import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../expenses/domain/expense.dart';
import '../../../expenses/presentation/providers/expense_providers.dart';
import '../../../focus/presentation/providers/study_providers.dart';
import '../../../grades/presentation/providers/grade_providers.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../domain/insight_math.dart';

/// Pro-only analytics: attendance projections, safe-skips, budget forecast,
/// GPA and study trends — all derived from the user's existing data.
class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final target = ref.watch(userProfileProvider).valueOrNull?.targetAttendancePercent ??
        AppConstants.defaultTargetAttendance;

    return Scaffold(
      appBar: AppBar(title: const Text('Insights & predictions')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          _attendanceCard(context, ref, theme, target),
          const SizedBox(height: 14),
          _budgetCard(context, ref, theme),
          const SizedBox(height: 14),
          _gradeCard(context, ref, theme),
          const SizedBox(height: 14),
          _studyCard(context, ref, theme),
        ],
      ),
    );
  }

  Widget _card(ThemeData theme, {required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: theme.brightness == Brightness.light
              ? AppColors.softShadow(opacity: 0.05, blur: 16)
              : null,
        ),
        child: child,
      );

  Widget _header(ThemeData theme, IconData icon, String title) => Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 8),
          Text(title,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      );

  Widget _attendanceCard(
      BuildContext context, WidgetRef ref, ThemeData theme, double target) {
    final overall = ref.watch(overallStatsProvider);
    final advice = attendanceAdvice(
        attended: overall.present, held: overall.held, target: target);
    final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];

    String headline;
    Color color;
    if (overall.held == 0) {
      headline = 'Mark some classes to see projections.';
      color = theme.hintColor;
    } else if (advice.unreachable) {
      headline = 'Target of ${target.toStringAsFixed(0)}% needs every '
          'remaining class — no more misses.';
      color = AppColors.danger;
    } else if (advice.onTrack) {
      headline = advice.canSkip > 0
          ? 'You can skip ${advice.canSkip} more class'
              '${advice.canSkip == 1 ? '' : 'es'} and stay above '
              '${target.toStringAsFixed(0)}%.'
          : 'You\'re right at your ${target.toStringAsFixed(0)}% target — don\'t miss any.';
      color = AppColors.success;
    } else {
      headline = 'Attend the next ${advice.mustAttend} class'
          '${advice.mustAttend == 1 ? '' : 'es'} to reach '
          '${target.toStringAsFixed(0)}%.';
      color = AppColors.warning;
    }

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, Icons.insights_rounded, 'Attendance projection'),
          const SizedBox(height: 12),
          Row(
            children: [
              Text('${advice.percent.toStringAsFixed(0)}%',
                  style: theme.textTheme.displaySmall
                      ?.copyWith(fontWeight: FontWeight.w800, color: color)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(headline,
                    style: theme.textTheme.bodyMedium?.copyWith(color: color)),
              ),
            ],
          ),
          if (subjects.isNotEmpty) ...[
            const Divider(height: 24),
            Text('By subject',
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: theme.hintColor)),
            const SizedBox(height: 6),
            ...subjects.take(12).map((s) {
              final stats = ref.watch(subjectStatsProvider(s.id));
              final a = attendanceAdvice(
                  attended: stats.present, held: stats.held, target: target);
              final subColor = stats.held == 0
                  ? theme.hintColor
                  : (a.onTrack ? AppColors.success : AppColors.danger);
              final trailing = stats.held == 0
                  ? 'no data'
                  : a.onTrack
                      ? (a.canSkip > 0 ? 'skip ${a.canSkip}' : 'at limit')
                      : 'attend ${a.mustAttend}';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text(s.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${a.percent.toStringAsFixed(0)}%  ·  ',
                        style: theme.textTheme.bodySmall),
                    Text(trailing,
                        style: theme.textTheme.labelMedium
                            ?.copyWith(color: subColor, fontWeight: FontWeight.w700)),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _budgetCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final currency = ref.watch(currencySymbolProvider);
    final spent = ref.watch(monthlyTotalProvider);
    final budget = ref.watch(monthlyBudgetProvider);
    final breakdown = ref.watch(categoryBreakdownProvider);
    final projected =
        projectedMonthlySpend(spentSoFar: spent, now: DateTime.now());

    final overBudget = budget > 0 && projected > budget;
    final topCat = breakdown.isNotEmpty ? breakdown.first : null;

    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, Icons.trending_up_rounded, 'Spending forecast'),
          const SizedBox(height: 12),
          Text('$currency${spent.toStringAsFixed(0)} spent so far this month',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text(
            'Projected month-end: $currency${projected.toStringAsFixed(0)}'
            '${budget > 0 ? ' of $currency${budget.toStringAsFixed(0)} budget' : ''}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: overBudget ? AppColors.danger : AppColors.success,
            ),
          ),
          if (overBudget)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'On track to exceed budget by '
                '$currency${(projected - budget).toStringAsFixed(0)}.',
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: AppColors.danger),
              ),
            ),
          if (topCat != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Biggest category: ${topCat.key.label} '
                '($currency${topCat.value.toStringAsFixed(0)}).',
                style: theme.textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }

  Widget _gradeCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final gpa = ref.watch(gpaSummaryProvider);
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, Icons.school_rounded, 'Grades'),
          const SizedBox(height: 12),
          if (gpa.gradedSubjects == 0)
            Text('Add some grades to see your GPA and averages.',
                style: theme.textTheme.bodyMedium)
          else
            Text(
              'GPA ${gpa.gpa.toStringAsFixed(2)} / ${gpa.maxPoints.toStringAsFixed(0)} '
              '· average ${gpa.averagePercent.toStringAsFixed(0)}% '
              'across ${gpa.gradedSubjects} subject${gpa.gradedSubjects == 1 ? '' : 's'}.',
              style: theme.textTheme.bodyMedium,
            ),
        ],
      ),
    );
  }

  Widget _studyCard(BuildContext context, WidgetRef ref, ThemeData theme) {
    final study = ref.watch(studyStatsProvider);
    final h = study.weekMinutes ~/ 60;
    final m = study.weekMinutes % 60;
    return _card(
      theme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme, Icons.timer_rounded, 'Study focus'),
          const SizedBox(height: 12),
          Text(
            '${h > 0 ? '${h}h ' : ''}${m}m focused this week · '
            '${study.streakDays}-day streak.',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
