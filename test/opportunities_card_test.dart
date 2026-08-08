import 'package:classtrack/core/providers/firebase_providers.dart';
import 'package:classtrack/features/opportunities/domain/resource.dart';
import 'package:classtrack/features/opportunities/domain/resource_status.dart';
import 'package:classtrack/features/opportunities/domain/resource_type.dart';
import 'package:classtrack/features/opportunities/presentation/widgets/resource_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('ResourceCard shows title, brand, type and deadline',
      (tester) async {
    final resource = Resource(
      id: 'r1',
      type: ResourceType.internship,
      title: 'AI Internship 2026',
      organization: 'OpenLab',
      status: ResourceStatus.active,
      deadline: DateTime.now().add(const Duration(days: 5)),
    );

    var tapped = false;
    await tester.pumpWidget(
      ProviderScope(
        // Signed-out override so the saved-state provider never touches
        // FirebaseAuth/Firestore in the test environment.
        overrides: [currentUidProvider.overrideWithValue(null)],
        child: MaterialApp(
          home: Scaffold(
            body: ResourceCard(
              resource: resource,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('AI Internship 2026'), findsOneWidget);
    expect(find.text('OpenLab'), findsOneWidget);
    expect(find.text('Internship'), findsOneWidget);
    expect(find.text('Closes in 5 days'), findsOneWidget);

    // Bookmark toggle is present (signed-out: no-op, but rendered).
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

    await tester.tap(find.text('AI Internship 2026'));
    expect(tapped, isTrue);
  });
}
