import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Directory fits narrow screen: dark=$dark, scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: const Scaffold(body: IdsScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (dark) {
          final cards = tester
              .widgetList<Material>(
                find.descendant(
                  of: find.byType(IdsScreen),
                  matching: find.byType(Material),
                ),
              )
              .where((material) => material.shape is RoundedRectangleBorder);
          expect(cards.length, greaterThanOrEqualTo(3));
          for (final card in cards) {
            expect(card.color!.computeLuminance(), lessThan(0.2));
          }
        }
      });
    }
  }
}

