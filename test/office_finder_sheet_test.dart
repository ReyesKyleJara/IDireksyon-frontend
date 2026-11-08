import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';

import 'fixtures/offices.dart';

void main() {
  for (final size in const [
    Size(280, 653),
    Size(320, 568),
    Size(360, 740),
    Size(430, 932),
    Size(650, 900),
    Size(844, 390),
  ]) {
    testWidgets('expanded office list fits $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: OfficeFinderScreen(
            services: FixtureOfficeServices(),
            mapBuilder: (_) => const SizedBox.expand(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      tester
          .widget<DraggableScrollableSheet>(
            find.byType(DraggableScrollableSheet),
          )
          .controller!
          .jumpTo(.96);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
