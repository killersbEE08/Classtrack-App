import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/states.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../schedule/presentation/providers/schedule_providers.dart';
import '../../../subjects/domain/subject.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../subjects/presentation/screens/edit_subject_screen.dart';
import '../../../subjects/presentation/screens/subject_detail_screen.dart';
import '../../domain/attendance_record.dart';
import '../providers/attendance_providers.dart';

/// Clean, refined subject-wise attendance. Color is used purposefully — the
/// status ring and a few small indicators — over a calm, mostly-neutral canvas.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  void _addSubject(BuildContext context) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const EditSubjectScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subjectsAsync = ref.watch(subjectsStreamProvider);
    final overall = ref.watch(overallStatsProvider);
    final target =
        ref.watch(userProfileProvider).valueOrNull?.targetAttendancePercent ??
            AppConstants.defaultTargetAttendance;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                if (canPop) ...[
                  RoundIconButton(
                    icon: Icons.arrow_back_rounded,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attendance',
                          style: theme.textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      Text('Stay above ${target.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
                _AddButton(onTap: () => _addSubject(context)),
              ],
            ),
            const SizedBox(height: 20),
            _OverallCard(overall: overall, target: target)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: 0.06, curve: Curves.easeOut),
            const SizedBox(height: 24),
            Row(
              children: [
                Text('Subjects', style: theme.textTheme.titleLarge),
                const Spacer(),
                if (subjectsAsync.valueOrNull?.isNotEmpty ?? false)
                  Text('${subjectsAsync.value!.length}',
                      style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            subjectsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.only(top: 40), child: LoadingView()),
              error: (e, _) => ErrorView(error: e),
              data: (subjects) {
                if (subjects.isEmpty) return _emptyState(context, theme);
                return Column(
                  children: [
                    for (var i = 0; i < subjects.length; i++)
                      _SubjectCard(subject: subjects[i], target: target)
                          .animate()
                          .fadeIn(delay: (i * 55).ms, duration: 300.ms)
                          .slideY(begin: 0.08, curve: Curves.easeOutCubic),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyState(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: softCard(context),
      child: Column(
        children: [
          const Icon(Icons.donut_large_rounded,
              size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          Text('No subjects yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Add subjects to start tracking attendance.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _addSubject(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('Add subject'),
          ),
        ],
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const SizedBox(
          width: 46,
          height: 46,
          child: Icon(Icons.add_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

/// Status color helper shared by the cards.
Color _statusColor(double percent, double target, {bool hasData = true}) {
  if (!hasData) return AppColors.unmarked;
  if (percent >= target) return AppColors.success;
  if (percent >= target - 15) return AppColors.warning;
  return AppColors.danger;
}

/// Calm overall summary: one status ring + four neutral stat columns.
class _OverallCard extends StatelessWidget {
  final AttendanceStats overall;
  final double target;
  const _OverallCard({required this.overall, required this.target});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = overall.present + overall.absent + overall.cancelled;
    final hasData = overall.held > 0;
    final color = _statusColor(overall.percent, target, hasData: hasData);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Overall attendance',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const Spacer(),
              _statusPill(theme, color, hasData),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              AnimatedProgressRing(
                percent: overall.percent,
                size: 104,
                strokeWidth: 8,
                color: color,
                subLabel: 'overall',
                centerLabel: hasData ? null : '—',
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                            child: _stat(theme, 'Present', overall.present,
                                AppColors.success)),
                        Expanded(
                            child: _stat(theme, 'Absent', overall.absent,
                                AppColors.danger)),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: _stat(theme, 'Cancelled', overall.cancelled,
                                AppColors.cancelled)),
                        Expanded(
                            child: _stat(theme, 'Total', total, theme.hintColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(ThemeData theme, Color color, bool hasData) {
    final String label;
    if (!hasData) {
      label = 'No data';
    } else if (overall.percent >= target) {
      final skip = overall.bunkableClasses(target);
      label = skip > 0 ? 'Can skip $skip' : 'On target';
    } else {
      final need = overall.classesToRecover(target);
      label = need > 0 ? 'Attend $need more' : 'Below target';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }

  Widget _stat(ThemeData theme, String label, int value, Color dot) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$value',
            style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(height: 3),
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ],
    );
  }
}

class _SubjectCard extends ConsumerWidget {
  final Subject subject;
  final double target;
  const _SubjectCard({required this.subject, required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = ref.watch(subjectStatsProvider(subject.id));
    final controller = ref.read(attendanceControllerProvider);
    final subjectColor = Color(subject.colorHex);
    final hasData = stats.held > 0;
    final color = _statusColor(stats.percent, target, hasData: hasData);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: softCard(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row.
          InkWell(
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SubjectDetailScreen(subjectId: subject.id))),
            borderRadius: BorderRadius.circular(12),
            child: Row(
              children: [
                AnimatedProgressRing(
                  percent: stats.percent,
                  size: 56,
                  strokeWidth: 6,
                  color: color,
                  centerLabel: hasData ? null : '—',
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                                color: subjectColor, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: Text(subject.name,
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasData
                            ? '${stats.present}/${stats.held} attended'
                            : 'No classes marked yet',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _statusPill(theme, stats, color),
                Icon(Icons.chevron_right_rounded,
                    size: 20, color: theme.hintColor),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (subject.hasTerm) ...[
            _termTimeline(context, ref, theme),
            const SizedBox(height: 12),
          ],
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 10),
          // Actions: quiet circular buttons.
          Row(
            children: [
              _circleBtn(context, Icons.check_rounded, AppColors.success,
                  'Present',
                  () => _mark(context, ref, controller,
                      AttendanceStatus.present, 'Present')),
              const SizedBox(width: 8),
              _circleBtn(context, Icons.close_rounded, AppColors.danger,
                  'Absent',
                  () => _mark(context, ref, controller,
                      AttendanceStatus.absent, 'Absent')),
              const SizedBox(width: 8),
              _circleBtn(context, Icons.event_busy_rounded,
                  AppColors.cancelled, 'Cancel',
                  () => _mark(context, ref, controller,
                      AttendanceStatus.cancelled, 'Cancelled')),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _editDialog(context, ref),
                icon: const Icon(Icons.tune_rounded, size: 16),
                label: const Text('Adjust'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.hintColor,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusPill(ThemeData theme, AttendanceStats stats, Color color) {
    if (stats.held == 0) return const SizedBox.shrink();
    final onTrack = stats.percent >= target;
    final skip = stats.bunkableClasses(target);
    final need = stats.classesToRecover(target);
    final label = onTrack
        ? (skip > 0 ? 'skip $skip' : 'on track')
        : (need > 0 ? 'attend $need' : 'low');
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11.5, fontWeight: FontWeight.w700)),
    );
  }

  Widget _circleBtn(BuildContext context, IconData icon, Color color,
      String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
              width: 42, height: 42, child: Icon(icon, size: 20, color: color)),
        ),
      ),
    );
  }

  Widget _termTimeline(BuildContext context, WidgetRef ref, ThemeData theme) {
    final week = subject.weekOfTerm;
    final total = subject.weeksTotal;
    final daysLeft = subject.daysUntilEnd;
    final progress = subject.termProgress ?? 0;
    final count = ref.watch(termScheduledCountProvider(subject.id));
    final weekLabel = (week == null || total == null)
        ? ''
        : (week == 0 ? 'Not started' : 'Week $week/$total');
    final daysLabel = daysLeft == null
        ? ''
        : daysLeft < 0
            ? 'ended'
            : daysLeft == 0
                ? 'ends today'
                : '$daysLeft days left';
    final text = [weekLabel, daysLabel].where((s) => s.isNotEmpty).join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_month_rounded,
                size: 13, color: theme.hintColor),
            const SizedBox(width: 6),
            Expanded(
              child: Text(text,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            if (count > 0)
              Text('~$count classes',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: progress.toDouble(),
            minHeight: 5,
            backgroundColor: theme.dividerColor.withValues(alpha: 0.5),
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ],
    );
  }

  void _mark(BuildContext context, WidgetRef ref,
      AttendanceController controller, AttendanceStatus status, String verb) {
    // Per-session marking: target the next unmarked class for the subject
    // today. With one class today a single tap marks it; with two classes a
    // second tap marks the second — so you get exactly one attendance per
    // class. It's idempotent, so marking the same class again (or from Home)
    // never double-counts. Use "Adjust" to override totals directly.
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final todayId = DateUtilsX.dateId(today);
    final slots = ref
        .read(classesForDayProvider(today))
        .where((c) => c.subject.id == subject.id)
        .map((c) => c.session.startTime)
        .toList()
      ..sort();
    final records =
        ref.read(attendanceForSubjectProvider(subject.id)).valueOrNull ??
            const <AttendanceRecord>[];
    final markedSlots = <String>{
      for (final r in records)
        if (r.dateId == todayId) r.slot,
    };
    final slot = nextAttendanceSlot(slots, markedSlots);
    controller.setForOccurrence(subject.id, now, slot, status);
    ScaffoldMessenger.of(context)
      ..removeCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$verb today · ${subject.name}'),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(milliseconds: 1100),
      ));
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete subject?'),
        content: Text(
            'This permanently removes "${subject.name}", its schedule and attendance history. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(subjectRepositoryProvider)?.delete(subject.id);
    if (context.mounted) _snack(context, 'Deleted ${subject.name}');
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref) async {
    final presentC = TextEditingController(text: '${subject.attended}');
    final absentC = TextEditingController(text: '${subject.absent}');
    final cancelledC = TextEditingController(text: '${subject.cancelled}');
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          int val(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
          final total = val(presentC) + val(absentC) + val(cancelledC);
          final theme = Theme.of(ctx);
          return AlertDialog(
            title: Text(subject.name),
            // Scrollable so it never overflows when the keyboard is open.
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Set each count directly. Nothing is marked absent '
                    'automatically — only what you enter counts.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 14),
                  _numField(presentC, 'Present', Icons.check_rounded,
                      AppColors.success, () => setState(() {})),
                  const SizedBox(height: 10),
                  _numField(absentC, 'Absent', Icons.close_rounded,
                      AppColors.danger, () => setState(() {})),
                  const SizedBox(height: 10),
                  _numField(cancelledC, 'Cancelled', Icons.event_busy_rounded,
                      AppColors.cancelled, () => setState(() {})),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Total classes: $total',
                        style: theme.textTheme.bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await _confirmDelete(context, ref);
                },
                child: const Text('Delete',
                    style: TextStyle(color: AppColors.danger)),
              ),
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel')),
              FilledButton(
                onPressed: () {
                  ref.read(attendanceControllerProvider).setCounts(
                        subject.id,
                        val(presentC),
                        val(absentC),
                        cancelled: val(cancelledC),
                      );
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _numField(TextEditingController controller, String label,
      IconData icon, Color color, VoidCallback onChanged) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      onChanged: (_) => onChanged(),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        prefixIcon: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
