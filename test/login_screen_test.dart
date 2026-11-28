import 'dart:async';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/features/auth/welcome_screen.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';

import 'package:idireksyon_frontend/features/auth/signup_form.dart';

Widget _noMotion(BuildContext context, Widget? child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(disableAnimations: true),
  child: child!,
);

void main() {
  testWidgets('Welcome opens login, validates fields, and toggles password', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: const WelcomeScreen(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await tester.tap(find.text('Log In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Enter your password'), findsNWidgets(2));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.first, 'resident@example.com');
    await tester.enterText(fields.last, 'example-password');
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isFalse,
    );
    await tester.tap(find.byTooltip('Hide password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).last).obscureText,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('wrong credentials allow editing and retrying', (tester) async {
    final previous = AuthService.instance;
    addTearDown(() => AuthService.instance = previous);
    var attempts = 0;
    AuthService.instance = AuthService(
      client: MockClient((_) async {
        attempts++;
        return http.Response(
          '{"errors":{"identifier":["The provided credentials are incorrect."]}}',
          422,
        );
      }),
    );

    await tester.pumpWidget(
      const MaterialApp(builder: _noMotion, home: LoginScreen()),
    );
    final fields = find.byType(TextFormField);
    final submit = find.widgetWithText(FilledButton, 'Log In');
    await tester.enterText(fields.first, 'resident@example.com');
    await tester.enterText(fields.last, 'wrong password');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(
      find.text('Incorrect email/mobile number or password.'),
      findsOneWidget,
    );

    await tester.enterText(fields.last, 'another password');
    await tester.pumpAndSettle();
    expect(
      find.text('Incorrect email/mobile number or password.'),
      findsNothing,
    );
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(attempts, 2);
  });

  testWidgets(
    'registration keeps the submitted contact method until it finishes',
    (tester) async {
      final previous = AuthService.instance;
      addTearDown(() => AuthService.instance = previous);
      final pending = Completer<http.Response>();
      AuthService.instance = AuthService(
        client: MockClient((_) => pending.future),
      );

      await tester.pumpWidget(
        const MaterialApp(builder: _noMotion, home: SignupForm(usePhone: true)),
      );
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), '09171234567');
      await tester.enterText(fields.at(1), 'ValidPass123!');
      await tester.enterText(fields.at(2), 'ValidPass123!');
      final agreement = find.byType(Checkbox);
      await tester.ensureVisible(agreement);
      await tester.tap(agreement);
      final submit = find.widgetWithText(FilledButton, 'Create Account');
      await tester.ensureVisible(submit);
      await tester.tap(submit);
      await tester.pump();

      final email = find.text('Email');
      await tester.ensureVisible(email);
      await tester.tap(email);
      await tester.pump();
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        '09171234567',
      );

      pending.complete(
        http.Response(
          '{"errors":{"phone":["The phone has already been taken."]}}',
          422,
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.textContaining('This phone number can’t be used'),
        findsOneWidget,
      );
      await tester.tap(email);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        isEmpty,
      );
    },
  );

  testWidgets('Login scrolls with large text and keyboard space', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: const TextScaler.linear(2),
            viewInsets: const EdgeInsets.only(bottom: 240),
          ),
          child: child!,
        ),
        home: const LoginScreen(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log In'));
    expect(
      find.widgetWithText(FilledButton, 'Log In').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
