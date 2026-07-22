import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/providers/notification_prefs_provider.dart';
import '../features/schedule/domain/class_session.dart';
import '../features/subjects/domain/subject.dart';
import '../features/tasks/domain/task_item.dart';
import '../features/exams/domain/exam.dart';
import '../features/habits/domain/habit.dart';

/// Wraps flutter_local_notifications: class-start reminders + attendance nudges.
class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static const _channelId = 'classtrack_reminders';
  static const _channelName = 'Class reminders';
  static const _channelDesc =
      'Reminders when a class is about to start and nudges to mark attendance.';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // CRITICAL: without setting the local location, tz.local defaults to UTC,
    // so every zonedSchedule fires at the wrong wall-clock time (e.g. +5:30
    // off in India). Resolve the device's IANA zone and use it.
    try {
      final localZone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(localZone.identifier));
    } catch (_) {
      // Leave the default (UTC) if the platform can't report a zone; better
      // than crashing, and rare on real devices.
    }
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _ready = true;
  }

  /// Ask the OS for permission (Android 13+ and iOS).
  Future<bool> requestPermissions() async {
    await init();
    final ios = await _plugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final android = await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    return (ios ?? true) || (android ?? true);
  }

  NotificationDetails get _details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Deterministic notification id from subject + weekday.
  int _idFor(String subjectId, int weekday0) =>
      (subjectId.hashCode & 0x7fffff) * 10 + weekday0;

  /// Schedule weekly reminders a few minutes before each recurring class.
  Future<void> scheduleForSubject(
    Subject subject,
    List<ClassSession> sessions, {
    int minutesBefore = 10,
    NotificationPrefs? prefs,
  }) async {
    await init();
    for (final s in sessions) {
      if (!s.recurring || s.dayOfWeek == null) continue;
      final parts = s.startTime.split(':');
      if (parts.length != 2) continue;
      final hour = int.tryParse(parts[0]) ?? 9;
      final minute = int.tryParse(parts[1]) ?? 0;

      final when = _nextInstanceOfWeekdayTime(
        weekday0: s.dayOfWeek!,
        hour: hour,
        minute: minute,
        minutesBefore: minutesBefore,
      );

      final id = _idFor(subject.id, s.dayOfWeek!);
      // Respect quiet hours: cancel any existing in-window reminder and skip.
      if (prefs != null && prefs.isQuietHour(when.hour)) {
        await _plugin.cancel(id);
        continue;
      }

      await _plugin.zonedSchedule(
        id,
        '${subject.name} starts soon',
        s.room != null && s.room!.isNotEmpty
            ? 'Starts at ${s.startTime} · Room ${s.room}. Tap to mark attendance.'
            : 'Starts at ${s.startTime}. Tap to mark attendance.',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
      );
    }
  }

  /// Task/course/video id namespace, kept distinct from class ids.
  int _idForTask(String taskId) => 1000000 + (taskId.hashCode & 0x7fffff);

  /// Schedule a one-off reminder for each task that has a future due date.
  /// Fires [minutesBefore] before 9:00 AM on the due date.
  Future<void> scheduleForTasks(
    List<TaskItem> tasks, {
    int minutesBefore = 10,
    NotificationPrefs? prefs,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    for (final t in tasks) {
      if (t.done || t.dueDate == null) continue;
      final due = t.dueDate!;
      var when = tz.TZDateTime(tz.local, due.year, due.month, due.day, 9, 0)
          .subtract(Duration(minutes: minutesBefore));
      if (when.isBefore(now)) continue; // don't schedule in the past
      final id = _idForTask(t.id);
      if (prefs != null && prefs.isQuietHour(when.hour)) {
        await _plugin.cancel(id);
        continue;
      }
      final label = switch (t.type) {
        TaskType.course => 'Course due',
        TaskType.video => 'Video planned',
        TaskType.task => 'Task due',
      };
      await _plugin.zonedSchedule(
        id,
        '$label: ${t.title}',
        t.hasLink ? 'Tap to open the link and get started.' : 'Due today.',
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  /// Exam id namespaces, kept distinct from class + task ids.
  int _idForExamDay(String examId) => 2000000 + (examId.hashCode & 0x7fffff);
  int _idForExamEve(String examId) => 3000000 + (examId.hashCode & 0x7fffff);

  /// Schedule two reminders per upcoming exam:
  ///  • a "starts soon" reminder [minutesBefore] the exam time, and
  ///  • an evening-before revision nudge at 18:00.
  Future<void> scheduleForExams(
    List<Exam> exams, {
    int minutesBefore = 30,
    NotificationPrefs? prefs,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    for (final e in exams) {
      final timeLabel =
          '${e.date.hour.toString().padLeft(2, '0')}:${e.date.minute.toString().padLeft(2, '0')}';

      final soon = tz.TZDateTime(
        tz.local,
        e.date.year,
        e.date.month,
        e.date.day,
        e.date.hour,
        e.date.minute,
      ).subtract(Duration(minutes: minutesBefore));
      final quietSoon = prefs != null && prefs.isQuietHour(soon.hour);
      if (soon.isAfter(now) && !quietSoon) {
        await _plugin.zonedSchedule(
          _idForExamDay(e.id),
          'Exam soon: ${e.title}',
          e.room != null && e.room!.isNotEmpty
              ? 'Starts at $timeLabel · Room ${e.room}. Good luck!'
              : 'Starts at $timeLabel. Good luck!',
          soon,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else if (quietSoon) {
        await _plugin.cancel(_idForExamDay(e.id));
      }

      final eve = tz.TZDateTime(
        tz.local,
        e.date.year,
        e.date.month,
        e.date.day,
        18,
        0,
      ).subtract(const Duration(days: 1));
      final quietEve = prefs != null && prefs.isQuietHour(eve.hour);
      if (eve.isAfter(now) && !quietEve) {
        await _plugin.zonedSchedule(
          _idForExamEve(e.id),
          'Exam tomorrow: ${e.title}',
          'Your exam is tomorrow at $timeLabel. Time for a final revision!',
          eve,
          _details,
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
        );
      } else if (quietEve) {
        await _plugin.cancel(_idForExamEve(e.id));
      }
    }
  }

  Future<void> cancelForSubject(String subjectId) async {    await init();
    for (var d = 0; d < 7; d++) {
      await _plugin.cancel(_idFor(subjectId, d));
    }
  }

  /// Cancel a task's scheduled reminder (on delete or when marked done).
  Future<void> cancelTask(String taskId) async {
    await init();
    await _plugin.cancel(_idForTask(taskId));
  }

  /// Cancel an exam's scheduled reminders (both the day-of and eve-before).
  Future<void> cancelExam(String examId) async {
    await init();
    await _plugin.cancel(_idForExamDay(examId));
    await _plugin.cancel(_idForExamEve(examId));
  }

  /// Habit reminder id namespace.
  int _idForHabit(String habitId) => 4000000 + (habitId.hashCode & 0x7fffff);

  /// Schedule a daily reminder for each habit that has a reminder time set;
  /// cancels reminders for habits that have theirs turned off.
  Future<void> scheduleForHabits(List<Habit> habits,
      {NotificationPrefs? prefs}) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    for (final h in habits) {
      final id = _idForHabit(h.id);
      if (!h.hasReminder) {
        await _plugin.cancel(id);
        continue;
      }
      var when = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        h.reminderHour,
        h.reminderMinute,
      );
      if (when.isBefore(now)) when = when.add(const Duration(days: 1));
      if (prefs != null && prefs.isQuietHour(when.hour)) {
        await _plugin.cancel(id);
        continue;
      }
      await _plugin.zonedSchedule(
        id,
        'Habit reminder: ${h.title}',
        "Keep your streak alive — don't forget today!",
        when,
        _details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelHabit(String habitId) async {
    await init();
    await _plugin.cancel(_idForHabit(habitId));
  }

  /// Daily agenda summary id (single, repeating).
  static const int _idDailySummary = 5000000;

  /// Schedules (or reschedules) the once-daily agenda summary at [hour]:[minute].
  /// Repeats every day via [DateTimeComponents.time].
  Future<void> scheduleDailySummary({
    required int hour,
    required int minute,
    required String title,
    required String body,
  }) async {
    await init();
    final now = tz.TZDateTime.now(tz.local);
    var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (when.isBefore(now)) when = when.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      _idDailySummary,
      title,
      body,
      when,
      _details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelDailySummary() async {
    await init();
    await _plugin.cancel(_idDailySummary);
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  tz.TZDateTime _nextInstanceOfWeekdayTime({
    required int weekday0,
    required int hour,
    required int minute,
    required int minutesBefore,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    ).subtract(Duration(minutes: minutesBefore));

    // Advance to the correct weekday (DateTime.weekday is 1..7, weekday0 is 0..6).
    while ((scheduled.weekday - 1) != weekday0 || scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}

final notificationServiceProvider = Provider<NotificationService>(
  (ref) => NotificationService(),
);
