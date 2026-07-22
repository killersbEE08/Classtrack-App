import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/habits/presentation/screens/habits_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('HabitEditorSheet lays out with the app theme', (tester) async {
    tester.view.physicalSize = const Size(1084, 2412);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder: (_) => const HabitEditorSheet(),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final ex = tester.takeException();
    expect(ex, isNull, reason: 'sheet threw: $ex');
    expect(find.text('Save'), findsOneWidget);
    // Sheet must have real height, not collapse to zero.
    final h = tester.getSize(find.text('Save')).height;
    expect(h, greaterThan(0));
  });
}
