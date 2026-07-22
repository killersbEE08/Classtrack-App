import 'package:flutter/material.dart';

import '../../../../core/utils/date_utils.dart';
import '../providers/schedule_providers.dart';

/// Google-Calendar-style single-day timeline: an hourly grid with class blocks
/// positioned by start time and sized by duration. Overlapping classes are
/// laid out side-by-side.
class DayTimeline extends StatelessWidget {
  final List<ScheduledClass> classes;
  final void Function(ScheduledClass)? onTap;
  final double hourHeight;

  const DayTimeline({
    super.key,
    required this.classes,
    this.onTap,
    this.hourHeight = 64,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Determine visible hour range (pad around the earliest/latest class).
    var minHour = 7;
    var maxHour = 20;
    for (final c in classes) {
      final s = DateUtilsX.minutesOfDay(c.session.startTime) ~/ 60;
      final e = (DateUtilsX.minutesOfDay(c.session.endTime) + 59) ~/ 60;
      if (s < minHour) minHour = s;
      if (e > maxHour) maxHour = e;
    }
    minHour = minHour.clamp(0, 23);
    maxHour = maxHour.clamp(minHour + 1, 24);

    final totalHours = maxHour - minHour;
    final gridHeight = totalHours * hourHeight;
    const labelWidth = 54.0;

    final lanes = _assignLanes(classes);
    final laneCount = (lanes.values.isEmpty
        ? 1
        : lanes.values.reduce((a, b) => a > b ? a : b) + 1);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 12, 120),
        child: SizedBox(
          height: gridHeight,
          child: Stack(
            children: [
              // Hour lines + labels
              for (int h = minHour; h <= maxHour; h++)
                Positioned(
                  top: (h - minHour) * hourHeight,
                  left: 0,
                  right: 0,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: labelWidth,
                        child: Text(
                          _hourLabel(h),
                          style: theme.textTheme.bodySmall,
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Divider(
                            height: 1,
                            color: theme.dividerColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              // Event blocks
              ...classes.map((c) {
                final start = DateUtilsX.minutesOfDay(c.session.startTime);
                final end = DateUtilsX.minutesOfDay(c.session.endTime);
                final top = (start - minHour * 60) / 60 * hourHeight;
                final height =
                    ((end - start) / 60 * hourHeight).clamp(28.0, gridHeight);
                final lane = lanes[c] ?? 0;

                return LayoutBuilder(builder: (context, constraints) {
                  final areaWidth = constraints.maxWidth - labelWidth - 16;
                  final blockWidth = areaWidth / laneCount;
                  return Positioned(
                    top: top + 8,
                    left: labelWidth + 16 + lane * blockWidth,
                    width: blockWidth - 4,
                    height: height - 4,
                    child: _EventBlock(
                      scheduled: c,
                      onTap: onTap == null ? null : () => onTap!(c),
                    ),
                  );
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  String _hourLabel(int h) {
    if (h == 0 || h == 24) return '12 AM';
    if (h == 12) return '12 PM';
    return h < 12 ? '$h AM' : '${h - 12} PM';
  }

  /// Greedy lane assignment so overlapping classes get separate columns.
  Map<ScheduledClass, int> _assignLanes(List<ScheduledClass> items) {
    final sorted = [...items]..sort((a, b) => DateUtilsX.minutesOfDay(
            a.session.startTime)
        .compareTo(DateUtilsX.minutesOfDay(b.session.startTime)));
    final laneEnds = <int>[]; // end minute of last event in each lane
    final result = <ScheduledClass, int>{};
    for (final c in sorted) {
      final start = DateUtilsX.minutesOfDay(c.session.startTime);
      final end = DateUtilsX.minutesOfDay(c.session.endTime);
      var placed = false;
      for (var i = 0; i < laneEnds.length; i++) {
        if (start >= laneEnds[i]) {
          laneEnds[i] = end;
          result[c] = i;
          placed = true;
          break;
        }
      }
      if (!placed) {
        result[c] = laneEnds.length;
        laneEnds.add(end);
      }
    }
    return result;
  }
}

class _EventBlock extends StatelessWidget {
  final ScheduledClass scheduled;
  final VoidCallback? onTap;
  const _EventBlock({required this.scheduled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = Color(scheduled.subject.colorHex);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: color.withOpacity(0.16),
            borderRadius: BorderRadius.circular(10),
            border: Border(left: BorderSide(color: color, width: 4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scheduled.subject.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelLarge
                    ?.copyWith(color: color, fontWeight: FontWeight.w600),
              ),
              Text(
                '${DateUtilsX.displayTime(context, scheduled.session.startTime)}–${DateUtilsX.displayTime(context, scheduled.session.endTime)}'
                '${scheduled.session.room?.isNotEmpty == true ? ' · ${scheduled.session.room}' : ''}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
