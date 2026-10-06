import 'package:flutter/material.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/roadmap_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/build_roadmap_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/confirm_documents_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

void main() {
  for (final page in <Widget>[
    const RoadmapScreen(),
    const ActiveJourneyScreen(),
    const BuildRoadmapScreen(),
    const ConfirmDocumentsScreen(),
    const SuggestedRoadmapScreen(),
    const PsaBirthCertificateGuideScreen(),
  ]) {
    testWidgets('${page.runtimeType} fits a narrow screen with large text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(body: page),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
