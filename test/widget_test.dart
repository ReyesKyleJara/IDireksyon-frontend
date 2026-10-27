import 'package:flutter/material.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

void main() {
  testWidgets('Preview Guide opens the selected catalog target', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SuggestedRoadmapScreen(targetIds: ['Philippine Passport'], targetCatalogIds: [55])),
    );

    await tester.tap(find.text('Preview Guide').first);
    await tester.pumpAndSettle();

    expect(find.byType(IdDetailsScreen), findsOneWidget);
    expect(tester.widget<IdDetailsScreen>(find.byType(IdDetailsScreen)).governmentId, 55);
    expect(find.text('PSA Birth Certificate Guide'), findsNothing);
  });
}