import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/subject_icons.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../domain/task_item.dart';
import '../providers/task_providers.dart';

/// A task rendered on a vertical timeline rail — used consistently across Home,
/// the Tasks page and the Schedule so tasks look the same everywhere.
///
/// The rail node is a tap-to-complete check (filled + strikethrough when done);
/// the card shows the subject/type icon, the title, a subtitle (subject or
/// type) and a colour-coded due badge. Tapping the card runs [onTap].
class TaskTimelineTile extends ConsumerWidget {
  final TaskItem task;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onTap;

  const TaskTimelineTile({
    super.key,
    required this.task,
    required this.isFirst,
    required this.isLast,
    required this.onTap,
  });

  (String, Color, IconData) _due(BuildContext context) {
    final now = DateTime.now();
    if (task.isOverdue) {
      return ('Overdue', AppColors.danger, Icons.error_outline_rounded);
    }
    if (task.dueDate == null) {
      return ('Later', Theme.of(context).hintColor, Icons.schedule_rounded);
    }
    if (DateUtilsX.isSameDay(task.dueDate!, now)) {
      return ('Today', AppColors.warning, Icons.today_rounded);
    }
    return (DateUtilsX.prettyDate(task.dueDate!), AppColors.info,
        Icons.event_rounded);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final done = task.done;
    final subject = task.subjectId == null
        ? null
        : ref.watch(subjectsByIdProvider)[task.subjectId];
    final pColor = done ? AppColors.success : task.priority.color;
    final tileColor =
        subject != null ? Color(subject.colorHex) : task.type.color;
    final tileIcon =
        subject != null ? SubjectIcons.resolve(subject.iconKey) : task.type.icon;
    final subtitle = subject?.name ?? task.type.label;
    final lineColor = AppColors.primary.withValues(alpha: 0.25);

    final (dueLabel, dueColorRaw, dueIcon) = _due(context);
    final dueColor = done ? AppColors.success : dueColorRaw;
    final badgeLabel = done ? 'Done' : dueLabel;
    final badgeIcon = done ? Icons.check_circle_rounded : dueIcon;

    void toggle() {
      final messenger = ScaffoldMessenger.of(context);
      final wasDone = task.done;
      ref.read(taskControllerProvider).toggle(task);
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        duration: const Duration(milliseconds: 1400),
        content: Text(
            wasDone ? 'Marked to-do · ${task.title}' : 'Completed · ${task.title}'),
      ));
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left rail: connector line + tap-to-complete check node.
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                    width: 2,
                    height: 22,
                    color: isFirst ? Colors.transparent : lineColor),
                Semantics(
                  button: true,
                  label: done
                      ? 'Mark "${task.title}" to-do'
                      : 'Mark "${task.title}" complete',
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: toggle,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      color: Colors.transparent,
                      child: Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: done ? AppColors.success : theme.cardColor,
                          border: Border.all(color: pColor, width: 3),
                        ),
                        child: Icon(Icons.check_rounded,
                            size: 11,
                            color: done
                                ? Colors.white
                                : pColor.withValues(alpha: 0.4)),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : lineColor),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: softCard(context, radius: 16),
              clipBehavior: Clip.antiAlias,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tileColor.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: Icon(tileIcon, color: tileColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(task.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : null,
                                      color: done ? theme.hintColor : null)),
                              const SizedBox(height: 3),
                              Text(subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodySmall
                                      ?.copyWith(color: theme.hintColor)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 6),
                          decoration: BoxDecoration(
                            color: dueColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(badgeIcon, size: 13, color: dueColor),
                              const SizedBox(width: 4),
                              Text(badgeLabel,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                      color: dueColor,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
