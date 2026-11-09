import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/roadmap/roadmap_screen.dart';

import 'fixtures/roadmap_auth.dart';

Map<String, dynamic> journeyJson(int id, String name, {String? completedAt}) =>
    {
      'id': id,
      'plan': planData([id], [planStep(id, name)]),
      'completed_step_identities': completedAt == null
          ? <String>[]
          : ['government_id:$id'],
      'completed_at': completedAt,
    };

IdJourney journey(int id, String name, {String? completedAt}) =>
    IdJourney.fromJson(journeyJson(id, name, completedAt: completedAt));

Widget screen(List<IdJourney> journeys, {IdJourney? initial}) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(
    body: ActiveJourneyScreen(journeys: journeys, initialJourney: initial),
  ),
);

void main() {
  late AuthService previousAuth;
  setUp(() => previousAuth = AuthService.instance);
  tearDown(() => AuthService.instance = previousAuth);

  test('a journey is completed only when every step is done', () {
    final done = journey(1, 'Passport', completedAt: '2026-11-09T04:00:00Z');
    expect(done.isCompleted, isTrue);
    expect(done.completedDateLabel, startsWith('Nov '));
    expect(done.completedDateLabel, endsWith(', 2026'));
    final ongoing = journey(2, 'NBI Clearance');
    expect(ongoing.isCompleted, isFalse);
    expect(ongoing.completedDateLabel, isNull);
    expect(IdJourney().isCompleted, isFalse);
  });

  testWidgets('tabs separate ongoing and finished journeys', (tester) async {
    await tester.pumpWidget(
      screen([
        journey(1, 'Older', completedAt: '2026-01-05T04:00:00Z'),
        journey(2, 'Ongoing'),
        journey(3, 'Newer', completedAt: '2026-03-05T04:00:00Z'),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('In Progress (1)'), findsOneWidget);
    expect(find.text('Completed (2)'), findsOneWidget);
    expect(find.text('Ongoing'), findsWidgets);
    expect(find.text('Older'), findsNothing);
    expect(find.text('Add another ID journey'), findsOneWidget);

    await tester.tap(find.text('Completed (2)'));
    await tester.pumpAndSettle();
    expect(find.text('Ongoing'), findsNothing);
    expect(find.text('Add another ID journey'), findsNothing);
    expect(find.text('Completed Mar 5, 2026'), findsOneWidget);
    expect(find.text('Completed Jan 5, 2026'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Completed Mar 5, 2026')).dy,
      lessThan(tester.getTopLeft(find.text('Completed Jan 5, 2026')).dy),
    );
    // The log starts collapsed, and a finished journey has nothing to mark.
    expect(find.text('Mark as Completed'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opens on Completed when nothing is in progress', (tester) async {
    await tester.pumpWidget(
      screen([journey(1, 'Done', completedAt: '2026-01-05T04:00:00Z')]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed Jan 5, 2026'), findsOneWidget);

    await tester.tap(find.text('In Progress'));
    await tester.pumpAndSettle();
    expect(find.text('No journeys in progress'), findsOneWidget);
    expect(find.text('Add another ID journey'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('opening a finished journey from elsewhere shows it in the log', (
    tester,
  ) async {
    final done = journey(1, 'Done', completedAt: '2026-01-05T04:00:00Z');
    await tester.pumpWidget(
      screen([journey(2, 'Ongoing'), done], initial: done),
    );
    await tester.pumpAndSettle();
    expect(find.text('Completed Jan 5, 2026'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });

  testWidgets('finishing the last step moves the journey to Completed', (
    tester,
  ) async {
    AuthService.instance = AuthService(
      baseUrl: 'http://localhost:8000/api',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'data': journeyJson(
              1,
              'Passport',
              completedAt: '2026-11-09T04:00:00Z',
            ),
          }),
          200,
        ),
      ),
    )..token = 'resident-token';
    await tester.pumpWidget(screen([journey(1, 'Passport')]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Mark as Completed'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Mark as Completed'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Completed (1)'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.textContaining('Completed Nov'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('empty roadmap has tabs at text scale $scale', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: const Scaffold(body: RoadmapScreen()),
        ),
      );
      expect(find.text('No active roadmap yet'), findsOneWidget);
      await tester.tap(find.text('Completed'));
      await tester.pumpAndSettle();
      expect(find.text('No completed journeys yet'), findsOneWidget);
      expect(find.text('No active roadmap yet'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
