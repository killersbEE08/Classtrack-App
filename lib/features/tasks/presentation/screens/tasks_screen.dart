import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/subject_icons.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/checklist_item.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/url_launcher_util.dart';
import '../../../../shared/widgets/feature_tip_banner.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../domain/task_item.dart';
import '../providers/task_providers.dart';

enum TaskFilter { all, inProgress, completed }

extension on TaskFilter {
  String get label => switch (this) {
        TaskFilter.all => 'All',
        TaskFilter.inProgress => 'In progress',
        TaskFilter.completed => 'Completed',
      };
}

/// How the visible task list is ordered. [smart] keeps the server's
/// due-then-priority ordering and groups tasks by due-window; the others
/// present a single flat, explicitly-sorted list.
enum TaskSort { smart, due, priority, created }

extension on TaskSort {
  String get label => switch (this) {
        TaskSort.smart => 'Smart',
        TaskSort.due => 'Due date',
        TaskSort.priority => 'Priority',
        TaskSort.created => 'Recently added',
      };

  IconData get icon => switch (this) {
        TaskSort.smart => Icons.auto_awesome_rounded,
        TaskSort.due => Icons.event_rounded,
        TaskSort.priority => Icons.flag_rounded,
        TaskSort.created => Icons.schedule_rounded,
      };
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.all;
  TaskSort _sort = TaskSort.smart;
  String _query = '';

  static void openEditor(BuildContext context, {TaskItem? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskEditorSheet(task: task),
    );
  }

  // ── Sorting ────────────────────────────────────────────────────────────
  int _byDue(TaskItem a, TaskItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final ad = a.dueDate, bd = b.dueDate;
    if (ad == null && bd == null) return 0;
    if (ad == null) return 1;
    if (bd == null) return -1;
    return ad.compareTo(bd);
  }

  int _byPriority(TaskItem a, TaskItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    if (a.priority != b.priority) {
      return b.priority.index.compareTo(a.priority.index);
    }
    return _byDue(a, b);
  }

  int _byCreated(TaskItem a, TaskItem b) {
    if (a.done != b.done) return a.done ? 1 : -1;
    final ac = a.createdAt, bc = b.createdAt;
    if (ac == null && bc == null) return 0;
    if (ac == null) return 1;
    if (bc == null) return -1;
    return bc.compareTo(ac); // newest first
  }

  List<TaskItem> _applySort(List<TaskItem> tasks) {
    switch (_sort) {
      case TaskSort.smart:
        return tasks; // repository already smart-sorts
      case TaskSort.due:
        return [...tasks]..sort(_byDue);
      case TaskSort.priority:
        return [...tasks]..sort(_byPriority);
      case TaskSort.created:
        return [...tasks]..sort(_byCreated);
    }
  }

  /// Flat animated list used for the explicit (non-smart) sorts.
  Widget _flatList(List<TaskItem> tasks) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 140),
      itemCount: tasks.length,
      itemBuilder: (_, i) => _TaskCard(task: tasks[i])
          .animate()
          .fadeIn(delay: (i * 35).ms, duration: 280.ms)
          .slideY(begin: 0.08, curve: Curves.easeOutCubic),
    );
  }

  /// Tasks grouped by due status for a scannable list (Smart sort).
  Widget _groupedList(BuildContext context, List<TaskItem> tasks) {
    final theme = Theme.of(context);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 7));

    final overdue = <TaskItem>[];
    final todayT = <TaskItem>[];
    final week = <TaskItem>[];
    final later = <TaskItem>[];
    final noDate = <TaskItem>[];
    final done = <TaskItem>[];

    for (final t in tasks) {
      if (t.done) {
        done.add(t);
        continue;
      }
      final d = t.dueDate;
      if (d == null) {
        noDate.add(t);
      } else {
        final dd = DateTime(d.year, d.month, d.day);
        if (dd.isBefore(today)) {
          overdue.add(t);
        } else if (dd == today) {
          todayT.add(t);
        } else if (!dd.isAfter(weekEnd)) {
          week.add(t);
        } else {
          later.add(t);
        }
      }
    }

    final sections = <(String, List<TaskItem>, Color)>[
      ('Overdue', overdue, AppColors.danger),
      ('Today', todayT, AppColors.primary),
      ('This week', week, AppColors.info),
      ('Later', later, theme.hintColor),
      ('No date', noDate, theme.hintColor),
      ('Completed', done, AppColors.success),
    ];

    var i = 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 140),
      children: [
        for (final (label, list, color) in sections)
          if (list.isNotEmpty) ...[
            _sectionHeader(theme, label, list.length, color),
            for (final t in list)
              _TaskCard(task: t)
                  .animate()
                  .fadeIn(delay: (i++ * 35).ms, duration: 280.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic),
          ],
      ],
    );
  }

  // ── Hero summary ─────────────────────────────────────────────────────────
  Widget _hero(ThemeData theme, int done, int total, int todo, int overdue,
      int dueToday) {
    final pct = total == 0 ? 0.0 : (done / total) * 100;
    final allDone = total > 0 && done == total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        boxShadow: AppColors.softShadow(opacity: 0.20, blur: 26),
      ),
      child: Row(
        children: [
          AnimatedProgressRing(
            percent: pct,
            size: 74,
            strokeWidth: 8,
            color: Colors.white,
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  allDone ? 'All caught up 🎉' : '$done of $total done',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _heroPill('$todo', 'to-do'),
                    if (dueToday > 0) _heroPill('$dueToday', 'today'),
                    if (overdue > 0)
                      _heroPill('$overdue', 'overdue', danger: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String value, String label, {bool danger = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
      decoration: BoxDecoration(
        color: danger
            ? Colors.white.withValues(alpha: 0.95)
            : Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                color: danger ? AppColors.danger : Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              )),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                color: danger
                    ? AppColors.danger
                    : Colors.white.withValues(alpha: 0.9),
                fontWeight: FontWeight.w600,
                fontSize: 12,
              )),
        ],
      ),
    );
  }

  // ── Segmented filter ──────────────────────────────────────────────────────
  Widget _segmentedFilter(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: TaskFilter.values.map((f) {
          final selected = f == _filter;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _filter = f),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(24),
                ),
                alignment: Alignment.center,
                child: Text(
                  f.label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: selected
                        ? Colors.white
                        : theme.textTheme.bodySmall?.color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionHeader(
      ThemeData theme, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.w800, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Future<void> _clearCompleted(
      BuildContext context, List<TaskItem> allTasks) async {
    final done = allTasks.where((t) => t.done).toList();
    if (done.isEmpty) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear completed?'),
        content: Text('Delete ${done.length} completed '
            'task${done.length == 1 ? '' : 's'}? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final ctrl = ref.read(taskControllerProvider);
    for (final t in done) {
      await ctrl.delete(t.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasksAsync = ref.watch(tasksStreamProvider);
    final allTasks = tasksAsync.valueOrNull ?? const <TaskItem>[];
    final todoCount = allTasks.where((t) => !t.done).length;
    final doneCount = allTasks.length - todoCount;
    final overdueCount = allTasks.where((t) => t.isOverdue).length;
    final now = DateTime.now();
    final dueTodayCount = allTasks
        .where((t) =>
            !t.done &&
            t.dueDate != null &&
            DateUtilsX.isSameDay(t.dueDate!, now))
        .length;
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      // Only show an in-screen add button when pushed as a standalone route;
      // as a tab, HomeShell already provides the docked quick-add FAB.
      floatingActionButton: canPop
          ? FloatingActionButton.extended(
              onPressed: () => openEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New task'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 0),
              child: Row(
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
                        Text('Your tasks',
                            style: theme.textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w800)),
                        Text(
                          allTasks.isEmpty
                              ? 'Add your first task'
                              : (todoCount == 0
                                  ? 'Everything is done'
                                  : '$todoCount to do · $doneCount done'),
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  // Sort
                  PopupMenuButton<TaskSort>(
                    tooltip: 'Sort',
                    icon: const Icon(Icons.sort_rounded),
                    initialValue: _sort,
                    onSelected: (s) => setState(() => _sort = s),
                    itemBuilder: (ctx) => TaskSort.values
                        .map((s) => PopupMenuItem(
                              value: s,
                              child: Row(
                                children: [
                                  Icon(s.icon,
                                      size: 18,
                                      color: s == _sort
                                          ? AppColors.primary
                                          : theme.hintColor),
                                  const SizedBox(width: 10),
                                  Text(s.label,
                                      style: TextStyle(
                                          fontWeight: s == _sort
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: s == _sort
                                              ? AppColors.primary
                                              : null)),
                                ],
                              ),
                            ))
                        .toList(),
                  ),
                  if (doneCount > 0)
                    IconButton(
                      tooltip: 'Clear completed',
                      onPressed: () => _clearCompleted(context, allTasks),
                      icon: const Icon(Icons.done_all_rounded),
                    ),
                ],
              ),
            ),
            const FeatureTipBanner(
              prefsKey: AppConstants.prefsTipTasks,
              message:
                  'Share any YouTube video to ClassTrack to create a task instantly.',
            ),
            if (allTasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: _hero(theme, doneCount, allTasks.length, todoCount,
                        overdueCount, dueTodayCount)
                    .animate()
                    .fadeIn(duration: 320.ms)
                    .slideY(begin: 0.06, curve: Curves.easeOut),
              ),
            if (allTasks.length > 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search tasks',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(() => _query = ''),
                          ),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: _segmentedFilter(theme),
            ),
            Expanded(
              child: tasksAsync.when(
                loading: () => const LoadingView(),
                error: (e, _) => ErrorView(error: e),
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return EmptyState(
                      icon: Icons.check_circle_rounded,
                      title: 'No tasks yet',
                      message:
                          'Add assignments, deadlines and to-dos. They’ll show up on your calendar and dashboard.',
                      actionLabel: 'Add task',
                      onAction: () => openEditor(context),
                    );
                  }
                  final filtered = switch (_filter) {
                    TaskFilter.all => tasks,
                    TaskFilter.inProgress =>
                      tasks.where((t) => !t.done).toList(),
                    TaskFilter.completed =>
                      tasks.where((t) => t.done).toList(),
                  };
                  final q = _query.trim().toLowerCase();
                  final searched = q.isEmpty
                      ? filtered
                      : filtered
                          .where((t) =>
                              t.title.toLowerCase().contains(q) ||
                              (t.note?.toLowerCase().contains(q) ?? false))
                          .toList();
                  if (searched.isEmpty) {
                    return Center(
                      child: Text(q.isEmpty ? 'Nothing here yet' : 'No matches',
                          style: theme.textTheme.bodyMedium),
                    );
                  }
                  final ordered = _applySort(searched);
                  // Smart sort keeps the scannable grouped view; explicit sorts
                  // (or a single-status filter) show a flat, ordered list.
                  return _sort == TaskSort.smart && _filter == TaskFilter.all
                      ? _groupedList(context, ordered)
                      : _flatList(ordered);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TaskCard extends ConsumerWidget {
  final TaskItem task;
  const _TaskCard({required this.task});

  String _dueLabel() {
    if (task.dueDate == null) return 'No date';
    final now = DateTime.now();
    if (task.isOverdue) return 'Overdue';
    if (DateUtilsX.isSameDay(task.dueDate!, now)) return 'Today';
    if (DateUtilsX.isSameDay(task.dueDate!, now.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    return DateUtilsX.prettyDate(task.dueDate!);
  }

  String _timeLabel(BuildContext context) {
    final d = task.dueDate;
    if (d == null) return 'No due date';
    final tod = TimeOfDay.fromDateTime(d);
    if (tod.hour == 0 && tod.minute == 0) return 'All day';
    return tod.format(context);
  }

  Widget _swipeBg(
      {required bool alignLeft,
      required Color color,
      required IconData icon,
      required String label}) {
    return Container(
      alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 6),
          Text(label,
              style: TextStyle(color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _completeToggle(
      BuildContext context, WidgetRef ref, bool done, Color accent) {
    return GestureDetector(
      onTap: () => ref.read(taskControllerProvider).toggle(task),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: done ? AppColors.success : Colors.transparent,
          shape: BoxShape.circle,
          border: Border.all(
            color: done ? AppColors.success : accent.withValues(alpha: 0.5),
            width: 2,
          ),
        ),
        child: done
            ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _chip(IconData icon, String text, Color color, {bool strong = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: strong ? 0.16 : 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(text,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  void _deleteWithUndo(BuildContext context, WidgetRef ref) {
    final removed = task;
    final ctrl = ref.read(taskControllerProvider);
    ctrl.delete(removed.id);
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    final controller = messenger.showSnackBar(SnackBar(
      // Kept long: we dismiss it ourselves via the timer below rather than
      // relying on the framework's built-in auto-dismiss.
      duration: const Duration(days: 1),
      content: Text('Deleted “${removed.title}”'),
      action: SnackBarAction(
        label: 'Undo',
        // Re-add restores the content (under a fresh id); its reminder is
        // rescheduled by reminderSyncProvider on the next data change.
        onPressed: () => ctrl.add(removed),
      ),
    ));

    // A continuously-running animation elsewhere in the shell (the center
    // FAB's "breathing" loop) can stall the SnackBar's own animation-gated
    // auto-dismiss, leaving the Undo bar stuck on screen until the app is
    // killed. A plain Dart Timer runs on the event loop independent of frames
    // and animations, so it always fires; closing the controller reuses the
    // exact dismissal path the Undo button uses (which is known to work).
    final timer = Timer(const Duration(seconds: 4), controller.close);
    // If the bar is dismissed early (Undo tapped, or another delete replaces
    // it), cancel the pending timer so it can't close a later bar.
    controller.closed.then((_) => timer.cancel());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final subject = task.subjectId == null
        ? null
        : ref.watch(subjectsByIdProvider)[task.subjectId];
    final overdue = task.isOverdue;
    final done = task.done;
    final accent = done ? AppColors.success : task.priority.color;
    final due = task.dueDate;
    final hasTime = due != null && !(due.hour == 0 && due.minute == 0);
    final dueColor = done
        ? theme.hintColor
        : overdue
            ? AppColors.danger
            : (due != null && DateUtilsX.isSameDay(due, DateTime.now()))
                ? AppColors.primary
                : theme.hintColor;
    final subtaskProgress =
        task.hasSubtasks ? task.subtasksDone / task.subtasks.length : 0.0;

    return Dismissible(
      key: ValueKey(task.id),
      background: _swipeBg(
          alignLeft: true,
          color: AppColors.success,
          icon: done ? Icons.undo_rounded : Icons.check_rounded,
          label: done ? 'Undo' : 'Done'),
      secondaryBackground: _swipeBg(
          alignLeft: false,
          color: AppColors.danger,
          icon: Icons.delete_outline_rounded,
          label: 'Delete'),
      confirmDismiss: (dir) async {
        if (dir == DismissDirection.startToEnd) {
          ref.read(taskControllerProvider).toggle(task);
          return false;
        }
        return true;
      },
      onDismissed: (_) => _deleteWithUndo(context, ref),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: overdue && !done
                ? AppColors.danger.withValues(alpha: 0.35)
                : theme.dividerColor,
          ),
          boxShadow: AppColors.softShadow(opacity: 0.05, blur: 16),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Slim priority accent.
              Container(width: 5, color: accent),
              Expanded(
                child: InkWell(
                  onTap: () =>
                      _TasksScreenState.openEditor(context, task: task),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _completeToggle(context, ref, done, accent),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  height: 1.15,
                                  decoration:
                                      done ? TextDecoration.lineThrough : null,
                                  color: done ? theme.hintColor : null,
                                ),
                              ),
                              if (task.note != null &&
                                  task.note!.trim().isNotEmpty) ...[
                                const SizedBox(height: 3),
                                Text(task.note!,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodySmall
                                        ?.copyWith(color: theme.hintColor)),
                              ],
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _chip(
                                      overdue && !done
                                          ? Icons.warning_amber_rounded
                                          : Icons.event_rounded,
                                      due == null ? 'No date' : _dueLabel(),
                                      dueColor,
                                      strong: overdue && !done),
                                  if (hasTime)
                                    _chip(Icons.schedule_rounded,
                                        _timeLabel(context), theme.hintColor),
                                  if (task.type != TaskType.task)
                                    _chip(task.type.icon, task.type.label,
                                        task.type.color),
                                  if (task.hasSubtasks)
                                    _chip(
                                        Icons.checklist_rounded,
                                        '${task.subtasksDone}/${task.subtasks.length}',
                                        task.priority.color),
                                ],
                              ),
                              // Subtask progress bar.
                              if (task.hasSubtasks && !done) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: LinearProgressIndicator(
                                    value: subtaskProgress,
                                    minHeight: 5,
                                    backgroundColor: theme.dividerColor,
                                    valueColor: AlwaysStoppedAnimation(
                                        task.priority.color),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Trailing: link action, else subject identity avatar.
                        if (task.hasLink) ...[
                          const SizedBox(width: 10),
                          Material(
                            color: task.type.color.withValues(alpha: 0.14),
                            shape: const CircleBorder(),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => openUrl(context, task.link),
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: Icon(
                                  task.type == TaskType.video
                                      ? Icons.play_arrow_rounded
                                      : Icons.open_in_new_rounded,
                                  size: 19,
                                  color: task.type.color,
                                ),
                              ),
                            ),
                          ),
                        ] else if (subject != null) ...[
                          const SizedBox(width: 10),
                          Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(subject.colorHex)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(SubjectIcons.resolve(subject.iconKey),
                                size: 20, color: Color(subject.colorHex)),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom-sheet editor for adding/editing a task.
class TaskEditorSheet extends ConsumerStatefulWidget {
  final TaskItem? task;
  final TaskType? initialType;
  final DateTime? initialDue;

  /// Pre-fill values for a brand-new item (e.g. from the Android share sheet).
  /// Ignored when editing an existing [task]. All remain fully editable.
  final String? initialTitle;
  final String? initialNote;
  final String? initialLink;
  final String? initialThumbnail;

  const TaskEditorSheet({
    super.key,
    this.task,
    this.initialType,
    this.initialDue,
    this.initialTitle,
    this.initialNote,
    this.initialLink,
    this.initialThumbnail,
  });

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late final TextEditingController _link;
  String? _subjectId;
  DateTime? _due;
  TaskPriority _priority = TaskPriority.medium;
  TaskType _type = TaskType.task;
  String? _thumbnail;
  final List<_SubtaskField> _subtasks = [];

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? widget.initialTitle ?? '');
    _note = TextEditingController(text: t?.note ?? widget.initialNote ?? '');
    _link = TextEditingController(text: t?.link ?? widget.initialLink ?? '');
    _subjectId = t?.subjectId;
    _due = t?.dueDate ?? widget.initialDue;
    _priority = t?.priority ?? TaskPriority.medium;
    _type = t?.type ?? widget.initialType ?? TaskType.task;
    _thumbnail = t?.thumbnail ?? widget.initialThumbnail;
    _subtasks.addAll((t?.subtasks ?? const [])
        .map((s) => _SubtaskField(text: s.text, done: s.done)));
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _link.dispose();
    for (final s in _subtasks) {
      s.dispose();
    }
    super.dispose();
  }

  List<ChecklistItem> _buildSubtasks() => _subtasks
      .where((s) => s.controller.text.trim().isNotEmpty)
      .map((s) => ChecklistItem(text: s.controller.text.trim(), done: s.done))
      .toList();

  void _addSubtask() => setState(() => _subtasks.add(_SubtaskField()));

  Widget _subtasksSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Checklist', style: theme.textTheme.labelLarge),
            const Spacer(),
            TextButton.icon(
              onPressed: _addSubtask,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add step'),
            ),
          ],
        ),
        for (var i = 0; i < _subtasks.length; i++)
          _subtaskRow(i, _subtasks[i]),
      ],
    );
  }

  Widget _subtaskRow(int i, _SubtaskField s) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => s.done = !s.done),
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: s.done ? AppColors.primary : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                    color: s.done ? AppColors.primary : theme.dividerColor,
                    width: 2),
              ),
              child: s.done
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: s.controller,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'Step',
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close_rounded, size: 18, color: theme.hintColor),
            onPressed: () => setState(() {
              s.dispose();
              _subtasks.removeAt(i);
            }),
          ),
        ],
      ),
    );
  }

  Widget _thumbnailPreview(ThemeData theme) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              _thumbnail!,
              fit: BoxFit.cover,
              // Keep the sheet usable if the preview can't load — just hide it.
              errorBuilder: (_, __, ___) => Container(
                color: theme.scaffoldBackgroundColor,
                alignment: Alignment.center,
                child: Icon(_type.icon, size: 36, color: theme.hintColor),
              ),
              loadingBuilder: (ctx, child, progress) => progress == null
                  ? child
                  : Container(
                      color: theme.scaffoldBackgroundColor,
                      alignment: Alignment.center,
                      child: const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
            ),
          ),
          Positioned(
            top: 6,
            right: 6,
            child: Material(
              color: Colors.black.withValues(alpha: 0.45),
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => setState(() => _thumbnail = null),
                child: const Padding(
                  padding: EdgeInsets.all(4),
                  child:
                      Icon(Icons.close_rounded, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _dueHasTime =>
      _due != null && !(_due!.hour == 0 && _due!.minute == 0);

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) {
      // Keep any time-of-day already chosen when only the date changes.
      final prev = _due;
      final keepTime = prev != null && !(prev.hour == 0 && prev.minute == 0);
      setState(() => _due = keepTime
          ? DateTime(picked.year, picked.month, picked.day, prev.hour,
              prev.minute)
          : picked);
    }
  }

  Future<void> _pickTime() async {
    final base = _due ?? DateTime.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (picked != null) {
      final d = _due ?? DateTime.now();
      setState(() =>
          _due = DateTime(d.year, d.month, d.day, picked.hour, picked.minute));
    }
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final link = _link.text.trim();
    final thumb = link.isEmpty ? null : _thumbnail;
    final controller = ref.read(taskControllerProvider);
    if (_isEdit) {
      controller.update(widget.task!.copyWith(
        title: _title.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        subjectId: _subjectId,
        dueDate: _due,
        priority: _priority,
        type: _type,
        link: link.isEmpty ? null : link,
        thumbnail: thumb,
        clearDue: _due == null,
        clearSubject: _subjectId == null,
        clearLink: link.isEmpty,
        subtasks: _buildSubtasks(),
      ));
    } else {
      controller.add(TaskItem(
        id: '',
        title: _title.text.trim(),
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        subjectId: _subjectId,
        dueDate: _due,
        priority: _priority,
        type: _type,
        link: link.isEmpty ? null : link,
        thumbnail: thumb,
        subtasks: _buildSubtasks(),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Text(_isEdit ? 'Edit item' : 'New item',
                style: theme.textTheme.titleLarge),
            if (_thumbnail != null && _thumbnail!.isNotEmpty) ...[
              const SizedBox(height: 14),
              _thumbnailPreview(theme),
            ],
            const SizedBox(height: 14),
            Row(
              children: TaskType.values.map((t) {
                final selected = t == _type;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _type = t),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? t.color.withValues(alpha: 0.14)
                              : theme.scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected ? t.color : theme.dividerColor,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(t.icon,
                                size: 20,
                                color: selected ? t.color : theme.hintColor),
                            const SizedBox(height: 4),
                            Text(t.label,
                                style: theme.textTheme.labelMedium?.copyWith(
                                  color: selected ? t.color : theme.hintColor,
                                  fontWeight: FontWeight.w600,
                                )),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              autofocus: !_isEdit,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'e.g. DBMS assignment 2',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 14),
            _subtasksSection(theme),
            const SizedBox(height: 12),
            TextField(
              controller: _link,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: _type == TaskType.task
                    ? 'Link (optional)'
                    : '${_type.label} link',
                hintText: 'https://youtube.com/…',
                prefixIcon: const Icon(Icons.link_rounded),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _subjectId,
              isExpanded: true,
              decoration:
                  const InputDecoration(labelText: 'Subject (optional)'),
              items: [
                const DropdownMenuItem(value: null, child: Text('None')),
                ...subjects.map((s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(s.name, overflow: TextOverflow.ellipsis),
                    )),
              ],
              onChanged: (v) => setState(() => _subjectId = v),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDue,
                    icon: const Icon(Icons.event_rounded, size: 18),
                    label: Text(_due == null
                        ? 'Set due date'
                        : DateUtilsX.prettyDate(_due!)),
                  ),
                ),
                if (_due != null)
                  IconButton(
                    tooltip: 'Clear date',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _due = null),
                  ),
              ],
            ),
            if (_due != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _pickTime,
                      icon: const Icon(Icons.schedule_rounded, size: 18),
                      label: Text(_dueHasTime
                          ? TimeOfDay.fromDateTime(_due!).format(context)
                          : 'Add time (all day)'),
                    ),
                  ),
                  if (_dueHasTime)
                    IconButton(
                      tooltip: 'Clear time',
                      icon: const Icon(Icons.close_rounded),
                      // Reset to midnight → treated as an all-day item.
                      onPressed: () => setState(() => _due =
                          DateTime(_due!.year, _due!.month, _due!.day)),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Text('Priority', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              children: TaskPriority.values.map((p) {
                final selected = p == _priority;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => _priority = p),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected
                              ? p.color
                              : p.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: selected ? Colors.white : p.color,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              p.label,
                              style: TextStyle(
                                color: selected ? Colors.white : p.color,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _save,
                child: Text(
                    _isEdit ? 'Save' : 'Add ${_type.label.toLowerCase()}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Editable subtask row backing (text field + done flag).
class _SubtaskField {
  final TextEditingController controller;
  bool done;
  _SubtaskField({String text = '', this.done = false})
      : controller = TextEditingController(text: text);
  void dispose() => controller.dispose();
}
