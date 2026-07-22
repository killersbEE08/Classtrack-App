import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../domain/habit.dart';
import '../providers/habit_providers.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  static const _dayShort = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final habitsAsync = ref.watch(habitsStreamProvider);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
          children: [
            Row(
              children: [
                RoundIconButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                _AddButton(onTap: () => _openEditor(context)),
              ],
            ),
            const SizedBox(height: 14),
            Text('Habits',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text('Build streaks, one day at a time 🔥',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.textTheme.bodySmall?.color)),
            const SizedBox(height: 18),
            habitsAsync.when(
              loading: () => const Padding(
                  padding: EdgeInsets.only(top: 40), child: LoadingView()),
              error: (e, _) => ErrorView(error: e),
              data: (habits) {
                if (habits.isEmpty) return _empty(context);
                return Column(
                  children: [
                    for (var i = 0; i < habits.length; i++)
                      _HabitCard(habit: habits[i])
                          .animate()
                          .fadeIn(delay: (i * 50).ms, duration: 300.ms)
                          .slideY(begin: 0.06, curve: Curves.easeOutCubic),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: softCard(context),
      child: Column(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 42, color: AppColors.coral),
          const SizedBox(height: 12),
          Text('No habits yet', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Text('Add habits like "Revise 30 min" or "Sleep by 11" and keep the streak alive.',
              textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openEditor(context),
            icon: const Icon(Icons.add_rounded),
            label: const Text('New habit'),
          ),
        ],
      ),
    );
  }

  static void _openEditor(BuildContext context, {Habit? habit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => HabitEditorSheet(initial: habit),
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
      borderRadius: BorderRadius.circular(30),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.fromLTRB(12, 10, 16, 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_rounded, size: 20, color: Colors.white),
              SizedBox(width: 6),
              Text('New habit',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
            ],
          ),
        ),
      ),
    );
  }
}

class _HabitCard extends ConsumerWidget {
  final Habit habit;
  const _HabitCard({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final color = Color(habit.colorHex);
    final doneToday = habit.doneToday;

    // Last 7 days (oldest -> today).
    final now = DateTime.now();
    final week = List.generate(
        7, (i) => DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: 6 - i)));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: softCard(context),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.bolt_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onLongPress: () =>
                          HabitsScreen._openEditor(context, habit: habit),
                      child: Text(habit.title,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.local_fire_department_rounded,
                            size: 14, color: AppColors.coral),
                        const SizedBox(width: 4),
                        Text('${habit.streak} day streak',
                            style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: FontWeight.w600)),
                        if (habit.totalDays > 0) ...[
                          Text('  ·  ${habit.totalDays} days total',
                              style: theme.textTheme.bodySmall),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              _toggle(context, ref, color, doneToday),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _dayDot(context, ref, HabitsScreen._dayShort[week[i].weekday - 1],
                    week[i], habit.doneOn(week[i]), color,
                    isToday: DateUtilsX.isSameDay(week[i], now)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _toggle(
      BuildContext context, WidgetRef ref, Color color, bool doneToday) {
    return GestureDetector(
      onTap: () => ref.read(habitControllerProvider).toggleToday(habit),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: doneToday ? color : color.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(
          doneToday ? Icons.check_rounded : Icons.add_rounded,
          color: doneToday ? Colors.white : color,
          size: 24,
        ),
      ),
    );
  }

  Widget _dayDot(BuildContext context, WidgetRef ref, String label,
      DateTime date, bool done, Color color,
      {required bool isToday}) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => ref.read(habitControllerProvider).toggleDate(habit, date),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: done ? color : theme.dividerColor.withValues(alpha: 0.4),
              shape: BoxShape.circle,
              border: isToday ? Border.all(color: color, width: 2) : null,
            ),
            child: done
                ? const Icon(Icons.check_rounded, size: 16, color: Colors.white)
                : null,
          ),
          const SizedBox(height: 4),
          Text(label, style: theme.textTheme.bodySmall?.copyWith(fontSize: 10)),
        ],
      ),
    );
  }
}

class HabitEditorSheet extends ConsumerStatefulWidget {
  final Habit? initial;
  const HabitEditorSheet({super.key, this.initial});

  @override
  ConsumerState<HabitEditorSheet> createState() => _HabitEditorSheetState();
}

class _HabitEditorSheetState extends ConsumerState<HabitEditorSheet> {
  late final TextEditingController _title;
  late int _color;
  int? _reminder;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.initial?.title ?? '');
    _color = widget.initial?.colorHex ??
        AppColors.subjectPalette.first.toARGB32();
    _reminder = widget.initial?.reminderMinutes;
  }

  Future<void> _pickReminder() async {
    final initial = _reminder != null
        ? TimeOfDay(hour: _reminder! ~/ 60, minute: _reminder! % 60)
        : const TimeOfDay(hour: 20, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() => _reminder = picked.hour * 60 + picked.minute);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the habit a name.')));
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final isNew = widget.initial == null;

    // Without a signed-in user there is no repository to write to, which is
    // why "nothing happens" when adding a habit — surface that clearly.
    if (ref.read(habitRepositoryProvider) == null) {
      messenger.showSnackBar(const SnackBar(
          content: Text('Please sign in to save habits.')));
      return;
    }

    final ctrl = ref.read(habitControllerProvider);
    try {
      if (isNew) {
        await ctrl.add(Habit(
            id: 'new',
            title: title,
            colorHex: _color,
            reminderMinutes: _reminder));
      } else {
        await ctrl.update(widget.initial!.copyWith(
            title: title,
            colorHex: _color,
            reminderMinutes: _reminder,
            clearReminder: _reminder == null));
      }
      navigator.pop();
      messenger.showSnackBar(SnackBar(
          content: Text(isNew ? 'Habit added 🔥' : 'Habit updated'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(
          content: Text("Couldn't save habit. Please try again.")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
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
                    borderRadius: BorderRadius.circular(4)),
              ),
            ),
            Text(widget.initial == null ? 'New habit' : 'Edit habit',
                style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Habit (e.g. Revise 30 min)'),
            ),
            const SizedBox(height: 16),
            Text('Color', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final c in AppColors.subjectPalette)
                  GestureDetector(
                    onTap: () => setState(() => _color = c.toARGB32()),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: _color == c.toARGB32()
                            ? Border.all(
                                color: theme.colorScheme.onSurface, width: 3)
                            : null,
                      ),
                      child: _color == c.toARGB32()
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.notifications_active_rounded,
                    size: 18, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Daily reminder',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
                if (_reminder != null) ...[
                  ActionChip(
                    label: Text(TimeOfDay(
                            hour: _reminder! ~/ 60, minute: _reminder! % 60)
                        .format(context)),
                    onPressed: _pickReminder,
                  ),
                  IconButton(
                    onPressed: () => setState(() => _reminder = null),
                    icon: const Icon(Icons.close_rounded, size: 18),
                    tooltip: 'Turn off',
                  ),
                ] else
                  OutlinedButton(
                    onPressed: _pickReminder,
                    // The app theme sets a full-width minimumSize
                    // (Size.fromHeight -> width == infinity). As a non-flex
                    // child of this Row the button would be measured with
                    // unbounded width and crash the whole sheet with
                    // "BoxConstraints forces an infinite width". Override with a
                    // content-sized minimum so it lays out correctly.
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    child: const Text('Set time'),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                if (widget.initial != null)
                  IconButton(
                    onPressed: () {
                      ref
                          .read(habitControllerProvider)
                          .delete(widget.initial!.id);
                      Navigator.pop(context);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: AppColors.danger),
                  ),
                Expanded(
                  child: FilledButton(
                      onPressed: _save, child: const Text('Save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
