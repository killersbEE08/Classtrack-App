import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/providers/app_settings_provider.dart';
import '../core/providers/notification_prefs_provider.dart';
import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../core/utils/date_utils.dart';
import '../features/auth/presentation/providers/auth_providers.dart';
import '../features/exams/presentation/providers/exam_providers.dart';
import '../features/habits/presentation/providers/habit_providers.dart';
import '../features/insights/domain/insight_math.dart';
import '../features/schedule/domain/class_session.dart';
import '../features/schedule/presentation/providers/schedule_providers.dart';
import '../features/subjects/domain/subject.dart';
import '../features/subjects/presentation/providers/subject_providers.dart';
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
    // Cancel reminders for subjects removed/deleted since the last sync so they
    // don't keep firing, then (re)schedule reminders for the current subjects.
    final currentSubjectIds = sessionsBySubject.keys.toSet();
    service.pruneClassReminders(currentSubjectIds);
    for (final entry in sessionsBySubject.entries) {
      final subject = subjectsById[entry.key];
      if (subject != null) {
        service.scheduleForSubject(subject, entry.value,
            minutesBefore: lead, prefs: prefs);
      }
    }
  } else {
    // Class reminders disabled: cancel everything we've tracked (including any
    // now-deleted subjects) plus the current ones, and clear the baseline.
    service.pruneClassReminders(<String>{});
    for (final id in sessionsBySubject.keys) {
      service.cancelForSubject(id);
    }
  }

  // ── Attendance check-ins (after each class ends) ──────────────────────────
  if (prefs.attendanceCheckIns) {
    final currentSubjectIds = sessionsBySubject.keys.toSet();
    service.pruneAttendanceCheckIns(currentSubjectIds);
    for (final entry in sessionsBySubject.entries) {
      final subject = subjectsById[entry.key];
      if (subject != null) {
        service.scheduleAttendanceCheckIns(subject, entry.value, prefs: prefs);
      }
    }
  } else {
    service.pruneAttendanceCheckIns(<String>{});
    for (final id in sessionsBySubject.keys) {
      service.cancelAttendanceCheckInsForSubject(id);
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
      body: 'Today: ${parts.join(' · ')}. Tap to view & download your summary.',
    );
  } else {
    service.cancelDailySummary();
  }

  // ── Attendance risk alerts (Pro) ─────────────────────────────────────────
  // Reuses the "smart daily notifications" toggle (dailySummary) as the opt-in
  // so there's no extra setting to hunt for. The evening before, if skipping a
  // class scheduled tomorrow would push a subject below the user's target, we
  // send one actionable heads-up. Recomputed on every data change, so the body
  // is always current; cancelled when nothing is at risk.
  if (isPro && prefs.dailySummary) {
    final subjects = ref.watch(subjectsStreamProvider).valueOrNull ?? const [];
    final target = ref
            .watch(userProfileProvider)
            .valueOrNull
            ?.targetAttendancePercent ??
        AppConstants.defaultTargetAttendance;
    final now = DateTime.now();
    final tomorrow =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    // How many of each subject's classes fall tomorrow.
    final tomorrowCount = <String, int>{};
    for (final sc in scheduledClasses) {
      if (sc.session.occursOn(tomorrow)) {
        tomorrowCount[sc.subject.id] = (tomorrowCount[sc.subject.id] ?? 0) + 1;
      }
    }

    final atRisk = <AttendanceRiskAlert>[];
    for (final s in subjects) {
      final upcoming = tomorrowCount[s.id] ?? 0;
      if (upcoming == 0) continue; // no class tomorrow -> nothing to warn about
      final alert = attendanceRiskAlert(
        subjectName: s.name,
        attended: s.attended,
        held: s.held,
        target: s.effectiveTarget(target),
        upcomingCount: upcoming,
      );
      if (alert.level == AttendanceRiskLevel.danger) atRisk.add(alert);
    }

    if (atRisk.isNotEmpty) {
      final t = target.toStringAsFixed(0);
      final title = atRisk.length == 1
          ? '${atRisk.first.subjectName} attendance at risk'
          : '${atRisk.length} subjects at risk tomorrow';
      final body = atRisk.length == 1
          ? atRisk.first.message
          : 'Missing tomorrow’s classes could drop ${atRisk.map((a) => a.subjectName).take(3).join(', ')} below your $t% target.';
      service.scheduleAttendanceRiskAlert(
        hour: 20,
        minute: 0,
        title: title,
        body: body,
        prefs: prefs,
      );
    } else {
      service.cancelAttendanceRiskAlert();
    }
  } else {
    service.cancelAttendanceRiskAlert();
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
