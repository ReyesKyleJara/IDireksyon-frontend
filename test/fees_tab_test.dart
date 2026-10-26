import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/fees_tab.dart';

Map<String, dynamic> choices() => {
  'id': 10, 'label': 'Processing Fee', 'type': 'options', 'selection_rule': 'choose_one',
  'options': [
    {'id': 11, 'label': 'Regular', 'type': 'fixed', 'amount_min': '950.00', 'currency': 'PHP', 'description': '10–15 working days'},
    {'id': 12, 'label': 'Expedited', 'type': 'fixed', 'amount_min': '1200.00', 'currency': 'PHP', 'description': '5–7 working days'},
  ],
};
GovernmentIdDetails record(List<Map<String, dynamic>> fees) => GovernmentIdDetails.fromJson({'id': 55, 'name': 'API entry', 'fees': fees});

void main() {
  test('parses nested amounts descriptions and keeps simple and legacy records', () {
    final fee = record([choices()]).fees.single;
    expect(fee.type, 'options'); expect(fee.options.length, 2);
    expect(fee.options[0].amountMin, 950); expect(fee.options[1].description, '5–7 working days');
    expect(fee.displayAmount, 'Choose one'); expect(fee.options[1].displayAmount, '₱1,200.00');
    expect(record([]).fees, isEmpty);
    expect(CatalogFee.fromJson({'type': 'free'}).displayAmount, 'Free');
    expect(CatalogFee.fromJson({'type': 'range', 'amount_min': '10', 'amount_max': '20'}).displayAmount, '₱10.00–₱20.00');
    expect(CatalogFee.fromJson({'type': 'varies'}).displayAmount, 'Varies');
    expect(CatalogFee.fromJson({'type': 'fixed'}).displayAmount, 'Varies');
  });

  testWidgets('choose one starts unselected and switching never adds option amounts', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeesTab(record: record([choices()])))));
    expect(find.text('Choose one processing option'), findsOneWidget);
    expect(find.text('Select one option to see its applicable fee.'), findsOneWidget);
    expect(find.textContaining('2,150'), findsNothing);
    await tester.tap(find.text('Regular')); await tester.pump();
    expect(find.text('Selected option: Regular — ₱950.00'), findsOneWidget);
    await tester.tap(find.text('Expedited')); await tester.pump();
    expect(find.text('Selected option: Expedited — ₱1,200.00'), findsOneWidget);
    expect(find.text('Selected option: Regular — ₱950.00'), findsNothing);
    expect(find.textContaining('2,150'), findsNothing); expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 900.0]) {
    testWidgets('choices fit width $width and stack on narrow screens', (tester) async {
      tester.view.physicalSize = Size(width, 1100); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeesTab(record: record([choices()])))));
      final regular = tester.getTopLeft(find.text('Regular'));
      final expedited = tester.getTopLeft(find.text('Expedited'));
      if (width < 520) { expect(expedited.dy, greaterThan(regular.dy)); }
      else { expect(expedited.dy, regular.dy); }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('simple optional fees and legacy fallback display real data', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeesTab(record: record([
      {'id': 1, 'label': 'Registration', 'type': 'fixed', 'amount_min': '100', 'is_optional': true},
    ])))));
    expect(find.text('₱100.00'), findsOneWidget); expect(find.text('Optional fee'), findsOneWidget);
    expect(find.text('Choose one processing option'), findsNothing);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: FeesTab(record: GovernmentIdDetails.fromJson({'id': 55, 'fee': 'Legacy fee note'})))));
    expect(find.text('Legacy fee note'), findsOneWidget);
  });
}
