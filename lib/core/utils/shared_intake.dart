/// De-duplication for links / text shared INTO the app via the system share
/// sheet (Android/iOS).
///
/// Why this exists: on some Android launchers (notably several OEM skins) the
/// original `ACTION_SEND` intent stays attached to the app's task, so a later
/// *cold start* of the app — opened from the launcher or Recents, NOT by
/// sharing again — re-delivers the already-handled link through
/// `getInitialMedia()`. The "New item" sheet then keeps reappearing pre-filled
/// with a stale URL every time the app is opened.
///
/// `MainActivity` already neutralises intents flagged
/// `FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY`, but that flag is not set on every
/// stale relaunch. This class is the cross-platform safety net: we remember the
/// last handled payload and skip an identical cold-start re-delivery.
///
/// Live shares (received while the app is already running, via the media
/// stream) are always genuine user actions and are never de-duplicated — so
/// sharing the same link twice on purpose still works.
class SharedIntake {
  const SharedIntake._();

  /// A stable signature for [text] used to detect OS re-deliveries. Trimmed so
  /// trailing whitespace differences don't defeat the match; stored verbatim
  /// (it is just a short URL / snippet), which is stable across app restarts —
  /// unlike `String.hashCode`, which the Dart VM may randomise per run.
  static String signature(String text) => text.trim();

  /// Whether a shared [text] should be processed now.
  ///
  ///  • A live share ([isColdStart] == false) is always handled.
  ///  • A cold-start delivery is handled unless its signature matches
  ///    [lastHandled] — i.e. it is an OS re-delivery of a share we already
  ///    consumed, which must be ignored.
  ///  • Empty / whitespace-only payloads are never handled.
  static bool shouldHandle({
    required String text,
    required bool isColdStart,
    required String? lastHandled,
  }) {
    final sig = signature(text);
    if (sig.isEmpty) return false;
    if (!isColdStart) return true;
    return sig != lastHandled;
  }
}
