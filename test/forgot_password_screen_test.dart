import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/auth/forgot_password_screen.dart';
import 'package:idireksyon_frontend/features/profile/password_security_screen.dart';

void main() {
  testWidgets('security opens reset with account email and sends the request', (tester) async {
    final previous = AuthService.instance;
    var requests = 0;
    AuthService.instance = AuthService(client: MockClient((request) async {
      requests++;
      expect(request.url.path, '/api/auth/forgot-password');
      expect(jsonDecode(request.body), {'email': 'resident@example.com'});
      return http.Response('{"message":"Check your inbox and spam folder."}', 200);
    }))..user = {'email': 'resident@example.com'};
    addTearDown(() { AuthService.instance.dispose(); AuthService.instance = previous; });
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

  testWidgets('invalid email is blocked and server failures allow retry', (tester) async {
    final previous = AuthService.instance;
    var requests = 0;
    AuthService.instance = AuthService(client: MockClient((request) async {
      requests++;
      return http.Response('{}', 503);
    }));
    addTearDown(() { AuthService.instance.dispose(); AuthService.instance = previous; });
    await tester.pumpWidget(const MaterialApp(home: ForgotPasswordScreen()));
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(requests, 0);
    await tester.enterText(find.byType(TextFormField), 'resident@example.com');
    await tester.tap(find.text('Send reset link'));
    await tester.pumpAndSettle();
    expect(find.text('The server is unavailable. Please try again.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNotNull);
  });
}
