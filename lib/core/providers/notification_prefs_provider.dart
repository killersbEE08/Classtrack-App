import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import 'app_settings_provider.dart';

/// User-configurable notification preferences, persisted in SharedPreferences.
///
/// Per-category toggles and quiet hours are always available. The daily agenda
/// summary and quiet hours are surfaced as Pro perks in the UI, but the model
/// itself stays store-agnostic — gating happens in the settings screen.
class NotificationPrefs {
  final bool classes;
  final bool tasks;
  final bool exams;
  final bool habits;

  /// A single morning notification summarising today's classes/tasks/exams.
  final bool dailySummary;
  final int summaryHour;
  final int summaryMinute;

  /// Suppress reminders during a nightly do-not-disturb window.
  final bool quietHours;
  final int quietStartHour; // inclusive
  final int quietEndHour; // exclusive

  const NotificationPrefs({
    this.classes = true,
    this.tasks = true,
    this.exams = true,
    this.habits = true,
    this.dailySummary = false,
    this.summaryHour = 7,
    this.summaryMinute = 30,
    this.quietHours = false,
    this.quietStartHour = 22,
    this.quietEndHour = 7,
  });

  TimeOfDay get summaryTime =>
      TimeOfDay(hour: summaryHour, minute: summaryMinute);

  /// Is [hour] (0..23) inside the quiet window? Handles windows that wrap past
  /// midnight (e.g. 22:00 → 07:00).
  bool isQuietHour(int hour) {
    if (!quietHours) return false;
    if (quietStartHour == quietEndHour) return false;
    if (quietStartHour < quietEndHour) {
      return hour >= quietStartHour && hour < quietEndHour;
    }
    return hour >= quietStartHour || hour < quietEndHour;
  }

  NotificationPrefs copyWith({
    bool? classes,
    bool? tasks,
    bool? exams,
    bool? habits,
    bool? dailySummary,
    int? summaryHour,
    int? summaryMinute,
    bool? quietHours,
    int? quietStartHour,
    int? quietEndHour,
  }) {
    return NotificationPrefs(
      classes: classes ?? this.classes,
      tasks: tasks ?? this.tasks,
      exams: exams ?? this.exams,
      habits: habits ?? this.habits,
      dailySummary: dailySummary ?? this.dailySummary,
      summaryHour: summaryHour ?? this.summaryHour,
      summaryMinute: summaryMinute ?? this.summaryMinute,
      quietHours: quietHours ?? this.quietHours,
      quietStartHour: quietStartHour ?? this.quietStartHour,
      quietEndHour: quietEndHour ?? this.quietEndHour,
    );
  }
}

class NotificationPrefsController extends StateNotifier<NotificationPrefs> {
  final ScopedPrefs _prefs;
  NotificationPrefsController(this._prefs) : super(_load(_prefs));

  static NotificationPrefs _load(ScopedPrefs p) => NotificationPrefs(
        classes: p.getBool(AppConstants.prefsNotifyClasses) ?? true,
        tasks: p.getBool(AppConstants.prefsNotifyTasks) ?? true,
        exams: p.getBool(AppConstants.prefsNotifyExams) ?? true,
        habits: p.getBool(AppConstants.prefsNotifyHabits) ?? true,
        dailySummary: p.getBool(AppConstants.prefsDailySummary) ?? false,
        summaryHour: p.getInt(AppConstants.prefsDailySummaryHour) ?? 7,
        summaryMinute: p.getInt(AppConstants.prefsDailySummaryMinute) ?? 30,
        quietHours: p.getBool(AppConstants.prefsQuietHours) ?? false,
        quietStartHour: p.getInt(AppConstants.prefsQuietStartHour) ?? 22,
        quietEndHour: p.getInt(AppConstants.prefsQuietEndHour) ?? 7,
      );

  Future<void> setCategory({
    bool? classes,
    bool? tasks,
    bool? exams,
    bool? habits,
  }) async {
    state = state.copyWith(
        classes: classes, tasks: tasks, exams: exams, habits: habits);
    if (classes != null) {
      await _prefs.setBool(AppConstants.prefsNotifyClasses, classes);
    }
    if (tasks != null) {
      await _prefs.setBool(AppConstants.prefsNotifyTasks, tasks);
    }
    if (exams != null) {
      await _prefs.setBool(AppConstants.prefsNotifyExams, exams);
    }
    if (habits != null) {
      await _prefs.setBool(AppConstants.prefsNotifyHabits, habits);
    }
  }

  Future<void> setDailySummary(bool enabled, {TimeOfDay? at}) async {
    state = state.copyWith(
      dailySummary: enabled,
      summaryHour: at?.hour,
      summaryMinute: at?.minute,
    );
    await _prefs.setBool(AppConstants.prefsDailySummary, enabled);
    if (at != null) {
      await _prefs.setInt(AppConstants.prefsDailySummaryHour, at.hour);
      await _prefs.setInt(AppConstants.prefsDailySummaryMinute, at.minute);
    }
  }

  Future<void> setQuietHours(bool enabled, {int? startHour, int? endHour}) async {
    state = state.copyWith(
      quietHours: enabled,
      quietStartHour: startHour,
      quietEndHour: endHour,
    );
    await _prefs.setBool(AppConstants.prefsQuietHours, enabled);
    if (startHour != null) {
      await _prefs.setInt(AppConstants.prefsQuietStartHour, startHour);
    }
    if (endHour != null) {
      await _prefs.setInt(AppConstants.prefsQuietEndHour, endHour);
    }
  }
}

final notificationPrefsProvider =
    StateNotifierProvider<NotificationPrefsController, NotificationPrefs>((ref) {
  return NotificationPrefsController(ref.watch(scopedPrefsProvider));
});
