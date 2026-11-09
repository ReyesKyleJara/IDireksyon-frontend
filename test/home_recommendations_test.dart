import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/home/diro_poses.dart';
import 'package:idireksyon_frontend/features/home/home_recommendations.dart';
import 'package:idireksyon_frontend/features/home/journey_banner.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

GovernmentIdDetails record(int id, String name, {String? type}) =>
    GovernmentIdDetails.fromJson({
      'id': id,
      'name': name,
      'description': 'About $name',
      'record_type': ?type,
    });

final catalog = [
  record(1, 'PhilSys National ID'),
  record(2, 'Philippine Passport'),
  record(3, 'NBI Clearance', type: 'document'),
  record(4, 'Postal ID'),
];

Map<String, dynamic> owning(int id) => {
  'government_ids': [
    {'id': id, 'owned': true},
  ],
  'documents': <Map<String, dynamic>>[],
};

Future<void> showCards(
  WidgetTester tester, {
  required Future<List<GovernmentIdDetails>> Function() loadCatalog,
  Future<Map<String, dynamic>> Function()? loadInventory,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: HomeRecommendations(
          loadCatalog: loadCatalog,
          loadInventory: loadInventory,
          loadDetail: (_) async => throw Exception('No guide'),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('cards come from the catalog, up to two', (tester) async {
    await showCards(tester, loadCatalog: () async => catalog);
    expect(find.text('PhilSys National ID'), findsOneWidget);
    expect(find.text('About PhilSys National ID'), findsOneWidget);
    expect(find.text('Philippine Passport'), findsOneWidget);
    expect(find.text('NBI Clearance'), findsNothing);
    expect(find.text('Postal ID'), findsNothing);
  });

  testWidgets('records the resident owns are left out', (tester) async {
    await showCards(
      tester,
      loadCatalog: () async => catalog,
      loadInventory: () async => owning(1),
    );
    expect(find.text('PhilSys National ID'), findsNothing);
    expect(find.text('Philippine Passport'), findsOneWidget);
    expect(find.text('NBI Clearance'), findsOneWidget);
  });

  testWidgets('tapping a card opens that exact catalog record', (tester) async {
    await showCards(
      tester,
      loadCatalog: () async => [catalog[2]],
    );
    await tester.tap(find.text('NBI Clearance'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final screen = tester.widget<IdDetailsScreen>(find.byType(IdDetailsScreen));
    expect(screen.governmentId, 3);
    expect(screen.recordType, 'document');
    await tester.pump(const Duration(seconds: 21));
  });

  testWidgets('a failed load can be retried', (tester) async {
    var attempts = 0;
    await showCards(
      tester,
      loadCatalog: () async {
        if (++attempts == 1) throw Exception('Offline');
        return catalog;
      },
    );
    expect(find.text('Could not load your recommendations.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(find.text('Philippine Passport'), findsOneWidget);
  });

  testWidgets('no matching records shows a plain note', (tester) async {
    await showCards(tester, loadCatalog: () async => [catalog[3]]);
    expect(find.textContaining('No recommendations right now'), findsOneWidget);
  });

  group('Diro', () {
    Widget diro({bool reduced = false}) => MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
        child: child!,
      ),
      home: const Scaffold(body: DiroPoses(size: 120)),
    );

    testWidgets('switches through every pose and starts over', (tester) async {
      await tester.pumpWidget(diro());
      for (var pose = 1; pose <= DiroPoses.poses.length; pose++) {
        await tester.pump(DiroPoses.interval);
        await tester.pump(const Duration(seconds: 1));
        final shown = pose % DiroPoses.poses.length;
        expect(find.byKey(ValueKey(shown)), findsOneWidget);
      }
    });

    testWidgets('holds one pose when the device asks for less motion', (
      tester,
    ) async {
      await tester.pumpWidget(diro(reduced: true));
      await tester.pump(DiroPoses.interval * 2);
      expect(find.byKey(const ValueKey(0)), findsOneWidget);
      expect(find.byKey(const ValueKey(1)), findsNothing);
    });

    for (final (width, scale, shown) in const [
      (390.0, 1.0, true),
      (320.0, 1.0, false),
      (390.0, 2.0, false),
    ]) {
      testWidgets('journey banner at $width wide, text x$scale fits', (
        tester,
      ) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: JourneyBanner(
                    journeys: [
                      IdJourney(targetIds: ['Passport ID', 'PhilSys ID']),
                    ],
                    onOpen: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(find.byType(DiroPoses), shown ? findsOneWidget : findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  });
}
