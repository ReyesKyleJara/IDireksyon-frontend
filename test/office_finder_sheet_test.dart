import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/office_finder/office_finder_screen.dart';

import 'fixtures/offices.dart';

void main() {
  testWidgets('back, search and location share one row at the page margin', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
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
    await tester.pumpAndSettle();
    final arrow = find.byIcon(Icons.arrow_back_rounded);
    final field = find.byType(TextField);
    expect(tester.getTopLeft(find.byTooltip('Back')).dx, closeTo(12, 2));
    expect(tester.getCenter(arrow).dy, tester.getCenter(field).dy);
    expect(
      tester.getTopRight(find.byTooltip('Use my current location')).dx,
      closeTo(378, 2),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

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
