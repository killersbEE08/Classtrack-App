import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_settings_provider.dart';
import '../core/providers/notification_prefs_provider.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../features/exams/presentation/providers/exam_providers.dart';
import '../features/habits/presentation/providers/habit_providers.dart';
import '../features/schedule/domain/class_session.dart';
import '../features/schedule/presentation/providers/schedule_providers.dart';
import '../features/subjects/domain/subject.dart';
import '../features/subscription/presentation/providers/subscription_providers.dart';
import '../features/tasks/presentation/providers/task_providers.dart';
import 'notification_service.dart';

/// Keeps class, task, exam & habit reminders in sync with the latest data and
/// the user's notification preferences while the app is open. Watched once
/// (by HomeShell) so it re-runs whenever the schedule/tasks/exams/prefs change
/// and reminders are enabled. Scheduling overwrites by id, so re-running is
/// idempotent; disabled categories are actively cancelled.
final reminderSyncProvider = Provider<void>((ref) {
  if (!ref.watch(remindersEnabledProvider)) return;
  final service = ref.watch(notificationServiceProvider);
  final lead = ref.watch(reminderLeadProvider);
  final prefs = ref.watch(notificationPrefsProvider);
  final isPro = ref.watch(isProProvider);

  final tasks = ref.watch(tasksStreamProvider).valueOrNull ?? const [];
  final exams = ref.watch(examsStreamProvider).valueOrNull ?? const [];
  final habits = ref.watch(habitsStreamProvider).valueOrNull ?? const [];
  final scheduledClasses = ref.watch(allSessionsProvider);

  // ── Classes ──────────────────────────────────────────────────────────────
  final sessionsBySubject = <String, List<ClassSession>>{};
  final subjectsById = <String, Subject>{};
  for (final sc in scheduledClasses) {
    sessionsBySubject.putIfAbsent(sc.subject.id, () => []).add(sc.session);
    subjectsById[sc.subject.id] = sc.subject;
  }
  if (prefs.classes) {
    for (final entry in sessionsBySubject.entries) {
      final subject = subjectsById[entry.key];
      if (subject != null) {
        service.scheduleForSubject(subject, entry.value,
            minutesBefore: lead, prefs: prefs);
      }
    }
  } else {
    for (final id in sessionsBySubject.keys) {
      service.cancelForSubject(id);
    }
  }

  // ── Tasks ────────────────────────────────────────────────────────────────
  if (prefs.tasks) {
    service.scheduleForTasks(tasks, minutesBefore: lead, prefs: prefs);
  } else {
    for (final t in tasks) {
      service.cancelTask(t.id);
    }
  }

  // ── Exams ────────────────────────────────────────────────────────────────
  if (prefs.exams) {
    service.scheduleForExams(exams, minutesBefore: 30, prefs: prefs);
  } else {
    for (final e in exams) {
      service.cancelExam(e.id);
    }
  }

  // ── Habits ───────────────────────────────────────────────────────────────
  if (prefs.habits) {
    service.scheduleForHabits(habits, prefs: prefs);
  } else {
    for (final h in habits) {
      service.cancelHabit(h.id);
    }
  }

  // ── Daily agenda summary (Pro) ───────────────────────────────────────────
  if (isPro && prefs.dailySummary) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final classCount =
        scheduledClasses.where((c) => c.session.occursOn(now)).length;
    final dueToday = tasks
        .where((t) =>
            !t.done &&
            t.dueDate != null &&
            DateUtilsX.isSameDay(t.dueDate!, now))
        .length;
    final examsSoon = exams
        .where((e) =>
            !e.date.isBefore(today) &&
            e.date.isBefore(today.add(const Duration(days: 2))))
        .length;
    final parts = <String>[
      '$classCount class${classCount == 1 ? '' : 'es'}',
      if (dueToday > 0) '$dueToday task${dueToday == 1 ? '' : 's'} due',
      if (examsSoon > 0) '$examsSoon exam${examsSoon == 1 ? '' : 's'} soon',
    ];
    service.scheduleDailySummary(
      hour: prefs.summaryHour,
      minute: prefs.summaryMinute,
      title: 'Your day at a glance',
      body: 'Today: ${parts.join(' · ')}. Tap to plan your day.',
    );
  } else {
    service.cancelDailySummary();
  }
});



/// Requests notification permission and, if granted, turns reminders on (which
/// makes [reminderSyncProvider] schedule everything). Safe to call from a
/// button tap.
Future<void> enableRemindersFlow(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final service = ref.read(notificationServiceProvider);
  final granted = await service.requestPermissions();
  if (granted) {
    await ref.read(remindersEnabledProvider.notifier).set(true);
    messenger.showSnackBar(const SnackBar(
        content: Text(
            "Reminders on — you'll be notified before classes, tasks and exams.")));
  } else {
    messenger.showSnackBar(const SnackBar(
        content: Text('Notification permission was denied.')));
  }
}

/// A small opt-in card shown only while reminders are OFF. Tapping Enable
/// requests permission and turns them on; the card then disappears.
class RemindersBanner extends ConsumerWidget {
  const RemindersBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(remindersEnabledProvider)) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_rounded,
              color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Turn on reminders',
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                Text('Get notified before classes, tasks and exams.',
                    style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: () => enableRemindersFlow(context, ref),
            style: FilledButton.styleFrom(
                minimumSize: const Size(0, 40),
                padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }
}
