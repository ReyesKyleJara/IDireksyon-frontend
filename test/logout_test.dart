import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/auth/session_store.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';
import 'package:idireksyon_frontend/features/startup/startup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      await tester.tapAt(corner);
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

  group('signed-in routes', () {
    late SessionStore store;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      store = SessionStore();
      await store.completeOnboarding();
    });

    void useAuth(WidgetTester tester, Future<http.Response> Function() reply) {
      final original = AuthService.instance;
      AuthService.instance = AuthService(
        sessionStore: store,
        client: MockClient((_) => reply()),
      );
      addTearDown(() => AuthService.instance = original);
    }

    testWidgets('without a session, /home goes to Log In', (tester) async {
      useAuth(tester, () => throw StateError('No HTTP expected'));
      await tester.pumpWidget(
        const MaterialApp(
          onGenerateRoute: AppRouter.generateRoute,
          initialRoute: '/home',
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResidentAppShell), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('a saved session continues to the requested page', (
      tester,
    ) async {
      await store.save(
        SavedSession(
          'saved-token',
          {'id': 7},
          DateTime.now().toUtc().add(const Duration(days: 1)),
        ),
      );
      useAuth(tester, () async => http.Response('{"user":{"id":7}}', 200));
      await tester.pumpWidget(
        MaterialApp(
          routes: {'/resumed': (_) => const Text('Resumed page')},
          home: const StartupScreen(resumeRoute: '/resumed'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Resumed page'), findsOneWidget);
      expect(AuthService.instance.token, 'saved-token');
    });
  });
}
