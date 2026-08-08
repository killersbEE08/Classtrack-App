import 'package:classtrack/features/home/presentation/widgets/home_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the first-run [HomeTour] coach-mark overlay: it advances
/// through steps, spotlights a keyed target, and finishes via Done or Skip.
Widget _harness({
  required List<TourStep> steps,
  required VoidCallback onFinish,
  GlobalKey? targetKey,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Stack(
        children: [
          if (targetKey != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(key: targetKey, height: 60, color: Colors.blue),
            ),
          HomeTour(steps: steps, onFinish: onFinish),
        ],
      ),
    ),
  );
}

void main() {
  testWidgets('shows the first step and advances with Next', (tester) async {
    final targetKey = GlobalKey();
    var finished = false;

    await tester.pumpWidget(_harness(
      targetKey: targetKey,
      onFinish: () => finished = true,
      steps: [
        const TourStep(
            title: 'Welcome', body: 'Intro', icon: Icons.waving_hand_rounded),
        TourStep(
            key: targetKey,
            title: 'Move around',
            body: 'Nav bar',
            icon: Icons.dashboard_rounded),
      ],
    ));

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Second (last) step is shown with a Done button; Skip is gone.
    expect(find.text('Move around'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(finished, isFalse);

    await tester.tap(find.text('Done'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('Skip finishes the tour immediately', (tester) async {
    var finished = false;
    await tester.pumpWidget(_harness(
      onFinish: () => finished = true,
      steps: const [
        TourStep(title: 'Welcome', body: 'Intro', icon: Icons.waving_hand_rounded),
        TourStep(title: 'Second', body: 'More', icon: Icons.dashboard_rounded),
      ],
    ));

    await tester.tap(find.text('Skip'));
    await tester.pump();
    expect(finished, isTrue);
  });

  testWidgets('tapping the dimmed backdrop advances to the next step',
      (tester) async {
    await tester.pumpWidget(_harness(
      onFinish: () {},
      steps: const [
        TourStep(title: 'One', body: 'a', icon: Icons.looks_one_rounded),
        TourStep(title: 'Two', body: 'b', icon: Icons.looks_two_rounded),
      ],
    ));

    expect(find.text('One'), findsOneWidget);
    // Tap near the top-left corner (backdrop, away from the card).
    await tester.tapAt(const Offset(8, 8));
    await tester.pumpAndSettle();
    expect(find.text('Two'), findsOneWidget);
  });
}
