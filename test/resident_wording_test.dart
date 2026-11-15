import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

/// Fake API data only.
GovernmentIdDetails fixture() =>
    GovernmentIdDetails.fromJson({'id': 1, 'name': 'Fixture ID'});

Map<String, dynamic> method(Map<String, dynamic> extra) => {
  'id': 7,
  'label': 'Walk-in',
  'requirement_sets': [],
  'fees': [],
  'offices': [
    {
      'name': 'Fixture Office',
      'address': 'Fixture Street',
      'services': {
        'new_application_status': 'unknown',
        'renewal_status': 'available',
        'replacement_status': 'unknown',
      },
    },
  ],
  ...extra,
};

Future<void> pump(WidgetTester tester, Map<String, dynamic> data) async {
  await tester.pumpWidget(
    MaterialApp(
      home: RequestMethodScreen(record: fixture(), method: data),
    ),
  );
  await tester.pumpAndSettle();
}

Iterable<String> texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  testWidgets('leaves out unknown appointment and office service values', (
    tester,
  ) async {
    await pump(tester, method({'appointment': 'unknown', 'fulfillment': []}));

    final shown = texts(tester).join('\n').toLowerCase();
    expect(shown, isNot(contains('unknown')));
    expect(find.text('Request information'), findsNothing);
    expect(find.text('Renewals: Available'), findsOneWidget);
    expect(find.textContaining('New applications'), findsNothing);
  });

  testWidgets('shows known request details in plain words', (tester) async {
    await pump(
      tester,
      method({
        'appointment': 'not_required',
        'fulfillment': ['pickup', 'delivery'],
      }),
    );

    expect(find.text('Request information'), findsOneWidget);
    expect(find.text('Appointment: Not required'), findsOneWidget);
    expect(find.text('How you receive it: Pickup, Delivery'), findsOneWidget);
  });
}
