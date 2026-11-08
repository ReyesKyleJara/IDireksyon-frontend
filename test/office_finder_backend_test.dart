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

late google.GoogleMap _map;

Future<void> _open(WidgetTester tester, OfficeMapServices services) async {
  tester.view.physicalSize = const Size(390, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
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
      expect(office.serviceTag, 'Philippine Passport +1');
      // Monday 2026-11-09.
      expect(
        office.hoursOn(manila(2026, 11, 9, 10)),
        'Today: 8:00 AM - 12:00 PM, 1:00 PM - 5:30 PM',
      );
      expect(office.hoursOn(manila(2026, 11, 8, 10)), 'Today: Closed');
      expect(office.hoursOn(manila(2026, 11, 10, 10)), 'Hours not listed');
      expect(office.hoursOn(manila(2026, 11, 11, 10)), 'Hours not listed');
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

  testWidgets('searching DFA lists the nearest office first', (tester) async {
    final services = _Services([_malolos, _noPin, _sss, _marilao]);
    await _open(tester, services);

    await tester.enterText(find.byType(TextField), 'd');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'dfa');
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
    expect(find.text('3 offices found near you'), findsOneWidget);
    expect(
      _map.markers.map((marker) => marker.markerId.value),
      isNot(contains('office-5')),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('a denied location still shows results and asks only once', (
    tester,
  ) async {
    final services = _Services([_malolos, _marilao], denied: true);
    await _open(tester, services);
    await tester.enterText(find.byType(TextField), 'd');
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'df');
    await tester.pumpAndSettle();
    expect(services.locates, 1);
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
    await tester.scrollUntilVisible(
      find.textContaining('no map location yet'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.textContaining('no map location yet'), findsOneWidget);
    final button = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Get directions'),
        matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
      ),
    );
    expect(button.onPressed, isNull);
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
