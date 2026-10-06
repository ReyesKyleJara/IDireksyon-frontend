import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

void main() {
  testWidgets('minimize, add a different journey, and reopen the original', (
    tester,
  ) async {
    final original = IdJourney();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResidentAppShell(initialIndex: 1, journeys: [original]),
      ),
    );
    await tester.tap(find.text('Minimize progress'));
    await tester.pumpAndSettle();
    expect(find.text('Your next steps'), findsNothing);
    expect(find.text('0%'), findsOneWidget);
    await tester.tap(find.text('Add another ID journey'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passport ID'));
    await tester.tap(find.text('PhilSys ID'));
    await tester.ensureVisible(find.text('Next'));
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save & Continue'));
    await tester.tap(find.text('Save & Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Passport ID'), findsNothing);
    await tester.ensureVisible(find.text('Confirm Suggested Journey'));
    await tester.tap(find.text('Confirm Suggested Journey'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    final active = tester.widget<ActiveJourneyScreen>(
      find.byType(ActiveJourneyScreen),
    );
    expect(active.journeys.length, 2);
    expect(identical(active.journeys.first, original), isTrue);
    expect(original.minimized, isTrue);
    expect(active.journeys.last.targetIds, ['PhilSys ID']);
    expect(active.journeys.last.ownedItems, contains('Birth Certificate'));
    await tester.tap(find.text('Expand progress'));
    await tester.pumpAndSettle();
    expect(original.minimized, isFalse);
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My ID Journey').last);
    await tester.pumpAndSettle();
    expect(original.minimized, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling another journey preserves the original card', (
    tester,
  ) async {
    final original = IdJourney()..minimized = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ResidentAppShell(initialIndex: 1, journeys: [original]),
      ),
    );
    await tester.tap(find.text('Add another ID journey'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Expand progress'), findsOneWidget);
    expect(
      tester
          .widget<ActiveJourneyScreen>(find.byType(ActiveJourneyScreen))
          .journeys,
      [original],
    );
  });

  testWidgets('minimized cards fit narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Scaffold(
          body: ActiveJourneyScreen(
            journeys: [
              IdJourney(targetIds: ['PhilSys ID', 'PhilHealth ID'])
                ..minimized = true,
            ],
          ),
        ),
      ),
    );
    await tester.scrollUntilVisible(
      find.text('Expand progress').hitTestable(),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Expand progress'));
    await tester.pumpAndSettle();
    expect(find.text('Minimize progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
