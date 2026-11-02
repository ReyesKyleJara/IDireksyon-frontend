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
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        return respond();
      }),
    )
      ..token = 'test-token'
      ..user = {'id': 7, 'name': 'Resident'};
  });

  Future<void> openDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.generateRoute,
        home: const PasswordSecurityScreen(),
      ),
    );
    await tester.ensureVisible(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account?'), findsOneWidget);
  }

  testWidgets('cancel and empty password never contact the server', (tester) async {
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

  testWidgets('wrong password shows the server error and keeps the session', (tester) async {
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

  testWidgets('successful deletion clears the session and returns to login', (tester) async {
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

  testWidgets('connection failure keeps the resident signed in', (tester) async {
    await tester.pumpWidget(const SizedBox());
    AuthService.instance = AuthService(
      client: MockClient((_) async => throw http.ClientException('offline')),
    )
      ..token = 'test-token'
      ..user = {'id': 7};
    await openDialog(tester);

    await tester.enterText(find.byType(TextFormField).last, 'secret-password');
    await tester.tap(find.text('Delete permanently'));
    await tester.pumpAndSettle();

    expect(
      find.text('Cannot connect to the server. Check your connection and try again.'),
      findsOneWidget,
    );
    expect(AuthService.instance.token, 'test-token');
    expect(find.byType(LoginScreen), findsNothing);
  });
}
