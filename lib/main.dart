import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/app_settings_provider.dart';
import 'features/subscription/data/subscription_service.dart';
import 'features/subscription/presentation/providers/subscription_providers.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/push_messaging_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase core must be ready before the app builds any auth/Firestore
  // providers. This is a LOCAL initialisation that completes offline.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Register the FCM background/terminated handler BEFORE runApp so pushes that
  // arrive while the app isn't foregrounded are handled. Synchronous, no
  // network — must reference a top-level function.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Local, fast — needed to build the settings providers.
  final prefs = await SharedPreferences.getInstance();

  // Build the service singletons synchronously (constructors do no I/O). Their
  // async initialisers touch the network — FCM getToken()/subscribeToTopic()
  // and RevenueCat — which can BLOCK when the app is launched offline or on a
  // device with degraded Google Play Services. Awaiting them here previously
  // meant runApp() was never reached and the app "wouldn't open without
  // internet". We create them now and initialise them AFTER the first frame.
  final notifications = NotificationService();
  final pushMessaging = PushMessagingService();
  final subscriptions = SubscriptionService();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
        pushMessagingServiceProvider.overrideWithValue(pushMessaging),
        subscriptionServiceProvider.overrideWithValue(subscriptions),
      ],
      child: const ClassTrackApp(),
    ),
  );

  // Fire-and-forget the non-critical initialisers so a slow or absent
  // connection can never delay the UI. Each is internally guarded (its own
  // try/catch) and idempotent, so running them in the background is safe:
  //  • notifications.init()  — local, but kept off the critical path anyway;
  //    scheduling paths call init() lazily so ordering is unaffected.
  //  • pushMessaging.init()  — network (token/topic); safe to complete late.
  //  • subscriptions.configure() — RevenueCat; the paywall/Pro providers all
  //    tolerate the "not configured yet" state until this finishes.
  unawaited(notifications.init());
  unawaited(pushMessaging.init());
  unawaited(subscriptions.configure());
}
