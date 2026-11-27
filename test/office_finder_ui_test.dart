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
  double textScale = 1,
  DateTime? now,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = FakeViewPadding(top: top, bottom: bottom);
  tester.view.viewInsets = FakeViewPadding(bottom: keyboard);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: OfficeFinderScreen(
        now: now == null ? null : () => now,
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

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text, skipOffstage: false).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text(text).first);
  await tester.pumpAndSettle();
}

/// Scrolls the open page until [target] is built and on screen.
Future<void> _scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

/// Philippine wall-clock time on Wednesday 2026-11-25 (PHT = UTC+8).
DateTime _manila(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 25, hour - 8, minute);

/// Open on weekdays only.
List<Map<String, dynamic>> _weekdays() => [
  day(0, 'closed'),
  for (var i = 1; i <= 5; i++)
    day(i, 'open', [
      ['08:00:00', '17:00:00'],
    ]),
  day(6, 'closed'),
];

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

    testWidgets('an office without hours shows no hours card and no gaps', (
      tester,
    ) async {
      final without = office(1, 'No Hours');
      final withHours = office(2, 'Has Hours', schedules: everyDay());
      await _open(tester, _Services([without, withHours]));

      await _tapText(tester, 'No Hours');
      expect(find.text('Not yet added'), findsNWidgets(2));
      expect(find.text('Office Hours'), findsOneWidget, reason: 'fact tile');
      expect(find.text('Open Now'), findsNothing);
      expect(find.text('Closed'), findsNothing);
      _expectNoVerificationText();

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      await _tapText(tester, 'Has Hours');
      // The week shows once, at the top; there is no second hours card.
      expect(find.text('Mon–Sun'), findsOneWidget);
      expect(find.text('Office Hours'), findsOneWidget);
      await _done(tester);
    });
  });

  group('open now', () {
    test('reads open, closed and unknown in Philippine time', () {
      final weekdays = office(1, 'Weekdays', schedules: _weekdays());
      final open = weekdays.openStateAt(_manila(9, 41))!;
      expect(open.open, isTrue);
      expect(open.minutesLeft, 7 * 60 + 19);
      expect(weekdays.openStateAt(_manila(7, 59))!.open, isFalse);
      expect(weekdays.openStateAt(_manila(17))!.open, isFalse);
      // Saturday 2026-11-28 is listed as closed.
      expect(
        weekdays.openStateAt(DateTime.utc(2026, 11, 28, 2))!.open,
        isFalse,
      );
      expect(office(2, 'Unknown').openStateAt(_manila(10)), isNull);
      expect(
        office(
          3,
          'Open, no times',
          schedules: [day(3, 'open')],
        ).openStateAt(_manila(10)),
        isNull,
      );
    });

    testWidgets('cards show Open Now or Closed only when hours are known', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([
          office(1, 'Weekday Office', schedules: _weekdays()),
          office(2, 'Unknown Hours'),
        ]),
        now: _manila(9, 41),
      );
      expect(find.text('Open Now'), findsNWidgets(2), reason: 'card and chip');
      expect(find.text('Closed'), findsNothing);
      await _tapText(tester, 'Weekday Office');
      expect(find.text('Open Now'), findsOneWidget);
      expect(find.text('Available Today'), findsOneWidget);
      expect(find.text('8:00 AM - 5:00 PM'), findsWidgets);
      expect(find.text('(ends in 7h 19m)'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('after hours the card says Closed', (tester) async {
      await _open(
        tester,
        _Services([office(1, 'Weekday Office', schedules: _weekdays())]),
        now: _manila(18),
      );
      expect(find.text('Closed'), findsOneWidget);
      expect(find.text('Open Now'), findsOneWidget, reason: 'the chip only');
      await _done(tester);
    });

    testWidgets('the Open Now filter keeps only open offices', (tester) async {
      await _open(
        tester,
        _Services([
          office(1, 'Weekday Office', schedules: _weekdays()),
          office(2, 'Unknown Hours'),
        ]),
        now: _manila(10),
      );
      await tester.tap(find.byKey(const ValueKey('office-filter-openNow')));
      await tester.pumpAndSettle();
      expect(find.text('Weekday Office'), findsOneWidget);
      expect(find.text('Unknown Hours'), findsNothing);
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();
      expect(find.text('Unknown Hours'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('Open Now with nothing open explains itself', (tester) async {
      await _open(
        tester,
        _Services([office(1, 'Weekday Office', schedules: _weekdays())]),
        now: _manila(20),
      );
      await tester.tap(find.byKey(const ValueKey('office-filter-openNow')));
      await tester.pumpAndSettle();
      expect(find.text('No offices open right now'), findsOneWidget);
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
      await _tapText(tester, 'View Office');
      expect(
        _map.markers.map((marker) => marker.markerId.value),
        contains('office-7'),
      );
      expect(find.text('Route to Encoded Office'), findsOneWidget);
      _expectNoVerificationText();
      await _tapText(tester, 'Start Route');
      expect(
        opened.single.toString(),
        'https://www.google.com/maps/dir/?api=1&destination=14.85%2C120.81&travelmode=driving',
      );
      await _done(tester);
    });

    testWidgets('invalid coordinates give no map and no disabled button', (
      tester,
    ) async {
      await _open(
        tester,
        _Services([office(8, 'Zero Pin', latitude: 0, longitude: 0)]),
      );
      await _tapText(tester, 'Zero Pin');
      expect(find.text('Start Route'), findsNothing);
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

  group('pages', () {
    testWidgets('View Office opens details and Back returns to the list', (
      tester,
    ) async {
      await _open(tester, _Services([office(1, 'First'), office(2, 'Second')]));
      expect(find.text('Office Finder'), findsOneWidget);
      expect(find.text('View Office'), findsNWidgets(2));
      await tester.tap(find.text('View Office').last);
      await tester.pumpAndSettle();
      expect(find.text('Office Details'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Office Finder'), findsOneWidget);
      await _done(tester);
    });

    testWidgets('a link from another page opens straight to details', (
      tester,
    ) async {
      await _open(tester, _Services([]), initial: office(4, 'Linked Office'));
      expect(find.text('Office Details'), findsOneWidget);
      expect(find.text('Linked Office'), findsOneWidget);
      await _done(tester);
    });
  });

  group('small screens, large text and the keyboard', () {
    for (final size in const [
      Size(280, 653),
      Size(320, 568),
      Size(360, 640),
      Size(844, 390),
      Size(1280, 800),
    ]) {
      testWidgets('both pages fit $size', (tester) async {
        await _open(
          tester,
          _Services([
            office(1, 'First Office With A Long Name', schedules: everyDay()),
            office(2, 'Second'),
          ]),
          size: size,
          top: 24,
          bottom: 24,
        );
        expect(tester.takeException(), isNull);
        await _tapText(tester, 'First Office With A Long Name');
        expect(tester.takeException(), isNull);
        await _scrollTo(tester, find.text('Start Route'));
        expect(find.text('Start Route').hitTestable(), findsOneWidget);
        await _done(tester);
      });
    }

    testWidgets('large text wraps on both pages', (tester) async {
      await _open(
        tester,
        _Services([office(1, 'First', schedules: everyDay())]),
        size: const Size(320, 640),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await _tapText(tester, 'First');
      await _scrollTo(tester, find.text('Start Route'));
      await _done(tester);
    });

    testWidgets('typing with the keyboard open does not break', (tester) async {
      await _open(
        tester,
        _Services([office(1, 'First'), office(2, 'Second')]),
        size: const Size(360, 400),
        keyboard: 260,
      );
      // Only the title fits above the keyboard; the field scrolls into view.
      await tester.ensureVisible(find.byType(TextField, skipOffstage: false));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'sec');
      await tester.pumpAndSettle();
      expect(find.text('First', skipOffstage: false), findsNothing);
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
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('First'), findsOneWidget);
      expect(find.text('1 office'), findsOneWidget);
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
        await _scrollTo(tester, find.text('IDs and documents'));
        await _done(tester);
      });
    }
  });

  testWidgets('related IDs and documents are listed on the details page', (
    tester,
  ) async {
    await _open(
      tester,
      _Services([
        office(1, 'First', records: ['TIN ID', 'Philippine Passport']),
      ]),
    );
    await _tapText(tester, 'First');
    expect(find.text('2 handled here'), findsOneWidget);
    await _scrollTo(tester, find.text('Philippine Passport'));
    expect(find.text('IDs and documents'), findsOneWidget);
    expect(find.text('TIN ID').hitTestable(), findsOneWidget);
    await _done(tester);
  });

  testWidgets('no documents card appears when there are none', (tester) async {
    await _open(tester, _Services([office(1, 'First', records: const [])]));
    await _tapText(tester, 'First');
    expect(find.text('IDs and documents'), findsNothing);
    await _done(tester);
  });
}
