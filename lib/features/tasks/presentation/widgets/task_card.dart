import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/subject_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/url_launcher_util.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../subjects/domain/subject.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../domain/task_item.dart';
import '../providers/task_providers.dart';

/// The canonical task row used across the Tasks page and Home: a tap-to-complete
/// circle, a subject/type icon tile, the title with a subject/type tag, a
/// colour-coded due status, a star (high-priority) toggle, an overflow menu and
/// an optional "Open link" pill.
///
/// Self-contained: it resolves its own due status, subject styling and handles
/// complete / star / edit / delete / open-link actions via [taskControllerProvider].
/// Callers only provide [onOpen] (usually "open the editor").
class TaskCard extends ConsumerWidget {
  final TaskItem task;
  final VoidCallback onOpen;

  const TaskCard({super.key, required this.task, required this.onOpen});

  static (String, String?, Color, IconData) _dueInfo(
      BuildContext context, TaskItem task) {
    final theme = Theme.of(context);
    if (task.done) {
      return ('Done', null, AppColors.success, Icons.check_circle_rounded);
    }
    final now = DateTime.now();
    final due = task.dueDate;
    String? timeLabel;
    if (due != null && !(due.hour == 0 && due.minute == 0)) {
      timeLabel = TimeOfDay.fromDateTime(due).format(context);
    }
    if (task.isOverdue) {
      return (
        'Overdue',
        due == null ? null : _dayMonth(due),
        AppColors.danger,
        Icons.error_outline_rounded
      );
    }
    if (due == null) {
      return ('No date', null, theme.hintColor, Icons.schedule_rounded);
    }
    if (DateUtilsX.isSameDay(due, now)) {
      return ('Due today', timeLabel, AppColors.warning, Icons.today_rounded);
    }
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    if (DateUtilsX.isSameDay(due, tomorrow)) {
      return ('Tomorrow', timeLabel, AppColors.info, Icons.event_rounded);
    }
    return (_dayMonth(due), timeLabel, AppColors.info, Icons.event_rounded);
  }

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec' //
  ];
  static String _dayMonth(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = task.done;
    final Subject? subject = task.subjectId == null
        ? null
        : ref.watch(subjectsByIdProvider)[task.subjectId];
    final tileColor =
        subject != null ? Color(subject.colorHex) : task.type.color;
    final tileIcon = subject != null
        ? SubjectIcons.resolve(subject.iconKey)
        : task.type.icon;
    final tagLabel = subject?.name ?? task.type.label;
    final isHigh = task.priority == TaskPriority.high;

    final (dueMain, dueSub, dueColorRaw, dueIcon) = _dueInfo(context, task);
    final dueColor = done ? AppColors.success : dueColorRaw;

    final hasLink = task.hasLink;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: softCard(context, radius: 16),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 10, 11, 10),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tap-to-complete circle.
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => ref.read(taskControllerProvider).toggle(task),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1, right: 9),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color:
                                done ? AppColors.success : Colors.transparent,
                            border: Border.all(
                                color: done
                                    ? AppColors.success
                                    : task.priority.color,
                                width: 2),
                          ),
                          child: done
                              ? const Icon(Icons.check_rounded,
                                  size: 14, color: Colors.white)
                              : null,
                        ),
                      ),
                    ),
                    // Icon tile.
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: tileColor.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Icon(tileIcon, color: tileColor, size: 19),
                    ),
                    const SizedBox(width: 11),
                    // Title + tag.
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(task.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  decoration: done
                                      ? TextDecoration.lineThrough
                                      : null,
                                  color: done ? theme.hintColor : null)),
                          if (task.note != null && task.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(task.note!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall
                                    ?.copyWith(color: theme.hintColor)),
                          ],
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: tileColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(tagLabel,
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: tileColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Right column: due status + actions.
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(dueIcon, size: 13, color: dueColor),
                            const SizedBox(width: 3),
                            Text(dueMain,
                                style: theme.textTheme.labelMedium?.copyWith(
                                    color: dueColor,
                                    fontWeight: FontWeight.w700)),
                          ],
                        ),
                        if (dueSub != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 1),
                            child: Text(dueSub,
                                style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.hintColor, fontSize: 11)),
                          ),
                        const SizedBox(height: 2),
                        GestureDetector(
                          onTap: () {
                            final next = task.priority == TaskPriority.high
                                ? TaskPriority.medium
                                : TaskPriority.high;
                            ref
                                .read(taskControllerProvider)
                                .update(task.copyWith(priority: next));
                          },
                          child: Icon(
                            isHigh
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            size: 20,
                            color: isHigh ? AppColors.accent : theme.hintColor,
                          ),
                        ),
                        if (hasLink) ...[
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () => openUrl(context, task.link),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.link_rounded,
                                      size: 14, color: AppColors.primary),
                                  const SizedBox(width: 5),
                                  Text('Open link',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w600)),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
