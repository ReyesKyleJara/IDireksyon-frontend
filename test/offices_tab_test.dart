import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/offices_tab.dart';

Map<String, dynamic> office(
  int id,
  String name, {
  dynamic latitude = 14.85,
  dynamic longitude = 120.81,
  String address = 'Saved address',
  String city = 'Malolos',
}) => {
  'id': id,
  'name': name,
  'address': address,
  'municipality': city,
  'latitude': latitude,
  'longitude': longitude,
};

void main() {
  late google.GoogleMap map;
  var mapBuilds = 0;

  Widget testMap(google.GoogleMap value) {
    map = value;
    mapBuilds++;
    return const ColoredBox(color: Color(0xFFEAF3FC));
  }

  Future<void> show(
    WidgetTester tester,
    List<Map<String, dynamic>> offices, {
    String type = 'government_id',
    Future<bool> Function(Uri)? launch,
    double scale = 1,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: OfficesTab(
              offices: offices,
              recordType: type,
              mapBuilder: testMap,
              launchDirections: launch,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'keeps distinct Passport offices with identical coordinates and focuses the tapped card',
    (tester) async {
      await show(tester, [
        office(3, 'DFA Consular Office Malolos'),
        office(4, 'DFA Consular Office Marilao', city: 'Marilao'),
      ]);
      expect(map.markers, hasLength(2));
      expect(map.markers.map((m) => m.infoWindow.title).toSet(), {
        'DFA Consular Office Malolos',
        'DFA Consular Office Marilao',
      });
      expect(find.text('DFA Consular Office Malolos'), findsOneWidget);
      await tester.ensureVisible(find.text('DFA Consular Office Marilao'));
      await tester.tap(find.text('DFA Consular Office Marilao'));
      await tester.pumpAndSettle();
      final selected = map.markers.firstWhere(
        (m) => m.infoWindow.title!.contains('Marilao'),
      );
      expect(
        selected.icon.toJson(),
        google.BitmapDescriptor.defaultMarkerWithHue(
          google.BitmapDescriptor.hueYellow,
        ).toJson(),
      );
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('km'), findsNothing);
      expect(find.textContaining('minutes away'), findsNothing);
    },
  );

  testWidgets(
    'search appears at four offices and hidden search never filters small lists',
    (tester) async {
      final offices = [
        for (var i = 1; i <= 4; i++)
          office(i, 'Office $i', latitude: null, longitude: null),
      ];
      for (final count in [1, 2, 3, 4]) {
        await show(tester, offices.take(count).toList());
        expect(
          find.byType(TextField),
          count >= 4 ? findsOneWidget : findsNothing,
        );
        for (var i = 1; i <= count; i++) {
          expect(find.text('Office $i'), findsOneWidget);
        }
      }
      await tester.enterText(find.byType(TextField), 'unmatched');
      await tester.pumpAndSettle();
      expect(find.text('No offices match your search.'), findsOneWidget);
      await show(tester, offices.take(3).toList());
      expect(find.byType(TextField), findsNothing);
      expect(find.text('No offices match your search.'), findsNothing);
      for (var i = 1; i <= 3; i++) {
        expect(find.text('Office $i'), findsOneWidget);
      }
    },
  );

  testWidgets(
    'searches name city and address locally while keeping all linked map markers',
    (tester) async {
      await show(tester, [
        office(3, 'DFA Consular Office Malolos', address: 'Transport Terminal'),
        office(
          4,
          'DFA Consular Office Marilao',
          city: 'Marilao',
          address: 'SM City',
        ),
        office(
          5,
          'NBI Clearance Center',
          city: 'Santa Maria',
          address: 'Municipal Hall',
        ),
        office(6, 'Another linked office'),
      ]);
      for (final query in [
        'marilao',
        'SM City',
        'DFA Consular Office Marilao',
      ]) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pumpAndSettle();
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text && widget.data == 'DFA Consular Office Marilao',
          ),
          findsOneWidget,
        );
        expect(find.text('DFA Consular Office Malolos'), findsNothing);
        expect(map.markers, hasLength(4));
      }
      await tester.enterText(find.byType(TextField), 'unmatched');
      await tester.pumpAndSettle();
      expect(find.text('No offices match your search.'), findsOneWidget);
      expect(
        find.text('No offices have been added for this ID yet.'),
        findsNothing,
      );
      await tester.tap(find.byTooltip('Clear office search'));
      await tester.pumpAndSettle();
      expect(find.text('DFA Consular Office Malolos'), findsOneWidget);
    },
  );

  testWidgets(
    'only valid finite coordinate pairs receive markers and directions',
    (tester) async {
      await show(tester, [
        office(1, 'Valid branch', latitude: '14.85', longitude: '120.81'),
        office(2, 'No coordinates', latitude: null, longitude: null),
        office(3, 'Out of range', latitude: 91),
        office(4, 'Nonfinite', latitude: double.nan),
        office(5, 'Partial', longitude: null),
        office(6, 'Invalid longitude', longitude: -181),
      ]);
      expect(map.markers, hasLength(1));
      expect(map.markers.single.position, const google.LatLng(14.85, 120.81));
      await tester.ensureVisible(find.text('Get Directions'));
      expect(find.text('Get Directions'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Invalid longitude'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Invalid longitude'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'actual saved Passport shape shows Malolos and Marilao without a map',
    (tester) async {
      mapBuilds = 0;
      await show(tester, [
        office(
          3,
          'DFA Consular Office Malolos',
          latitude: null,
          longitude: null,
          address: '',
        ),
        office(
          4,
          'DFA Consular Office Marilao',
          latitude: null,
          longitude: null,
          address: 'SM City Marilao',
          city: 'Marilao',
        ),
      ]);
      expect(mapBuilds, 0);
      expect(find.text('DFA Consular Office Malolos'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text && widget.data == 'DFA Consular Office Marilao',
        ),
        findsOneWidget,
      );
      expect(find.text('Malolos'), findsOneWidget);
      expect(find.text('SM City Marilao'), findsOneWidget);
      expect(find.text('Get Directions'), findsNothing);
    },
  );

  testWidgets(
    'directions uses the existing Google Maps coordinate destination and handles failure',
    (tester) async {
      Uri? destination;
      await show(
        tester,
        [office(3, 'Malolos')],
        launch: (uri) async {
          destination = uri;
          return false;
        },
      );
      await tester.ensureVisible(find.text('Get Directions'));
      await tester.tap(find.text('Get Directions'));
      await tester.pumpAndSettle();
      expect(destination!.host, 'www.google.com');
      expect(destination!.path, '/maps/dir/');
      expect(destination!.queryParameters, {
        'api': '1',
        'destination': '14.85,120.81',
      });
      expect(
        find.text('Could not open Google Maps. Please try again.'),
        findsOneWidget,
      );
    },
  );

  for (final type in ['government_id', 'document']) {
    testWidgets('$type empty state only when there are zero linked offices', (
      tester,
    ) async {
      await show(tester, [], type: type);
      expect(
        find.text(
          type == 'document'
              ? 'No offices have been added for this document yet.'
              : 'No offices have been added for this ID yet.',
        ),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsNothing);
    });
  }

  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets(
      'map and cards scroll without overflow at $size and large text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(tester, [
          {
            ...office(
              1,
              'Department of Foreign Affairs Consular Office — Malolos',
            ),
            'schedules': [
              {
                'day_of_week': 1,
                'status': 'open',
                'intervals': [
                  {'opens_at': '08:00', 'closes_at': '17:00'},
                ],
              },
            ],
          },
          office(2, 'Marilao'),
        ], scale: 2);
        await tester.scrollUntilVisible(
          find.text('Marilao'),
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Marilao'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
