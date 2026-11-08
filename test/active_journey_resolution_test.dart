import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/id_journey.dart';
import 'package:idireksyon_frontend/features/roadmap/roadmap_widgets.dart';
import 'package:idireksyon_frontend/models/roadmap_plan.dart';

import 'fixtures/roadmap_auth.dart';

const proofKey = 'government_id:56:set:23:group:52';

Map<String, dynamic> credentialJourney({
  bool empty = false,
  bool manual = false,
  int? chosen,
}) => {
  'id': 12,
  'completed_step_identities': ['document:28'],
  'plan': planData(
    [56],
    [
      planStep(28, 'Birth record', type: 'document', selected: false),
      if (chosen == null)
        {
          ...planStep(
            52,
            'Proof of Identity / Supporting Document',
            type: 'unresolved_requirement',
            selected: false,
          ),
          'resolution_key': proofKey,
          'owner_key': 'government_id:56',
          'kind': 'requirement',
          'manual_preparation': manual,
          'remaining_count': 1,
          'message': 'Choose one accepted option.',
          'suggestions': empty
              ? []
              : [
                  for (var i = 1; i <= 4; i++)
                    {
                      'type': 'document',
                      'id': 100 + i,
                      'name': 'Accepted document $i',
                      'way_id': 60,
                      'recommended': i <= 3,
                      'recommendation_reasons': ['No additional ID required'],
                      'processing_time': '$i days',
                    },
                ],
        }
      else
        planStep(
          chosen,
          'Accepted document ${chosen - 100}',
          type: 'document',
          selected: false,
        ),
      planStep(
        56,
        'PhilSys National ID',
        prerequisites: [
          if (chosen != null) missingPrerequisite(chosen, type: 'document'),
        ],
      ),
    ],
  ),
};

void main() {
  late AuthService previous;
  late List<http.Request> requests;
  bool fail = false;
  bool refreshManual = false;
  bool refreshReady = false;
  Map<String, dynamic> refreshedJourney() {
    final data = credentialJourney(
      empty: refreshManual || refreshReady,
      manual: refreshManual,
    );
    if (refreshReady) {
      final plan = data['plan'] as Map<String, dynamic>;
      ((plan['steps'] as List)[1] as Map)['resolution_ready'] = true;
    }
    return data;
  }

  setUp(() {
    previous = AuthService.instance;
    requests = [];
    fail = false;
    refreshManual = false;
    refreshReady = false;
    AuthService.instance = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' && request.url.path.endsWith('/journeys')) {
          return http.Response(
            jsonEncode({
              'data': [refreshedJourney()],
            }),
            200,
          );
        }
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/auth/journeys/12/resolution');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        final selection = body['resolution'] as Map<String, dynamic>;
        expect(selection['key'], proofKey);
        if (selection.length == 1) {
          expect(refreshReady, isTrue);
          return http.Response(
            jsonEncode({'data': credentialJourney(chosen: 101)}),
            200,
          );
        }
        expect(selection['type'], 'document');
        expect(selection['way_id'], 60);
        if (fail) {
          return http.Response(
            '{"message":"This option is no longer available."}',
            422,
          );
        }
        return http.Response(
          jsonEncode({
            'data': credentialJourney(chosen: selection['id'] as int),
          }),
          200,
        );
      }),
    )..token = 'resident';
  });
  tearDown(() {
    AuthService.instance.dispose();
    AuthService.instance = previous;
  });

  Future<IdJourney> open(
    WidgetTester tester, {
    bool empty = false,
    bool manual = false,
  }) async {
    final journey = IdJourney.fromJson(
      credentialJourney(empty: empty, manual: manual),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ActiveJourneyScreen(journeys: [journey])),
      ),
    );
    await tester.pumpAndSettle();
    return journey;
  }

  Future<void> tapVisible(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> chooseFourth(WidgetTester tester) async {
    await tapVisible(tester, find.text('See Suggested Options'));
    expect(find.text('Recommended'), findsOneWidget);
    expect(find.textContaining('No additional ID required'), findsNWidgets(3));
    expect(find.text('Accepted document 4'), findsNothing);
    await tapVisible(tester, find.text('View other accepted options'));
    final card = find
        .ancestor(
          of: find.text('Accepted document 4'),
          matching: find.byType(RoadmapCard),
        )
        .first;
    await tapVisible(
      tester,
      find.descendant(of: card, matching: find.text('Add to Journey')),
    );
    expect(find.text('Add Accepted document 4 to Journey?'), findsOneWidget);
  }

  testWidgets(
    'Active Journey shows the ranked chooser and saves the actual fourth acquisition',
    (tester) async {
      final journey = await open(tester);
      expect(
        find.textContaining('Requirement needs manual preparation'),
        findsNothing,
      );
      await chooseFourth(tester);
      await tapVisible(tester, find.text('Add to Journey'));
      expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
      expect(
        journey.confirmedPlan!.steps.any((step) => step.isUnresolved),
        isFalse,
      );
      expect(
        journey.confirmedPlan!.steps.map((step) => step.name),
        contains('Accepted document 4'),
      );
      expect(journey.completedStepIdentities, {'document:28'});
      expect(journey.completedStepIdentities, isNot(contains('document:104')));
      expect(journey.completionLabel, '33%');
      expect(
        find.text('Proof of Identity / Supporting Document'),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Active Journey refreshes a legacy empty list before presenting accepted options',
    (tester) async {
      await open(tester, empty: true);
      await chooseFourth(tester);
      expect(requests.where((r) => r.method == 'GET'), hasLength(1));
      await tapVisible(tester, find.text('Cancel'));
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
      expect(
        find.text('Proof of Identity / Supporting Document'),
        findsOneWidget,
      );
      expect(
        find.textContaining('Requirement needs manual preparation'),
        findsNothing,
      );
    },
  );

  testWidgets('a rejected active choice keeps the original plan and progress', (
    tester,
  ) async {
    final journey = await open(tester);
    fail = true;
    await chooseFourth(tester);
    await tapVisible(tester, find.text('Add to Journey'));
    expect(find.text('This option is no longer available.'), findsOneWidget);
    expect(
      journey.confirmedPlan!.steps.any((step) => step.isUnresolved),
      isTrue,
    );
    expect(journey.completedStepIdentities, {'document:28'});
  });

  testWidgets('only a verified manual fallback offers manual completion', (
    tester,
  ) async {
    final journey = await open(tester, empty: true, manual: true);
    expect(find.text('See Suggested Options'), findsNothing);
    expect(
      journey.confirmedPlan!.steps
          .firstWhere((s) => s.isUnresolved)
          .isManualPreparation,
      isTrue,
    );
    expect(
      find.textContaining('Requirement needs manual preparation'),
      findsOneWidget,
    );
  });

  test(
    'an empty legacy list is not proof that a credential is manual preparation',
    () {
      final data = credentialJourney(empty: true);
      final plan = data['plan'] as Map<String, dynamic>;
      final rows = plan['steps'] as List;
      (rows[1] as Map).remove('manual_preparation');
      final step = RoadmapPlan.fromJson(plan).steps[1];
      expect(step.isManualPreparation, isFalse);
      expect(step.isActionable, isFalse);
      expect(
        waitingOnSteps(
          RoadmapPlan.fromJson(plan).steps.last,
          RoadmapPlan.fromJson(plan).steps,
          {proofKey},
        ),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'covered saved placeholders require explicit adoption of the updated Roadmap',
    (tester) async {
      final journey = await open(tester, empty: true);
      refreshReady = true;
      await tapVisible(tester, find.text('See Suggested Options'));
      expect(find.text('Review updated Roadmap'), findsOneWidget);
      expect(requests.where((r) => r.method == 'PUT'), isEmpty);
      await tapVisible(tester, find.text('Use Updated Roadmap'));
      expect(
        journey.confirmedPlan!.steps.any((step) => step.isUnresolved),
        isFalse,
      );
      expect(requests.where((r) => r.method == 'PUT'), hasLength(1));
      expect(journey.completedStepIdentities, {'document:28'});
    },
  );
}
