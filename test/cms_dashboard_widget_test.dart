import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/cms/domain/cms_role.dart';
import 'package:classtrack/features/cms/presentation/providers/cms_resource_providers.dart';
import 'package:classtrack/features/cms/presentation/screens/cms_dashboard_screen.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';

void main() {
  testWidgets('Dashboard shows live content metrics from the resource stream',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final sample = <Resource>[
      const Resource(id: '1', type: ResourceType.scholarship, title: 'A', organization: 'O', status: ResourceStatus.active),
      const Resource(id: '2', type: ResourceType.discount, title: 'B', organization: 'O', status: ResourceStatus.draft),
      const Resource(id: '3', type: ResourceType.discount, title: 'C', organization: 'O', status: ResourceStatus.active),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cmsResourcesProvider.overrideWith((ref) => Stream.value(sample)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: CmsDashboardScreen(role: CmsRole.superAdmin),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Total resources'), findsOneWidget);
    expect(find.text('Published'), findsOneWidget);
    expect(find.text('Content by type'), findsOneWidget);
    // 3 total, 2 published (active), 1 draft — the values render as headline text.
    expect(find.text('3'), findsWidgets);
  });
}
