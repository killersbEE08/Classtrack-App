import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/providers/app_settings_provider.dart';
import '../core/utils/date_utils.dart';
import '../features/import/presentation/providers/import_providers.dart';
import '../features/calendar/presentation/providers/calendar_push_providers.dart';
import '../features/subscription/presentation/providers/subscription_providers.dart';

/// Pure gate for the once-daily Google Calendar/Tasks background sync.
///
/// Returns true only when ALL of the following hold, so the sync runs at most
/// once per calendar day, on or after the configured hour, and only for a Pro
/// account that has actually connected Google:
///  • [isPro]        — automatic daily sync is a ClassTrack Pro perk (manual
///    one-tap import stays free);
///  • [enabled]      — the user hasn't turned the daily auto-sync off;
///  • [connected]    — Google was linked at least once (scopes granted), so a
///    silent, dialog-free fetch is possible;
///  • [now] is at or past [hour] (24h, local) — the 7 PM trigger;
///  • [lastSyncYmd] (the yyyy-MM-dd of the last successful sync) is not today.
///
/// Side-effect free so it can be unit-tested without any prefs, network or
/// OAuth.
bool shouldAutoSync({
  required bool isPro,
  required bool enabled,
  required bool connected,
  required DateTime now,
  required String? lastSyncYmd,
  int hour = AppConstants.googleAutoSyncHour,
}) {
  if (!isPro || !enabled || !connected) return false;
  if (now.hour < hour) return false;
  return lastSyncYmd != DateUtilsX.dateId(now);
}

// ── Persisted state (per signed-in user) ────────────────────────────────────

/// Whether the daily 7 PM Google auto-sync is enabled. Defaults to ON ("for all
/// users"), per user so one account's choice never leaks to another on a shared
/// device.
class GoogleAutoSyncEnabledController extends StateNotifier<bool> {
  final ScopedPrefs _prefs;
  GoogleAutoSyncEnabledController(this._prefs)
      : super(_prefs.getBool(AppConstants.prefsGoogleAutoSync) ?? true);

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(AppConstants.prefsGoogleAutoSync, value);
  }
}

final googleAutoSyncEnabledProvider =
    StateNotifierProvider<GoogleAutoSyncEnabledController, bool>((ref) {
  return GoogleAutoSyncEnabledController(ref.watch(scopedPrefsProvider));
});

/// Whether this account has connected Google at least once (set true after the
/// first successful manual import). The silent auto-sync only runs once this is
/// true, guaranteeing the OAuth scopes are already granted so no dialog appears.
class GoogleAutoSyncConnectedController extends StateNotifier<bool> {
  final ScopedPrefs _prefs;
  GoogleAutoSyncConnectedController(this._prefs)
      : super(_prefs.getBool(AppConstants.prefsGoogleAutoSyncConnected) ?? false);

  Future<void> set(bool value) async {
    if (state == value) return;
    state = value;
    await _prefs.setBool(AppConstants.prefsGoogleAutoSyncConnected, value);
  }
}

final googleAutoSyncConnectedProvider =
    StateNotifierProvider<GoogleAutoSyncConnectedController, bool>((ref) {
  return GoogleAutoSyncConnectedController(ref.watch(scopedPrefsProvider));
});

/// The yyyy-MM-dd of the last successful auto-sync (null until the first run),
/// used to run the sync at most once per calendar day.
class GoogleAutoSyncLastDateController extends StateNotifier<String?> {
  final ScopedPrefs _prefs;
  GoogleAutoSyncLastDateController(this._prefs)
      : super(_prefs.getString(AppConstants.prefsGoogleAutoSyncLastDate));

  Future<void> set(String ymd) async {
    state = ymd;
    await _prefs.setString(AppConstants.prefsGoogleAutoSyncLastDate, ymd);
  }
}

final googleAutoSyncLastDateProvider =
    StateNotifierProvider<GoogleAutoSyncLastDateController, String?>((ref) {
  return GoogleAutoSyncLastDateController(ref.watch(scopedPrefsProvider));
});

/// Whether the daily sync should ALSO push ClassTrack classes/exams/deadlines
/// into Google Calendar (two-way sync, Pro). Opt-in, default OFF — nothing is
/// ever written to the user's calendar without them turning this on.
class GoogleAutoPushController extends StateNotifier<bool> {
  final ScopedPrefs _prefs;
  GoogleAutoPushController(this._prefs)
      : super(_prefs.getBool(AppConstants.prefsGoogleAutoPush) ?? false);

  Future<void> set(bool value) async {
    state = value;
    await _prefs.setBool(AppConstants.prefsGoogleAutoPush, value);
  }
}

final googleAutoPushEnabledProvider =
    StateNotifierProvider<GoogleAutoPushController, bool>((ref) {
  return GoogleAutoPushController(ref.watch(scopedPrefsProvider));
});

// ── Controller ──────────────────────────────────────────────────────────────

/// Drives the daily background Google sync. Call [maybeSync] whenever there's
/// an opportunity to run (app launch, resume from background, and periodically
/// while the app is foregrounded); it self-gates via [shouldAutoSync] so it
/// fires at most once per day on or after 7 PM local time, and only for a
/// connected account with the feature enabled.
class CalendarAutoSyncController {
  CalendarAutoSyncController(this._ref);

  final Ref _ref;
  bool _running = false;

  Future<void> maybeSync({DateTime? now}) async {
    if (_running) return;
    final at = now ?? DateTime.now();

    if (!shouldAutoSync(
      isPro: _ref.read(isProProvider),
      enabled: _ref.read(googleAutoSyncEnabledProvider),
      connected: _ref.read(googleAutoSyncConnectedProvider),
      now: at,
      lastSyncYmd: _ref.read(googleAutoSyncLastDateProvider),
    )) {
      return;
    }

    final repo = _ref.read(importRepositoryProvider);
    if (repo == null) return; // signed out / not ready

    _running = true;
    try {
      // Runs silently (no dialogs). De-dup inside the repo guarantees a repeat
      // sync never creates duplicate tasks/events.
      await repo.autoSyncGoogle();
      // Two-way sync (Pro): if the user opted into auto-push, write their
      // classes/exams/deadlines back into Google Calendar (idempotent upsert,
      // silent). Best-effort — never let a push failure block the import half.
      if (_ref.read(googleAutoPushEnabledProvider)) {
        try {
          await _ref.read(calendarPushControllerProvider).push(interactive: false);
        } catch (_) {/* best-effort background push */}
      }
      // Mark today done only after a clean run, so a transient network failure
      // is retried on the next opportunity rather than skipped until tomorrow.
      await _ref
          .read(googleAutoSyncLastDateProvider.notifier)
          .set(DateUtilsX.dateId(at));
    } catch (_) {
      // Best-effort background work: swallow errors and retry next trigger.
    } finally {
      _running = false;
    }
  }
}

final calendarAutoSyncProvider = Provider<CalendarAutoSyncController>((ref) {
  return CalendarAutoSyncController(ref);
});
