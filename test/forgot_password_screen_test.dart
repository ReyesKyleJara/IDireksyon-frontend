import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/auth/forgot_password_screen.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/profile/password_security_screen.dart';

void main() {
  for (final identifier in [
    ' resident@example.com ',
    '09171234567',
    'bad@email',
  ]) {
    testWidgets(
      'login opens recovery with valid email prefill only: $identifier',
      (tester) async {
        await tester.pumpWidget(const MaterialApp(home: LoginScreen()));
        await tester.pump(const Duration(milliseconds: 600));
        await tester.enterText(find.byType(TextFormField).first, identifier);
        await tester.ensureVisible(find.text('Forgot password?'));
        await tester.tap(find.text('Forgot password?'));
        await tester.pumpAndSettle();
        expect(find.byType(ForgotPasswordScreen), findsOneWidget);
        final field = tester.widget<TextFormField>(find.byType(TextFormField));
        expect(
          field.controller!.text,
          identifier.contains('example.com') ? 'resident@example.com' : '',
        );
        expect(find.textContaining('expires after 60 minutes'), findsOneWidget);
      },
    );
  }

  testWidgets(
    'loading prevents duplicate requests and retry succeeds after failure',
    (tester) async {
      final previous = AuthService.instance;
      final pending = Completer<http.Response>();
      var requests = 0;
      AuthService.instance = AuthService(
        baseUrl: 'http://localhost:8000/api',
        client: MockClient((request) {
          requests++;
          expect(request.method, 'POST');
          expect(jsonDecode(request.body), {'email': 'resident@example.com'});
          return requests == 1
              ? pending.future
              : Future.value(
                  http.Response('{"message":"Check your inbox."}', 200),
                );
        }),
      );
      addTearDown(() {
        AuthService.instance.dispose();
        AuthService.instance = previous;
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: ' resident@example.com '),
        ),
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pump();
      expect(find.text('Sending…'), findsOneWidget);
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).enabled,
        isFalse,
      );
      tester.widget<TextField>(find.byType(TextField)).onSubmitted!('');
      await tester.pump();
      expect(requests, 1);
      pending.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(
        find.text('The server is unavailable. Please try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(requests, 2);
      expect(find.text('Check your inbox.'), findsOneWidget);
      expect(
        find.text('The server is unavailable. Please try again.'),
        findsNothing,
      );
    },
  );

  test(
    'service accepts current and legacy messages without changing the session',
    () async {
      for (final message in [
        'Check your inbox and spam folder.',
        'If an active account uses this email, a password reset link will be sent. Check your inbox and spam folder.',
      ]) {
        final auth = AuthService(
          baseUrl: 'http://localhost:8000/api',
          client: MockClient((request) async {
            expect(request.url.path, '/api/auth/forgot-password');
            expect(request.method, 'POST');
            expect(jsonDecode(request.body), {'email': 'resident@example.com'});
            return http.Response(jsonEncode({'message': message}), 200);
          }),
        )..token = 'existing-session';
        addTearDown(auth.dispose);
        expect(
          await auth.sendPasswordResetEmail(' resident@example.com '),
          message,
        );
        expect(auth.token, 'existing-session');
      }
    },
  );

  for (final payload in [
    '{}',
    '{"message":null}',
    '{"message":42}',
    '{"message":[]}',
    '{"message":" "}',
    'not-json',
  ]) {
    test(
      'service safely rejects malformed success message: $payload',
      () async {
        final auth = AuthService(
          client: MockClient((_) async => http.Response(payload, 200)),
        );
        addTearDown(auth.dispose);
        await expectLater(
          auth.sendPasswordResetEmail('resident@example.com'),
          throwsA(
            isA<AuthException>().having(
              (e) => e.message,
              'message',
              'The server returned an unexpected response.',
            ),
          ),
        );
      },
    );
  }

  for (final status in [422, 429]) {
    testWidgets('recovery shows backend error and permits retry: $status', (
      tester,
    ) async {
      final previous = AuthService.instance;
      AuthService.instance = AuthService(
        client: MockClient(
          (_) async => http.Response(
            '{"errors":{"email":["Enter a valid email address."]}}',
            status,
          ),
        ),
      );
      addTearDown(() {
        AuthService.instance.dispose();
        AuthService.instance = previous;
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: ForgotPasswordScreen(initialEmail: 'resident@example.com'),
        ),
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          status == 429
              ? 'Too many attempts. Please wait a minute and try again.'
              : 'Enter a valid email address.',
        ),
        findsOneWidget,
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull,
      );
    });
  }

  testWidgets('security opens reset with account email and sends the request', (
    tester,
  ) async {
    final previous = AuthService.instance;
    var requests = 0;
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        requests++;
        expect(request.url.path, '/api/auth/forgot-password');
        expect(jsonDecode(request.body), {'email': 'resident@example.com'});
        return http.Response(
          '{"message":"Check your inbox and spam folder."}',
          200,
        );
      }),
    )..user = {'email': 'resident@example.com'};
    addTearDown(() {
      AuthService.instance.dispose();
      AuthService.instance = previous;
    });
    await tester.pumpWidget(const MaterialApp(home: PasswordSecurityScreen()));
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(find.byType(ForgotPasswordScreen), findsOneWidget);
    expect(find.text('resident@example.com'), findsOneWidget);
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(requests, 1);
    expect(find.text('Check your inbox and spam folder.'), findsOneWidget);
  });

  testWidgets('invalid email is blocked and server failures allow retry', (
    tester,
  ) async {
    final previous = AuthService.instance;
    var requests = 0;
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        requests++;
        return http.Response('{}', 503);
      }),
    );
    addTearDown(() {
      AuthService.instance.dispose();
      AuthService.instance = previous;
    });
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(requests, 0);
    await tester.enterText(find.byType(TextFormField), 'resident@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(
      find.text('The server is unavailable. Please try again.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });
}
