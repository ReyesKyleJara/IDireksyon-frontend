import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/applicant_context.dart';
import 'package:idireksyon_frontend/models/government_id_applicability.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/applicant_flow_controller.dart';
import 'package:idireksyon_frontend/features/ids/applicant_context_card.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

Map<String, dynamic> profile(int id, String label) => {
  'id': id,
  'label': label,
  'application_type': 'new',
};
Map<String, dynamic> requirements(int id, String label) => {
  'id': id,
  'display_label': label,
  'groups': [
    {
      'id': id,
      'title': '$label evidence',
      'condition_type': 'always',
      'ways': [
        {
          'required_count': 1,
          'qualification_type': 'none',
          'items': [
            {'id': id, 'type': 'custom', 'name': '$label document'},
          ],
        },
      ],
    },
  ],
};
Map<String, dynamic> step(int id, String title, {int? owner}) => {
  'id': id,
  'title': title,
  'applicability_profile_id': owner,
  'blocks': [],
};
GovernmentIdApplicability evaluation({
  int id = 34,
  String status = 'matched',
  List<String> missing = const [],
  List<Map<String, dynamic>> profiles = const [],
  List<Map<String, dynamic>> matched = const [],
  List<Map<String, dynamic>> manual = const [],
  Map<String, dynamic>? selected,
  List<Map<String, dynamic>> activeRequirements = const [],
  List<Map<String, dynamic>> pendingRequirements = const [],
  List<Map<String, dynamic>> steps = const [],
  List<Map<String, dynamic>> pendingSteps = const [],
}) => GovernmentIdApplicability.fromJson({
  'government_id': {'id': id},
  'applicability': {
    'status': status,
    'missing_context': missing,
    'available_profiles': profiles,
    'matched_profiles': matched,
    'manual_profiles': manual,
    'selected_profile': selected,
  },
  'requirements': {
    'profiles': activeRequirements,
    'pending_profiles': pendingRequirements,
  },
  'application_guide': {'steps': steps, 'pending_steps': pendingSteps},
});
Future<void> openFlow(WidgetTester tester, EvaluateApplicant evaluate) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IdDetailsScreen(
        idName: 'Passport',
        governmentId: 34,
        loadDetail: (_) async =>
            GovernmentIdDetails.fromJson({'id': 34, 'name': 'Passport'}),
        evaluateApplicant: evaluate,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tab(WidgetTester tester, String label) async {
  final target = find.widgetWithText(Tab, label);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'serializes known facts only and keeps ownership and manual selection',
    () {
      expect(ApplicantContext().toJson(), isEmpty);
      final context = ApplicantContext(age: 9, ownedDocumentIds: [7]);
      expect(context.selectProfile(987).toJson(), {
        'age': 9,
        'owned_document_ids': [7],
        'selected_profile_id': 987,
      });
      expect(() => context.ownedDocumentIds.add(8), throwsUnsupportedError);
    },
  );
  test('parses all server states and treats unknown states conservatively', () {
    for (final value in [
      'matched',
      'multiple_matches',
      'insufficient_context',
      'manual_confirmation_required',
      'manual_selected',
      'no_match',
    ]) {
      expect(
        evaluation(status: value).status,
        isNot(ApplicabilityStatus.unknown),
      );
    }
    expect(evaluation(status: 'future').status, ApplicabilityStatus.unknown);
  });
  test(
    'latest request wins, old responses cannot replace the shared context',
    () async {
      final calls = <Completer<GovernmentIdApplicability>>[];
      final flow = ApplicantFlowController(34, (_, _) {
        final call = Completer<GovernmentIdApplicability>();
        calls.add(call);
        return call.future;
      });
      final first = flow.refresh();
      final second = flow.choose(22);
      calls[1].complete(evaluation(selected: profile(22, 'Latest')));
      await second;
      calls[0].complete(evaluation(selected: profile(11, 'Old')));
      await first;
      expect(flow.result!.selectedProfile!.id, 22);
      expect(flow.context.selectedProfileId, 22);
      flow.dispose();
    },
  );
  test(
    'validation and network failures preserve previous content as stale',
    () async {
      var fail = false;
      final flow = ApplicantFlowController(34, (_, _) async {
        if (fail) {
          throw const ApplicabilityRequestException({
            'age': ['Invalid age'],
          });
        }
        return evaluation(selected: profile(1, 'Kept'));
      });
      await flow.refresh();
      fail = true;
      await flow.choose(2);
      expect(flow.result!.selectedProfile!.label, 'Kept');
      expect(flow.stale, isTrue);
      expect(flow.error, contains('check your application details'));
      flow.dispose();
      final offline = ApplicantFlowController(
        34,
        (_, _) async => throw Exception('Offline'),
      );
      await offline.refresh();
      expect(offline.result, isNull);
      expect(offline.error, isNotNull);
      offline.dispose();
    },
  );
  test('closing the screen ignores requests still in flight', () async {
    final pending = Completer<GovernmentIdApplicability>();
    final flow = ApplicantFlowController(34, (_, _) => pending.future);
    final future = flow.refresh();
    flow.dispose();
    pending.complete(evaluation());
    await future;
    expect(flow.result, isNull);
  });
  testWidgets(
    'age alone is requested and draft persists across tabs without another request',
    (tester) async {
      var calls = 0;
      await openFlow(tester, (_, _) async {
        calls++;
        return evaluation(
          status: 'insufficient_context',
          missing: ['age'],
          steps: [step(1, 'General appointment')],
        );
      });
      expect(find.widgetWithText(TextFormField, 'Your age'), findsOneWidget);
      expect(find.text('What type of application is this?'), findsNothing);
      await tester.enterText(find.byType(TextFormField), '23');
      await tab(tester, 'Guide');
      expect(find.text('General appointment'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Your age'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(find.byType(TextFormField)).initialValue,
        '23',
      );
      await tester.enterText(find.byType(TextFormField), '24');
      await tab(tester, 'Requirements');
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '24',
      );
      expect(calls, 1);
    },
  );
  testWidgets(
    'application type alone is requested using backend profile options',
    (tester) async {
      ApplicantContext? sent;
      await openFlow(tester, (_, context) async {
        sent = context;
        return evaluation(
          status: 'insufficient_context',
          missing: ['application_type'],
          profiles: [profile(1, 'Label unrelated to age')],
        );
      });
      expect(find.text('Your age'), findsNothing);
      expect(find.text('What type of application is this?'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('New application').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Update application'));
      await tester.pumpAndSettle();
      expect(sent!.toJson(), {'application_type': 'new'});
    },
  );
  testWidgets(
    'backend-selected content is shared and review does not refetch or invent questions',
    (tester) async {
      var calls = 0;
      final option = profile(91, 'Agency option');
      await openFlow(tester, (_, context) async {
        calls++;
        final label = context.age == null ? 'Initial' : 'Changed';
        return evaluation(
          profiles: [option],
          selected: option,
          activeRequirements: [requirements(91, label)],
          steps: [step(5, '$label guide', owner: 91)],
        );
      });
      expect(find.text('Initial evidence'), findsOneWidget);
      await tab(tester, 'Guide');
      expect(find.text('Initial guide'), findsOneWidget);
      expect(calls, 1);
      // Review exposes only previously requested/known facts, not a new questionnaire.
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(find.text('Your age'), findsNothing);
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      await tab(tester, 'Requirements');
      expect(calls, 1);
    },
  );
  testWidgets(
    'missing facts submitted from Guide update Requirements and Guide together',
    (tester) async {
      var calls = 0;
      final option = profile(17, 'Chosen by backend');
      await openFlow(tester, (_, context) async {
        calls++;
        return context.age == null
            ? evaluation(
                status: 'insufficient_context',
                missing: ['age'],
                steps: [step(1, 'Common guide')],
              )
            : evaluation(
                selected: option,
                activeRequirements: [
                  requirements(17, context.age == 17 ? 'Resolved' : 'Revised'),
                ],
                steps: [
                  step(1, 'Common guide'),
                  step(
                    2,
                    context.age == 17 ? 'Resolved guide' : 'Revised guide',
                    owner: 17,
                  ),
                ],
              );
      });
      await tab(tester, 'Guide');
      await tester.enterText(find.byType(TextFormField), '17');
      await tester.tap(find.text('Update application'));
      await tester.pumpAndSettle();
      expect(find.text('Resolved guide'), findsOneWidget);
      expect(find.text('Your age'), findsNothing);
      await tab(tester, 'Requirements');
      expect(find.text('Resolved evidence'), findsOneWidget);
      expect(calls, 2);
      await tester.drag(find.byType(NestedScrollView), const Offset(0, 500));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '18');
      await tester.tap(find.text('Update application'));
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.text('Revised evidence'), findsOneWidget);
      await tab(tester, 'Guide');
      expect(calls, 3);
      expect(find.text('Revised guide'), findsOneWidget);
    },
  );
  for (final state in ['multiple_matches', 'manual_confirmation_required']) {
    testWidgets(
      '$state waits for explicit choice and preserves pending content',
      (tester) async {
        ApplicantContext? sent;
        var calls = 0;
        final option = profile(987, 'Students');
        await openFlow(tester, (_, context) async {
          sent = context;
          calls++;
          if (context.selectedProfileId != null) {
            return evaluation(
              status: 'manual_selected',
              selected: option,
              activeRequirements: [requirements(987, 'Manual')],
              steps: [
                step(1, 'Shared step'),
                step(2, 'Manual guide', owner: 987),
              ],
            );
          }
          return evaluation(
            status: state,
            profiles: [option],
            matched: [option],
            manual: [option],
            pendingRequirements: [requirements(987, 'Pending')],
            steps: [step(1, 'Shared step')],
            pendingSteps: [step(2, 'Possible guide', owner: 987)],
          );
        });
        expect(sent!.selectedProfileId, isNull);
        expect(find.text('Additional requirements may apply'), findsOneWidget);
        expect(
          find.text('Choose the option that best matches your situation'),
          findsOneWidget,
        );
        expect(find.textContaining('987'), findsNothing);
        expect(find.textContaining('scenario'), findsNothing);
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Students').last);
        await tester.pumpAndSettle();
        expect(sent!.selectedProfileId, 987);
        expect(find.text('Manual evidence'), findsOneWidget);
        await tab(tester, 'Guide');
        expect(find.text('Manual guide'), findsOneWidget);
        expect(calls, 2);
      },
    );
  }
  testWidgets(
    'network error retains content with warning and retry uses current facts',
    (tester) async {
      var fail = false;
      await openFlow(tester, (_, context) async {
        if (fail) throw Exception('Offline');
        return evaluation(
          status: 'manual_confirmation_required',
          profiles: [profile(1, 'Option')],
          selected: null,
          activeRequirements: [requirements(1, 'Previous')],
        );
      });
      fail = true;
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Option').last);
      await tester.pumpAndSettle();
      expect(find.text('Previous evidence'), findsOneWidget);
      expect(find.textContaining('has not been verified'), findsOneWidget);
      expect(find.text('Retry application'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'resolved manual selection hides the prompt until Change is opened',
    (tester) async {
      final option = profile(7, 'Manual option');
      await openFlow(
        tester,
        (_, context) async => evaluation(
          status: context.selectedProfileId == null
              ? 'manual_confirmation_required'
              : 'manual_selected',
          profiles: [option],
          manual: [option],
          selected: context.selectedProfileId == null ? null : option,
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual option').last);
      await tester.pumpAndSettle();
      expect(
        find.text('Choose the option that best matches your situation'),
        findsNothing,
      );
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      expect(find.text('Manual option'), findsOneWidget);
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose the option that best matches your situation'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'pending context summary shows entered facts without inferring age groups',
    (tester) async {
      final flow = ApplicantFlowController(
        34,
        (_, _) async => evaluation(status: 'manual_confirmation_required'),
      );
      flow.context = ApplicantContext(age: 20, applicationType: 'replacement');
      await flow.refresh();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ApplicantContextCard(flow: flow)),
        ),
      );
      expect(find.text('Age 20 · Replacement'), findsOneWidget);
      expect(find.textContaining('Adult'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      flow.dispose();
    },
  );
  testWidgets(
    'manual selection can return to backend questions without inventing facts',
    (tester) async {
      await openFlow(tester, (_, context) async {
        if (context.selectedProfileId != null) {
          return evaluation(
            status: 'manual_selected',
            selected: profile(7, 'Manual option'),
            profiles: [profile(7, 'Manual option')],
          );
        }
        return evaluation(
          status: 'manual_confirmation_required',
          profiles: [profile(7, 'Manual option')],
        );
      });
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Manual option').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Use application details'));
      await tester.pumpAndSettle();
      expect(
        find.text('Choose the option that best matches your situation'),
        findsOneWidget,
      );
      expect(find.text('Your age'), findsNothing);
    },
  );
  testWidgets(
    'validation failure and initial offline state show retry without guessing content',
    (tester) async {
      await openFlow(
        tester,
        (_, _) async => throw const ApplicabilityRequestException({
          'selected_profile_id': ['Invalid selection'],
        }),
      );
      expect(
        find.text('Please check your application details and try again.'),
        findsOneWidget,
      );
      expect(find.text('Retry application'), findsOneWidget);
      expect(find.textContaining('selected_profile_id'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('context card wraps on narrow screens at large text scale', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: IdDetailsScreen(
          idName: 'ID',
          governmentId: 34,
          loadDetail: (_) async =>
              GovernmentIdDetails.fromJson({'id': 34, 'name': 'ID'}),
          evaluateApplicant: (_, _) async => evaluation(
            status: 'insufficient_context',
            missing: ['age', 'application_type'],
            profiles: [
              profile(1, 'A long application option defined by the agency'),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'new Government ID starts a fresh flow and no-match never selects an option',
    (tester) async {
      var calls = 0;
      for (final id in [34, 35]) {
        await tester.pumpWidget(
          MaterialApp(
            home: IdDetailsScreen(
              idName: 'ID',
              governmentId: id,
              loadDetail: (id) async =>
                  GovernmentIdDetails.fromJson({'id': id, 'name': 'ID'}),
              evaluateApplicant: (id, context) async {
                calls++;
                expect(context.toJson(), isEmpty);
                return evaluation(id: id, status: 'no_match');
              },
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('No matching application option'),
          findsOneWidget,
        );
      }
      expect(calls, 2);
    },
  );
}
