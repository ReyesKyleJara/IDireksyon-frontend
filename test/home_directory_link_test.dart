import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/home/home_screen.dart';
import 'package:idireksyon_frontend/features/shell/resident_app_shell.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> openHome(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.lightTheme, home: const ResidentAppShell()),
    );
    await tester.pump();
  }

  int tab(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack).first).index!;

  bool pushedPage(WidgetTester tester) =>
      tester.state<NavigatorState>(find.byType(Navigator).first).canPop();

  Finder homeList() => find
      .descendant(
        of: find.byType(HomeScreen),
        matching: find.byType(Scrollable),
      )
      .first;

  Future<void> tapOnHome(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(
      find.text(text),
      200,
      scrollable: homeList(),
    );
    await tester.ensureVisible(find.text(text));
    await tester.pump();
    await tester.tap(find.text(text));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('View all on Home switches to the IDirectory tab', (
    tester,
  ) async {
    await openHome(tester);
    expect(tab(tester), 0);
    await tapOnHome(tester, 'View all');
    expect(tab(tester), 2);
    expect(pushedPage(tester), isFalse);
  });

  testWidgets('ID Directory quick action switches to the IDirectory tab', (
    tester,
  ) async {
    await openHome(tester);
    await tapOnHome(tester, 'ID\nDirectory');
    expect(tab(tester), 2);
    expect(pushedPage(tester), isFalse);
  });

  testWidgets('Home fits phone widths without overflow', (tester) async {
    addTearDown(tester.view.reset);
    for (final size in const [Size(390, 844), Size(320, 640)]) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      await openHome(tester);
      expect(find.text('Get started'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: '$size');
    }
  });
}
