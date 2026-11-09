import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/office_finder/map_services.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';

import 'fixtures/offices.dart';

const _openFailed =
    'Could not open Google Maps. Install Google Maps or a web browser, then try again.';

void main() {
  var roadEstimates = false;

  Future<void> open(
    WidgetTester tester,
    OfficeMapServices services, {
    bool selected = true,
    Future<bool> Function(Uri)? launch,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        home: OfficeFinderScreen(
          initialOffice: selected ? dfaMalolos : null,
          services: services,
          mapBuilder: _testMap,
          launchDirections: launch,
          showRoadEstimates: roadEstimates,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
  }

  Future<void> showDirections(WidgetTester tester) async {
    await tester.pumpAndSettle();
    if (roadEstimates) {
      await tester.tap(find.text('More details'));
      await tester.pumpAndSettle();
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('Get Directions hands the office to Google Maps', (tester) async {
    final services = _TestServices();
    final opened = <Uri>[];
    await open(
      tester,
      services,
      launch: (uri) async {
        opened.add(uri);
        return true;
      },
    );
    expect(find.text('Drive'), findsNothing);
    expect(find.text('Walk'), findsNothing);
    expect(find.text('Public transport'), findsNothing);
    await showDirections(tester);
    expect(
      find.text('Opens Google Maps. Pin may be approximate.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Get Directions'));
    await tester.pumpAndSettle();

    expect(opened.single.toString(), _mapsUrl);
    expect(services.locates, 0);
    expect(_lastMap.polylines, isEmpty);
    expect(find.text(_openFailed), findsNothing);

    await tester.ensureVisible(find.byTooltip('Minimize panel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Minimize panel'));
    await tester.pumpAndSettle();
    expect(find.text(dfaMalolos.address), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  final failures = <String, Future<bool> Function(Uri)>{
    'nothing can open the link': (_) async => false,
    'opening the link throws': (_) async => throw StateError('no handler'),
  };
  for (final failure in failures.entries) {
    testWidgets('shows a clear message when ${failure.key}', (tester) async {
      await open(tester, _TestServices(), launch: failure.value);
      await showDirections(tester);
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      expect(find.text(_openFailed), findsOneWidget);
      expect(tester.takeException(), isNull);
      await close(tester);
    });
  }

  testWidgets('a double-tap opens Google Maps once', (tester) async {
    final launching = Completer<bool>();
    var launches = 0;
    await open(
      tester,
      _TestServices(),
      launch: (_) {
        launches++;
        return launching.future;
      },
    );
    await showDirections(tester);
    await tester.tap(find.text('Get Directions'));
    await tester.pump();
    await tester.tap(find.text('Get Directions'), warnIfMissed: false);
    await tester.pump();
    expect(launches, 1);

    launching.complete(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Directions'));
    await tester.pump();
    expect(launches, 2);
    await close(tester);
  });

  testWidgets('road estimates stay hidden by default for closed testing', (
    tester,
  ) async {
    final services = _TestServices();
    await open(tester, services);
    await showDirections(tester);
    expect(find.text('Get Directions'), findsOneWidget);
    expect(find.text('Show road distance and time'), findsNothing);
    expect(find.textContaining('Your current location is sent'), findsNothing);
    expect(services.estimates, 0);
    await close(tester);
  });

  group('road distance', () {
    const button = 'Show road distance and time';

    setUp(() => roadEstimates = true);
    tearDown(() => roadEstimates = false);

    testWidgets('never runs until the resident taps the button', (
      tester,
    ) async {
      final services = _TestServices();
      await open(tester, services);
      await tester.pumpAndSettle();
      expect(services.locates, 0);
      expect(services.estimates, 0);
      await showDirections(tester);
      expect(
        find.textContaining('Your current location is sent'),
        findsOneWidget,
      );
      expect(find.text(button), findsOneWidget);
      expect(services.locates, 0);
      expect(services.estimates, 0);
      await close(tester);
    });

    testWidgets('shows road distance and driving time after the tap', (
      tester,
    ) async {
      final services = _TestServices();
      await open(tester, services);
      await showDirections(tester);
      await tester.ensureVisible(find.text(button));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pumpAndSettle();
      expect(find.text('2.4 km by road • About 8 min drive'), findsOneWidget);
      expect(
        find.text('Estimated without live traffic. Actual time may differ.'),
        findsOneWidget,
      );
      expect(find.text(button), findsNothing);
      expect(services.locates, 1);
      expect(services.estimates, 1);
      expect(services.officeIds.single, dfaMalolos.id);
      expect(_lastMap.polylines, isEmpty);
      await close(tester);
    });

    final failures = <String, void Function(_TestServices)>{
      'location is denied': (services) => services.denied = true,
      'the estimate fails': (services) => services.estimateFails = true,
    };
    for (final failure in failures.entries) {
      testWidgets('Get Directions still works when ${failure.key}', (
        tester,
      ) async {
        final services = _TestServices();
        failure.value(services);
        final opened = <Uri>[];
        await open(
          tester,
          services,
          launch: (uri) async {
            opened.add(uri);
            return true;
          },
        );
        await showDirections(tester);
        await tester.ensureVisible(find.text(button));
        await tester.pumpAndSettle();
        await tester.tap(find.text(button));
        await tester.pumpAndSettle();
        expect(
          find.text(
            services.denied
                ? 'Allow location access to continue.'
                : 'Road distance is unavailable right now.',
          ),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        if (services.denied) expect(services.estimates, 0);

        await tester.ensureVisible(find.text('Get Directions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Get Directions'));
        await tester.pumpAndSettle();
        expect(opened.single.toString(), _mapsUrl);
        await close(tester);
      });
    }

    testWidgets('a late reply is ignored after leaving the office', (
      tester,
    ) async {
      final services = _TestServices()..reply = Completer<RoadEstimate>();
      await open(tester, services);
      await showDirections(tester);
      await tester.ensureVisible(find.text(button));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pump();
      expect(find.text('Calculating road distance…'), findsOneWidget);

      // The spinner keeps animating, so settling must wait for the tap below.
      await tester.tap(find.byTooltip('Back to offices'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(postOffice.name).first);
      await tester.pumpAndSettle();
      services.reply!.complete(const RoadEstimate(2400, 480));
      await tester.pumpAndSettle();
      expect(find.textContaining('by road'), findsNothing);
      await close(tester);
    });

    test('sends the token and location, and reuses a nearby answer', () async {
      final requests = <http.Request>[];
      final service = OfficeMapServices(
        baseUrl: 'http://localhost:8000/api',
        token: () => 'resident-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"data":{"distance_meters":8400,"duration_seconds":1200}}',
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final first = await service.roadEstimate(
        '7',
        const LatLng(14.75741, 120.94831),
      );
      await service.roadEstimate('7', const LatLng(14.75742, 120.94832));

      expect(first.meters, 8400);
      expect(first.seconds, 1200);
      expect(requests, hasLength(1));
      expect(
        requests.single.url.toString(),
        'http://localhost:8000/api/auth/offices/7/route',
      );
      expect(requests.single.headers['Authorization'], 'Bearer resident-token');
      expect(requests.single.headers.containsKey('X-Goog-Api-Key'), isFalse);
      expect(jsonDecode(requests.single.body), {
        'latitude': 14.75741,
        'longitude': 120.94831,
      });
    });

    final problems = <String, (int, String, String)>{
      'an expired login': (401, '{}', 'Log in again to see road distance.'),
      'too many requests': (
        429,
        '{}',
        'Too many requests. Please wait a moment, then try again.',
      ),
      'no route': (
        422,
        '{"code":"no_route"}',
        'No driving route was found to this office.',
      ),
      'an office with no location': (
        422,
        '{"code":"office_no_location"}',
        'Road distance is not available for this office yet.',
      ),
      'a location outside the Philippines': (
        422,
        '{"message":"bad"}',
        'Road distance is only available within the Philippines.',
      ),
      'a server problem': (
        503,
        'oops',
        'Road distance is unavailable right now.',
      ),
    };
    for (final problem in problems.entries) {
      test('explains ${problem.key}', () async {
        final (status, body, message) = problem.value;
        final service = OfficeMapServices(
          baseUrl: 'http://localhost:8000/api',
          token: () => 'resident-token',
          client: MockClient((_) async => http.Response(body, status)),
        );
        addTearDown(service.dispose);
        await expectLater(
          service.roadEstimate('7', const LatLng(14.7, 120.9)),
          throwsA(
            isA<StateError>().having((e) => e.message, 'message', message),
          ),
        );
      });
    }
  });

  testWidgets('current location marks the map and a denial is recoverable', (
    tester,
  ) async {
    final services = _TestServices();
    await open(tester, services, selected: false);
    await tester.tap(find.byTooltip('Use my current location'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Using your current location'), findsOneWidget);
    expect(
      _lastMap.markers.map((marker) => marker.markerId.value),
      contains('current-position'),
    );

    services.denied = true;
    await tester.tap(find.byTooltip('Using your current location'));
    await tester.pumpAndSettle();
    expect(find.text('Allow location access to continue.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  testWidgets('search uses the loaded offices and no map endpoints', (
    tester,
  ) async {
    final paths = <String>[];
    final services = _RecordingServices(paths);
    addTearDown(services.dispose);
    await open(tester, services, selected: false);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'sss');
    await tester.pumpAndSettle();
    expect(find.text('SSS Santa Maria Branch'), findsOneWidget);
    expect(find.text('DFA Consular Office Malolos'), findsNothing);

    await tester.enterText(find.byType(TextField), 'unlisted office');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(find.text('No matching offices'), findsOneWidget);
    expect(find.text('Search places on map'), findsNothing);
    expect(paths, ['/api/offices']);
    expect(tester.takeException(), isNull);
    await close(tester);
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('map layout fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: OfficeFinderScreen(
            services: FixtureOfficeServices(),
            mapBuilder: _testMap,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final dark in [false, true]) {
    testWidgets(
      'embedded office selection and filters (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            home: OfficeFinderScreen(
              services: FixtureOfficeServices(),
              mapBuilder: _testMap,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(TextField), findsOneWidget);
        expect(find.text('All offices'), findsNothing);
        expect(find.text('Passport'), findsNothing);
        expect(find.text('SSS / UMID'), findsNothing);
        expect(find.byType(ChoiceChip), findsNothing);
        expect(find.text('3 offices'), findsOneWidget);
        await tester.tap(find.text('DFA Consular Office Malolos').first);
        await tester.pumpAndSettle();
        expect(find.text('Get Directions'), findsOneWidget);
        expect(find.text('Open in Maps'), findsNothing);
        await tester.tap(find.byTooltip('Back to offices'));
        await tester.enterText(find.byType(TextField), 'unlisted office');
        await tester.pump();
        expect(find.text('No matching offices'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  }
}

const _mapsUrl =
    'https://www.google.com/maps/dir/?api=1&destination=14.8527%2C120.816';

late google.GoogleMap _lastMap;
Widget _testMap(google.GoogleMap map) {
  _lastMap = map;
  return const SizedBox.expand();
}

class _TestServices extends FixtureOfficeServices {
  bool denied = false;
  bool estimateFails = false;
  Completer<RoadEstimate>? reply;
  int locates = 0;
  int estimates = 0;
  final officeIds = <String>[];

  @override
  Future<LatLng> locate() async {
    locates++;
    if (denied) throw StateError('Allow location access to continue.');
    return const LatLng(14.84, 120.81);
  }

  @override
  Future<RoadEstimate> roadEstimate(String officeId, LatLng origin) async {
    estimates++;
    officeIds.add(officeId);
    if (estimateFails) {
      throw StateError('Road distance is unavailable right now.');
    }
    return reply?.future ?? const RoadEstimate(2400, 480);
  }
}

/// Goes through the real request code and records every path it calls.
class _RecordingServices extends OfficeMapServices {
  _RecordingServices(List<String> paths)
    : super(
        baseUrl: 'http://localhost:8000/api',
        client: MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'data': [
                {'id': 1, 'name': dfaMalolos.name, 'address': 'Malolos'},
                {'id': 2, 'name': sssSantaMaria.name, 'address': 'Santa Maria'},
              ],
            }),
            200,
          );
        }),
      );

  @override
  Future<LatLng> locate() async => const LatLng(14.84, 120.81);
}
