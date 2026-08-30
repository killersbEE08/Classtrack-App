import 'package:classtrack/features/home/presentation/widgets/home_tour.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Widget tests for the home walkthrough. It is a safe, dismissible bottom
/// sheet: it advances through steps and finishes (marks itself seen) whenever
/// it closes — via Done, Skip, or dismissing the sheet.
Widget _harness({
  required List<TourStep> steps,
  required VoidCallback onFinish,
}) {
  return MaterialApp(
    home: Scaffold(
      body: Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () =>
                showHomeTour(context, steps: steps, onFinish: onFinish),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows the first step and advances with Next, Done finishes',
      (tester) async {
    var finished = false;

    await tester.pumpWidget(_harness(
      onFinish: () => finished = true,
      steps: const [
        TourStep(
            title: 'Welcome', body: 'Intro', icon: Icons.waving_hand_rounded),
        TourStep(
            title: 'Move around',
            body: 'Nav bar',
            icon: Icons.dashboard_rounded),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Last step shows a Done button.
    expect(find.text('Move around'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
    expect(finished, isFalse);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(finished, isTrue);
  });

  testWidgets('Skip closes the tour and marks it finished', (tester) async {
    var finished = false;
    await tester.pumpWidget(_harness(
      onFinish: () => finished = true,
      steps: const [
        TourStep(
            title: 'Welcome', body: 'Intro', icon: Icons.waving_hand_rounded),
        TourStep(title: 'Second', body: 'More', icon: Icons.dashboard_rounded),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(finished, isTrue);
    expect(find.text('Welcome'), findsNothing);
  });
}
