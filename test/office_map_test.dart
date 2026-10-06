import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:latlong2/latlong.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/office_finder/map_services.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';
import 'package:idireksyon_frontend/features/office_finder/models/office_catalog.dart';

void main() {
  testWidgets('directions stay in the map and location denial is recoverable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final services = _TestServices();
    addTearDown(services.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: OfficeFinderScreen(
          initialOffice: officeCatalog.first,
          services: services,
          tileProvider: _TestTiles(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.drag(find.byType(ListView).last, const Offset(0, -280));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.ensureVisible(find.text('Get directions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get directions'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('8 min • 2.4 km'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsOneWidget);
    services.denied = true;
    await tester.pumpAndSettle();
    tester
        .widget<DraggableScrollableSheet>(find.byType(DraggableScrollableSheet))
        .controller!
        .jumpTo(.78);
    await tester.pumpAndSettle();
    tester.widget<ListView>(find.byType(ListView).last).controller!.jumpTo(0);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Refresh route'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Refresh route'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Allow location access to continue.'), findsOneWidget);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('map layout fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(home: OfficeFinderScreen(tileProvider: _TestTiles())),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  test(
    'requests a road route and decodes longitude/latitude and route steps',
    () async {
      final service = OfficeMapServices(
        client: MockClient((request) async {
          expect(request.url.path, contains('120.8,14.8;120.9,14.9'));
          expect(request.url.queryParameters['steps'], 'true');
          return http.Response(
            jsonEncode({
              'code': 'Ok',
              'routes': [
                {
                  'distance': 2400,
                  'duration': 480,
                  'geometry': {
                    'coordinates': [
                      [120.8, 14.8],
                      [120.85, 14.82],
                      [120.9, 14.9],
                    ],
                  },
                  'legs': [
                    {
                      'steps': [
                        {
                          'name': 'Main Street',
                          'maneuver': {'type': 'turn', 'modifier': 'right'},
                        },
                        {
                          'name': '',
                          'maneuver': {'type': 'arrive'},
                        },
                      ],
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }),
      );
      final route = await service.route(
        const LatLng(14.8, 120.8),
        const LatLng(14.9, 120.9),
      );
      expect(route.points[1], const LatLng(14.82, 120.85));
      expect(route.meters, 2400);
      expect(route.seconds, 480);
      expect(route.steps, [
        'Turn right onto Main Street',
        'Arrive at your destination',
      ]);
      service.dispose();
    },
  );

  test('no route produces a recoverable error', () async {
    final service = OfficeMapServices(
      client: MockClient((_) async => http.Response('{"code":"NoRoute"}', 200)),
    );
    await expectLater(
      service.route(const LatLng(14, 120), const LatLng(15, 121)),
      throwsStateError,
    );
    service.dispose();
  });

  test('place searches are cached', () async {
    var calls = 0;
    final service = OfficeMapServices(
      client: MockClient((_) async {
        calls++;
        return http.Response(
          '[{"display_name":"Malolos","lat":"14.85","lon":"120.81"}]',
          200,
        );
      }),
    );
    await service.search('Malolos');
    final results = await service.search('malolos');
    expect(calls, 1);
    expect(results.single.point, const LatLng(14.85, 120.81));
    service.dispose();
  });

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
            home: OfficeFinderScreen(tileProvider: _TestTiles()),
          ),
        );
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Office Finder'), findsOneWidget);
        await tester.tap(find.text('Passport'));
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('1 office'), findsOneWidget);
        await tester.tap(find.text('DFA Consular Office Malolos').first);
        await tester.pump(const Duration(milliseconds: 300));
        expect(find.text('Get directions'), findsOneWidget);
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

class _TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

class _TestServices extends OfficeMapServices {
  bool denied = false;
  @override
  Future<LatLng> locate() async {
    if (denied) throw StateError('Allow location access to continue.');
    return const LatLng(14.84, 120.81);
  }

  @override
  Future<OfficeRoute> route(LatLng origin, LatLng destination) async =>
      OfficeRoute(
        [origin, const LatLng(14.845, 120.815), destination],
        2400,
        480,
        ['Head straight onto Main Street', 'Arrive at your destination'],
      );
}
