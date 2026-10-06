import 'package:flutter/material.dart';
import 'package:idireksyon_frontend/features/loading/loading_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

void main() {
  testWidgets('Confirmation loads journey and keeps it when switching tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SuggestedRoadmapScreen(),
      ),
    );
    final confirm = find.text('Confirm Suggested Journey');
    await tester.ensureVisible(confirm);
    await tester.tap(confirm);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(LoadingScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.byType(ActiveJourneyScreen), findsOneWidget);
    expect(
      tester
          .widget<BottomNavigationBar>(find.byType(BottomNavigationBar))
          .currentIndex,
      1,
    );
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('My ID Journey').last);
    await tester.pumpAndSettle();
    expect(find.text('Your next steps'), findsOneWidget);
    await tester.ensureVisible(find.text('Birth Certificate'));
    await tester.tap(find.text('Birth Certificate'));
    await tester.pumpAndSettle();
    expect(find.byType(PsaBirthCertificateGuideScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
