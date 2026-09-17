import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

void main() {
  testWidgets('Preview Guide opens the Birth Certificate guide', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(home: SuggestedRoadmapScreen()),
    );

    await tester.tap(find.text('Preview Guide').first);
    await tester.pumpAndSettle();

    expect(find.text('PSA Birth Certificate Guide'), findsOneWidget);
  });
}