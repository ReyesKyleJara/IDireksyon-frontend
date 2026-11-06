import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_view.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';

import 'fixtures/roadmap_auth.dart';

RoadmapPlan samplePlan() => RoadmapPlan.fromJson(
  planData(
    [4],
    [
      planStep(
        1,
        'Supporting document',
        type: 'document',
        selected: false,
        satisfied: 1,
        total: 1,
      ),
      planStep(2, 'Supporting ID', selected: false),
      planStep(3, 'Another document', type: 'document', selected: false),
      planStep(4, 'Target ID'),
    ],
  ),
);

void main() {
  for (final completed in [0, 1, 2, 4]) {
    testWidgets(
      '$completed explicit completions determine progress independently of readiness',
      (tester) async {
        final plan = samplePlan();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ActiveJourneyView(
                  title: 'Target ID',
                  steps: plan.steps,
                  completedStepIdentities: plan.steps
                      .take(completed)
                      .map((step) => step.identity)
                      .toSet(),
                ),
              ),
            ),
          ),
        );
        expect(find.text('${completed * 25}%'), findsOneWidget);
        expect(find.text('$completed of 4 completed'), findsOneWidget);
        expect(find.text('Completed'), findsNWidgets(completed));
        expect(
          find.text('Current step'),
          completed == 4 ? findsNothing : findsOneWidget,
        );
        expect(
          find.text('Upcoming'),
          findsNWidgets(completed == 4 ? 0 : 3 - completed),
        );
        for (final step in plan.steps) {
          expect(
            find.text(step.name),
            step.id == 4 ? findsNWidgets(3) : findsOneWidget,
          );
        }
        expect(find.textContaining('Readiness'), findsNothing);
        expect(find.textContaining('verified'), findsNothing);
      },
    );
  }

  testWidgets(
    'confirmed snapshot keeps all steps without recalculating or updating Inventory',
    (tester) async {
      final original = AuthService.instance;
      final calls = <http.Request>[];
      AuthService.instance = AuthService(
        client: MockClient((request) async {
          calls.add(request);
          return http.Response('{}', 500);
        }),
      );
      addTearDown(() {
        AuthService.instance.dispose();
        AuthService.instance = original;
      });
      final journey = IdJourney(
        targetIds: ['Target ID'],
        targetCatalogIds: [4],
        confirmedPlan: samplePlan(),
        progress: 1,
        ownedItems: ['Supporting document'],
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ActiveJourneyScreen(journeys: [journey])),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('0 of 4 completed'), findsOneWidget);
      expect(find.text('Current step'), findsOneWidget);
      expect(find.text('Upcoming'), findsNWidgets(3));
      expect(find.text('Manage Inventory'), findsNothing);
      expect(find.text('Your next steps'), findsNothing);
      expect(journey.completedStepIdentities, isEmpty);
      expect(journey.minimized, isFalse);
      expect(calls, isEmpty);
    },
  );

  for (final type in ['document', 'government_id']) {
    testWidgets('$type step opens the existing typed catalog guide', (
      tester,
    ) async {
      await http.runWithClient(
        () async {
          final plan = samplePlan();
          final step = plan.steps.firstWhere((step) => step.type == type);
          await tester.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: SingleChildScrollView(
                  child: ActiveJourneyView(
                    title: 'Target ID',
                    steps: plan.steps,
                  ),
                ),
              ),
            ),
          );
          await tester.ensureVisible(find.text(step.name));
          await tester.tap(find.text(step.name));
          await tester.pumpAndSettle();
          final page = tester.widget<IdDetailsScreen>(
            find.byType(IdDetailsScreen),
          );
          expect(page.recordType, type);
          expect(page.governmentId, step.id);
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode({
              'data': {'id': 1, 'name': 'Guide'},
            }),
            200,
          ),
        ),
      );
    });
  }

  testWidgets('unresolved future steps remain visible', (tester) async {
    final step = RoadmapPlanStep.fromJson({
      ...planStep(9, 'Choose supporting proof', type: 'unresolved_requirement'),
      'resolution_key': 'requirement:9',
      'kind': 'requirement',
      'message': 'Choose supporting proof.',
      'suggestions': [],
    });
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveJourneyView(
              title: 'Target ID',
              steps: [samplePlan().steps.first, step, samplePlan().steps.last],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Choose supporting proof'), findsOneWidget);
    expect(find.text('Upcoming'), findsNWidgets(2));
  });
}
