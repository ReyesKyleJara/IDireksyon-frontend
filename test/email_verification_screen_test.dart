import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/auth/email_verification_screen.dart';

void main() {
  testWidgets('email account is created only after code verification', (
    tester,
  ) async {
    final original = AuthService.instance;
    final paths = <String>[];
    final auth = AuthService(
      client: MockClient((request) async {
        paths.add(request.url.path);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('email-verification/verify')) {
          expect(body, {'challenge_id': 'challenge', 'code': '123456'});
          return http.Response('{"email_verification_token":"proof"}', 200);
        }
        expect(body['email_verification_token'], 'proof');
        expect(body['email'], 'test@example.com');
        return http.Response('{"token":"session","user":{"id":1}}', 201);
      }),
    );
    AuthService.instance = auth;
    addTearDown(() {
      AuthService.instance = original;
      auth.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        routes: {
          '/profile/setup': (_) => const Scaffold(body: Text('Profile setup')),
        },
        home: EmailVerificationScreen(
          email: 'test@example.com',
          challengeId: 'challenge',
          onVerified: (proof) => auth.register(
            emailVerificationToken: proof,
            contact: 'test@example.com',
            usePhone: false,
            password: 'password123',
            confirmation: 'password123',
            accepted: true,
          ),
        ),
      ),
    );
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Resend code in 60s'),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Verify and create account'));
    await tester.pump();
    expect(
      find.text('Enter the six-digit code from your email.'),
      findsOneWidget,
    );
    expect(paths, isEmpty);
    expect(auth.token, isNull);
    await tester.enterText(find.byType(TextField), '123456');
    await tester.tap(find.text('Verify and create account'));
    await tester.pumpAndSettle();
    expect(paths, [
      '/api/auth/email-verification/verify',
      '/api/auth/register',
    ]);
    expect(find.text('Profile setup'), findsOneWidget);
    expect(auth.token, 'session');
  });

  testWidgets('invalid codes keep the user on verification with no account', (
    tester,
  ) async {
    final original = AuthService.instance;
    final auth = AuthService(
      client: MockClient(
        (_) async => http.Response(
          '{"errors":{"code":["The code is incorrect or expired."]}}',
          422,
        ),
      ),
    );
    AuthService.instance = auth;
    addTearDown(() {
      AuthService.instance = original;
      auth.dispose();
    });
    await tester.pumpWidget(
      MaterialApp(
        home: EmailVerificationScreen(
          email: 'test@example.com',
          challengeId: 'challenge',
          onVerified: (_) async => fail('Invalid codes cannot create accounts'),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), '000000');
    await tester.tap(find.text('Verify and create account'));
    await tester.pumpAndSettle();
    expect(find.text('The code is incorrect or expired.'), findsOneWidget);
    expect(auth.token, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'registration retry retains proof after a temporary server error',
    (tester) async {
      final original = AuthService.instance;
      var verifications = 0;
      var registrations = 0;
      final auth = AuthService(
        client: MockClient((_) async {
          verifications++;
          return http.Response('{"email_verification_token":"proof"}', 200);
        }),
      );
      AuthService.instance = auth;
      addTearDown(() {
        AuthService.instance = original;
        auth.dispose();
      });
      await tester.pumpWidget(
        MaterialApp(
          routes: {
            '/profile/setup': (_) =>
                const Scaffold(body: Text('Profile setup')),
          },
          home: EmailVerificationScreen(
            email: 'test@example.com',
            challengeId: 'challenge',
            onVerified: (proof) async {
              expect(proof, 'proof');
              registrations++;
              if (registrations == 1) {
                throw const AuthException('Please try again.');
              }
            },
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), '123456');
      await tester.tap(find.text('Verify and create account'));
      await tester.pumpAndSettle();
      expect(find.text('Please try again.'), findsOneWidget);
      await tester.tap(find.text('Verify and create account'));
      await tester.pumpAndSettle();
      expect(verifications, 1);
      expect(registrations, 2);
      expect(find.text('Profile setup'), findsOneWidget);
    },
  );
}
