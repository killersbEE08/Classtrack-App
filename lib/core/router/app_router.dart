import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers/app_settings_provider.dart';
import '../../core/providers/firebase_providers.dart';
import '../../features/auth/presentation/providers/auth_providers.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/onboarding_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/verify_email_screen.dart';
import '../../features/home/presentation/screens/home_shell.dart';

/// App router. Redirects between onboarding → auth → home based on state.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref
    ..listen(authStateProvider, (_, __) => refresh.value++)
    ..listen(onboardingDoneProvider, (_, __) => refresh.value++)
    ..listen(authReloadTickProvider, (_, __) => refresh.value++)
    ..onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      // Still resolving the auth stream — stay on splash.
      if (auth.isLoading) {
        return loc == '/splash' ? null : '/splash';
      }

      final onboardingDone = ref.read(onboardingDoneProvider);
      if (!onboardingDone) {
        return loc == '/onboarding' ? null : '/onboarding';
      }

      final loggedIn = auth.valueOrNull != null;
      final onAuthRoute = loc == '/login' || loc == '/signup';

      if (!loggedIn) {
        return onAuthRoute ? null : '/login';
      }

      // Email-verification gate for email/password accounts (Google is already
      // verified). Read the live user so a post-reload change is picked up.
      final repo = ref.read(authRepositoryProvider);
      if (repo.isPasswordUser && !repo.isEmailVerified) {
        return loc == '/verify-email' ? null : '/verify-email';
      }

      // Verified/social user: keep them out of entry + verify routes.
      if (onAuthRoute ||
          loc == '/splash' ||
          loc == '/onboarding' ||
          loc == '/verify-email') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, __) => const SignupScreen()),
      GoRoute(
          path: '/verify-email', builder: (_, __) => const VerifyEmailScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeShell()),
    ],
  );
});
