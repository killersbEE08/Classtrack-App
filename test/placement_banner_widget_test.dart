import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/core/theme/app_theme.dart';
import 'package:classtrack/features/cms/domain/marketing.dart';
import 'package:classtrack/shared/widgets/placement_banner.dart';

void main() {
  testWidgets('PlacementBanner renders a live banner for its placement',
      (tester) async {
    const banner = CmsBanner(
      id: 'b1',
      title: 'Summer deal',
      placement: Placements.opportunities,
      published: true,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placementBannersProvider(Placements.opportunities)
              .overrideWith((ref) => Stream.value(const [banner])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: PlacementBanner(placement: Placements.opportunities),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Summer deal'), findsOneWidget);
  });

  testWidgets('PlacementBanner renders nothing when there is no live banner',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          placementBannersProvider(Placements.discounts)
              .overrideWith((ref) => Stream.value(const <CmsBanner>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: PlacementBanner(placement: Placements.discounts),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(InkWell), findsNothing);
  });
}
