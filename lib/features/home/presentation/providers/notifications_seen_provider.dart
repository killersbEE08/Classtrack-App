import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/app_settings_provider.dart';

/// Per-user "seen" state for the Home notification bell.
///
/// [seenAt] is when the bell was last opened — anything published after it is a
/// "new" match. [seenAnnouncementIds] are the CMS announcement (banner) ids the
/// user has already dismissed. Both persist per signed-in user via [ScopedPrefs]
/// (device-local, which is exactly what Option A / B1 call for).
class NotificationsSeenState {
  final DateTime seenAt;
  final Set<String> seenAnnouncementIds;
  const NotificationsSeenState(this.seenAt, this.seenAnnouncementIds);
}

class NotificationsSeenController
    extends StateNotifier<NotificationsSeenState> {
  final ScopedPrefs _prefs;
  NotificationsSeenController(this._prefs) : super(_load(_prefs));

  static NotificationsSeenState _load(ScopedPrefs prefs) {
    final millis = prefs.getInt(AppConstants.prefsNotifSeenAt);
    final DateTime seenAt;
    if (millis == null) {
      // Baseline at first read so the bell never floods with "new" items on
      // install — only content published after this counts as new.
      seenAt = DateTime.now();
      prefs.setInt(AppConstants.prefsNotifSeenAt, seenAt.millisecondsSinceEpoch);
    } else {
      seenAt = DateTime.fromMillisecondsSinceEpoch(millis);
    }
    final ids = (prefs.getString(AppConstants.prefsAnnouncementsSeen) ?? '')
        .split(',')
        .where((e) => e.isNotEmpty)
        .toSet();
    return NotificationsSeenState(seenAt, ids);
  }

  /// Marks everything currently shown as seen: advances [seenAt] to now and
  /// records the given announcement ids. Called when the bell sheet closes.
  Future<void> markSeen(Iterable<String> announcementIds) async {
    final now = DateTime.now();
    final ids = {...state.seenAnnouncementIds, ...announcementIds};
    state = NotificationsSeenState(now, ids);
    await _prefs.setInt(
        AppConstants.prefsNotifSeenAt, now.millisecondsSinceEpoch);
    await _prefs.setString(
        AppConstants.prefsAnnouncementsSeen, ids.join(','));
  }
}

final notificationsSeenProvider =
    StateNotifierProvider<NotificationsSeenController, NotificationsSeenState>(
        (ref) {
  return NotificationsSeenController(ref.watch(scopedPrefsProvider));
});
