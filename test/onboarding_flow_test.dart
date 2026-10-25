import 'package:flutter/material.dart';
import 'package:idireksyon_frontend/features/onboarding/onboarding_speech_bubble.dart';
import 'package:idireksyon_frontend/features/onboarding/onboarding_mascot_scene.dart';
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Hi! I’m Diro, your ID guide.'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Let’s get you prepared.'), findsOneWidget);
    expect(
      find.text(
        'Keep your requirements in one place. I’ll guide you through what to prepare, step by step.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LoadingScreen), findsNothing);
    expect(tester.takeException(), isNull);

    // Users can return to the first page before finishing onboarding.
    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Next'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.ensureVisible(find.text('Get Started'));
    expect(tester.takeException(), isNull);
    expect(find.text('Get Started').hitTestable(), findsOneWidget);
  });
  testWidgets('Mascot loops gently and respects reduced motion', (
    tester,
  ) async {
    Future<void> showScene(bool reduced) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const OnboardingMascotScene(
              isRequirements: false,
              height: 260,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    double verticalOffset() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(OnboardingMascotScene),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[13];
    await showScene(false);
    final initial = verticalOffset();
    await tester.pump(const Duration(milliseconds: 750));
    expect(verticalOffset(), isNot(initial));
    await showScene(true);
    final still = verticalOffset();
    await tester.pump(const Duration(seconds: 2));
    expect(verticalOffset(), still);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets('Speech bubble floats and respects reduced motion', (
    tester,
  ) async {
    Future<void> showScene(bool reduced) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: const OnboardingSpeechBubble(child: Text("Hello!")),
          ),
        ),
      );
      await tester.pump();
    }

    double verticalOffset() => tester
        .widget<Transform>(
          find
              .descendant(
                of: find.byType(OnboardingSpeechBubble),
                matching: find.byType(Transform),
              )
              .first,
        )
        .transform
        .storage[13];
    await showScene(false);
    final initial = verticalOffset();
    await tester.pump(const Duration(milliseconds: 750));
    expect(verticalOffset(), isNot(initial));
    await showScene(true);
    final still = verticalOffset();
    await tester.pump(const Duration(seconds: 2));
    expect(verticalOffset(), still);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
