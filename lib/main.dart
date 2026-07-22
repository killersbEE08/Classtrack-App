import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers/app_settings_provider.dart';
import 'features/subscription/data/subscription_service.dart';
import 'features/subscription/presentation/providers/subscription_providers.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final prefs = await SharedPreferences.getInstance();

  // Initialise local notifications (permissions requested from Settings).
  final notifications = NotificationService();
  await notifications.init();

  // Configure subscriptions (RevenueCat). Safe no-op until keys are set; the
  // user is linked to their Firebase uid later via subscriptionAuthLinkProvider.
  final subscriptions = SubscriptionService();
  await subscriptions.configure();

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
        notificationServiceProvider.overrideWithValue(notifications),
        subscriptionServiceProvider.overrideWithValue(subscriptions),
      ],
      child: const ClassTrackApp(),
    ),
  );
}
