import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/features/auth/welcome_screen.dart';
import 'package:idireksyon_frontend/features/auth/email_signup_screen.dart';
import 'package:idireksyon_frontend/features/auth/phone_signup_screen.dart';
import 'package:idireksyon_frontend/features/profile/profile_setup_screen.dart';

void main() {
  setUp(() {
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        return http.Response(
          '{"user":{"id":1,"name":"Juan"},"token":"test-token"}',
          201,
        );
      }),
    );
  });
  testWidgets(
    'Sign Up opens email page and method tabs switch separate pages',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: const WelcomeScreen(),
          onGenerateRoute: AppRouter.generateRoute,
        ),
      );
      await tester.tap(find.text('Sign Up'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailSignupScreen), findsOneWidget);
      await tester.ensureVisible(
        find.widgetWithText(TextButton, 'Phone Number'),
      );
      await tester.tap(find.widgetWithText(TextButton, 'Phone Number'));
      await tester.pumpAndSettle();
      expect(find.byType(PhoneSignupScreen), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).at(1)).keyboardType,
        TextInputType.phone,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Email'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailSignupScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final phone in [false, true]) {
    testWidgets(
      '${phone ? "Phone" : "Email"} validation and agreement on small screen',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            routes: {
              '/home': (_) => const Scaffold(body: Text('Resident home')),
            },
            onGenerateRoute: AppRouter.generateRoute,
            home: phone ? const PhoneSignupScreen() : const EmailSignupScreen(),
          ),
        );
        final submit = find.widgetWithText(FilledButton, 'Sign Up');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Enter your name'), findsOneWidget);
        expect(
          find.text('Please accept the Terms and Privacy Policy.'),
          findsOneWidget,
        );
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'Juan');
        await tester.enterText(
          fields.at(1),
          phone ? '09091234567' : 'juan@example.com',
        );
        await tester.enterText(fields.at(2), 'password123');
        await tester.enterText(fields.at(3), 'wrong-password');
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.text('Passwords do not match'), findsOneWidget);
        await tester.enterText(fields.at(3), 'password123');
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.ensureVisible(submit);
        await tester.tap(submit);
        await tester.pumpAndSettle();
        expect(find.byType(ProfileSetupScreen), findsOneWidget);
        expect(find.text('Next'), findsOneWidget);
        expect(find.text('Resident home'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
