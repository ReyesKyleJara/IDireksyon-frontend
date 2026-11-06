import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_view.dart';
import 'package:idireksyon_frontend/features/roadmap/build_roadmap_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/confirm_documents_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_journey_view.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';

import 'fixtures/roadmap_auth.dart';

Map<String, dynamic> choice({
  List<Map<String, dynamic>> suggestions = const [
    {
      'type': 'document',
      'id': 7,
      'name': 'Fast option',
      'way_id': 1,
      'processing_time': '3 days',
      'estimated_days': 3,
      'in_journey': true,
    },
    {'type': 'document', 'id': 8, 'name': 'Other option', 'way_id': 1},
  ],
}) => {
  ...planStep(
    9,
    'Valid IDs',
    type: 'unresolved_requirement',
    selected: false,
  ),
  'resolution_key': 'government_id:57:set:1:group:9',
  'kind': 'requirement',
  'owner_key': 'government_id:57',
  'message': 'You still need at least one accepted option.',
  'suggestions': suggestions,
};

void main() {
  late AuthService previous;
  setUp(() => previous = AuthService.instance);
  tearDown(() => AuthService.instance = previous);

  Map<String, dynamic> threeGoals({List<Map<String, dynamic>> extra = const []}) =>
      planData(
        [56, 55, 57],
        [
          planStep(56, 'PhilSys National ID'),
          planStep(55, 'Philippine Passport')
            ..['processing_time'] = '10–12 working days',
          ...extra,
          planStep(
            57,
            'Postal ID',
            prerequisites: [missingPrerequisite(56)],
          ),
        ],
      );

  void serve(Map<String, dynamic> plan) {
    AuthService.instance = AuthService(
      baseUrl: 'http://localhost:8000/api',
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({'data': plan}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    )..token = 'test';
  }

  Widget suggested() => MaterialApp(
    theme: AppTheme.lightTheme,
    home: const SuggestedRoadmapScreen(
      targetIds: ['PhilSys National ID', 'Philippine Passport', 'Postal ID'],
      targetCatalogIds: [56, 55, 57],
    ),
  );

  Widget suggested56() => MaterialApp(
    theme: AppTheme.lightTheme,
    home: const SuggestedRoadmapScreen(
      targetIds: ['PhilSys National ID'],
      targetCatalogIds: [56],
    ),
  );

  VoidCallback? confirmAction(WidgetTester tester) => tester
      .widget<ElevatedButton>(
        find.widgetWithText(ElevatedButton, 'Confirm Suggested Journey'),
      )
      .onPressed;

  testWidgets('every selected target reaches the confirmation screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    AuthService.instance = journeyAuth();
    GovernmentIdDetails record(int id, String name, [String? type]) =>
        GovernmentIdDetails.fromJson({
          'id': id,
          'name': name,
          'record_type': ?type,
          'guidance_mode': 'guided',
        });
    await tester.pumpWidget(
      MaterialApp(
        home: BuildRoadmapScreen(
          loadIds: () async => [
            record(55, 'Philippine Passport'),
            record(56, 'PhilSys National ID'),
            record(28, 'PSA Birth Certificate', 'document'),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    for (final name in [
      'Philippine Passport',
      'PSA Birth Certificate',
      'PhilSys National ID',
    ]) {
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    final confirm = tester.widget<ConfirmDocumentsScreen>(
      find.byType(ConfirmDocumentsScreen),
    );
    expect(confirm.targetCatalogIds, [55, 56]);
    expect(confirm.targetDocumentIds, [28]);
    expect(confirm.targetIds, [
      'Philippine Passport',
      'PSA Birth Certificate',
      'PhilSys National ID',
    ]);
    expect(
      find.text(
        'Your roadmap will cover: Philippine Passport, PSA Birth Certificate, PhilSys National ID',
      ),
      findsOneWidget,
    );
  });

  testWidgets('every goal is listed on its own line with its processing time', (
    tester,
  ) async {
    final plan = RoadmapPlan.fromJson(threeGoals());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SuggestedJourneyView(plan: plan)),
        ),
      ),
    );
    expect(find.text('YOUR TARGETS'), findsOneWidget);
    // Once in the goal card and once as a step.
    expect(find.text('Postal ID'), findsNWidgets(2));
    expect(find.textContaining(' + '), findsNothing);
    expect(
      find.text('Listed processing time: 10–12 working days'),
      findsOneWidget,
    );
    // A real link says so; an unrelated goal isn't presented as dependent.
    expect(find.text('Complete PhilSys National ID first.'), findsOneWidget);
    expect(find.text('Needed for Postal ID.'), findsOneWidget);
    expect(
      find.text('No required order. You can work on this anytime.'),
      findsOneWidget,
    );
  });

  group('a selected target the resident already owns', () {
    Map<String, dynamic> withOwned() => planData(
      [56, 57],
      [
        {...planStep(56, 'PhilSys National ID'), 'already_owned': true},
        planStep(57, 'Postal ID'),
      ],
    );

    testWidgets('is shown as owned and is not a numbered step', (tester) async {
      serve(withOwned());
      await tester.pumpWidget(
        const MaterialApp(
          home: SuggestedRoadmapScreen(
            targetIds: ['PhilSys National ID', 'Postal ID'],
            targetCatalogIds: [56, 57],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Already in your Inventory, so no steps needed: PhilSys National ID',
        ),
        findsOneWidget,
      );
      expect(find.byType(SuggestedJourneyStep), findsOneWidget);
      expect(find.text('1 step to complete'), findsOneWidget);
      expect(confirmAction(tester), isNotNull);
    });

    testWidgets('counts for nothing in progress and cannot be completed', (
      tester,
    ) async {
      final plan = RoadmapPlan.fromJson(withOwned());
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ActiveJourneyView(
                title: 'Goals',
                steps: plan.steps,
                onComplete: (_) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('Already in your Inventory'), findsOneWidget);
      expect(find.text('0 of 1 completed'), findsOneWidget);
      expect(find.text('Mark as Completed'), findsOneWidget);
      final journey = IdJourney.fromJson({
        'id': 1,
        'plan': withOwned(),
        'completed_step_identities': <String>[],
      });
      expect(journey.totalSteps, 1);
    });

    testWidgets('when nothing else remains, saving is not offered', (
      tester,
    ) async {
      serve(
        planData(
          [56],
          [
            {...planStep(56, 'PhilSys National ID'), 'already_owned': true},
          ],
        ),
      );
      await tester.pumpWidget(suggested56());
      await tester.pumpAndSettle();
      expect(
        find.text('You already have everything in this roadmap.'),
        findsOneWidget,
      );
      expect(confirmAction(tester), isNull);
    });
  });

  testWidgets('a choice says which goal it is for', (tester) async {
    final plan = RoadmapPlan.fromJson(threeGoals(extra: [choice()]));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(child: SuggestedJourneyView(plan: plan)),
        ),
      ),
    );
    expect(find.text('Needed for Postal ID'), findsOneWidget);
  });

  testWidgets('open choices hold back confirmation and options stay honest', (
    tester,
  ) async {
    serve(threeGoals(extra: [choice()]));
    await tester.pumpWidget(suggested());
    await tester.pumpAndSettle();
    expect(find.text('Make the 1 choice above to continue'), findsOneWidget);
    expect(confirmAction(tester), isNull);

    await tester.ensureVisible(find.text('See Suggested Options'));
    await tester.tap(find.text('See Suggested Options'));
    await tester.pumpAndSettle();
    expect(find.text('ALREADY IN THIS ROADMAP'), findsOneWidget);
    expect(find.text('Use This Option'), findsOneWidget);
    expect(find.text('Add to Journey'), findsOneWidget);
    expect(find.text('Listed processing time: 3 days'), findsOneWidget);
    expect(find.textContaining('astest'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('no choices to make leaves confirmation enabled', (tester) async {
    serve(threeGoals());
    await tester.pumpWidget(suggested());
    await tester.pumpAndSettle();
    expect(find.textContaining('to continue'), findsNothing);
    expect(confirmAction(tester), isNotNull);
  });

  testWidgets('a choice with no options cannot trap the resident', (
    tester,
  ) async {
    serve(threeGoals(extra: [choice(suggestions: const [])]));
    await tester.pumpWidget(suggested());
    await tester.pumpAndSettle();
    expect(confirmAction(tester), isNotNull);
  });

  testWidgets('unrelated goals can finish in any order, dependents must wait', (
    tester,
  ) async {
    final plan = RoadmapPlan.fromJson(threeGoals());
    final tapped = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveJourneyView(
              title: 'PhilSys National ID + Philippine Passport + Postal ID',
              steps: plan.steps,
              onComplete: (step) => tapped.add(step.identity),
            ),
          ),
        ),
      ),
    );
    expect(find.text('3 target IDs'), findsOneWidget);
    expect(find.text('Current step'), findsOneWidget);
    expect(find.text('Ready to start'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Complete PhilSys National ID first.'), findsOneWidget);
    expect(find.text('Mark as Completed'), findsNWidgets(2));

    await tester.tap(find.text('Mark as Completed').last);
    expect(tapped, ['government_id:55']);
  });

  testWidgets('a dependent opens once what it needs is complete', (
    tester,
  ) async {
    final plan = RoadmapPlan.fromJson(threeGoals());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ActiveJourneyView(
              title: 'Goals',
              steps: plan.steps,
              completedStepIdentities: const {'government_id:56'},
              onComplete: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(find.text('Upcoming'), findsNothing);
    expect(find.textContaining('first.'), findsNothing);
    expect(find.text('Mark as Completed'), findsNWidgets(2));
  });

  test('only short processing times are shown to residents', () {
    expect(displayProcessingTime('10–12 working days'), '10–12 working days');
    expect(displayProcessingTime('  Varies '), 'Varies');
    expect(displayProcessingTime('   '), isNull);
    expect(displayProcessingTime(null), isNull);
    expect(
      displayProcessingTime(
        'Digital and paper-format availability and physical-card delivery vary.',
      ),
      isNull,
    );
  });

  test('reference-only and satisfied prerequisites do not hold a step back', () {
    final plan = RoadmapPlan.fromJson(
      planData(
        [2],
        [
          planStep(1, 'Other', selected: false),
          planStep(
            2,
            'Goal',
            prerequisites: [
              {...missingPrerequisite(1), 'resolution': 'reference_only'},
              {...missingPrerequisite(1), 'status': 'satisfied'},
              {'type': 'custom', 'id': null, 'name': 'x', 'status': 'manual'},
            ],
          ),
        ],
      ),
    );
    expect(waitingOnSteps(plan.steps.last, plan.steps, const {}), isEmpty);
  });

  for (final (size, scale) in [
    (const Size(320, 640), 2.0),
    (const Size(390, 844), 1.0),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('long multi-goal screens fit $size x$scale dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        serve(
          planData(
            [1, 2, 3],
            [
              planStep(1, 'Philippine Identification System (PhilSys National ID)'),
              planStep(2, 'OWWA OFW eCard (Overseas Workers Welfare Administration eCard)'),
              planStep(3, 'Non-Professional Driver’s License (NPDL)'),
            ],
          ),
        );
        Widget wrap(Widget home) => MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home,
        );
        await tester.pumpWidget(
          wrap(
            const SuggestedRoadmapScreen(
              targetIds: ['A', 'B', 'C'],
              targetCatalogIds: [1, 2, 3],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          find.text('Confirm Suggested Journey').hitTestable(),
          findsOneWidget,
        );

        await tester.pumpWidget(
          wrap(
            Scaffold(
              body: SingleChildScrollView(
                child: ActiveJourneyView(
                  title: IdJourney(targetIds: ['A', 'B', 'C']).title,
                  steps: RoadmapPlan.fromJson(
                    planData(
                      [1, 2],
                      [
                        planStep(1, 'Philippine Identification System (PhilSys National ID)'),
                        planStep(2, 'OWWA OFW eCard (Overseas Workers Welfare Administration eCard)'),
                      ],
                    ),
                  ).steps,
                  onComplete: (_) {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
