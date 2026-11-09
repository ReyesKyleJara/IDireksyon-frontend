import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/profile/privacy_policy_screen.dart';
import 'package:idireksyon_frontend/features/profile/terms_of_service_screen.dart';

void main() {
  // Tall enough that the ListView builds every section.
  Future<void> show(
    WidgetTester tester,
    Widget screen, {
    double width = 390,
    double textScale = 1,
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = Size(width, 9000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: screen,
      ),
    );
    await tester.pump();
  }

  bool shows(String text) =>
      find.textContaining(text, findRichText: true).evaluate().isNotEmpty;

  testWidgets('Privacy Policy keeps the required disclosures', (tester) async {
    await show(tester, const PrivacyPolicyScreen());
    for (final text in [
      'not an official government app',
      'GeoBytes',
      'birth date',
      'Roadmap progress',
      'saved roadmap progress',
      'inventory and roadmap progress',
      'does not ask for their ID numbers',
      'Office Finder',
      'Your location is not saved',
      'not uploaded',
      'Railway',
      'Google Maps Platform',
      'Resend',
      'does not sell your personal information',
      'advertising or analytics SDKs',
      'expires after 30 days',
      'permanently delete your account',
      'www.idireksyon.online/account-deletion',
      'www.idireksyon.online/privacy',
    ]) {
      expect(shows(text), isTrue, reason: text);
    }
    expect(shows('journey'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Terms cover guidance, limits, and account use', (tester) async {
    await show(tester, const TermsOfServiceScreen());
    for (final text in [
      'Informational guidance only',
      'Not an official government service',
      'Requirements, fees, office locations',
      'Check with official sources',
      'Your responsibilities',
      'Acceptable use',
      'does not guarantee eligibility',
      'Deleting or ending an account',
      'Password & security',
    ]) {
      expect(shows(text), isTrue, reason: text);
    }
    expect(tester.takeException(), isNull);
  });

  for (final (name, screen) in [
    ('Privacy Policy', const PrivacyPolicyScreen()),
    ('Terms of Service', const TermsOfServiceScreen()),
  ]) {
    testWidgets('$name fits a small screen with large text', (tester) async {
      await show(tester, screen, width: 320, textScale: 2);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$name renders in dark mode', (tester) async {
      await show(tester, screen, theme: AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Modal version keeps the Close button', (tester) async {
    await show(tester, const TermsOfServiceScreen(isModal: true));
    expect(find.byTooltip('Close'), findsOneWidget);
    await show(tester, const PrivacyPolicyScreen(isModal: true));
    expect(find.byTooltip('Close'), findsOneWidget);
  });
}
