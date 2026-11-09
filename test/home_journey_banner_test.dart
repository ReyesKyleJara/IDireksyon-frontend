import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/home/home_screen.dart';
import 'package:idireksyon_frontend/features/home/journey_banner.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

import 'fixtures/roadmap_auth.dart';

IdJourney savedJourney(int id, String name, {bool done = false}) =>
    IdJourney.fromJson({
      'id': id,
      'plan': planData([id], [planStep(id, name)]),
      'completed_step_identities': done ? ['government_id:$id'] : <String>[],
      'completed_at': done ? '2026-11-09T04:00:00Z' : null,
    });

Widget homeWith(List<IdJourney> journeys) => MaterialApp(
  theme: AppTheme.lightTheme,
  home: Scaffold(body: HomeScreen(journeys: journeys)),
);

void main() {
  testWidgets('all journeys completed shows the get started banner', (
    tester,
  ) async {
    await tester.pumpWidget(
      homeWith([savedJourney(1, 'Passport', done: true)]),
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(find.text('ONGOING JOURNEY'), findsNothing);
    expect(find.byType(JourneyBanner), findsNothing);
  });

  testWidgets('only unfinished journeys appear as ongoing', (tester) async {
    await tester.pumpWidget(
      homeWith([
        savedJourney(1, 'Passport', done: true),
        savedJourney(2, 'NBI Clearance'),
      ]),
    );
    expect(find.text('ONGOING JOURNEY'), findsOneWidget);
    expect(find.text('NBI Clearance'), findsOneWidget);
    expect(find.text('Passport'), findsNothing);
    expect(find.textContaining('Swipe to browse'), findsNothing);
  });

  testWidgets('banner recovers when the shown journey is finished', (
    tester,
  ) async {
    await tester.pumpWidget(
      homeWith([
        savedJourney(1, 'Passport'),
        savedJourney(2, 'NBI Clearance'),
        savedJourney(3, 'Postal ID'),
      ]),
    );
    await tester.tap(find.byTooltip('Next journey'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Next journey'));
    await tester.pumpAndSettle();
    expect(find.text('Journey 3 of 3 · Swipe to browse'), findsOneWidget);

    await tester.pumpWidget(
      homeWith([
        savedJourney(1, 'Passport'),
        savedJourney(2, 'NBI Clearance'),
        savedJourney(3, 'Postal ID', done: true),
      ]),
    );
    await tester.pumpAndSettle();
    expect(find.text('Journey 1 of 2 · Swipe to browse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('empty home keeps get started banner', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(body: HomeScreen()),
      ),
    );
    expect(find.text('Get started'), findsOneWidget);
    expect(find.byType(JourneyBanner), findsNothing);
  });

  testWidgets('swipe banners and continue the selected minimized journey', (
    tester,
  ) async {
    final first = IdJourney(progress: .25);
    final second = IdJourney(targetIds: ['PhilSys ID'], progress: .5)
      ..minimized = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResidentAppShell(journeys: [first, second]),
      ),
    );
    expect(find.text('Get started'), findsNothing);
    expect(find.text('Overall progress: 0%'), findsOneWidget);
    expect(find.text('Journey 1 of 2 · Swipe to browse'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Journey 2 of 2 · Swipe to browse'), findsOneWidget);
    expect(find.text('Overall progress: 0%'), findsOneWidget);
    expect(
      tester
          .widget<LinearProgressIndicator>(
            find
                .descendant(
                  of: find.byType(JourneyBanner),
                  matching: find.byType(LinearProgressIndicator),
                )
                .first,
          )
          .value,
      0,
    );
    await tester.tap(find.text('Continue journey').hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ActiveJourneyScreen>(find.byType(ActiveJourneyScreen))
          .initialJourney,
      same(second),
    );
    expect(second.minimized, isFalse);
    expect(
      find.text('0%'),
      findsNWidgets(2),
    ); // Readiness is not journey completion.
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(find.text('Journey 2 of 2 · Swipe to browse'), findsOneWidget);
    await tester.tap(find.byTooltip('Previous journey'));
    await tester.pumpAndSettle();
    expect(find.text('Journey 1 of 2 · Swipe to browse'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('single journey banner fits narrow width and large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    IdJourney? opened;
    final journey = IdJourney(
      targetIds: ['Passport ID', 'PhilHealth ID', 'PhilSys ID'],
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: JourneyBanner(
                journeys: [journey],
                onOpen: (value) => opened = value,
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.byTooltip('Next journey'), findsNothing);
    await tester.ensureVisible(find.text('Continue journey'));
    await tester.tap(find.text('Continue journey'));
    expect(opened, same(journey));
    expect(tester.takeException(), isNull);
  });
}
