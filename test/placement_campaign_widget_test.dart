import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:classtrack/features/cms/domain/marketing.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';
import 'package:classtrack/features/opportunities/presentation/providers/opportunities_providers.dart';
import 'package:classtrack/shared/widgets/placement_campaign.dart';

void main() {
  const promoted = Resource(
    id: 'r1',
    type: ResourceType.scholarship,
    title: 'Promoted Scholarship',
    organization: 'Acme',
    status: ResourceStatus.active,
  );

  Widget host(List<Campaign> campaigns, List<Resource> resources) => ProviderScope(
        overrides: [
          placementCampaignsProvider(Placements.opportunities)
              .overrideWith((ref) => Stream.value(campaigns)),
          visibleResourcesProvider.overrideWith((ref) => Stream.value(resources)),
        ],
        child: const MaterialApp(
          home: Scaffold(
            body: PlacementCampaign(placement: Placements.opportunities),
          ),
        ),
      );

  testWidgets('renders a sponsored card for the promoted resource',
      (tester) async {
    const campaign = Campaign(
      id: 'c1',
      company: 'Acme Corp',
      name: 'Autumn push',
      resourceId: 'r1',
      placement: Placements.opportunities,
      published: true,
    );

    await tester.pumpWidget(host(const [campaign], const [promoted]));
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Promoted Scholarship'), findsOneWidget);
    expect(find.textContaining('SPONSORED'), findsOneWidget);
    expect(find.textContaining('Acme Corp'), findsOneWidget);
  });

  testWidgets('renders nothing when the promoted resource is not visible',
      (tester) async {
    const campaign = Campaign(
      id: 'c1',
      company: 'Acme Corp',
      name: 'Autumn push',
      resourceId: 'missing',
      placement: Placements.opportunities,
      published: true,
    );

    await tester.pumpWidget(host(const [campaign], const [promoted]));
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('SPONSORED'), findsNothing);
  });
}
