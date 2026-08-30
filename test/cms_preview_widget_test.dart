import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/auth/presentation/providers/auth_providers.dart';
import 'package:classtrack/features/cms/presentation/screens/cms_resource_preview_screen.dart';
import 'package:classtrack/features/opportunities/domain/recommendation_weights.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';
import 'package:classtrack/features/opportunities/presentation/providers/opportunities_providers.dart';

void main() {
  testWidgets('Preview renders the real card + detail for a resource',
      (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const resource = Resource(
      id: 'r1',
      type: ResourceType.internship,
      title: 'Google STEP Internship',
      organization: 'Google',
      description: 'A first-year internship program for students.',
      applicationUrl: 'https://example.com',
      countries: ['India'],
      status: ResourceStatus.active,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Avoid Firestore in tests; the recommender uses default weights.
          recommendationWeightsProvider
              .overrideWith((ref) => Stream.value(RecommendationWeights.defaults)),
          userProfileProvider.overrideWith((ref) => Stream.value(null)),
          savedResourceIdsProvider
              .overrideWith((ref) => Stream.value(const <String>{})),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const CmsResourcePreviewScreen(resource: resource),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Preview profile'), findsOneWidget);
    expect(find.text('IN THE FEED'), findsOneWidget);
    expect(find.text('DETAIL PAGE'), findsOneWidget);
    // The resource title appears (feed card + detail preview).
    expect(find.text('Google STEP Internship'), findsWidgets);
  });
}
