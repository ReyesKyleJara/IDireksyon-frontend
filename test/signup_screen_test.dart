import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      if (request.url.path.endsWith('/email-verification/send')) return http.Response('{"challenge_id":"test-challenge","resend_after":42}',200);
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

  group('password fields', () {
    const mismatch = 'Passwords do not match';
    final fields = find.byType(TextFormField);
    Finder eye(int index) => find.byTooltip('Show password').at(index);
    TextField input(WidgetTester tester, int field) => tester.widget<TextField>(
      find.descendant(of: fields.at(field), matching: find.byType(TextField)),
    );

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const MaterialApp(home: EmailSignupScreen()));
      await settleSignup(tester);
    }

    testWidgets('both can be edited in any order, keeping their own text', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.enterText(fields.at(2), 'Different123!');
      await tester.enterText(fields.at(1), 'Password123!x');
      expect(input(tester, 1).controller!.text, 'Password123!x');
      expect(input(tester, 2).controller!.text, 'Different123!');
      await tester.enterText(fields.at(2), 'Different123!y');
      expect(input(tester, 1).controller!.text, 'Password123!x');
      expect(input(tester, 2).controller!.text, 'Different123!y');
      await tester.enterText(fields.at(0), 'juan@example.com');
      await settleSignup(tester);
      expect(input(tester, 1).controller!.text, 'Password123!x');
      expect(input(tester, 2).controller!.text, 'Different123!y');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('the mismatch message follows edits to either field', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.pump();
      expect(find.text(mismatch), findsNothing);
      await tester.enterText(fields.at(2), 'Different123!');
      await tester.pump();
      expect(find.text(mismatch), findsOneWidget);
      await tester.enterText(fields.at(1), 'Different123!');
      await tester.pump();
      expect(find.text(mismatch), findsNothing);
      await tester.enterText(fields.at(2), 'Different123');
      await tester.pump();
      expect(find.text(mismatch), findsOneWidget);
      await tester.enterText(fields.at(2), 'Different123!');
      await tester.pump();
      expect(find.text(mismatch), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Tab and Shift+Tab go straight between the two fields', (
      tester,
    ) async {
      await open(tester);
      bool focused(int field) => tester
          .widget<EditableText>(
            find.descendant(
              of: fields.at(field),
              matching: find.byType(EditableText),
            ),
          )
          .focusNode
          .hasFocus;
      await tester.tap(fields.at(2));
      await tester.pump();
      expect(focused(2), isTrue);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      expect(focused(1), isTrue, reason: 'Shift+Tab reaches Password');
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focused(2), isTrue, reason: 'Tab reaches Confirm Password');
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Password stays editable after Confirm Password has text', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.enterText(fields.at(2), 'Password123!');
      await tester.pump();
      expect(input(tester, 1).readOnly, isFalse);
      expect(input(tester, 1).enabled, isNot(false));

      // Back to Password from the keyboard, then type without touching it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pump();
      tester.testTextInput.enterText('Changed123!');
      await tester.pump();
      expect(input(tester, 1).controller!.text, 'Changed123!');
      expect(input(tester, 2).controller!.text, 'Password123!');
      expect(find.text(mismatch), findsOneWidget);

      // Tapping back into Password works as well, and fixing it clears the error.
      await tester.tap(fields.at(2));
      await tester.pump();
      await tester.tap(fields.at(1));
      await tester.pump();
      tester.testTextInput.enterText('Password123!');
      await tester.pump();
      expect(input(tester, 1).controller!.text, 'Password123!');
      expect(find.text(mismatch), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('show/hide changes only its own field and keeps the text', (
      tester,
    ) async {
      await open(tester);
      await tester.enterText(fields.at(1), 'Password123!');
      await tester.enterText(fields.at(2), 'Different123!');
      await tester.tap(eye(0));
      await settleSignup(tester);
      expect(input(tester, 1).obscureText, isFalse);
      expect(input(tester, 2).obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await settleSignup(tester);
      expect(input(tester, 2).obscureText, isFalse);
      expect(input(tester, 1).controller!.text, 'Password123!');
      expect(input(tester, 2).controller!.text, 'Different123!');
      await tester.pumpWidget(const SizedBox.shrink());
    });
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
        expect(jsonDecode(requests.single.body), allOf(
          containsPair('password', 'Password123!'),
          containsPair('password_confirmation', 'Password123!'),
        ));
      } else {
        expect(find.byType(EmailVerificationScreen),findsOneWidget);
        expect(AuthService.instance.token,isNull);
        expect(requests.single.url.path, '/api/auth/email-verification/send');
        expect(find.text('Resend code in 42s'), findsOneWidget);
        await tester.pageBack();
        await settleSignup(tester);
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await settleSignup(tester);
        expect(requests.length, 1);
        expect(find.textContaining('A code was already requested.'), findsOneWidget);

      }
      expect(tester.takeException(),isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
