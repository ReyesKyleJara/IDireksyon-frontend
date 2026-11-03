import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/profile/password_security_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late List<http.Request> requests;
  late http.Response Function() respond;

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'profile_photo_7': 'cGhvdG8=',
      'profile_photo_8': 'b3RoZXI=',
    });
    requests = [];
    final original = AuthService.instance;
    addTearDown(() => AuthService.instance = original);
    AuthService.instance =
        AuthService(
            client: MockClient((request) async {
              requests.add(request);
              return respond();
            }),
          )
          ..token = 'test-token'
          ..user = {'id': 7, 'name': 'Resident'};
  });

  Future<void> openDialog(WidgetTester tester, {double scale = 1}) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        onGenerateRoute: AppRouter.generateRoute,
        home: const PasswordSecurityScreen(),
      ),
    );
    await tester.ensureVisible(
      find.widgetWithText(OutlinedButton, 'Delete account'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
  }

  testWidgets('cancel and empty password never contact the server', (
    tester,
  ) async {
    respond = () => http.Response('{}', 500);
    await openDialog(tester);

    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password to confirm.'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(requests, isEmpty);
    expect(AuthService.instance.token, 'test-token');
  });

  testWidgets('wrong password shows the server error and keeps the session', (
    tester,
  ) async {
    respond = () => http.Response(
      jsonEncode({
        'message': 'Your password is incorrect.',
        'errors': {
          'password': ['Your password is incorrect.'],
        },
      }),
      422,
    );
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).last, 'wrong');
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(find.text('Your password is incorrect.'), findsOneWidget);
    expect(find.text('Delete your account?'), findsOneWidget);
    expect(AuthService.instance.token, 'test-token');
    expect(AuthService.instance.user, isNotNull);
  });

  testWidgets('successful deletion clears the session and returns to login', (
    tester,
  ) async {
    respond = () => http.Response('{"message":"Account deleted."}', 200);
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).last, 'secret-password');
    await tester.tap(find.text('Delete permanently'));
    // The login screen animates continuously, so pump instead of settling.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(requests, hasLength(1));
    expect(requests.single.method, 'POST');
    expect(requests.single.url.path, '/api/auth/account/delete');
    expect(requests.single.headers['Authorization'], 'Bearer test-token');
    expect(jsonDecode(requests.single.body), {'password': 'secret-password'});

    expect(AuthService.instance.token, isNull);
    expect(AuthService.instance.user, isNull);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(LoginScreen))).canPop(),
      isFalse,
    );
    expect(find.text('Your account has been deleted.'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('profile_photo_7'), isNull);
    expect(prefs.getString('profile_photo_8'), 'b3RoZXI=');
    expect(tester.takeException(), isNull);
  });

  testWidgets('connection failure keeps the resident signed in', (
    tester,
  ) async {
    await tester.pumpWidget(const SizedBox());
    AuthService.instance =
        AuthService(
            client: MockClient(
              (_) async => throw http.ClientException('offline'),
            ),
          )
          ..token = 'test-token'
          ..user = {'id': 7};
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).last, 'secret-password');
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(
      find.text(
        'Cannot connect to the server. Check your connection and try again.',
      ),
      findsOneWidget,
    );
    expect(AuthService.instance.token, 'test-token');
    expect(find.byType(LoginScreen), findsNothing);
  });
  for (final body in ['{}', '{"message":null}', '{"message":"Unexpected"}']) {
    test(
      'malformed successful deletion response retains the session: $body',
      () async {
        respond = () => http.Response(body, 200);
        await expectLater(
          AuthService.instance.deleteAccount(password: 'password'),
          throwsA(isA<AuthException>()),
        );
        expect(AuthService.instance.token, 'test-token');
        expect(AuthService.instance.user, isNotNull);
      },
    );
  }

  testWidgets(
    'pending deletion prevents duplicate requests and server failure retains the session',
    (tester) async {
      final pending = Completer<http.Response>();
      var calls = 0;
      AuthService.instance =
          AuthService(
              client: MockClient((request) {
                calls++;
                return pending.future;
              }),
            )
            ..token = 'test-token'
            ..user = {'id': 7};
      await openDialog(tester);
      await tester.enterText(find.byType(TextFormField).last, 'password');
      await tester.tap(find.text('Delete permanently'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester
            .widget<FilledButton>(
              find.descendant(
                of: find.byType(AlertDialog),
                matching: find.byType(FilledButton),
              ),
            )
            .onPressed,
        isNull,
      );
      expect(calls, 1);
      expect(AuthService.instance.token, 'test-token');
      pending.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(
        find.text('The server is unavailable. Please try again.'),
        findsOneWidget,
      );
      expect(AuthService.instance.token, 'test-token');
    },
  );

  testWidgets('delete confirmation fits narrow screens with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    respond = () => http.Response('{}', 503);
    await openDialog(tester, scale: 2);
    await tester.ensureVisible(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
