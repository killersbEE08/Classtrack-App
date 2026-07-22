import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/auth/domain/app_user.dart';
import 'package:classtrack/features/auth/presentation/providers/auth_providers.dart';
import 'package:classtrack/features/referral/domain/referral_info.dart';
import 'package:classtrack/features/referral/presentation/providers/referral_providers.dart';
import 'package:classtrack/features/referral/presentation/screens/referral_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ReferralScreen lays out with data (not-yet-redeemed)',
      (tester) async {
    // A typical phone width, to catch any width-constraint layout bug.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          referralInfoProvider.overrideWith(
            (ref) => const ReferralInfo(
              code: 'K7P2QM9',
              referralCount: 0,
              referredBy: null,
              rewardDays: 14,
            ),
          ),
          userProfileProvider.overrideWith(
            (ref) => Stream<AppUser?>.value(
              const AppUser(uid: 'u1', displayName: 'Alex'),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ReferralScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The screen laid out with no exception, and the invite code (near the
    // top) is visible. "Redeem"/"Share invite" live further down the ListView
    // and are lazily built off-screen, so they aren't asserted here.
    expect(tester.takeException(), isNull);
    expect(find.text('K7P2QM9'), findsOneWidget);

    // Scrolling to the bottom must also not throw a layout error.
    await tester.drag(find.byType(Scrollable), const Offset(0, -1200));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Redeem'), findsOneWidget);
  });
}
