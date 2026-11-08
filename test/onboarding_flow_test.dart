import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/routes/app_router.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/auth/email_signup_screen.dart';
import 'package:idireksyon_frontend/features/auth/login_screen.dart';
import 'package:idireksyon_frontend/features/loading/loading_screen.dart';
import 'package:idireksyon_frontend/features/onboarding/onboarding_hero.dart';
import 'package:idireksyon_frontend/features/onboarding/onboarding_screen.dart';

const intro = 'Hi! I’m Diro, your ID guide.';
const prepared = 'Let’s get you prepared.';
const welcome = 'Welcome to IDireksyon!';

// Hidden copies of every slide reserve the sheet height; match visible text.
Finder shown(String text) => find.text(text).hitTestable();

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

  void phone(WidgetTester tester, [Size size = const Size(390, 844)]) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> settle(WidgetTester tester) async {
    // Diro loops forever, so pump a bounded time instead of pumpAndSettle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> openApp(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const OnboardingScreen(),
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await settle(tester);
  }

  testWidgets('Next walks the slides into Welcome; back steps return', (
    tester,
  ) async {
    phone(tester);
    await openApp(tester);
    expect(shown(intro), findsOneWidget);
    expect(find.text('Log In'), findsNothing);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(shown(prepared), findsOneWidget);
    expect(
      shown(
        'Keep your requirements in one place. I’ll guide you through what to prepare, step by step.',
      ),
      findsOneWidget,
    );
    final dotsTop = tester.getTopLeft(find.bySemanticsLabel('Page 2 of 3')).dy;

    // System back moves to the previous slide instead of leaving the app.
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(shown(intro), findsOneWidget);

    await tester.tap(find.text('Next'));
    await settle(tester);
    await tester.tap(find.text('Next'));
    await settle(tester);
    expect(shown(welcome), findsOneWidget);
    // Page dots stay in the same spot on every slide.
    expect(tester.getTopLeft(find.bySemanticsLabel('Page 3 of 3')).dy, dotsTop);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Skip'), findsNothing);
    expect(find.text('Log In').hitTestable(), findsOneWidget);
    expect(find.text('Sign Up').hitTestable(), findsOneWidget);
    expect(find.byType(LoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Swipes change slides; there is no Skip button', (tester) async {
    phone(tester);
    await openApp(tester);
    expect(find.text('Skip'), findsNothing);
    await tester.fling(shown(intro), const Offset(-300, 0), 1200);
    await settle(tester);
    expect(shown(prepared), findsOneWidget);
    await tester.fling(shown(prepared), const Offset(300, 0), 1200);
    await settle(tester);
    expect(shown(intro), findsOneWidget);

    for (var i = 0; i < 2; i++) {
      await tester.fling(
        find.byType(OnboardingScreen),
        const Offset(-300, 0),
        1200,
      );
      await settle(tester);
    }
    expect(shown(welcome), findsOneWidget);
    await tester.tap(find.text('Log In'));
    await settle(tester);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Welcome route shows only the final step and opens Sign Up', (
    tester,
  ) async {
    phone(tester);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        initialRoute: '/welcome',
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
    await settle(tester);
    expect(shown(welcome), findsOneWidget);
    expect(find.text('Skip'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Page')), findsNothing);
    await tester.fling(shown(welcome), const Offset(300, 0), 1200);
    await settle(tester);
    expect(shown(welcome), findsOneWidget);
    await tester.tap(find.text('Sign Up'));
    await settle(tester);
    expect(find.byType(EmailSignupScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Welcome stays usable on a small screen with large text', (
    tester,
  ) async {
    phone(tester, const Size(320, 640));
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const OnboardingScreen(initialPage: 2),
      ),
    );
    await settle(tester);
    for (final label in ['Log In', 'Sign Up']) {
      await tester.ensureVisible(find.text(label));
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Diro floats gently and holds still under reduced motion', (
    tester,
  ) async {
    phone(tester);
    Future<void> show(bool reduced) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: const Size(390, 844),
              disableAnimations: reduced,
            ),
            child: const OnboardingScreen(),
          ),
        ),
      );
      await tester.pump();
    }

    double lift() => tester
        .widget<Transform>(find.byKey(OnboardingHero.diroKey))
        .transform
        .storage[13];

    await show(false);
    final start = lift();
    await tester.pump(const Duration(milliseconds: 900));
    expect(lift(), isNot(start));

    await show(true);
    final still = lift();
    await tester.pump(const Duration(seconds: 2));
    expect(lift(), still);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
