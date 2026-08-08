import 'package:flutter/material.dart';
import 'package:classtrack/core/theme/app_icons.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/attendance_record.dart';

/// Playful "bunk calculator" — how many classes you can still skip (or must
/// attend) to stay at/above [target] %.
class BunkCalculator extends StatelessWidget {
  final AttendanceStats stats;
  final double target;

  const BunkCalculator({
    super.key,
    required this.stats,
    required this.target,
  });

  @override
  Widget build(BuildContext context) {
    if (stats.held == 0) {
      return _shell(
        context,
        color: AppColors.info,
        icon: PhosphorIcons.info(),
        title: 'No classes marked yet',
        message: 'Mark a few classes and your bunk budget will appear here.',
      );
    }

    final above = stats.percent >= target;
    if (above) {
      final canSkip = stats.bunkableClasses(target);
      return _shell(
        context,
        color: AppColors.success,
        icon: PhosphorIcons.confetti(),
        title: canSkip == 0
            ? 'Right on the line'
            : 'You can skip $canSkip ${canSkip == 1 ? 'class' : 'classes'}',
        message: canSkip == 0
            ? 'You’re exactly at your ${target.toStringAsFixed(0)}% target — attend the next one to be safe.'
            : 'And still stay at or above your ${target.toStringAsFixed(0)}% target. Use them wisely 😉',
      );
    } else {
      final need = stats.classesToRecover(target);
      return _shell(
        context,
        color: AppColors.danger,
        icon: PhosphorIcons.warning(),
        title: need <= 0
            ? 'Target out of reach for now'
            : 'Attend $need more in a row',
        message: need <= 0
            ? 'Reaching ${target.toStringAsFixed(0)}% will take a while — keep attending consistently.'
            : 'Attend the next $need ${need == 1 ? 'class' : 'classes'} without missing to get back to ${target.toStringAsFixed(0)}%.',
      );
    }
  }

  Widget _shell(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: theme.textTheme.titleMedium?.copyWith(color: color)),
                const SizedBox(height: 4),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
