// Lightweight widget test that does not require Firebase initialisation.
//
// The full app (ClassTrackApp) needs Firebase + SharedPreferences overrides,
// so integration/widget tests for it should run against the Firebase emulator.
// This test just verifies a shared widget renders, keeping `flutter test` green.

import 'package:classtrack/shared/widgets/progress_ring.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ProgressRing shows its percentage label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: ProgressRing(percent: 82)),
        ),
      ),
    );

    expect(find.text('82%'), findsOneWidget);
  });
}
