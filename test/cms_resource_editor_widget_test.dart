import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/cms/presentation/screens/cms_resource_editor_screen.dart';

void main() {
  testWidgets(
      'CmsResourceEditorScreen renders the form and pins Save to the bottom',
      (tester) async {
    tester.view.physicalSize = const Size(1900, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CmsResourceEditorScreen(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    // No layout/overflow exceptions.
    expect(tester.takeException(), isNull);

    // The form body actually rendered its fields (regression: it previously
    // collapsed to zero height, leaving the screen blank).
    expect(find.text('Basics'), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);

    // The content-quality panel is present.
    expect(find.text('Content quality'), findsOneWidget);

    // The sticky Save action is present and sits at the bottom of the screen,
    // not floating in the vertical centre.
    final save = find.text('Create resource');
    expect(save, findsOneWidget);
    final saveRect = tester.getRect(save);
    expect(saveRect.center.dy, greaterThan(700),
        reason: 'Save bar should be pinned near the bottom (window is 900 tall)');
  });
}
