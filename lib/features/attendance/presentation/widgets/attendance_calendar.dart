import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../providers/attendance_providers.dart';

/// A month-view attendance calendar shown at the end of the Attendance page.
///
/// Each day is a soft, colour-coded cell (green = present, red = absent,
/// grey = no class) built from the per-day tallies in [dailyAttendanceProvider].
/// Below the grid a "This month" summary breaks down present/absent/no-class
/// counts and the month's total held classes. Navigable month-to-month.
class AttendanceCalendar extends ConsumerStatefulWidget {
  const AttendanceCalendar({super.key});

  @override
  ConsumerState<AttendanceCalendar> createState() => _AttendanceCalendarState();
}

class _AttendanceCalendarState extends ConsumerState<AttendanceCalendar> {
  late DateTime _month; // always the 1st of the visible month

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shift(int delta) =>
      setState(() => _month = DateTime(_month.year, _month.month + delta));

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final daily = ref.watch(dailyAttendanceProvider);

    // Month scope for the summary.
    final prefix = DateFormat('yyyy-MM').format(_month);
    var present = 0, absent = 0, cancelled = 0;
    daily.forEach((dateId, day) {
      if (dateId.startsWith(prefix)) {
        present += day.present;
        absent += day.absent;
        cancelled += day.cancelled;
      }
    });
    final held = present + absent;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
      decoration: softCard(context, radius: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(theme),
          const SizedBox(height: 18),
          _weekdayRow(theme),
          const SizedBox(height: 6),
          _grid(theme, daily),
          const SizedBox(height: 14),
          Divider(height: 1, color: theme.dividerColor),
          const SizedBox(height: 14),
          _summary(theme, present, absent, cancelled, held),
        ],
      ),
    );
  }

  // ── Header: title + month navigator ───────────────────────────────────────
  Widget _header(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Text('Attendance calendar',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800)),
        ),
        _NavButton(icon: Icons.chevron_left_rounded, onTap: () => _shift(-1)),
        const SizedBox(width: 2),
        SizedBox(
          width: 108,
          child: Text(
            DateUtilsX.monthYear(_month),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.primary, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 2),
        // Don't navigate into the future past the current month.
        _NavButton(
          icon: Icons.chevron_right_rounded,
          onTap: _isCurrentMonth ? null : () => _shift(1),
        ),
      ],
    );
  }

  Widget _weekdayRow(ThemeData theme) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: [
        for (final l in labels)
          Expanded(
            child: Center(
              child: Text(l,
                  style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.hintColor, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  // ── The week-by-week grid ──────────────────────────────────────────────────
  Widget _grid(ThemeData theme, Map<String, DayAttendance> daily) {
    final daysInMonth = DateUtils.getDaysInMonth(_month.year, _month.month);
    // weekday: Mon=1..Sun=7 → leading blanks before day 1.
    final leading = DateTime(_month.year, _month.month, 1).weekday - 1;
    final totalCells = leading + daysInMonth;
    final rows = (totalCells / 7).ceil();

    final today = DateUtils.dateOnly(DateTime.now());

    return Column(
      children: [
        for (var w = 0; w < rows; w++)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                for (var d = 0; d < 7; d++)
                  Expanded(
                    child: _cell(
                      theme,
                      dayNumber: (w * 7 + d) - leading + 1,
                      daysInMonth: daysInMonth,
                      daily: daily,
                      today: today,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(
    ThemeData theme, {
    required int dayNumber,
    required int daysInMonth,
    required Map<String, DayAttendance> daily,
    required DateTime today,
  }) {
    // Out-of-month padding cell.
    if (dayNumber < 1 || dayNumber > daysInMonth) {
      return const AspectRatio(aspectRatio: 1, child: SizedBox.shrink());
    }

    final date = DateTime(_month.year, _month.month, dayNumber);
    final isToday = DateUtils.isSameDay(date, today);
    final day = daily[DateUtilsX.dateId(date)];

    // Resolve a single status colour for the day.
    // absent (any miss) > present (any attend, no miss) > no-class (cancelled).
    Color fill;
    Color textColor;
    if (day == null || (day.present + day.absent + day.cancelled) == 0) {
      fill = theme.brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.03)
          : AppColors.lavenderSoft;
      textColor = theme.hintColor.withValues(alpha: 0.55);
    } else if (day.absent > 0) {
      fill = AppColors.absent.withValues(alpha: 0.22);
      textColor = AppColors.absent;
    } else if (day.present > 0) {
      fill = AppColors.present.withValues(alpha: 0.22);
      textColor = AppColors.present.withValues(alpha: 0.9);
    } else {
      // cancelled only → no class
      fill = AppColors.cancelled.withValues(alpha: 0.22);
      textColor = AppColors.cancelled;
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(12),
            border: isToday
                ? Border.all(color: AppColors.primary, width: 2)
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            '$dayNumber',
            style: theme.textTheme.labelMedium?.copyWith(
              color: isToday ? AppColors.primary : textColor,
              fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
              fontSize: 11.5,
            ),
          ),
        ),
      ),
    );
  }

  // ── "This month" summary — compact stat tiles + total ─────────────────────
  Widget _summary(
      ThemeData theme, int present, int absent, int cancelled, int held) {
    String pct(int v) => held == 0 ? '—' : '${((v / held) * 100).round()}%';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('This month',
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: RichText(
                text: TextSpan(
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: AppColors.primaryDark),
                  children: [
                    const TextSpan(text: 'Total  '),
                    TextSpan(
                        text: '$held',
                        style: const TextStyle(fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statTile(theme, AppColors.present, 'Present', present, pct(present)),
            const SizedBox(width: 10),
            _statTile(theme, AppColors.absent, 'Absent', absent, pct(absent)),
            const SizedBox(width: 10),
            _statTile(theme, AppColors.cancelled, 'No class', cancelled, '—'),
          ],
        ),
      ],
    );
  }

  Widget _statTile(
      ThemeData theme, Color color, String label, int value, String pct) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration:
                      BoxDecoration(color: color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: theme.hintColor)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$value',
                    style: theme.textTheme.titleLarge?.copyWith(
                        color: color, fontWeight: FontWeight.w800)),
                const SizedBox(width: 4),
                Text(pct,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.hintColor, fontSize: 11)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _NavButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onTap != null;
    return Material(
      color: theme.brightness == Brightness.dark
          ? AppColors.darkSurfaceAlt
          : AppColors.lavenderSoft,
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icon,
              size: 20,
              color: enabled ? AppColors.primary : theme.disabledColor),
        ),
      ),
    );
  }
}
