import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/cms/domain/cms_role.dart';
import 'package:classtrack/features/cms/presentation/providers/cms_resource_providers.dart';
import 'package:classtrack/features/cms/presentation/screens/cms_resources_screen.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

void main() {
  testWidgets('Resources list supports multi-select bulk actions',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const sample = <Resource>[
      Resource(id: '1', type: ResourceType.scholarship, title: 'Alpha', organization: 'O', status: ResourceStatus.draft),
      Resource(id: '2', type: ResourceType.internship, title: 'Beta', organization: 'O', status: ResourceStatus.active),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsResourcesProvider.overrideWith((ref) => Stream.value(sample)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CmsResourcesScreen(role: CmsRole.superAdmin),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    expect(tester.takeException(), isNull);

    // Enter selection mode.
    expect(find.text('Select'), findsOneWidget);
    await tester.tap(find.text('Select'));
    await tester.pump();
    expect(find.byType(Checkbox), findsNWidgets(2));

    // Select one row -> contextual bulk bar appears with actions.
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    expect(find.text('1 selected'), findsOneWidget);
    expect(find.text('Publish'), findsOneWidget);
    expect(find.text('Archive'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });
}
