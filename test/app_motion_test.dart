import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/widgets/app_motion.dart';

void main() {
  for (final reduced in [false, true]) {
    testWidgets('press feedback respects reduced motion: $reduced', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: Scaffold(
              body: Center(
                child: MotionInkWell(
                  onTap: () => taps++,
                  child: const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('Action'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Action')),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale,
        reduced ? 1 : .985,
      );
      await gesture.cancel();
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
      await tester.tap(find.text('Action'));
      await tester.pumpAndSettle();
      expect(taps, 1);
    });
  }

  testWidgets(
    'tab switching preserves form state and disables hidden tickers',
    (tester) async {
      final selected = ValueNotifier(0);
      addTearDown(selected.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ValueListenableBuilder<int>(
              valueListenable: selected,
              builder: (_, index, _) => IndexedStack(
                index: index,
                children: [
                  MotionTab(active: index == 0, child: const TextField()),
                  MotionTab(
                    active: index == 1,
                    child: const Text('Second tab'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Keep this');
      selected.value = 1;
      await tester.pumpAndSettle();
      final field = tester.element(find.byType(TextField, skipOffstage: false));
      expect(TickerMode.valuesOf(field).enabled, isFalse);
      selected.value = 0;
      await tester.pumpAndSettle();
      expect(find.text('Keep this'), findsOneWidget);
    },
  );
}
