import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/subject_icons.dart';
import '../../../../core/models/checklist_item.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/url_launcher_util.dart';
import '../../../../shared/widgets/progress_ring.dart';
import '../../../../shared/widgets/states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../domain/task_item.dart';
import '../providers/task_providers.dart';

enum TaskFilter { all, inProgress, completed }

extension on TaskFilter {
  String get label => switch (this) {
        TaskFilter.all => 'All Tasks',
        TaskFilter.inProgress => 'In Progress',
        TaskFilter.completed => 'Completed',
      };
}

class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  TaskFilter _filter = TaskFilter.all;
  String _query = '';

  static void openEditor(BuildContext context, {TaskItem? task}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskEditorSheet(task: task),
    );
  }

  /// Tasks grouped by due status for a scannable list.
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
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 120),
      children: [
        for (final (label, list, color) in sections)
          if (list.isNotEmpty) ...[
            _sectionHeader(theme, label, list.length, color),
            for (final t in list)
              _TaskCard(task: t)
                  .animate()
                  .fadeIn(delay: (i++ * 40).ms, duration: 300.ms)
                  .slideY(begin: 0.08, curve: Curves.easeOutCubic),
          ],
      ],
    );
  }

  Widget _progressCard(
      ThemeData theme, int done, int total, int todo, int overdue) {
    final pct = total == 0 ? 0.0 : (done / total) * 100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: softCard(context),
      child: Row(
        children: [
          AnimatedProgressRing(
            percent: pct,
            size: 56,
            strokeWidth: 6,
            color: AppColors.success,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$done of $total done',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _miniStat(theme, '$todo', 'to-do', AppColors.primary),
                    const SizedBox(width: 8),
                    _miniStat(theme, '$overdue', 'overdue',
                        overdue > 0 ? AppColors.danger : AppColors.cancelled),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStat(ThemeData theme, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w800, fontSize: 13)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _sectionHeader(
      ThemeData theme, String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
            const SizedBox(width: 6),
            Text('$count',
                style: TextStyle(
                    color: color.withValues(alpha: 0.7),
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
          ],
        ),
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
    final canPop = Navigator.of(context).canPop();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  if (canPop) ...[
                    RoundIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  if (doneCount > 0)
                    TextButton.icon(
                      onPressed: () => _clearCompleted(context, allTasks),
                      icon: const Icon(Icons.done_all_rounded, size: 16),
                      label: const Text('Clear done'),
                    ),
                  RoundIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Your tasks',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                    allTasks.isEmpty
                        ? 'Add your first task'
                        : (todoCount == 0
                            ? 'All caught up 🎉'
                            : '$todoCount to do · $doneCount done'),
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (allTasks.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: _progressCard(
                    theme, doneCount, allTasks.length, todoCount, overdueCount),
              ),
            if (allTasks.length > 4)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
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
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                children: TaskFilter.values.map((f) {
                  final selected = f == _filter;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _filter = f),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 9),
                        decoration: BoxDecoration(
                          color: selected
                              ? AppColors.primary
                              : theme.cardColor,
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: selected
                                ? AppColors.primary
                                : theme.dividerColor,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          f.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: selected
                                ? Colors.white
                                : theme.textTheme.bodySmall?.color,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
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
                      child: Text(
                          q.isEmpty ? 'Nothing here yet' : 'No matches',
                          style: theme.textTheme.bodyMedium),
                    );
                  }
                  return _groupedList(context, searched);
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
    if (DateUtilsX.isSameDay(
        task.dueDate!, now.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    return DateUtilsX.prettyDate(task.dueDate!);
  }

  /// Time shown at the top of the card (mirrors the reference's time line).
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(24),
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
      onDismissed: (_) => ref.read(taskControllerProvider).delete(task.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: softCard(context),
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
  const TaskEditorSheet(
      {super.key, this.task, this.initialType, this.initialDue});

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
  final List<_SubtaskField> _subtasks = [];

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _note = TextEditingController(text: t?.note ?? '');
    _link = TextEditingController(text: t?.link ?? '');
    _subjectId = t?.subjectId;
    _due = t?.dueDate ?? widget.initialDue;
    _priority = t?.priority ?? TaskPriority.medium;
    _type = t?.type ?? widget.initialType ?? TaskType.task;
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

  Future<void> _pickDue() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (picked != null) setState(() => _due = picked);
  }

  void _save() {
    if (_title.text.trim().isEmpty) return;
    final link = _link.text.trim();
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
                            ? t.color.withOpacity(0.14)
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
            value: _subjectId,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Subject (optional)'),
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
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => setState(() => _due = null),
                ),
            ],
          ),
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
                            : p.color.withOpacity(0.12),
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
              child: Text(_isEdit ? 'Save' : 'Add ${_type.label.toLowerCase()}'),
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
