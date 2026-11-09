import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';

void main() {
  for (final offline in [false, true]) {
    testWidgets('logout clears session and navigation, offline: $offline', (
      tester,
    ) async {
      final original = AuthService.instance;
      addTearDown(() => AuthService.instance = original);
      var calls = 0;
      AuthService.instance =
          AuthService(
              client: MockClient((request) async {
                if (request.url.path.endsWith('/journeys') && request.method == 'GET') return http.Response('{"data":[]}', 200);
                if (request.url.path.endsWith('/inventory') && request.method == 'GET') return http.Response('{"data":{"government_ids":[],"documents":[]}}', 200);
                calls++;
                expect(request.url.path, '/api/auth/logout');
                expect(request.headers['Authorization'], 'Bearer test-token');
                if (offline) throw http.ClientException('offline');
                return http.Response('{"message":"Logged out."}', 200);
              }),
            )
            ..token = 'test-token'
            ..user = {'name': 'Resident'};
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          onGenerateRoute: AppRouter.generateRoute,
          home: const ResidentAppShell(initialIndex: 3),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Log out'), 300, scrollable: find.byType(Scrollable).first);
      await tester.ensureVisible(find.text('Log out'));
      await tester.pumpAndSettle();
      // One click near the button's corner, away from its icon and label,
      // then an accidental second click before the first has finished.
      final button = find.ancestor(
        of: find.text('Log out'),
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      );
      final corner = tester.getTopLeft(button) + const Offset(14, 14);
      await tester.tapAt(corner);
      // Direct, because Navigator briefly absorbs pointers after a push.
      tester.widget<OutlinedButton>(button).onPressed!();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(calls, 0);
      expect(AuthService.instance.token, 'test-token');
      await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(calls, 1);
      expect(AuthService.instance.token, isNull);
      expect(AuthService.instance.user, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResidentAppShell), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('cancelling the logout dialog stays signed in', (tester) async {
    final original = AuthService.instance;
    addTearDown(() => AuthService.instance = original);
    var calls = 0;
    AuthService.instance =
        AuthService(
            client: MockClient((request) async {
              if (request.url.path.endsWith('/auth/logout')) calls++;
              return http.Response('{"data":[]}', 200);
            }),
          )
          ..token = 'test-token'
          ..user = {'name': 'Resident'};
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.generateRoute,
        home: const ResidentAppShell(initialIndex: 3),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Log out'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();

    for (var attempt = 0; attempt < 2; attempt++) {
      // The dialog can be opened again after it has been cancelled.
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.text('Log out of IDireksyon?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
    }

    expect(calls, 0);
    expect(AuthService.instance.token, 'test-token');
    expect(find.byType(ResidentAppShell), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
