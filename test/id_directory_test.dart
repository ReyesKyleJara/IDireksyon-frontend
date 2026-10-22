import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

void main() {
  testWidgets(
    'directory uses supplied records and filters names and agencies',
    (tester) async {
      final records = [
        GovernmentIdDetails.fromJson({
          'id': 81,
          'name': 'Current CMS ID',
          'issued_by': 'Current agency',
        }),
        GovernmentIdDetails.fromJson({
          'id': 82,
          'name': 'Another CMS ID',
          'issued_by': 'Different agency',
        }),
      ];
      // Also works as a directly pushed screen, without an ancestor Scaffold.
      await tester.pumpWidget(
        MaterialApp(home: IdsScreen(loadIds: () async => records)),
      );
      await tester.pumpAndSettle();
      expect(find.text('ID Directory'), findsOneWidget);
      expect(find.text('Featured IDs'), findsOneWidget);
      expect(find.text('All IDs'), findsOneWidget);
      expect(find.text('Current CMS ID'), findsWidgets);
      expect(find.text('Passport ID'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Different agency');
      await tester.pumpAndSettle();
      expect(find.text('Current CMS ID'), findsNothing);
      expect(find.text('Another CMS ID'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
