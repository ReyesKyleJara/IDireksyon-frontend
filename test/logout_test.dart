import 'dart:async';

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
import 'package:idireksyon_frontend/features/profile/profile_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Counts full-page navigations; the confirmation dialog is not one.
class _PagePushes extends NavigatorObserver {
  int count = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (route is PageRoute) count++;
  }
}

class _BrokenStore extends SessionStore {
  @override
  Future<void> clear() async => throw StateError('storage unavailable');
}

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
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // The server answers only when told to, so frames are drawn while logout is
  // waiting, as on a real device. An instant mock hides that window.
  group('confirmed logout with a slow server', () {
    late SessionStore store;
    late Completer<http.Response> server;
    late List<String?> logoutTokens;
    late _PagePushes pages;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      SharedPreferences.setMockInitialValues({});
      store = SessionStore();
      logoutTokens = [];
      pages = _PagePushes();
    });

    AuthService useAuth() {
      // Made here, inside the test's fake-time zone, so pump can deliver it.
      server = Completer();
      final original = AuthService.instance;
      addTearDown(() => AuthService.instance = original);
      return AuthService.instance = AuthService(
        sessionStore: store,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/logout')) {
            logoutTokens.add(request.headers['Authorization']);
            return server.future;
          }
          if (request.url.path.endsWith('/auth/me')) {
            return http.Response('{"user":{"id":7,"name":"Resident"}}', 200);
          }
          return http.Response('{"data":[]}', 200);
        }),
      );
    }

    Future<void> openDialog(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          navigatorObservers: [pages],
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
      await tester.tap(find.text('Log out'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      pages.count = 0;
    }

    Finder confirm() => find.widgetWithText(FilledButton, 'Log out');

    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
    }

    Future<void> finishRequest(WidgetTester tester) async {
      server.complete(http.Response('{"message":"Logged out."}', 200));
      await settle(tester);
    }

    void expectOnLogin(WidgetTester tester) {
      expect(AuthService.instance.token, isNull);
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(ResidentAppShell), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(pages.count, 1);
      expect(tester.takeException(), isNull);
    }

    testWidgets('Login appears without waiting for the server', (tester) async {
      useAuth()
        ..token = 'test-token'
        ..user = {'name': 'Resident'};
      await openDialog(tester);

      await tester.tap(confirm());
      await settle(tester);

      // The server has not answered yet.
      expect(server.isCompleted, isFalse);
      expectOnLogin(tester);
      expect(logoutTokens, ['Bearer test-token']);
      expect(await store.read(), isNull);
      await finishRequest(tester);
    });

    testWidgets('a late server success changes nothing', (tester) async {
      useAuth()
        ..token = 'test-token'
        ..user = {'name': 'Resident'};
      await openDialog(tester);

      await tester.tap(confirm());
      await settle(tester);
      await finishRequest(tester);

      expectOnLogin(tester);
      expect(logoutTokens, hasLength(1));
      expect(find.byType(SnackBar), findsNothing);
    });

    for (final failure in ['server error', 'no connection']) {
      testWidgets('$failure leaves the resident signed out, with no alarm', (
        tester,
      ) async {
        useAuth()
          ..token = 'test-token'
          ..user = {'name': 'Resident'};
        await openDialog(tester);

        await tester.tap(confirm());
        await settle(tester);
        if (failure == 'server error') {
          server.complete(http.Response('{"message":"Failed."}', 500));
        } else {
          server.completeError(http.ClientException('offline'));
        }
        await settle(tester);

        expectOnLogin(tester);
        expect(logoutTokens, hasLength(1));
        expect(find.byType(SnackBar), findsNothing);
        expect(await store.read(), isNull);
      });
    }

    testWidgets('a local cleanup failure is reported, on Login', (
      tester,
    ) async {
      store = _BrokenStore();
      useAuth()
        ..token = 'test-token'
        ..user = {'name': 'Resident'};
      await openDialog(tester);

      await tester.tap(confirm());
      await settle(tester);

      expectOnLogin(tester);
      expect(
        find.text('Could not clear the saved session. Please try again.'),
        findsOneWidget,
      );
      expect(logoutTokens, isEmpty);
    });

    testWidgets('double tap on the confirm button logs out once', (
      tester,
    ) async {
      useAuth()
        ..token = 'test-token'
        ..user = {'name': 'Resident'};
      await openDialog(tester);

      final button = tester.getCenter(confirm());
      await tester.tapAt(button);
      await tester.pump(const Duration(milliseconds: 30));
      await tester.tapAt(button);
      await tester.pump(const Duration(milliseconds: 600));

      await finishRequest(tester);
      expectOnLogin(tester);
      expect(logoutTokens, hasLength(1));
    });

    testWidgets('a restored session logs out with one confirmation', (
      tester,
    ) async {
      await store.completeOnboarding();
      await store.save(
        SavedSession(
          'saved-token',
          {'id': 7, 'name': 'Resident'},
          DateTime.now().toUtc().add(const Duration(days: 1)),
        ),
      );
      final auth = useAuth();
      expect(await auth.startupRoute(), '/home');
      expect(auth.token, 'saved-token');
      await openDialog(tester);

      await tester.tap(confirm());
      await settle(tester);

      expect(server.isCompleted, isFalse);
      expectOnLogin(tester);
      expect(logoutTokens, ['Bearer saved-token']);
      expect(await store.read(), isNull);
      await finishRequest(tester);
      expectOnLogin(tester);
    });
  });
}
