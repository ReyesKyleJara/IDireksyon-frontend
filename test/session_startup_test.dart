import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/auth/session_store.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/onboarding/onboarding_screen.dart';
import 'package:idireksyon_frontend/features/startup/startup_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SessionStore store;
  final secure = const FlutterSecureStorage();

  AuthService service(http.Response Function(http.Request) respond) =>
      AuthService(
        sessionStore: store,
        client: MockClient((request) async => respond(request)),
      );

  Future<void> seed({DateTime? expiresAt}) async {
    await store.completeOnboarding();
    await store.save(
      SavedSession('saved-token', {
        'id': 7,
        'name': 'Cached resident',
      }, expiresAt ?? DateTime.now().toUtc().add(const Duration(days: 10))),
    );
  }

  setUp(() => store = SessionStore());

  test('first launch has no session and requires onboarding', () async {
    final auth = service((_) => throw StateError('No HTTP expected'));
    expect(await auth.startupRoute(), '/onboarding');
    expect(auth.token, isNull);
    expect(await store.onboardingCompleted, isFalse);
  });

  test('onboarding completion survives a new service and store', () async {
    await store.completeOnboarding();
    final restarted = AuthService(sessionStore: SessionStore());
    expect(await restarted.startupRoute(), '/login');
  });

  for (final path in ['login', 'register']) {
    test(
      '$path persists securely and restores with server validation',
      () async {
        final auth = service((request) {
          expect(request.url.path, '/api/auth/$path');
          return http.Response('{"token":"new-token","user":{"id":7}}', 200);
        });
        if (path == 'login') {
          await auth.login('resident@example.com', 'password123');
        } else {
          await auth.register(
            contact: 'resident@example.com',
            usePhone: false,
            password: 'password123',
            confirmation: 'password123',
            accepted: true,
          );
        }
        expect(await store.onboardingCompleted, isTrue);
        final encoded = await secure.read(key: SessionStore.sessionKey);
        expect(SavedSession.decode(encoded!).token, 'new-token');
        final prefs = await SharedPreferences.getInstance();
        for (final key in prefs.getKeys()) {
          expect('${prefs.get(key)}', isNot(contains('new-token')));
          expect('${prefs.get(key)}', isNot(contains('password123')));
        }
        final restarted = AuthService(
          sessionStore: SessionStore(),
          client: MockClient((request) async {
            expect(request.method, 'GET');
            expect(request.url.path, '/api/auth/me');
            expect(request.headers['Authorization'], 'Bearer new-token');
            return http.Response(
              '{"user":{"id":7,"name":"Fresh resident"}}',
              200,
            );
          }),
        );
        expect(restarted.token, isNull);
        expect(await restarted.startupRoute(), '/home');
        expect(restarted.token, 'new-token');
        expect(restarted.user?['name'], 'Fresh resident');
        expect((await store.read())!.user['name'], 'Fresh resident');
      },
    );
  }

  for (final status in [401, 403]) {
    test('rejected session ($status) is removed and opens Login', () async {
      await seed();
      final auth = service((_) => http.Response('{}', status));
      expect(await auth.startupRoute(), '/login');
      expect(auth.token, isNull);
      expect(auth.user, isNull);
      expect(await secure.read(key: SessionStore.sessionKey), isNull);
      expect(await store.onboardingCompleted, isTrue);
    });
  }

  test('locally expired session goes to Login even offline', () async {
    await seed(
      expiresAt: DateTime.now().toUtc().subtract(const Duration(seconds: 1)),
    );
    final auth = service(
      (_) => throw StateError('Expired session must not be sent'),
    );
    expect(await auth.startupRoute(), '/login');
    expect(await store.read(), isNull);
    expect(auth.token, isNull);
  });

  for (final failure in ['offline', 'timeout', '503', '429', 'malformed']) {
    test(
      '$failure retains saved credentials and cached user on startup',
      () async {
        await seed();
        final original = await secure.read(key: SessionStore.sessionKey);
        final auth = service((_) {
          if (failure == 'offline') throw http.ClientException('offline');
          if (failure == 'timeout') throw TimeoutException('timeout');
          if (failure == 'malformed') return http.Response('not json', 200);
          return http.Response('{}', int.parse(failure));
        });
        expect(await auth.startupRoute(), '/home');
        expect(auth.token, 'saved-token');
        expect(auth.user?['name'], 'Cached resident');
        expect(await secure.read(key: SessionStore.sessionKey), original);
        // A later online launch can validate normally.
        final online = service((_) => http.Response('{"user":{"id":7}}', 200));
        expect(await online.startupRoute(), '/home');
      },
    );
  }

  for (final offline in [false, true]) {
    test(
      'logout clears secure session, retains onboarding, offline: $offline',
      () async {
        await seed();
        final auth =
            service((_) {
                if (offline) throw http.ClientException('offline');
                return http.Response('{}', 200);
              })
              ..token = 'saved-token'
              ..user = {'id': 7};
        if (offline) {
          await expectLater(auth.logout(), throwsA(isA<AuthException>()));
        } else {
          await auth.logout();
        }
        expect(auth.token, isNull);
        expect(auth.user, isNull);
        expect(await secure.read(key: SessionStore.sessionKey), isNull);
        expect(await store.onboardingCompleted, isTrue);
        expect(
          await AuthService(sessionStore: SessionStore()).startupRoute(),
          '/login',
        );
      },
    );
  }

  test('logout removes saved session before a slow server responds', () async {
    await seed();
    final requested = Completer<void>();
    final response = Completer<http.Response>();
    final auth =
        AuthService(
            sessionStore: store,
            client: MockClient((request) {
              expect(request.headers['Authorization'], 'Bearer saved-token');
              requested.complete();
              return response.future;
            }),
          )
          ..token = 'saved-token'
          ..user = {'id': 7};
    final logout = auth.logout();
    await requested.future;
    expect(auth.token, isNull);
    expect(await secure.read(key: SessionStore.sessionKey), isNull);
    expect(
      await AuthService(sessionStore: SessionStore()).startupRoute(),
      '/login',
    );
    response.complete(http.Response('{}', 200));
    await logout;
  });

  test(
    'successful deletion clears saved session and keeps onboarding',
    () async {
      await seed();
      final auth =
          service((request) {
              expect(request.url.path, '/api/auth/account/delete');
              return http.Response('{"message":"Account deleted."}', 200);
            })
            ..token = 'saved-token'
            ..user = {'id': 7};
      await auth.deleteAccount(password: 'password123');
      expect(auth.token, isNull);
      expect(auth.user, isNull);
      expect(await secure.read(key: SessionStore.sessionKey), isNull);
      expect(await store.onboardingCompleted, isTrue);
      expect(
        await AuthService(sessionStore: SessionStore()).startupRoute(),
        '/login',
      );
    },
  );

  test('failed deletion keeps saved and in-memory session', () async {
    await seed();
    final auth =
        service((_) => http.Response('{"message":"Wrong password"}', 422))
          ..token = 'saved-token'
          ..user = {'id': 7};
    await expectLater(
      auth.deleteAccount(password: 'wrong'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.token, 'saved-token');
    expect((await store.read())!.token, 'saved-token');
  });

  test('fresh install ignores an old Keychain entry', () async {
    await seed();
    SharedPreferences.setMockInitialValues({});
    final auth = service((_) => throw StateError('No HTTP expected'));
    expect(await auth.startupRoute(), '/onboarding');
    expect(await secure.read(key: SessionStore.sessionKey), isNull);
  });

  test(
    'corrupt secure session is discarded without replaying onboarding',
    () async {
      await seed();
      await secure.write(key: SessionStore.sessionKey, value: '{broken');
      expect(
        await service((_) => throw StateError('No HTTP expected'))
            .startupRoute(),
        '/login',
      );
      expect(await secure.read(key: SessionStore.sessionKey), isNull);
    },
  );

  test('secure write failure does not report a successful login', () async {
    final auth = AuthService(
      sessionStore: _FailingStore(),
      client: MockClient(
        (_) async => http.Response('{"token":"new","user":{"id":7}}', 200),
      ),
    );
    await expectLater(
      auth.login('user', 'password'),
      throwsA(isA<AuthException>()),
    );
    expect(auth.token, isNull);
  });

  testWidgets('bootstrap waits for validation before showing Home', (
    tester,
  ) async {
    await seed();
    final response = Completer<http.Response>();
    final original = AuthService.instance;
    AuthService.instance = AuthService(
      sessionStore: store,
      client: MockClient((_) => response.future),
    );
    addTearDown(() => AuthService.instance = original);
    await tester.pumpWidget(
      MaterialApp(
        onGenerateRoute: AppRouter.generateRoute,
        routes: {'/home': (_) => const Scaffold(body: Text('Restored Home'))},
      ),
    );
    await tester.pump();
    expect(find.byType(StartupScreen), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Restored Home'), findsNothing);
    response.complete(http.Response('{"user":{"id":7}}', 200));
    await tester.pumpAndSettle();
    expect(find.text('Restored Home'), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.text('Restored Home'))).canPop(),
      isFalse,
    );
  });

  testWidgets(
    'first launch opens onboarding; Login removes it and persists completion',
    (tester) async {
      final original = AuthService.instance;
      AuthService.instance = service(
        (_) => throw StateError('No HTTP expected'),
      );
      addTearDown(() => AuthService.instance = original);
      await tester.pumpWidget(
        MaterialApp(onGenerateRoute: AppRouter.generateRoute),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('I already have an account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
      expect(
        Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
        isFalse,
      );
      expect(await store.onboardingCompleted, isTrue);
      await tester.pumpWidget(const SizedBox.shrink());
      AuthService.instance = AuthService(sessionStore: SessionStore());
      await tester.pumpWidget(
        MaterialApp(onGenerateRoute: AppRouter.generateRoute),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.byType(OnboardingScreen), findsNothing);
    },
  );

  testWidgets(
    'reaching final onboarding slide persists completion without login',
    (tester) async {
      await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));
      await tester.pump(const Duration(milliseconds: 700));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 700));
      }
      expect(await store.onboardingCompleted, isTrue);
      expect(
        await service((_) => throw StateError('No HTTP expected'))
            .startupRoute(),
        '/login',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'storage read failure offers retry without choosing auth screen',
    (tester) async {
      final original = AuthService.instance;
      final failing = _FailingStore()..failRead = true;
      AuthService.instance = AuthService(sessionStore: failing);
      addTearDown(() => AuthService.instance = original);
      await tester.pumpWidget(
        MaterialApp(onGenerateRoute: AppRouter.generateRoute),
      );
      await tester.pumpAndSettle();
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(LoginScreen), findsNothing);
      failing.failRead = false;
      await tester.tap(find.text('Retry'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}

class _FailingStore extends SessionStore {
  bool failRead = false;

  @override
  Future<SavedSession?> read() async {
    if (failRead) throw StateError('Keychain locked');
    return super.read();
  }

  @override
  Future<void> save(SavedSession session) async =>
      throw StateError('Secure store unavailable');
}
