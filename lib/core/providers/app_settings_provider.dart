import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// SharedPreferences instance — overridden in main() after it is loaded.
final sharedPrefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('sharedPrefsProvider must be overridden'),
);

/// Whether the user has completed onboarding.
class OnboardingController extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  OnboardingController(this._prefs)
      : super(_prefs.getBool(AppConstants.prefsOnboardingDone) ?? false);

  Future<void> complete() async {
    await _prefs.setBool(AppConstants.prefsOnboardingDone, true);
    state = true;
  }

  Future<void> reset() async {
    await _prefs.setBool(AppConstants.prefsOnboardingDone, false);
    state = false;
  }
}

final onboardingDoneProvider =
    StateNotifierProvider<OnboardingController, bool>((ref) {
  return OnboardingController(ref.watch(sharedPrefsProvider));
});

/// App theme mode (system/light/dark), persisted.
class ThemeModeController extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;
  ThemeModeController(this._prefs) : super(_load(_prefs));

  static ThemeMode _load(SharedPreferences prefs) {
    final raw = prefs.getString(AppConstants.prefsThemeMode);
    return switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(AppConstants.prefsThemeMode, mode.name);
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeController, ThemeMode>((ref) {
  return ThemeModeController(ref.watch(sharedPrefsProvider));
});

/// On-device Gemini API key (entered by the user in Settings).
class GeminiKeyController extends StateNotifier<String?> {
  final SharedPreferences _prefs;
  GeminiKeyController(this._prefs)
      : super(_prefs.getString(AppConstants.prefsGeminiKey));

  bool get hasKey => (state ?? '').trim().isNotEmpty;

  Future<void> set(String key) async {
    final trimmed = key.trim();
    await _prefs.setString(AppConstants.prefsGeminiKey, trimmed);
    state = trimmed;
  }

  Future<void> clear() async {
    await _prefs.remove(AppConstants.prefsGeminiKey);
    state = null;
  }
}

final geminiKeyProvider =
    StateNotifierProvider<GeminiKeyController, String?>((ref) {
  return GeminiKeyController(ref.watch(sharedPrefsProvider));
});

/// How many minutes before a class/task to fire the reminder (e.g. 10 or 30).
class ReminderLeadController extends StateNotifier<int> {
  final SharedPreferences _prefs;
  ReminderLeadController(this._prefs)
      : super(_prefs.getInt(AppConstants.prefsReminderLead) ?? 10);

  Future<void> set(int minutes) async {
    state = minutes;
    await _prefs.setInt(AppConstants.prefsReminderLead, minutes);
  }
}

final reminderLeadProvider =
    StateNotifierProvider<ReminderLeadController, int>((ref) {
  return ReminderLeadController(ref.watch(sharedPrefsProvider));
});

/// Whether the user has enabled reminders (set true after granting permission
/// and scheduling from Settings). Drives automatic re-sync of reminders.
class RemindersEnabledController extends StateNotifier<bool> {
  final SharedPreferences _prefs;
  RemindersEnabledController(this._prefs)
      : super(_prefs.getBool(AppConstants.prefsRemindersEnabled) ?? false);

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(AppConstants.prefsRemindersEnabled, value);
  }
}

final remindersEnabledProvider =
    StateNotifierProvider<RemindersEnabledController, bool>((ref) {
  return RemindersEnabledController(ref.watch(sharedPrefsProvider));
});

/// Grading scale used to compute GPA: 4.0 scale or 10-point (CGPA).
enum GpaScaleType { four, ten }

class GpaScaleController extends StateNotifier<GpaScaleType> {
  final SharedPreferences _prefs;
  GpaScaleController(this._prefs)
      : super(_prefs.getString(AppConstants.prefsGpaScale) == 'ten'
            ? GpaScaleType.ten
            : GpaScaleType.four);

  Future<void> set(GpaScaleType type) async {
    state = type;
    await _prefs.setString(
        AppConstants.prefsGpaScale, type == GpaScaleType.ten ? 'ten' : 'four');
  }
}

final gpaScaleProvider =
    StateNotifierProvider<GpaScaleController, GpaScaleType>((ref) {
  return GpaScaleController(ref.watch(sharedPrefsProvider));
});

/// User-chosen accent color (Pro). Null = the default ClassTrack purple.
/// Stored as an ARGB int; 0 means "use default".
class AccentColorController extends StateNotifier<Color?> {
  final SharedPreferences _prefs;
  AccentColorController(this._prefs) : super(_load(_prefs));

  static Color? _load(SharedPreferences p) {
    final v = p.getInt(AppConstants.prefsAccentColor) ?? 0;
    return v == 0 ? null : Color(v);
  }

  Future<void> set(Color? color) async {
    state = color;
    if (color == null) {
      await _prefs.remove(AppConstants.prefsAccentColor);
    } else {
      await _prefs.setInt(AppConstants.prefsAccentColor, color.toARGB32());
    }
  }
}

final accentColorProvider =
    StateNotifierProvider<AccentColorController, Color?>((ref) {
  return AccentColorController(ref.watch(sharedPrefsProvider));
});
