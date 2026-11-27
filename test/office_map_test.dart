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
    await showDirections(tester);
    // Residents pick walking or commuting in Google Maps, not here.
    expect(find.text('Walk'), findsNothing);
    expect(find.text('Transit'), findsNothing);
    expect(find.text('Car'), findsNothing);
    expect(
      find.text('Opens Google Maps. Pin may be approximate.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Start Route'));
    await tester.tap(find.text('Start Route'));
    await tester.pumpAndSettle();

    expect(opened.single.toString(), _mapsUrl);
    expect(services.locates, 0);
    expect(_lastMap.polylines, isEmpty);
    expect(find.text(_openFailed), findsNothing);
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
      await tester.ensureVisible(find.text('Start Route'));
      await tester.tap(find.text('Start Route'));
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
    await tester.ensureVisible(find.text('Start Route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Route'));
    await tester.pump();
    await tester.tap(find.text('Start Route'), warnIfMissed: false);
    await tester.pump();
    expect(launches, 1);

    launching.complete(true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Route'));
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
    expect(find.text('Start Route'), findsOneWidget);
    expect(find.text('Show travel time'), findsNothing);
    expect(find.textContaining('Uses your current location'), findsNothing);
    expect(services.estimates, 0);
    await close(tester);
  });

  group('road distance', () {
    const button = 'Show travel time';

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
        find.text('Uses your current location. IDireksyon does not save it.'),
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
      expect(find.text('8 min'), findsWidgets);
      expect(find.text('2.4 km'), findsOneWidget);
      expect(find.text('by car'), findsOneWidget);
      expect(
        find.text('Estimated without live traffic. Actual time may differ.'),
        findsOneWidget,
      );
      expect(find.text(button), findsNothing);
      expect(services.locates, 1);
      expect(services.estimates, 1);
      expect(services.officeIds.single, dfaMalolos.id);
      await close(tester);
    });

    testWidgets('draws the drive as a blue line on the map', (tester) async {
      final services = _TestServices()..knownLocation = _here;
      await open(tester, services);
      await tester.pumpAndSettle();
      expect(find.text('8 min'), findsWidgets);
      final lines = {
        for (final line in _lastMap.polylines) line.polylineId.value: line,
      };
      expect(lines.keys, unorderedEquals(['route', 'route-edge']));
      expect(lines['route']!.points, hasLength(3));
      expect(lines['route']!.points.first.latitude, 14.84);
      expect(lines['route']!.zIndex, greaterThan(lines['route-edge']!.zIndex));
      await close(tester);
    });

    testWidgets('a route without a line still shows time and distance', (
      tester,
    ) async {
      final services = _TestServices()
        ..knownLocation = _here
        ..path = const [];
      await open(tester, services);
      await tester.pumpAndSettle();
      expect(find.text('8 min'), findsWidgets);
      expect(_lastMap.polylines, isEmpty);
      await close(tester);
    });

    testWidgets('appears by itself once the location is already known', (
      tester,
    ) async {
      final opened = <Uri>[];
      final services = _TestServices()..knownLocation = _here;
      await open(
        tester,
        services,
        launch: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await tester.pumpAndSettle();
      expect(find.text('8 min'), findsWidgets);
      expect(services.locates, 0, reason: 'no permission prompt');
      expect(find.text(button), findsNothing);

      await tester.ensureVisible(find.text('Start Route'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Route'));
      await tester.pumpAndSettle();
      expect(opened.single.toString(), _mapsUrlFrom);
      await close(tester);
    });

    testWidgets('no driving route shows a calm note, not a made-up time', (
      tester,
    ) async {
      final services = _TestServices()
        ..knownLocation = _here
        ..noRoute = true;
      await open(tester, services);
      await tester.pumpAndSettle();
      expect(
        find.text(
          'No driving route was found to this office. Google Maps may still suggest a way.',
        ),
        findsOneWidget,
      );
      expect(find.text('Try again'), findsNothing);
      expect(find.textContaining(' min'), findsNothing);
      await close(tester);
    });

    testWidgets('tapping quickly through offices asks only for the last', (
      tester,
    ) async {
      final services = _TestServices()..knownLocation = _here;
      await open(tester, services, selected: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text(postOffice.name).first);
      await tester.pump(const Duration(milliseconds: 100));
      // Leaves before the short pause ends, so no estimate is asked for.
      tester.state<NavigatorState>(find.byType(Navigator)).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(sssSantaMaria.name).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(sssSantaMaria.name).first);
      await tester.pumpAndSettle();
      expect(services.officeIds, [sssSantaMaria.id]);
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
                : 'Travel time is unavailable right now.',
          ),
          findsOneWidget,
        );
        expect(find.text('Try again'), findsOneWidget);
        if (services.denied) expect(services.estimates, 0);

        await tester.ensureVisible(find.text('Start Route'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Route'));
        await tester.pumpAndSettle();
        expect(
          opened.single.toString(),
          services.denied ? _mapsUrl : _mapsUrlFrom,
        );
        await close(tester);
      });
    }

    testWidgets('a late reply is ignored after leaving the office', (
      tester,
    ) async {
      final services = _TestServices()..reply = Completer<RoadEstimate>();
      await open(tester, services, selected: false);
      await tester.pumpAndSettle();
      await tester.tap(find.text(dfaMalolos.name).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text(button));
      await tester.pumpAndSettle();
      await tester.tap(find.text(button));
      await tester.pump();
      expect(find.text('Calculating travel time…'), findsOneWidget);

      // The spinner keeps animating, so settling must wait for the tap below.
      await tester.tap(find.byTooltip('Back'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));
      // The next office gets its own estimate straight away.
      await tester.ensureVisible(find.text(postOffice.name).first);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text(postOffice.name).first);
      await tester.pumpAndSettle();
      expect(find.text('8 min'), findsWidgets);
      services.reply!.complete(const RoadEstimate(9900, 3600));
      await tester.pumpAndSettle();
      expect(find.text('1 hr'), findsNothing);
      expect(find.text('9.9 km'), findsNothing);
      expect(find.text('8 min'), findsWidgets);
      expect(services.officeIds, [dfaMalolos.id, postOffice.id]);
      await close(tester);
    });

    test('reads the server switch with the office list', () async {
      for (final (meta, expected) in [
        ('{"travel_times":true}', true),
        ('{"travel_times":false}', false),
        ('null', false),
      ]) {
        final service = OfficeMapServices(
          baseUrl: 'http://localhost:8000/api',
          client: MockClient(
            (_) async => http.Response('{"data":[],"meta":$meta}', 200),
          ),
        );
        await service.offices();
        expect(service.travelTimes, expected, reason: meta);
        service.dispose();
      }
    });

    test('remembers a missing route instead of asking again', () async {
      var calls = 0;
      final service = OfficeMapServices(
        baseUrl: 'http://localhost:8000/api',
        token: () => 'resident-token',
        client: MockClient((_) async {
          calls++;
          return http.Response('{"code":"no_route"}', 422);
        }),
      );
      addTearDown(service.dispose);
      for (var i = 0; i < 2; i++) {
        await expectLater(
          service.roadEstimate('7', _here),
          throwsA(isA<TravelUnavailable>()),
        );
      }
      expect(calls, 1);
    });

    test('decodes the route line, and ignores a broken one', () {
      // Google's documented example.
      expect(
        decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@')
            .map((p) => (p.latitude, p.longitude))
            .toList(),
        [(38.5, -120.2), (40.7, -120.95), (43.252, -126.453)],
      );
      expect(decodePolyline(null), isEmpty);
      expect(decodePolyline(''), isEmpty);
      expect(decodePolyline('_p~iF'), isEmpty);
      expect(decodePolyline(' '), isEmpty);
    });

    test('sends the token and location, and reuses a nearby answer', () async {
      final requests = <http.Request>[];
      final service = OfficeMapServices(
        baseUrl: 'http://localhost:8000/api',
        token: () => 'resident-token',
        client: MockClient((request) async {
          requests.add(request);
          return http.Response(
            '{"data":{"distance_meters":8400,"duration_seconds":1200,"polyline":"_p~iF~ps|U_ulLnnqC"}}',
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
      expect(first.path, hasLength(2));
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
      'an expired login': (401, '{}', 'Log in again to see travel time.'),
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
        'Travel time is not available for this office yet.',
      ),
      'a location outside the Philippines': (
        422,
        '{"message":"bad"}',
        'Travel time is only available within the Philippines.',
      ),
      'a server problem': (
        503,
        'oops',
        'Travel time is unavailable right now.',
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
            problem.key == 'no route'
                ? isA<TravelUnavailable>().having(
                    (e) => e.message,
                    'message',
                    message,
                  )
                : isA<StateError>().having(
                    (e) => e.message,
                    'message',
                    message,
                  ),
          ),
        );
      });
    }
  });

  testWidgets(
    'Nearby asks for location, marks the map, and a denial is recoverable',
    (tester) async {
      final services = _TestServices();
      await open(tester, services, selected: false);
      await tester.pumpAndSettle();
      services.denied = true;
      await tester.tap(find.text('Nearby'));
      await tester.pumpAndSettle();
      expect(find.text('Allow location access to continue.'), findsOneWidget);
      expect(find.text('3 offices'), findsOneWidget, reason: 'still on All');

      services.denied = false;
      await tester.tap(find.text('Nearby'));
      await tester.pumpAndSettle();
      expect(services.locates, 2);
      expect(find.textContaining('nearest first'), findsOneWidget);
      // SSS Santa Maria is about 16 km away, past the Nearby limit.
      expect(find.text(sssSantaMaria.name), findsNothing);
      expect(find.text(dfaMalolos.name), findsOneWidget);

      await tester.tap(find.text(dfaMalolos.name));
      await tester.pumpAndSettle();
      expect(
        _lastMap.markers.map((marker) => marker.markerId.value),
        contains('current-position'),
      );
      expect(tester.takeException(), isNull);
      await close(tester);
    },
  );

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
        expect(find.text('Start Route'), findsOneWidget);
        expect(find.text('Open in Maps'), findsNothing);
        await tester.tap(find.byTooltip('Back'));
        await tester.pumpAndSettle();
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
    'https://www.google.com/maps/dir/?api=1&destination=14.8527%2C120.816&travelmode=driving';

/// After the location is known, Google Maps gets it as the starting point.
const _here = LatLng(14.84, 120.81);

const _mapsUrlFrom =
    'https://www.google.com/maps/dir/?api=1&origin=14.84%2C120.81&destination=14.8527%2C120.816&travelmode=driving';

late google.GoogleMap _lastMap;
Widget _testMap(google.GoogleMap map) {
  _lastMap = map;
  return const SizedBox.expand();
}

class _TestServices extends FixtureOfficeServices {
  bool denied = false;
  bool estimateFails = false;
  bool noRoute = false;
  Completer<RoadEstimate>? reply;
  int locates = 0;
  int estimates = 0;
  final officeIds = <String>[];

  /// The drive's line; from the resident's spot to the DFA office.
  List<LatLng> path = const [
    _here,
    LatLng(14.846, 120.813),
    LatLng(14.8527, 120.816),
  ];

  @override
  Future<LatLng> locate() async {
    locates++;
    if (denied) throw StateError('Allow location access to continue.');
    return _here;
  }

  @override
  Future<RoadEstimate> roadEstimate(String officeId, LatLng origin) async {
    estimates++;
    officeIds.add(officeId);
    if (estimateFails) {
      throw StateError('Travel time is unavailable right now.');
    }
    if (noRoute) {
      throw const TravelUnavailable(
        'No driving route was found to this office.',
      );
    }
    // Only the first office waits, so a late reply can be told apart.
    final waiting = reply;
    if (waiting != null && officeId == dfaMalolos.id) return waiting.future;
    return RoadEstimate(2400, 480, path);
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
