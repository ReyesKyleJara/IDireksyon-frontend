import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/features/office_finder/map_services.dart';
import 'package:idireksyon_frontend/features/office_finder/models/office_model.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> day(int day, String status, [List<List<String>>? hours]) =>
    {
      'day_of_week': day,
      'status': status,
      'intervals': [
        for (final row in hours ?? const <List<String>>[])
          {'opens_at': row[0], 'closes_at': row[1]},
      ],
    };

/// Philippine wall-clock time expressed in UTC (PHT = UTC+8).
DateTime manila(int y, int m, int d, int h) => DateTime.utc(y, m, d, h - 8);

class _Services extends OfficeMapServices {
  _Services(this.list, {this.denied = false});
  List<OfficeModel> list;
  bool denied;
  bool failing = false;
  int locates = 0;

  @override
  Future<List<OfficeModel>> offices() async {
    if (failing) throw StateError('Offices are unavailable. Please try again.');
    return list;
  }

  @override
  Future<LatLng> locate() async {
    locates++;
    if (denied) throw StateError('Allow location access.');
    return const LatLng(14.80, 120.92); // Beside Marilao, far from Malolos.
  }
}

const _malolos = OfficeModel(
  id: '3',
  name: 'DFA Malolos',
  agency: 'DFA',
  address: 'Malolos',
  records: ['Philippine Passport'],
  latitude: 14.8527,
  longitude: 120.8160,
);
const _marilao = OfficeModel(
  id: '4',
  name: 'DFA Marilao',
  agency: 'DFA',
  address: 'Marilao',
  records: ['Philippine Passport'],
  latitude: 14.7900,
  longitude: 120.9300,
);
const _noPin = OfficeModel(
  id: '5',
  name: 'DFA Annex',
  agency: 'DFA',
  address: 'Unknown',
  records: ['Philippine Passport'],
);
const _sss = OfficeModel(
  id: '6',
  name: 'SSS Marilao',
  agency: 'SSS',
  address: 'Marilao',
  records: ['MySSS Card'],
  latitude: 14.7901,
  longitude: 120.9301,
);

/// Test-only coordinates, shaped like one row of `GET /api/offices`.
Map<String, dynamic> _pilotJson(int id, String name, {bool located = true}) => {
  'id': id,
  'name': name,
  'address': 'Pilot address',
  'records': ['Philippine Passport'],
  'latitude': located ? '14.8000000' : null,
  'longitude': located ? '120.8000000' : null,
};

late google.GoogleMap _map;

Future<void> _open(
  WidgetTester tester,
  OfficeMapServices services, {
  Size size = const Size(390, 1000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OfficeFinderScreen(
        services: services,
        mapBuilder: (map) {
          _map = map;
          return const SizedBox.expand();
        },
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  group('OfficeModel.fromJson', () {
    test('reads the API payload, including decimal strings', () {
      final office = OfficeModel.fromJson({
        'id': 3,
        'name': 'DFA Consular Office Malolos',
        'address': 'SM City Malolos',
        'municipality': 'Malolos',
        'province': 'Bulacan',
        'latitude': '14.8527000',
        'longitude': '120.8160000',
        'agency': {'name': 'Department of Foreign Affairs', 'acronym': 'DFA'},
        'records': ['Philippine Passport', 'Authentication'],
        'schedules': [
          day(1, 'open', [
            ['08:00:00', '12:00:00'],
            ['13:00:00', '17:30:00'],
          ]),
          day(0, 'closed'),
          day(2, 'unknown'),
        ],
      });
      expect(office.id, '3');
      expect(office.agency, 'DFA');
      expect(office.latitude, 14.8527);
      expect(office.address, 'SM City Malolos, Bulacan');
      expect(office.serviceTag, 'Philippine Passport and 1 more');
      // Monday 2026-11-09.
      expect(
        office.hoursOn(manila(2026, 11, 9, 10)),
        'Today: 8:00 AM - 12:00 PM, 1:00 PM - 5:30 PM',
      );
      expect(office.hoursOn(manila(2026, 11, 8, 10)), 'Today: Closed');
      expect(office.hoursOn(manila(2026, 11, 10, 10)), isNull);
      expect(office.hoursOn(manila(2026, 11, 11, 10)), isNull);
    });

    test('uses Philippine time for the day of the week', () {
      final office = OfficeModel.fromJson({
        'id': 1,
        'name': 'Office',
        'schedules': [
          day(1, 'open', [
            ['08:00:00', '17:00:00'],
          ]),
        ],
      });
      // Sunday 17:00 UTC is already Monday 1:00 AM in Manila.
      expect(
        office.hoursOn(DateTime.utc(2026, 11, 8, 17)),
        'Today: 8:00 AM - 5:00 PM',
      );
    });

    test('tidies CMS typing slips for display', () {
      final office = OfficeModel.fromJson({
        'id': 1,
        'name': ' BIR RDO 25A- West  Bulacan ',
        'address': '2nd Floor, Provincial PESO Building,',
        'municipality': 'Malolos',
        'records': ['Student Driver`s License'],
      });
      expect(office.name, 'BIR RDO 25A - West Bulacan');
      expect(office.address, '2nd Floor, Provincial PESO Building, Malolos');
      expect(office.records.single, 'Student Driver’s License');

      String address(String text, String town) => OfficeModel.fromJson({
        'id': 1,
        'name': 'A',
        'address': text,
        'municipality': town,
      }).address;
      expect(address('Sampaloc, Manila.', 'Manila'), 'Sampaloc, Manila');
      expect(address('162 Sandico St.', 'Marilao'), '162 Sandico St., Marilao');
    });

    test('treats missing or partial coordinates as no location', () {
      expect(OfficeModel.fromJson({'id': 1, 'name': 'A'}).latitude, isNull);
      final partial = OfficeModel.fromJson({
        'id': 1,
        'name': 'A',
        'latitude': '14.8',
        'longitude': null,
      });
      expect(partial.latitude, isNull);
      expect(partial.longitude, isNull);
      expect(partial.address, 'Address not yet added.');
    });

    test('keeps saved coordinates with no further step', () {
      final office = OfficeModel.fromJson(_pilotJson(19, 'PSA'));
      expect(office.latitude, 14.8);
      expect(office.longitude, 120.8);
    });
  });

  group('pilot offices', () {
    Future<void> select(WidgetTester tester, String name) async {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }

    Future<void> done(WidgetTester tester) async {
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    }

    for (final (id, name) in [
      (3, 'DFA Malolos pilot'),
      (19, 'PSA Bulacan CRS Outlet'),
    ]) {
      testWidgets('$name offers directions as soon as it has coordinates', (
        tester,
      ) async {
        await _open(
          tester,
          _Services([OfficeModel.fromJson(_pilotJson(id, name))]),
        );
        await tester.pumpAndSettle();
        expect(
          _map.markers.map((marker) => marker.markerId.value),
          contains('office-$id'),
        );
        await select(tester, name);
        expect(find.text('Get Directions'), findsOneWidget);
        expect(find.textContaining('erified'), findsNothing);
        await done(tester);
      });

      testWidgets('$name offers no directions without coordinates', (
        tester,
      ) async {
        await _open(
          tester,
          _Services([
            OfficeModel.fromJson(_pilotJson(id, name, located: false)),
          ]),
        );
        await tester.pumpAndSettle();
        expect(_map.markers, isEmpty);
        await select(tester, name);
        expect(find.text('Get Directions'), findsNothing);
        await done(tester);
      });
    }

    testWidgets(
      'an office without coordinates stays listed without navigation or distance',
      (tester) async {
        final services = _Services([
          OfficeModel.fromJson(
            _pilotJson(14, 'PRC Regional Office III', located: false),
          ),
        ]);
        await _open(tester, services);
        await tester.tap(find.byTooltip('Use my current location'));
        await tester.pumpAndSettle();
        expect(find.text('PRC Regional Office III'), findsOneWidget);
        expect(find.textContaining('Straight-line'), findsNothing);
        expect(
          _map.markers.map((marker) => marker.markerId.value),
          isNot(contains('office-14')),
        );
        await select(tester, 'PRC Regional Office III');
        expect(find.text('Get Directions'), findsNothing);
        expect(find.textContaining('isn’t available'), findsOneWidget);
        expect(find.textContaining('erified'), findsNothing);
        await done(tester);
      },
    );
  });

  test('offices() reads GET /offices and reports failures', () async {
    final service = OfficeMapServices(
      baseUrl: 'http://localhost:8000/api',
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.toString(), 'http://localhost:8000/api/offices');
        return http.Response(
          jsonEncode({
            'data': [
              {'id': 9, 'name': 'Listed'},
            ],
          }),
          200,
        );
      }),
    );
    expect((await service.offices()).single.name, 'Listed');
    service.dispose();

    final failing = OfficeMapServices(
      baseUrl: 'http://localhost:8000/api',
      client: MockClient((_) async => http.Response('Not found', 404)),
    );
    await expectLater(failing.offices(), throwsStateError);
    failing.dispose();
  });

  testWidgets('the location button ranks searched offices by distance', (
    tester,
  ) async {
    final services = _Services([_malolos, _noPin, _sss, _marilao]);
    await _open(tester, services);

    await tester.enterText(find.byType(TextField), 'dfa');
    await tester.pumpAndSettle();
    expect(services.locates, 0);
    expect(find.textContaining('Straight-line'), findsNothing);

    await tester.tap(find.byTooltip('Use my current location'));
    await tester.pumpAndSettle();
    expect(services.locates, 1);
    expect(find.text('SSS Marilao'), findsNothing);
    tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!
        .jumpTo(.96);
    await tester.pumpAndSettle();
    double top(String name) => tester.getTopLeft(find.text(name)).dy;
    expect(top('DFA Marilao'), lessThan(top('DFA Malolos')));
    expect(top('DFA Malolos'), lessThan(top('DFA Annex')));
    expect(find.text('3 offices'), findsOneWidget);
    expect(find.textContaining('found near you'), findsNothing);
    expect(
      find.text('Straight-line distances, not road distances.'),
      findsOneWidget,
    );
    expect(
      _map.markers.map((marker) => marker.markerId.value),
      isNot(contains('office-5')),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('search works and never asks for location', (tester) async {
    final services = _Services([_malolos, _marilao], denied: true);
    await _open(tester, services);
    await tester.enterText(find.byType(TextField), 'd');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'df');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(services.locates, 0);
    expect(find.text('2 offices'), findsOneWidget);
    expect(find.text('DFA Malolos'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('an office without coordinates cannot start directions', (
    tester,
  ) async {
    await _open(tester, _Services([_noPin]));
    await tester.tap(find.text('DFA Annex'));
    await tester.pumpAndSettle();
    expect(find.textContaining('isn’t available'), findsOneWidget);
    expect(find.text('Get Directions'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('related IDs and documents read as plain rows', (tester) async {
    const office = OfficeModel(
      id: '8',
      name: 'Regional Office',
      address: 'Malolos',
      records: ['TIN ID', 'Philippine Passport'],
      latitude: 14.8,
      longitude: 120.8,
    );
    await _open(tester, _Services([office]));
    expect(find.text('TIN ID and 1 more'), findsOneWidget);
    await tester.tap(find.text('Regional Office'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('More details'));
    await tester.pumpAndSettle();
    expect(find.text('IDs and documents'), findsOneWidget);
    expect(find.text('TIN ID'), findsOneWidget);
    expect(find.text('Philippine Passport'), findsOneWidget);
    expect(find.byIcon(Icons.description_outlined), findsNWidgets(2));
    expect(find.byType(Chip), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('the related section is hidden when an office has none', (
    tester,
  ) async {
    const office = OfficeModel(
      id: '9',
      name: 'Bare Office',
      address: 'Bulacan',
    );
    await _open(tester, _Services([office]));
    await tester.tap(find.text('Bare Office'));
    await tester.pumpAndSettle();
    expect(find.text('IDs and documents'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('long CMS text wraps fully under large Android text', (
    tester,
  ) async {
    final longName =
        'Bureau of Internal Revenue Revenue District Office ${'Bulacan ' * 8}'
            .trim();
    final longAddress = 'Unit 11, ${'McArthur Highway, ' * 8}Bulacan';
    final longRecord = 'Certificate of ${'Registration ' * 8}'.trim();
    final office = OfficeModel(
      id: '10',
      name: longName,
      address: longAddress,
      records: [longRecord],
      latitude: 14.8,
      longitude: 120.8,
    );
    await _open(
      tester,
      _Services([office]),
      size: const Size(320, 640),
      textScale: 2,
    );
    final sheet = tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!;
    sheet.jumpTo(.96);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longName)).maxLines, isNull);
    expect(tester.widget<Text>(find.text(longAddress)).maxLines, isNull);
    expect(tester.takeException(), isNull);

    // The wrapped name is taller than the screen, so tap its first line.
    await tester.tapAt(
      tester.getTopLeft(find.text(longName)) + const Offset(20, 10),
    );
    await tester.pumpAndSettle();
    expect(find.text('Get Directions'), findsOneWidget);
    sheet.jumpTo(.96);
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text(longRecord)).maxLines, isNull);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a failed load can be retried', (tester) async {
    final services = _Services([_malolos])..failing = true;
    await _open(tester, services);
    expect(
      find.text('Offices are unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('No matching offices'), findsNothing);
    services.failing = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('DFA Malolos'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });
}
