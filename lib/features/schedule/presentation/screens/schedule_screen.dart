import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:classtrack/core/theme/app_icons.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../shared/widgets/states.dart';
import '../../../../shared/widgets/ui_kit.dart';
import '../../../settings/presentation/screens/settings_screen.dart';
import '../../../attendance/domain/attendance_record.dart';
import '../../../attendance/presentation/providers/attendance_providers.dart';
import '../../../exams/domain/exam.dart';
import '../../../exams/presentation/providers/exam_providers.dart';
import '../../../exams/presentation/screens/exams_screen.dart';
import '../../../subjects/presentation/providers/subject_providers.dart';
import '../../../tasks/domain/task_item.dart';
import '../../../tasks/presentation/providers/task_providers.dart';
import '../../../tasks/presentation/screens/tasks_screen.dart';
import '../providers/schedule_providers.dart';
import 'edit_session_screen.dart';

enum ScheduleView { day, week, month }

class ScheduleScreen extends ConsumerStatefulWidget {
  const ScheduleScreen({super.key});

  @override
  ConsumerState<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends ConsumerState<ScheduleScreen> {
  ScheduleView _view = ScheduleView.day;
  DateTime _selectedDay = DateTime.now();
  DateTime _focusedDay = DateTime.now();

  void _openEditor() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EditSessionScreen()),
    );
  }

  void _showClassSheet(ScheduledClass c, DateTime date) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final theme = Theme.of(ctx);
        final color = Color(c.subject.colorHex);
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(width: 10, height: 10,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(c.subject.name,
                        style: theme.textTheme.titleLarge),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${DateUtilsX.displayTime(ctx, c.session.startTime)} – ${DateUtilsX.displayTime(ctx, c.session.endTime)}'
                '${c.session.room?.isNotEmpty == true ? '  ·  ${c.session.room}' : ''}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 18),
              Text('Mark attendance', style: theme.textTheme.labelLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final s in [
                    AttendanceStatus.present,
                    AttendanceStatus.absent,
                    AttendanceStatus.cancelled,
                  ]) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: s.color,
                          side: BorderSide(color: s.color),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () {
                          // Mark this specific class occurrence (per session),
                          // idempotent so it matches Home/Progress and never
                          // double-counts.
                          ref.read(attendanceControllerProvider).setForOccurrence(
                              c.subject.id, date, c.session.startTime, s);
                          Navigator.pop(ctx);
                        },
                        icon: Icon(s.icon, size: 18),
                        label: Text(s.label,
                            style: const TextStyle(fontSize: 12)),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                  Text('Schedule', style: theme.textTheme.displaySmall),
                  const Spacer(),
                  RoundIconButton(
                    icon: Icons.add_rounded,
                    background: AppColors.primary,
                    iconColor: Colors.white,
                    onTap: _openEditor,
                  ),
                  const SizedBox(width: 10),
                  RoundIconButton(
                    icon: Icons.settings_rounded,
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => const SettingsScreen())),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: ScheduleView.values.map((v) {
                  final selected = v == _view;
                  final label = switch (v) {
                    ScheduleView.day => 'Day',
                    ScheduleView.week => 'Week',
                    ScheduleView.month => 'Month',
                  };
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () => setState(() => _view = v),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 22, vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? AppColors.ink : theme.cardColor,
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: Text(
                          label,
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
            const SizedBox(height: 12),
            Expanded(
              child: switch (_view) {
                ScheduleView.day => _dayView(),
                ScheduleView.week => _weekView(),
                ScheduleView.month => _monthView(),
              },
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- DAY ----------------
  Widget _dayView() {
    final classes = ref.watch(classesForDayProvider(_selectedDay));
    final dueTasks = ref.watch(tasksForDayProvider(_selectedDay));
    final allExams = ref.watch(examsStreamProvider).valueOrNull ?? const [];
    final exams = allExams
        .where((e) => DateUtilsX.isSameDay(e.date, _selectedDay))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final isEmpty = classes.isEmpty && dueTasks.isEmpty && exams.isEmpty;

    return Column(
      children: [
        _dateStrip(),
        Expanded(
          child: isEmpty
              ? EmptyState(
                  icon: PhosphorIcons.coffee(),
                  title: 'Nothing scheduled',
                  message:
                      'No classes, tasks, or exams for ${DateUtilsX.prettyDate(_selectedDay)}. Enjoy the break!',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  children: [
                    if (exams.isNotEmpty) ...[
                      _sectionLabel('Exams', AppColors.danger),
                      for (final e in exams) _examTile(e),
                      const SizedBox(height: 6),
                    ],
                    if (classes.isNotEmpty) ...[
                      _sectionLabel('Classes', AppColors.info),
                      for (var i = 0; i < classes.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _classTile(classes[i], _selectedDay)
                              .animate()
                              .fadeIn(delay: (i * 60).ms, duration: 320.ms)
                              .slideX(
                                  begin: 0.08, curve: Curves.easeOutCubic),
                        ),
                      const SizedBox(height: 6),
                    ],
                    if (dueTasks.isNotEmpty) ...[
                      _sectionLabel('Tasks', AppColors.primary),
                      for (final t in dueTasks) _taskTile(t),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _dateStrip() {
    final today = DateTime.now();
    return SizedBox(
      height: 84,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: 21,
        itemBuilder: (context, i) {
          final date = DateTime(today.year, today.month, today.day)
              .add(Duration(days: i - 3));
          final selected = DateUtilsX.isSameDay(date, _selectedDay);
          final theme = Theme.of(context);
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = date),
            child: Container(
              width: 56,
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? AppColors.primary : theme.dividerColor,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    Weekdays.short[date.weekday - 1],
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected ? Colors.white70 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.day}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: selected ? Colors.white : null,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ---------------- WEEK ----------------
  Widget _weekView() {
    final theme = Theme.of(context);
    final todayIdx = DateTime.now().weekday - 1;
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      itemCount: 7,
      itemBuilder: (context, day) {
        final classes = ref.watch(classesForWeekdayProvider(day));
        final isToday = day == todayIdx;
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: softCard(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(Weekdays.full[day], style: theme.textTheme.titleMedium),
                  if (isToday) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text('Today',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    classes.isEmpty
                        ? 'Free'
                        : '${classes.length} ${classes.length == 1 ? 'class' : 'classes'}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              if (classes.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text('No classes — free day 🎉',
                      style: theme.textTheme.bodySmall),
                )
              else ...[
                const SizedBox(height: 12),
                ...classes.map((c) => _classTileStatic(c)),
              ],
            ],
          ),
        );
      },
    );
  }

  // ---------------- MONTH ----------------
  Widget _monthView() {
    final theme = Theme.of(context);
    final classes = ref.watch(classesForDayProvider(_selectedDay));
    final tasks = ref.watch(tasksForDayProvider(_selectedDay));
    final allExams = ref.watch(examsStreamProvider).valueOrNull ?? const [];
    final exams = allExams
        .where((e) => DateUtilsX.isSameDay(e.date, _selectedDay))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Watch tasks/exams streams so markers refresh on change.
    ref.watch(tasksStreamProvider);

    List<Object> eventsFor(DateTime day) => [
          ...ref.read(classesForDayProvider(day)),
          ...ref.read(tasksForDayProvider(day)),
          ...(ref.read(examsStreamProvider).valueOrNull ?? const [])
              .where((e) => DateUtilsX.isSameDay(e.date, day)),
        ];

    final nothing = classes.isEmpty && tasks.isEmpty && exams.isEmpty;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(26),
            boxShadow: theme.brightness == Brightness.light
                ? AppColors.softShadow(opacity: 0.06, blur: 22)
                : null,
          ),
          child: TableCalendar<Object>(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (d) => DateUtilsX.isSameDay(d, _selectedDay),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            eventLoader: eventsFor,
            onDaySelected: (selected, focused) => setState(() {
              _selectedDay = selected;
              _focusedDay = focused;
            }),
            headerStyle: HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
              leftChevronIcon: const Icon(Icons.chevron_left_rounded),
              rightChevronIcon: const Icon(Icons.chevron_right_rounded),
              titleTextStyle: theme.textTheme.titleLarge!,
            ),
            daysOfWeekStyle: DaysOfWeekStyle(
              weekdayStyle: theme.textTheme.bodySmall!,
              weekendStyle: theme.textTheme.bodySmall!,
            ),
            calendarStyle: CalendarStyle(
              isTodayHighlighted: true,
              markersMaxCount: 1,
              markerSize: 5,
              markerMargin: const EdgeInsets.only(top: 1),
              markerDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: theme.textTheme.bodyMedium!,
              weekendTextStyle: theme.textTheme.bodyMedium!,
              outsideTextStyle: theme.textTheme.bodySmall!
                  .copyWith(color: theme.disabledColor),
              todayDecoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              todayTextStyle: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700),
              selectedDecoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        const SizedBox(height: 18),
        Text(DateUtilsX.prettyFullDate(_selectedDay),
            style: theme.textTheme.titleMedium),
        const SizedBox(height: 12),
        if (nothing)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(PhosphorIcons.coffee(), color: theme.hintColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Nothing scheduled this day',
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          )
        else ...[
          if (exams.isNotEmpty) ...[
            _sectionLabel('Exams', AppColors.danger),
            for (final e in exams) _examTile(e),
            const SizedBox(height: 6),
          ],
          if (classes.isNotEmpty) ...[
            _sectionLabel('Classes', AppColors.info),
            for (final c in classes) _monthEventCard(c),
            const SizedBox(height: 6),
          ],
          if (tasks.isNotEmpty) ...[
            _sectionLabel('Tasks', AppColors.primary),
            for (final t in tasks) _taskTile(t),
          ],
        ],
      ],
    );
  }

  /// Soft, subject-tinted agenda card (matches the calendar reference design).
  Widget _monthEventCard(ScheduledClass c) {
    final theme = Theme.of(context);
    final color = Color(c.subject.colorHex);
    final time =
        '${DateUtilsX.displayTime(context, c.session.startTime)} – ${DateUtilsX.displayTime(context, c.session.endTime)}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _showClassSheet(c, _selectedDay),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(PhosphorIcons.clock(), size: 14, color: color),
                          const SizedBox(width: 6),
                          Text(time,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: color, fontWeight: FontWeight.w600)),
                          if (c.session.room != null &&
                              c.session.room!.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text('· ${c.session.room}',
                                style: theme.textTheme.bodySmall),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: color.withOpacity(0.9), shape: BoxShape.circle),
                  child: const Icon(Icons.chevron_right_rounded,
                      color: Colors.white, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- shared tiles ----------------
  Widget _classTile(ScheduledClass c, DateTime date) {
    final theme = Theme.of(context);
    final color = Color(c.subject.colorHex);
    final hasRoom = c.session.room != null && c.session.room!.isNotEmpty;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Time rail
          SizedBox(
            width: 66,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateUtilsX.displayTime(context, c.session.startTime),
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 2),
                Text(
                  DateUtilsX.displayTime(context, c.session.endTime),
                  style: theme.textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 4,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Material(
              color: color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(18),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _showClassSheet(c, date),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(c.subject.name,
                                style: theme.textTheme.titleMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (hasRoom) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.meeting_room_outlined,
                                      size: 13, color: color),
                                  const SizedBox(width: 5),
                                  Text(c.session.room!,
                                      style: theme.textTheme.bodySmall),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right_rounded, color: color),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classTileStatic(ScheduledClass c) {
    final theme = Theme.of(context);
    final color = Color(c.subject.colorHex);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 4,
              height: 36,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(4)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(c.subject.name,
                      style: theme.textTheme.titleMedium?.copyWith(fontSize: 15),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(
                    '${DateUtilsX.displayTime(context, c.session.startTime)} – ${DateUtilsX.displayTime(context, c.session.endTime)}',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------- tasks & exams ----------------
  Widget _sectionLabel(String text, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(text,
              style: theme.textTheme.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _examTile(Exam e) {
    final theme = Theme.of(context);
    final byId = ref.watch(subjectsByIdProvider);
    final subject = e.subjectId != null ? byId[e.subjectId] : null;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.danger.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => ExamEditorSheet(initial: e),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                      color: AppColors.danger.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.event_note_rounded,
                      color: AppColors.danger, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title,
                          style: theme.textTheme.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      Text(
                        '${TimeOfDay.fromDateTime(e.date).format(context)}'
                        '${subject != null ? ' · ${subject.name}' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                PillTag(
                    label: e.countdownLabel,
                    background: AppColors.danger,
                    foreground: Colors.white),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _taskTile(TaskItem t) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: softCard(context),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => ref.read(taskControllerProvider).toggle(t),
              child: Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: t.done ? AppColors.primary : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color:
                          t.done ? AppColors.primary : theme.dividerColor,
                      width: 2),
                ),
                child: t.done
                    ? const Icon(Icons.check_rounded,
                        size: 15, color: Colors.white)
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => TaskEditorSheet(task: t),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          decoration:
                              t.done ? TextDecoration.lineThrough : null,
                          color: t.done ? theme.hintColor : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                    Row(
                      children: [
                        Icon(t.type.icon, size: 12, color: t.type.color),
                        const SizedBox(width: 5),
                        Text(t.type.label, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 4,
              height: 32,
              decoration: BoxDecoration(
                  color: t.priority.color,
                  borderRadius: BorderRadius.circular(4)),
            ),
          ],
        ),
      ),
    );
  }
}
