import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classtrack/core/theme/app_icons.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/states.dart';
import '../../../auth/presentation/providers/auth_providers.dart';
import '../../../subjects/domain/subject.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../providers/attendance_providers.dart';

class AttendanceScreen extends ConsumerWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subjectsAsync = ref.watch(subjectsStreamProvider);
    final target =
        ref.watch(userProfileProvider).valueOrNull?.targetAttendancePercent ??
            AppConstants.defaultTargetAttendance;
    final overall = ref.watch(overallStatsProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance')),
      body: subjectsAsync.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(error: e),
        data: (subjects) {
          if (subjects.isEmpty) {
            return EmptyState(
              icon: PhosphorIcons.chartPieSlice(),
              title: 'No subjects yet',
              message:
                  'Add subjects first, then track how many classes you attend for each.',
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              _overallCard(theme, overall, target),
              const SizedBox(height: 16),
              Text('By subject', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ...subjects.map((s) => _SubjectAttendanceCard(subject: s, target: target)),
            ],
          );
        },
      ),
    );
  }

  Widget _overallCard(ThemeData theme, overall, double target) {
    final pct = overall.percent;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryLight],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Overall attendance',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                overall.held == 0
                    ? 'No classes logged yet'
                    : '${overall.present} attended of ${overall.held}',
                style:
                    theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
            ],
          ),
          const Spacer(),
          Text(
            overall.held == 0 ? '—' : '${pct.toStringAsFixed(0)}%',
            style: theme.textTheme.displaySmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SubjectAttendanceCard extends ConsumerWidget {
  final Subject subject;
  final double target;
  const _SubjectAttendanceCard({required this.subject, required this.target});

  Color _pctColor(double p) => p >= 75
      ? AppColors.success
      : p >= 60
          ? AppColors.warning
          : AppColors.danger;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(subject.colorHex);
    final pct = subject.percent;
    final pctColor = subject.held == 0 ? theme.hintColor : _pctColor(pct);
    final controller = ref.read(attendanceControllerProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 12, height: 12,
                  decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(subject.name,
                    style: theme.textTheme.titleMedium,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              Text(
                subject.held == 0 ? '—' : '${pct.toStringAsFixed(0)}%',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: pctColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: subject.held == 0 ? 0 : (subject.attended / subject.held),
              minHeight: 8,
              backgroundColor: theme.dividerColor,
              valueColor: AlwaysStoppedAnimation(pctColor),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text('${subject.attended} attended · ${subject.missed} missed · ${subject.held} total',
                  style: theme.textTheme.bodySmall),
              const Spacer(),
              InkWell(
                onTap: () => _editDialog(context, ref),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(Icons.tune_rounded, size: 18, color: theme.hintColor),
                ),
              ),
            ],
          ),
          if (subject.held > 0) ...[
            const SizedBox(height: 6),
            Text(_bunkHint(subject, target),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: pct >= target ? AppColors.success : AppColors.danger,
                  fontWeight: FontWeight.w500,
                )),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => controller.markPresent(subject.id),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('Present'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => controller.markAbsent(subject.id),
                  icon: const Icon(Icons.close_rounded, size: 18),
                  label: const Text('Absent'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _bunkHint(Subject s, double target) {
    final stats = AttendanceStatsShim(s.attended, s.missed);
    if (s.percent >= target) {
      final canSkip = stats.bunkable(target);
      return canSkip <= 0
          ? 'Right on your ${target.toStringAsFixed(0)}% target'
          : 'You can skip $canSkip more and stay ≥ ${target.toStringAsFixed(0)}%';
    } else {
      final need = stats.recover(target);
      return need <= 0
          ? 'Below ${target.toStringAsFixed(0)}% target'
          : 'Attend $need in a row to reach ${target.toStringAsFixed(0)}%';
    }
  }

  Future<void> _editDialog(BuildContext context, WidgetRef ref) async {
    var attended = subject.attended;
    var held = subject.held;
    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(subject.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _stepperRow(ctx, 'Attended', attended, (v) {
                setState(() {
                  attended = v < 0 ? 0 : v;
                  if (attended > held) held = attended;
                });
              }),
              const SizedBox(height: 8),
              _stepperRow(ctx, 'Total classes', held, (v) {
                setState(() {
                  held = v < attended ? attended : v;
                });
              }),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                ref
                    .read(attendanceControllerProvider)
                    .setCounts(subject.id, attended, held);
                Navigator.pop(ctx);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepperRow(
      BuildContext context, String label, int value, ValueChanged<int> onChange) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline_rounded),
          onPressed: () => onChange(value - 1),
        ),
        SizedBox(
          width: 32,
          child: Text('$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline_rounded),
          onPressed: () => onChange(value + 1),
        ),
      ],
    );
  }
}

/// Tiny helper mirroring AttendanceStats bunk math for a subject's counters.
class AttendanceStatsShim {
  final int present;
  final int absent;
  const AttendanceStatsShim(this.present, this.absent);
  int get held => present + absent;
  double get percent => held == 0 ? 0 : present / held * 100;

  int bunkable(double target) {
    if (held == 0 || percent < target) return 0;
    final maxTotal = present * 100.0 / target;
    final x = (maxTotal - held).floor();
    return x < 0 ? 0 : x;
  }

  int recover(double target) {
    if (held == 0 || percent >= target) return 0;
    final t = target / 100.0;
    if (t >= 1) return -1;
    final y = ((t * held - present) / (1 - t)).ceil();
    return y < 0 ? 0 : y;
  }
}
