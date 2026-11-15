import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

/// Fake API data only.
Future<void> pump(WidgetTester tester, Map<String, dynamic> extra) async {
  final record = GovernmentIdDetails.fromJson({
    'id': 1,
    'name': 'Fixture ID',
    'issued_by': 'Fixture Agency',
    ...extra,
  });
  await tester.pumpWidget(
    MaterialApp(
      home: IdDetailsScreen(
        idName: record.name,
        governmentId: record.id,
        loadDetail: (_) async => record,
        shareRecord: (_, _) async {},
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final long = List.filled(
    12,
    'A long sentence about this fixture ID.',
  ).join(' ');

  testWidgets('shows About in the hero under the issuer, shortened', (
    tester,
  ) async {
    await pump(tester, {'description': long});
    final hero = find.byKey(const ValueKey('detail-brand-header'));
    final about = find.descendant(of: hero, matching: find.text(long));

    expect(about, findsOneWidget);
    expect(tester.widget<Text>(about).maxLines, 3);
    expect(
      tester.getTopLeft(about).dy,
      greaterThan(tester.getTopLeft(find.text('Fixture Agency')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens the whole About text when tapped', (tester) async {
    await pump(tester, {'description': long});
    await tester.tap(find.byKey(const ValueKey('hero-about')));
    await tester.pumpAndSettle();

    expect(find.text('About Fixture ID'), findsOneWidget);
    expect(find.byType(SelectableText), findsWidgets);
  });

  testWidgets('shows no About block without a description', (tester) async {
    await pump(tester, {});
    expect(find.byKey(const ValueKey('hero-about')), findsNothing);
    expect(find.text('About'), findsNothing);
  });
}
