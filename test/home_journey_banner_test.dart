import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/home/home_screen.dart';
import 'package:idireksyon_frontend/features/home/journey_banner.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

void main() {
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
    expect(find.text('Overall readiness: 25%'), findsOneWidget);
    expect(find.text('Journey 1 of 2 · Swipe to browse'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Journey 2 of 2 · Swipe to browse'), findsOneWidget);
    expect(find.text('Overall readiness: 50%'), findsOneWidget);
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
      .5,
    );
    await tester.tap(find.text('Continue journey').hitTestable());
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    expect(
      tester
          .widget<ActiveJourneyScreen>(find.byType(ActiveJourneyScreen))
          .initialJourney,
      same(second),
    );
    expect(second.minimized, isFalse);
    expect(find.text('50%'), findsOneWidget);
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
