import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/loading/loading_screen.dart';
import 'package:idireksyon_frontend/features/auth/welcome_screen.dart';
import 'package:idireksyon_frontend/features/onboarding/onboarding_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('Google Sans')
          ..addFont(rootBundle.load('assets/fonts/GoogleSans-Regular.woff2'))
          ..addFont(rootBundle.load('assets/fonts/GoogleSans-Bold.woff2')))
        .load();
    await (FontLoader(
      'Bricolage Grotesque',
    )..addFont(rootBundle.load('assets/fonts/BricolageGrotesque.ttf'))).load();
  });
  testWidgets('Next opens requirements; Get Started opens welcome', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Simplify Your Government\nID Journey'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Track Your Requirements in\nOne Place'), findsOneWidget);
    expect(
      find.text('No more confusion. Just a clear step-by-step roadmap'),
      findsOneWidget,
    );
    expect(find.byType(LoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);

    // Users can return to the first page before finishing onboarding.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.byType(LoadingScreen), findsNothing);
    expect(find.text('Welcome!'), findsOneWidget);
    expect(find.text('Log In').hitTestable(), findsOneWidget);
    expect(find.text('Sign Up').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Requirements remains usable on a small screen with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const OnboardingScreen.requirements(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Get Started'));
    expect(tester.takeException(), isNull);
    expect(find.text('Get Started').hitTestable(), findsOneWidget);
  });
}
