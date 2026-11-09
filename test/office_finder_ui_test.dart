import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/office_finder/map_services.dart';
import 'package:idireksyon_frontend/features/office_finder/models/office_model.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';
import 'package:latlong2/latlong.dart';

Map<String, dynamic> day(
  int day,
  String status, [
  List<List<dynamic>>? hours,
]) => {
  'day_of_week': day,
  'status': status,
  'intervals': [
    for (final row in hours ?? const <List<dynamic>>[])
      {'opens_at': row[0], 'closes_at': row[1]},
  ],
};

/// Open at the same hours every day, so tests do not depend on today's date.
List<Map<String, dynamic>> everyDay() => [
  for (var i = 0; i < 7; i++)
    day(i, 'open', [
      ['08:00:00', '17:00:00'],
    ]),
];

OfficeModel office(
  int id,
  String name, {
  dynamic latitude = 14.85,
  dynamic longitude = 120.81,
  List<Map<String, dynamic>> schedules = const [],
  List<String> records = const ['Philippine Passport', 'Postal ID'],
}) => OfficeModel.fromJson({
  'id': id,
  'name': name,
  'address': 'Saved address $id',
  'latitude': latitude,
  'longitude': longitude,
  'schedules': schedules,
  'records': records,
});

class _Services extends OfficeMapServices {
  _Services(this.list);
  final List<OfficeModel> list;
  bool failing = false;

  @override
  Future<List<OfficeModel>> offices() async {
    if (failing) throw StateError('Offices are unavailable. Please try again.');
    return list;
  }

  @override
  Future<LatLng> locate() async => const LatLng(14.84, 120.81);
}

late google.GoogleMap _map;

Future<void> _open(
  WidgetTester tester,
  OfficeMapServices services, {
  Size size = const Size(360, 740),
  double top = 0,
  double bottom = 0,
  double keyboard = 0,
  OfficeModel? initial,
  Future<bool> Function(Uri)? launch,
  bool dark = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: OfficeFinderScreen(
        initialOffice: initial,
        services: services,
        mapBuilder: (map) {
          _map = map;
          return const ColoredBox(
            key: ValueKey('map-area'),
            color: Color(0xFFE8EEE6),
          );
        },
        launchDirections: launch,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _done(WidgetTester tester) async {
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

double _panelTop(WidgetTester tester) =>
    tester.getTopLeft(find.byKey(const ValueKey('office-sheet-handle'))).dy;

DraggableScrollableController _sheet(WidgetTester tester) => tester
    .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
    .controller!;

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// Wording the app must never show again.
void _expectNoVerificationText() {
  for (final text in [
    'verified',
    'Verified',
    'Hours not listed',
    'Confirm before visiting',
  ]) {
    expect(find.textContaining(text), findsNothing, reason: text);
  }
}

void main() {
  group('usable location rule', () {
    test('accepts saved coordinates, including decimal strings', () {
      final location = OfficeModel.usableLocation('14.8527000', '120.8160000');
      expect(location?.latitude, 14.8527);
      expect(location?.longitude, 120.816);
      expect(OfficeModel.usableLocation(90, 180), isNotNull);
      expect(OfficeModel.usableLocation(0, 120.9), isNotNull);
      expect(OfficeModel.usableLocation(14.8, 0), isNotNull);
    });

    final invalid = <String, (Object?, Object?)>{
      'both missing': (null, null),
      'latitude missing': (null, 120.8),
      'longitude missing': (14.8, null),
      'zero zero': (0, 0),
      'zero zero text': ('0.0000000', '0.0000000'),
      'latitude out of range': (90.5, 120),
      'longitude out of range': (14, 180.5),
      'not a number': ('abc', '120'),
      'infinite': (double.infinity, 120),
    };
    for (final entry in invalid.entries) {
      test('rejects ${entry.key}', () {
        final (latitude, longitude) = entry.value;
        expect(OfficeModel.usableLocation(latitude, longitude), isNull);
        final parsed = OfficeModel.fromJson({
          'id': 1,
          'name': 'A',
          'latitude': latitude,
          'longitude': longitude,
        });
        expect(parsed.latitude, isNull);
        expect(parsed.longitude, isNull);
      });
    }

    test('needs no verification field', () {
      final parsed = OfficeModel.fromJson({
        'id': 1,
        'name': 'A',
        'latitude': '14.8',
        'longitude': '120.8',
      });
      expect(parsed.latitude, 14.8);
    });
  });

  group('operating hours', () {
    test('reports no hours when nothing real is known', () {
      for (final schedules in [
        <Map<String, dynamic>>[],
        [for (var i = 0; i < 7; i++) day(i, 'unknown')],
        [for (var i = 0; i < 7; i++) day(i, 'open')],
        [
          for (var i = 0; i < 7; i++)
            day(i, 'open', [
              ['soon', 'later'],
              [null, '17:00:00'],
              ['25:00:00', '26:00:00'],
            ]),
        ],
      ]) {
        final model = office(1, 'A', schedules: schedules);
        expect(model.hoursOn(DateTime.now()), isNull);
        expect(model.weeklyHours, isEmpty);
      }
    });

    test('groups matching days and keeps the real times', () {
      final model = office(
        1,
        'A',
        schedules: [
          for (var i = 1; i <= 5; i++)
            day(i, 'open', [
              ['08:00:00', '12:00:00'],
              ['13:00:00', '17:30:00'],
            ]),
          day(6, 'open', [
            ['09:00', '12:00'],
          ]),
          day(0, 'closed'),
        ],
      );
      expect(model.weeklyHours.map((line) => '$line'), [
        'Mon–Fri: 8:00 AM - 12:00 PM, 1:00 PM - 5:30 PM',
        'Sat: 9:00 AM - 12:00 PM',
        'Sun: Closed',
      ]);
    });

    test('a day with no research is not merged or shown as closed', () {
      final model = office(
        1,
        'A',
        schedules: [day(1, 'closed'), day(2, 'unknown'), day(3, 'closed')],
      );
      expect(model.weeklyHours.map((line) => '$line'), [
        'Mon: Closed',
        'Wed: Closed',
      ]);
    });

    testWidgets('the hours row disappears with no gap when none exist', (
      tester,
    ) async {
      final without = office(1, 'No Hours');
      final withHours = office(2, 'Has Hours', schedules: everyDay());
      await _open(tester, _Services([without, withHours]));

      expect(find.text('Today: 8:00 AM - 5:00 PM'), findsOneWidget);
      await _tapText(tester, 'No Hours');
      expect(find.byIcon(Icons.schedule_rounded), findsNothing);
      expect(find.textContaining('Today'), findsNothing);
      expect(find.text('Weekly hours'), findsNothing);
      _expectNoVerificationText();
      final gap =
          tester.getTopLeft(find.text('Get Directions')).dy -
          tester.getBottomLeft(find.text('Saved address 1')).dy;
      expect(gap, lessThan(40));

      await tester.tap(find.byTooltip('Back to offices'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Has Hours');
      expect(find.text('Today: 8:00 AM - 5:00 PM'), findsOneWidget);
      expect(find.byIcon(Icons.schedule_rounded), findsOneWidget);
      await _tapText(tester, 'More details');
      expect(find.text('Weekly hours'), findsOneWidget);
      expect(find.text('Mon–Sun'), findsOneWidget);
      await _done(tester);
    });
  });

  group('location states', () {
    testWidgets('valid coordinates give a marker and working directions', (
      tester,
    ) async {
      final opened = <Uri>[];
      await _open(
        tester,
        _Services([office(7, 'Encoded Office')]),
        launch: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      expect(
        _map.markers.map((marker) => marker.markerId.value),
        contains('office-7'),
      );
      await _tapText(tester, 'Encoded Office');
      _expectNoVerificationText();
      await _tapText(tester, 'Get Directions');
      expect(
        opened.single.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=14.85%2C120.81',
      );
      await _done(tester);
    });

    testWidgets('invalid coordinates give no pin and no disabled button', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([office(8, 'Zero Pin', latitude: 0, longitude: 0)]),
      );
      expect(_map.markers, isEmpty);
      await _tapText(tester, 'Zero Pin');
      expect(find.text('Get Directions'), findsNothing);
      expect(find.byType(FilledButton), findsNothing);
      expect(
        find.text('Map location isn’t available for this office yet.'),
        findsOneWidget,
      );
      expect(find.text('Saved address 8'), findsOneWidget);
      _expectNoVerificationText();
      await _done(tester);
    });
  });

  group('compact panel', () {
    testWidgets('leaves most of the screen to the map', (tester) async {
      await _open(tester, _Services([office(1, 'First'), office(2, 'Second')]));
      expect(_panelTop(tester), greaterThan(740 * .6));

      await _tapText(tester, 'First');
      expect(_panelTop(tester), greaterThan(740 * .55));
      expect(find.text('Get Directions').hitTestable(), findsOneWidget);
      await _done(tester);
    });

    testWidgets('a long list still rests low, leaving the map visible', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([for (var i = 1; i <= 15; i++) office(i, 'Office $i')]),
      );
      expect(_panelTop(tester), greaterThan(740 * .6));
      await _done(tester);
    });

    testWidgets('the header is one compact row', (tester) async {
      await _open(tester, _Services([office(1, 'First')]), top: 24);
      expect(tester.getSize(find.byType(TextField)).height, lessThan(52));
      final search = tester.getRect(find.byType(TextField));
      final back = tester.getRect(find.byTooltip('Back'));
      final locate = tester.getRect(find.byTooltip('Use my current location'));
      expect(back.center.dy, closeTo(search.center.dy, 1));
      expect(locate.center.dy, closeTo(search.center.dy, 1));
      expect(search.top, greaterThanOrEqualTo(24));
      expect(find.text('Use my current location'), findsNothing);
      await _done(tester);
    });

    testWidgets('expands to its content and collapses to the title', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([office(1, 'First', schedules: everyDay())]),
      );
      await _tapText(tester, 'First');
      final mid = _panelTop(tester);

      await _tapText(tester, 'More details');
      final full = _panelTop(tester);
      expect(full, lessThan(mid));
      expect(find.text('Philippine Passport').hitTestable(), findsOneWidget);
      expect(find.text('Less details'), findsOneWidget);
      // Nothing but padding lies below the last row.
      expect(
        740 - tester.getBottomLeft(find.text('Postal ID')).dy,
        lessThan(40),
      );

      await _tapText(tester, 'Less details');
      expect(_panelTop(tester), closeTo(mid, 2));

      await tester.tap(find.byKey(const ValueKey('office-sheet-handle')));
      await tester.pumpAndSettle();
      final peek = _panelTop(tester);
      expect(peek, greaterThan(740 * .8));
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Get Directions').hitTestable(), findsNothing);

      await tester.tap(find.byTooltip('Expand panel'));
      await tester.pumpAndSettle();
      expect(_panelTop(tester), closeTo(mid, 2));
      await _done(tester);
    });

    testWidgets('dragging moves between resting points', (tester) async {
      await _open(
        tester,
        _Services([office(1, 'First', schedules: everyDay())]),
      );
      await _tapText(tester, 'First');
      final mid = _panelTop(tester);

      await tester.drag(
        find.byKey(const ValueKey('office-sheet-handle')),
        const Offset(0, 400),
      );
      await tester.pumpAndSettle();
      expect(_panelTop(tester), greaterThan(mid + 60));
      expect(find.byTooltip('Expand panel'), findsOneWidget);

      await tester.drag(
        find.byKey(const ValueKey('office-sheet-handle')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(_panelTop(tester), lessThan(mid));
      expect(find.text('Less details'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('the map stays reachable above the collapsed panel', (
      tester,
    ) async {
      await _open(tester, _Services([office(1, 'First')]));
      await _tapText(tester, 'First');
      await tester.tap(find.byKey(const ValueKey('office-sheet-handle')));
      await tester.pumpAndSettle();
      expect(
        find
            .byKey(const ValueKey('map-area'))
            .hitTestable(at: Alignment.center),
        findsOneWidget,
      );
      await _done(tester);
    });

    testWidgets('closing details returns to the office list', (tester) async {
      await _open(tester, _Services([office(1, 'First'), office(2, 'Second')]));
      await _tapText(tester, 'First');
      expect(find.text('Second'), findsNothing);
      await tester.tap(find.byTooltip('Back to offices'));
      await tester.pumpAndSettle();
      expect(find.text('2 offices'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('system back closes details before leaving', (tester) async {
      await _open(tester, _Services([office(1, 'First'), office(2, 'Second')]));
      await _tapText(tester, 'First');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('2 offices'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('opening an office after scrolling starts at its top', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([for (var i = 1; i <= 12; i++) office(i, 'Office $i')]),
      );
      _sheet(tester).jumpTo(1);
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('Office 12'),
        find.byType(SingleChildScrollView),
        const Offset(0, -300),
      );
      await tester.pumpAndSettle();
      await _tapText(tester, 'Office 12');
      expect(find.text('Office 12').hitTestable(), findsOneWidget);
      expect(find.text('Get Directions').hitTestable(), findsOneWidget);
      await _done(tester);
    });

    testWidgets('keeps its full width when the zoom buttons have no room', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([for (var i = 1; i <= 20; i++) office(i, 'Office $i')]),
        top: 24,
      );
      _sheet(tester).jumpTo(1);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Zoom in'), findsNothing);
      expect(tester.getSize(find.byType(SingleChildScrollView)).width, 360);
      expect(tester.getSize(find.byKey(const ValueKey('map-area'))).width, 360);
      await _done(tester);
    });

    testWidgets('never climbs over the search bar', (tester) async {
      await _open(
        tester,
        _Services([for (var i = 1; i <= 20; i++) office(i, 'Office $i')]),
        top: 24,
      );
      _sheet(tester).jumpTo(1);
      await tester.pumpAndSettle();
      expect(
        _panelTop(tester),
        greaterThanOrEqualTo(tester.getBottomLeft(find.byType(TextField)).dy),
      );
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      await _done(tester);
    });
  });

  group('small screens, safe areas and the keyboard', () {
    for (final size in const [
      Size(280, 653),
      Size(320, 568),
      Size(360, 640),
      Size(844, 390),
    ]) {
      testWidgets('details fit $size', (tester) async {
        await _open(
          tester,
          _Services([
            office(
              1,
              'Bureau of Internal Revenue Revenue District Office',
              schedules: everyDay(),
            ),
          ]),
          size: size,
          top: 24,
          bottom: 24,
        );
        await _tapText(
          tester,
          'Bureau of Internal Revenue Revenue District Office',
        );
        expect(tester.takeException(), isNull);
        expect(find.text('Get Directions'), findsOneWidget);
        await _tapText(tester, 'More details');
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('office-sheet-handle')));
        await tester.pumpAndSettle();
        await _done(tester);
      });
    }

    testWidgets('actions stay above the system navigation bar', (tester) async {
      await _open(tester, _Services([office(1, 'First')]), bottom: 48);
      await _tapText(tester, 'First');
      expect(
        tester.getBottomLeft(find.text('Get Directions')).dy,
        lessThan(740 - 48),
      );
      await _done(tester);
    });

    testWidgets('results sit above the keyboard with the search visible', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([office(1, 'First'), office(2, 'Second')]),
        keyboard: 300,
      );
      await tester.enterText(find.byType(TextField), 'first');
      await tester.pumpAndSettle();
      expect(find.text('1 office'), findsOneWidget);
      expect(find.text('First').hitTestable(), findsOneWidget);
      expect(tester.getBottomLeft(find.text('First')).dy, lessThan(740 - 300));
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      await _done(tester);
    });

    testWidgets('a short window with the keyboard open does not break', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([for (var i = 1; i <= 6; i++) office(i, 'Office $i')]),
        size: const Size(320, 568),
        top: 24,
        keyboard: 320,
      );
      await tester.enterText(find.byType(TextField), 'office');
      await tester.pumpAndSettle();
      expect(find.byType(TextField).hitTestable(), findsOneWidget);
      await _done(tester);
    });
  });

  group('states', () {
    testWidgets('shows loading, then results', (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: OfficeFinderScreen(
            services: _Services([office(1, 'First')]),
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      expect(find.text('Loading offices…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('a failed load can be retried', (tester) async {
      final services = _Services([office(1, 'First')])..failing = true;
      await _open(tester, services);
      expect(
        find.text('Offices are unavailable. Please try again.').hitTestable(),
        findsOneWidget,
      );
      services.failing = false;
      await _tapText(tester, 'Try again');
      expect(find.text('First').hitTestable(), findsOneWidget);
      await _done(tester);
    });

    testWidgets('shows an empty state for a search with no match', (
      tester,
    ) async {
      await _open(tester, _Services([office(1, 'First')]));
      await tester.enterText(find.byType(TextField), 'zzz');
      await tester.pumpAndSettle();
      expect(find.text('No matching offices').hitTestable(), findsOneWidget);
      await _done(tester);
    });

    for (final dark in [false, true]) {
      testWidgets('renders in ${dark ? 'dark' : 'light'} mode', (tester) async {
        await _open(
          tester,
          _Services([office(1, 'First', schedules: everyDay())]),
          dark: dark,
        );
        await _tapText(tester, 'First');
        await _tapText(tester, 'More details');
        await _done(tester);
      });
    }
  });

  testWidgets('related IDs and documents are listed in expanded details', (
    tester,
  ) async {
    await _open(
      tester,
      _Services([
        office(1, 'First', records: ['TIN ID', 'Philippine Passport']),
      ]),
    );
    expect(find.text('TIN ID and 1 more'), findsOneWidget);
    await _tapText(tester, 'First');
    await _tapText(tester, 'More details');
    expect(find.text('IDs and documents'), findsOneWidget);
    expect(find.text('TIN ID').hitTestable(), findsOneWidget);
    expect(find.text('Philippine Passport').hitTestable(), findsOneWidget);
    await _done(tester);
  });

  testWidgets('no More details link appears when there is nothing more', (
    tester,
  ) async {
    await _open(tester, _Services([office(1, 'First', records: const [])]));
    await _tapText(tester, 'First');
    expect(find.text('More details'), findsNothing);
    await _done(tester);
  });
}
