import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../firebase_options.dart';
import 'notification_service.dart';

/// Android channel used to *display* Firebase Cloud Messaging pushes. It must
/// match the `default_notification_channel_id` metadata in AndroidManifest.xml
/// so background/terminated notifications from the Firebase console render with
/// the right importance instead of falling into a silent "Miscellaneous" bucket.
const String kPushChannelId = 'classtrack_push';
const String kPushChannelName = 'Announcements';
const String kPushChannelDesc =
    'Updates and announcements sent by the ClassTrack team.';

/// Topic every device subscribes to, so the Firebase console can broadcast to
/// the whole audience with a single "topic" send in addition to the built-in
/// "all users" segment.
const String kBroadcastTopic = 'all';

/// Background/terminated message handler.
///
/// MUST be a top-level (or static) function annotated with
/// `@pragma('vm:entry-point')` — Flutter spins up a *separate* isolate to run
/// it, so it can't capture any app state. For "notification" messages sent from
/// the Firebase console the system tray notification is drawn automatically by
/// the FCM SDK; this handler only needs to exist (and initialise Firebase for
/// the background isolate) so data-only messages don't crash.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // The background isolate has no access to the app's already-initialised
  // Firebase instance, so initialise it here. Guard against the rare case where
  // it's already been set up for this isolate.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (_) {/* already initialised for this isolate */}
  // No further work required: notification messages are shown by the OS.
  debugPrint('[FCM] background message: ${message.messageId}');
}

/// Wires Firebase Cloud Messaging into the app so pushes sent from the Firebase
/// console (Messaging → "Create your first campaign"/"New notification") are
/// delivered and displayed on this device.
class PushMessagingService {
  PushMessagingService({FlutterLocalNotificationsPlugin? localPlugin})
      : _local = localPlugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _local;
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  bool _ready = false;

  /// Initialise messaging: request permission, create the Android display
  /// channel, wire foreground/tap handlers and subscribe to the broadcast
  /// topic. Safe to call multiple times.
  Future<void> init() async {
    if (_ready) return;

    // 1. Ask the user for notification permission (Android 13+ / iOS).
    await _fcm.requestPermission(alert: true, badge: true, sound: true);

    // 2. iOS: make sure a notification shows while the app is foregrounded.
    await _fcm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // 3. Android: create the channel the manifest points at, so background
    //    pushes display at high importance (heads-up) rather than silently.
    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        kPushChannelId,
        kPushChannelName,
        description: kPushChannelDesc,
        importance: Importance.high,
      ),
    );

    // 4. Initialise the local-notifications plugin so we can render pushes that
    //    arrive while the app is in the foreground (FCM doesn't auto-display
    //    those). Reuse the app icon; taps flow through onDidReceive... below.
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (resp) {
        final p = resp.payload;
        if (p != null && p.isNotEmpty) {
          NotificationService.selectedPayload.value = p;
        }
      },
    );

    // 5. Foreground messages → draw a local notification ourselves.
    FirebaseMessaging.onMessage.listen(_showForeground);

    // 6. Tap on a notification that opened/resumed the app → deep-link.
    FirebaseMessaging.onMessageOpenedApp.listen(_handleOpened);

    // 7. Cold start from a tapped push while the app was terminated.
    final initial = await _fcm.getInitialMessage();
    if (initial != null) _handleOpened(initial);

    // 8. Subscribe to the broadcast topic (web/desktop don't support topics).
    //    Bounded by a timeout: subscribeToTopic can stall indefinitely offline
    //    or without Google Play Services, and this must never wedge init().
    if (!kIsWeb) {
      try {
        await _fcm
            .subscribeToTopic(kBroadcastTopic)
            .timeout(const Duration(seconds: 5));
      } catch (_) {/* topic subscription is best-effort */}
    }

    // 9. Log the device token — handy for targeting a single device from the
    //    console's "Send test message" during testing. Bounded by a timeout:
    //    getToken() is a known offline/no-Play-Services hang, so we never let
    //    it block initialisation.
    try {
      final token =
          await _fcm.getToken().timeout(const Duration(seconds: 5));
      debugPrint('[FCM] device token: $token');
    } catch (_) {/* token may be unavailable (offline / no APNs / timeout) */}

    _ready = true;
  }

  /// Render a foreground push using the same channel as background pushes.
  Future<void> _showForeground(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return; // data-only messages are handled elsewhere.
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          kPushChannelId,
          kPushChannelName,
          channelDescription: kPushChannelDesc,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: _payloadFor(message),
    );
  }

  /// Surface the tapped push's payload so the UI can deep-link. Falls back to
  /// the daily-agenda screen used by local reminders when no explicit route is
  /// provided in the message's data block.
  void _handleOpened(RemoteMessage message) {
    NotificationService.selectedPayload.value = _payloadFor(message);
  }

  /// Custom `data` key `payload` (settable in the console under
  /// "Additional options → Custom data") drives deep-linking; otherwise reuse
  /// the daily-agenda payload so a tap still lands somewhere sensible.
  String _payloadFor(RemoteMessage message) {
    final custom = message.data['payload'];
    if (custom is String && custom.isNotEmpty) return custom;
    return NotificationService.dailyAgendaPayload;
  }
}

final pushMessagingServiceProvider = Provider<PushMessagingService>(
  (ref) => PushMessagingService(),
);
