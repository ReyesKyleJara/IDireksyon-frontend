import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/office_finder/map_services.dart';
import 'package:idireksyon_frontend/features/office_finder/models/office_model.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';
import 'package:latlong2/latlong.dart';

const bulac = 3, guyong = 9;

OfficeModel office(int id, String name, {String? coverage, int? barangay}) =>
    OfficeModel.fromJson({
      'id': id,
      'name': name,
      'address': 'Saved address $id',
      'latitude': 14.85,
      'longitude': 120.81,
      'coverage': coverage,
      'barangay': barangay == null ? null : {'id': barangay, 'name': 'B$id'},
    });

final allOffices = [
  office(1, 'Municipal Hall', coverage: 'shared'),
  office(2, 'Bulac Barangay Hall', coverage: 'barangay', barangay: bulac),
  office(3, 'PhilSys Office'),
  office(4, 'Guyong Barangay Hall', coverage: 'barangay', barangay: guyong),
];

class _Services extends OfficeMapServices {
  @override
  Future<List<OfficeModel>> offices() async => [...allOffices];

  @override
  Future<LatLng> locate() async => const LatLng(14.84, 120.81);
}

Future<void> _open(WidgetTester tester) async {
  // Tall enough that every row is built.
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: OfficeFinderScreen(
        services: _Services(),
        mapBuilder: (_) => const SizedBox.expand(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

List<String> _order(WidgetTester tester) {
  final names = [for (final o in allOffices) o.name];
  final shown = names.where((n) => find.text(n).evaluate().isNotEmpty).toList()
    ..sort(
      (a, b) => tester
          .getTopLeft(find.text(a).first)
          .dy
          .compareTo(tester.getTopLeft(find.text(b).first).dy),
    );
  return shown;
}

Future<void> _done(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  tearDown(() => AuthService.instance.user = null);

  test('reads the barangay only from barangay-specific offices', () {
    expect(allOffices[1].barangayId, bulac);
    expect(allOffices[0].barangayId, isNull);
    expect(allOffices[2].barangayId, isNull);
    // A barangay sent with another coverage is ignored.
    expect(
      OfficeModel.fromJson({
        'id': 5,
        'name': 'X',
        'coverage': 'shared',
        'barangay': {'id': bulac},
      }).barangayId,
      isNull,
    );
  });

  testWidgets('pins and labels the resident\'s own hall, keeping all others', (
    tester,
  ) async {
    AuthService.instance.user = {'id': 1, 'barangay_id': guyong};
    await _open(tester);

    expect(_order(tester), [
      'Guyong Barangay Hall',
      'Municipal Hall',
      'Bulac Barangay Hall',
      'PhilSys Office',
    ]);
    expect(find.text('Your Barangay'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('finder-your-barangay-4')),
      findsOneWidget,
    );
    await _done(tester);
  });

  testWidgets('leaves the list unchanged without a saved barangay', (
    tester,
  ) async {
    AuthService.instance.user = {'id': 1, 'barangay_id': null};
    await _open(tester);

    expect(_order(tester), [for (final o in allOffices) o.name]);
    expect(find.text('Your Barangay'), findsNothing);

    // Saving a barangay in Account Details updates the open finder.
    AuthService.instance.user = {'id': 1, 'barangay_id': bulac};
    await tester.pumpAndSettle();
    expect(_order(tester).first, 'Bulac Barangay Hall');
    expect(
      find.byKey(const ValueKey('finder-your-barangay-2')),
      findsOneWidget,
    );
    await _done(tester);
  });
}
