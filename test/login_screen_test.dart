import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/features/auth/welcome_screen.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';

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
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log In'));
    await tester.tap(find.widgetWithText(FilledButton, 'Log In'));
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Log In'));
    expect(
      find.widgetWithText(FilledButton, 'Log In').hitTestable(),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
