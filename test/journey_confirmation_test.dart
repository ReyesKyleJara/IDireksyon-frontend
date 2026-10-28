import 'fixtures/roadmap_auth.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:idireksyon_frontend/features/loading/loading_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

void main() {
  late AuthService previousAuth;
  setUp(() { previousAuth = AuthService.instance; AuthService.instance = journeyAuth(); });
  tearDown(() { AuthService.instance.dispose(); AuthService.instance = previousAuth; });
  testWidgets('Confirmation loads journey and keeps it when switching tabs', (
    tester,
  ) async {
    await http.runWithClient(() async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const SuggestedRoadmapScreen(targetIds: ['Philippine Passport'], targetCatalogIds: [55]),
      ),
    );
    await tester.pumpAndSettle(); // Wait for the saved-Inventory plan before confirming.
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
      tester.widget<ResidentAppShell>(find.byType(ResidentAppShell)).initialIndex,
      1,
    );
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Roadmap').last);
    await tester.pumpAndSettle();
    expect(find.text('Your next steps'), findsOneWidget);
    expect(find.text('Birth Certificate'), findsNothing);
    await tester.ensureVisible(find.text('Preview Guide').last);
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Preview Guide').last);
    await tester.pumpAndSettle();
    expect(find.byType(IdDetailsScreen), findsOneWidget);
    expect(tester.widget<IdDetailsScreen>(find.byType(IdDetailsScreen)).governmentId, 55);
    expect(tester.takeException(), isNull);
    }, () => MockClient((request) async => http.Response(jsonEncode({'data': request.url.path.endsWith('/55') ? {'id': 55, 'name': 'Philippine Passport'} : [{'id': 55, 'name': 'Philippine Passport'}]}), 200)));
  });
}
