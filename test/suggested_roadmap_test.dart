import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/active_journey_screen.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_journey_view.dart';
import 'package:idireksyon_frontend/features/roadmap/suggested_roadmap_screen.dart';

import 'fixtures/roadmap_auth.dart';

import 'package:idireksyon_frontend/models/roadmap_plan.dart';

void main() {
  setUpAll(() async {
    final font = FontLoader('Google Sans')
      ..addFont(rootBundle.load('assets/fonts/GoogleSans-Regular.woff2'));
    await font.load();
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  late AuthService previous;
  late AuthService auth;
  late List<http.Request> requests;

  setUp(() {
    previous = AuthService.instance;
    requests = [];
  });
  tearDown(() {
    AuthService.instance = previous;
    auth.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    bool owned = false,
    bool blocked = false,
    double scale = 1,
    bool dark = false,
    bool additionalDisplayStep = false,
  }) async {
    final steps = [
      if (!owned)
        planStep(
          28,
          'PSA Birth Certificate',
          type: 'document',
          selected: false,
          blocked: blocked,
        ),
      if (additionalDisplayStep)
        planStep(
          99,
          'Another returned document',
          type: 'document',
          selected: false,
        ),
      planStep(
        55,
        'Philippine Passport',
        blocked: blocked,
        satisfied: owned ? 1 : 0,
        total: 1,
      ),
    ];
    auth = AuthService(
      client: MockClient((request) async {
        requests.add(request);
        if (request.url.path.contains('/requirement-preparation/')) {
          final parts = request.url.pathSegments;
          return http.Response(
            jsonEncode({
              'data': {
                'record_type': parts[parts.length - 2],
                'record_id': int.parse(parts.last),
                'items': [],
              },
            }),
            200,
          );
        }
        expectSync(request.url.path, '/api/auth/roadmap-plan');
        expectSync(request.method, 'POST');
        expectSync(jsonDecode(request.body), {
          'target_government_id_ids': [55],
        });
        return http.Response(
          jsonEncode({
            'data': planData([55], steps),
          }),
          200,
        );
      }),
    )..token = 'resident';
    AuthService.instance = auth;
    await tester.pumpWidget(
      MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: const SuggestedRoadmapScreen(
          targetIds: ['Philippine Passport'],
          targetCatalogIds: [55],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder step(String type, int id) =>
      find.byKey(ValueKey('suggested-step-$type-$id'));

  void noTechnicalText(WidgetTester tester) {
    final text = tester
        .widgetList<Text>(find.byType(Text))
        .map((widget) => widget.data ?? '')
        .join(' ');
    expect(
      RegExp(
        r'prerequisite|verified|selected target|missing — must come first|blocked|%',
        caseSensitive: false,
      ).hasMatch(text),
      isFalse,
    );
    expect(find.text('Preview Guide'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  }

  testWidgets(
    'Document target appears in the summary and remains the final goal',
    (tester) async {
      auth = journeyAuth();
      final plan = RoadmapPlan.fromJson({
        ...planData([], [
          planStep(28, 'PSA Birth Certificate', type: 'document'),
        ]),
        'target_document_ids': [28],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: SuggestedJourneyView(plan: plan)),
        ),
      );
      expect(
        tester.widget<RoadmapGoalCard>(find.byType(RoadmapGoalCard)).title,
        'PSA Birth Certificate',
      );
      expect(
        tester
            .widget<SuggestedJourneyStep>(find.byType(SuggestedJourneyStep))
            .isGoal,
        isTrue,
      );
      noTechnicalText(tester);
    },
  );

  testWidgets(
    'missing Birth Certificate stays first and Passport is the final goal',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await show(tester);
      expect(find.text('Suggested Roadmap'), findsOneWidget);
      expect(
        find.text('Here’s the recommended sequence for your Passport journey.'),
        findsOneWidget,
      );
      expect(find.text('2 steps to complete'), findsOneWidget);
      expect(
        tester.getTopLeft(step('document', 28)).dy,
        lessThan(tester.getTopLeft(step('government_id', 55)).dy),
      );
      expect(
        find.text(
          'Get this document first before continuing with your Passport application.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Continue here once your required documents are ready.'),
        findsOneWidget,
      );
      final view = tester.widget<SuggestedJourneyView>(
        find.byType(SuggestedJourneyView),
      );
      expect(view.plan.steps.map((row) => row.id), [28, 55]);
      expect(requests, hasLength(1));
      noTechnicalText(tester);
    },
  );

  testWidgets(
    'owned Birth Certificate stays absent and Passport is the next step',
    (tester) async {
      await show(tester, owned: true);
      expect(find.text('PSA Birth Certificate'), findsNothing);
      expect(step('document', 28), findsNothing);
      expect(step('government_id', 55), findsOneWidget);
      expect(find.text('1 step to complete'), findsOneWidget);
      expect(find.byType(SuggestedJourneyStep), findsOneWidget);
      expect(find.text('View Guide'), findsOneWidget);
      noTechnicalText(tester);
    },
  );

  testWidgets(
    'additional server steps fit the same timeline without local sequencing',
    (tester) async {
      await show(tester, additionalDisplayStep: true);
      expect(find.text('3 steps to complete'), findsOneWidget);
      final view = tester.widget<SuggestedJourneyView>(
        find.byType(SuggestedJourneyView),
      );
      expect(view.plan.steps.map((row) => row.id), [28, 99, 55]);
      expect(find.byType(SuggestedJourneyStep), findsNWidgets(3));
    },
  );

  testWidgets(
    'setup cards stay above a consecutive actionable timeline before and after resolution',
    (tester) async {
      auth = journeyAuth();
      final callbacks = <String>[];
      Map<String, dynamic> setup(int id) => {
        ...planStep(
          id,
          'Choose request path $id',
          type: 'unresolved_requirement',
          selected: false,
        ),
        'kind': 'path',
        'resolution_key': 'document:$id:path',
        'message': 'Select your request path.',
        'suggestions': <Map<String, dynamic>>[],
      };
      final requirement = {
        ...planStep(
          12,
          'Valid ID / Supporting Document',
          type: 'unresolved_requirement',
          selected: false,
        ),
        'kind': 'requirement',
        'resolution_key': 'government_id:55:set:22:group:12',
        'message': 'You still need at least one accepted option.',
        'suggestions': <Map<String, dynamic>>[],
      };
      final rows = [
        setup(28),
        planStep(
          28,
          'PSA Birth Certificate',
          type: 'document',
          selected: false,
        ),
        setup(56),
        requirement,
        planStep(55, 'Philippine Passport'),
        setup(99),
      ];

      Future<void> render(List<Map<String, dynamic>> rows) async {
        final plan = RoadmapPlan.fromJson(planData([55], rows));
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SuggestedJourneyView(
                  plan: plan,
                  onResolve: (step) => callbacks.add(step.identity),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          plan.steps.map((step) => step.name),
          rows.map((row) => row['name']),
        );
        expect(find.text('3 steps to complete'), findsOneWidget);
        for (final id in [28, 56, 99]) {
          final card = find.byKey(ValueKey('document:$id:path'));
          expect(tester.widget<JourneyResolutionCard>(card).number, isNull);
          expect(
            tester.getTopLeft(card).dy,
            lessThan(tester.getTopLeft(find.text('Your next steps')).dy),
          );
          for (final number in ['1', '2', '3']) {
            expect(
              find.descendant(of: card, matching: find.text(number)),
              findsNothing,
            );
          }
        }
        for (final number in ['1', '2', '3']) {
          expect(find.text(number), findsOneWidget);
        }
        expect(find.text('4'), findsNothing);
        expect(
          tester.widget<SuggestedJourneyStep>(step('document', 28)).number,
          1,
        );
        final goal = tester.widget<SuggestedJourneyStep>(
          step('government_id', 55),
        );
        expect(goal.number, 3);
        expect(goal.isLast, isTrue);
        expect(goal.earlierSteps, 2);
      }

      await render(rows);
      final pending = find.byKey(
        ValueKey(requirement['resolution_key'] as String),
      );
      expect(tester.widget<JourneyResolutionCard>(pending).number, 2);
      expect(
        find.descendant(of: pending, matching: find.text('2')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(step('document', 28)).dy,
        lessThan(tester.getTopLeft(pending).dy),
      );
      expect(
        tester.getTopLeft(pending).dy,
        lessThan(tester.getTopLeft(step('government_id', 55)).dy),
      );
      final options = find.descendant(
        of: pending,
        matching: find.text('See Suggested Options'),
      );
      await tester.ensureVisible(options);
      await tester.tap(options);
      expect(callbacks, [requirement['resolution_key']]);

      await render([
        for (final row in rows)
          if (identical(row, requirement))
            planStep(56, 'PhilSys National ID', selected: false)
          else
            row,
      ]);
      expect(find.text('Valid ID / Supporting Document'), findsNothing);
      expect(
        tester.widget<SuggestedJourneyStep>(step('government_id', 56)).number,
        2,
      );
      expect(
        find.descendant(
          of: step('government_id', 56),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('fallback summary counts its displayed target step', (
    tester,
  ) async {
    auth = journeyAuth();
    await tester.pumpWidget(const MaterialApp(home: SuggestedRoadmapScreen()));
    expect(find.text('1 step to complete'), findsOneWidget);
    expect(
      tester
          .widget<SuggestedJourneyStep>(find.byType(SuggestedJourneyStep))
          .number,
      1,
    );
  });

  testWidgets('steps needing attention remain visible and prevent starting', (
    tester,
  ) async {
    await show(tester, blocked: true);
    expect(step('document', 28), findsOneWidget);
    expect(
      find.text(
        'Please check the requirements with the issuing office before starting this roadmap.',
      ),
      findsOneWidget,
    );
    final action = tester.widget<ElevatedButton>(
      find.widgetWithText(ElevatedButton, 'Confirm Suggested Journey'),
    );
    expect(action.onPressed, isNull);
    noTechnicalText(tester);
  });

  testWidgets('View Guide opens the exact returned document record', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await show(tester);
        final guide = find.descendant(
          of: step('document', 28),
          matching: find.text('View Guide'),
        );
        await tester.ensureVisible(guide);
        await tester.pumpAndSettle();
        await tester.tap(guide);
        await tester.pumpAndSettle();
        final detail = tester.widget<IdDetailsScreen>(
          find.byType(IdDetailsScreen),
        );
        expect(detail.governmentId, 28);
        expect(detail.recordType, 'document');
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        expectSync(request.url.path, '/api/documents/28');
        return http.Response(
          '{"data":{"id":28,"record_type":"document","name":"PSA Birth Certificate"}}',
          200,
        );
      }),
    );
  });

  testWidgets(
    'Confirm Suggested Journey keeps the existing journey-loading action',
    (tester) async {
      await show(tester, owned: true);
      await tester.ensureVisible(find.text('Confirm Suggested Journey'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Confirm Suggested Journey'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      final loading = tester.widget<JourneyLoadingScreen>(
        find.byType(JourneyLoadingScreen),
      );
      expect(loading.journey!.targetCatalogIds, [55]);
      expect(loading.journey!.targetIds, ['Philippine Passport']);
      expect(requests.where((request) => request.method == 'PUT'), isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final size in [const Size(320, 640), const Size(844, 390)]) {
    for (final dark in [false, true]) {
      testWidgets('journey fits $size at large text dark=$dark', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await show(tester, scale: 2, dark: dark);
        await tester.scrollUntilVisible(
          find.text('Confirm Suggested Journey').hitTestable(),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Confirm Suggested Journey').hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        noTechnicalText(tester);
      });
    }
  }
}
