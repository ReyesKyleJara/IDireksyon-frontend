import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/features/auth/welcome_screen.dart';
import 'package:idireksyon_frontend/features/auth/email_signup_screen.dart';
import 'package:idireksyon_frontend/features/auth/phone_signup_screen.dart';
import 'package:idireksyon_frontend/features/auth/email_verification_screen.dart';

Future<void> settleSignup(WidgetTester tester) async {
  // The mascot intentionally loops; a bounded pump tests navigation without waiting forever.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  late AuthService previous;
  final requests = <http.Request>[];
  setUp(() {
    previous = AuthService.instance;
    requests.clear();
    AuthService.instance = AuthService(client: MockClient((request) async {
      requests.add(request);
      if (request.url.path.endsWith('/email-verification/send')) return http.Response('{"challenge_id":"test-challenge"}',200);
      return http.Response('{"user":{"id":1},"token":"test-token"}',201);
    }));
  });
  tearDown(() { AuthService.instance.dispose(); AuthService.instance = previous; });

  testWidgets('Sign Up opens the account form and method tabs change contact validation', (tester) async {
    await tester.pumpWidget(MaterialApp(home: const WelcomeScreen(), onGenerateRoute: AppRouter.generateRoute));
    await tester.tap(find.text('Sign Up'));
    await settleSignup(tester);
    expect(find.byType(EmailSignupScreen), findsOneWidget);
    await tester.ensureVisible(find.text('Phone Number').first);
    await tester.tap(find.text('Phone Number').first);
    await settleSignup(tester);
    expect(tester.widget<TextField>(find.byType(TextField).first).keyboardType, TextInputType.phone);
    await tester.tap(find.text('Email').first);
    await settleSignup(tester);
    expect(tester.widget<TextField>(find.byType(TextField).first).keyboardType, TextInputType.emailAddress);
    expect(requests, isEmpty);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final phone in [false,true]) {
    testWidgets('${phone ? 'Phone' : 'Email'} validation agreement and current registration flow on small screen', (tester) async {
      tester.view.physicalSize = const Size(320,640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(routes: {'/profile/setup': (_) => const Scaffold(body: Text('Profile setup'))},
        home: phone ? const PhoneSignupScreen() : const EmailSignupScreen()));
      final submit = find.widgetWithText(FilledButton,'Create Account');
      await tester.ensureVisible(submit); await tester.tap(submit); await settleSignup(tester);
      expect(find.text('Please accept the Terms and Privacy Policy.'), findsOneWidget);
      expect(requests,isEmpty);
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0),phone ? '09091234567' : 'juan@example.com');
      await tester.enterText(fields.at(1),'Password123!');
      await tester.enterText(fields.at(2),'Different123!');
      await tester.ensureVisible(submit); await tester.tap(submit); await settleSignup(tester);
      expect(find.text('Passwords do not match'),findsOneWidget);
      await tester.enterText(fields.at(2),'Password123!');
      await tester.ensureVisible(find.byType(Checkbox)); await tester.tap(find.byType(Checkbox));
      await tester.ensureVisible(submit); await tester.tap(submit); await settleSignup(tester);
      if (phone) {
        expect(find.text('Profile setup'),findsOneWidget);
        expect(AuthService.instance.token,'test-token');
        expect(requests.single.url.path, '/api/auth/register');
      } else {
        expect(find.byType(EmailVerificationScreen),findsOneWidget);
        expect(AuthService.instance.token,isNull);
        expect(requests.single.url.path, '/api/auth/email-verification/send');
      }
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
