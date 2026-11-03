import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

GovernmentIdDetails fixture({bool informational = false}) =>
    GovernmentIdDetails.fromJson({
      ...jsonDecode(
        File('test/fixtures/catalog/special-case.json').readAsStringSync(),
      ) as Map<String, dynamic>,
      'guidance_mode': informational ? 'informational_only' : 'guided',
    });

void main() {
  testWidgets(
    'assistance opens separately below request choices and survives channel switching and back',
    (tester) async {
      final record = fixture();
      final original = jsonEncode(record.raw['special_cases']);
      await tester.pumpWidget(
        MaterialApp(
          home: IdDetailsScreen(
            idName: record.name,
            governmentId: record.id,
            recordType: 'document',
            loadDetail: (_) async => record,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guide'));
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      expect(find.text('How do I request it?'), findsOneWidget);
      expect(find.text("Don't have a Birth Certificate yet?"), findsOneWidget);
      expect(find.text('Normal copy step'), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'In Person'));
      await tester.pumpAndSettle();
      expect(find.text('Normal copy step'), findsOneWidget);
      await tester.ensureVisible(find.text('Learn about delayed registration'));
      await tester.tap(find.text('Learn about delayed registration'));
      await tester.pumpAndSettle();
      expect(find.byType(SpecialCaseGuideScreen), findsOneWidget);
      expect(find.text('Before You Begin'), findsOneWidget);
      expect(find.text('Normal copy step'), findsNothing);
      expect(find.text('Fixture case-only evidence'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Official Sources'),
        500,
        scrollable: find
            .descendant(
              of: find
                  .descendant(
                    of: find.byType(SpecialCaseGuideScreen),
                    matching: find.byType(ListView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Where to Apply'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Back to ${record.name}'),
        300,
        scrollable: find
            .descendant(
              of: find
                  .descendant(
                    of: find.byType(SpecialCaseGuideScreen),
                    matching: find.byType(ListView),
                  )
                  .first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.tap(find.text('Back to ${record.name}'));
      await tester.pumpAndSettle();
      expect(find.byType(SpecialCaseGuideScreen), findsNothing);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Online'));
      await tester.pumpAndSettle();
      expect(find.text('Normal copy step'), findsNothing);
      expect(find.text('Learn about delayed registration'), findsOneWidget);
      expect(jsonEncode(record.raw['special_cases']), original);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'dedicated requirements never fetch inventory or calculate completion',
    (tester) async {
      final original = AuthService.instance;
      var requests = 0;
      AuthService.instance = AuthService(
        client: MockClient((request) async {
          requests++;
          return http.Response('{}', 500);
        }),
      )..token = 'fixture';
      addTearDown(() => AuthService.instance = original);
      final record = fixture();
      await tester.pumpWidget(
        MaterialApp(
          home: SpecialCaseGuideScreen(
            parent: record,
            guide: record.raw['special_cases'][0],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(requests, 0);
      expect(find.textContaining('inventory readiness'), findsNothing);
      expect(find.textContaining('% complete'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty optional sections and unsafe links are omitted on a narrow large-text screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = fixture();
      final guide = Map<String, dynamic>.from(record.raw['special_cases'][0])
        ..addAll({
          'requirement_sets': [],
          'fees': [],
          'offices': [],
          'steps': [],
          'before_you_begin': '',
          'introduction': '',
          'notes': '',
          'sources': [
            {'title': 'Unsafe fixture URL', 'url': 'javascript:alert(1)'},
          ],
        });
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SpecialCaseGuideScreen(parent: record, guide: guide),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Requirements'), findsNothing);
      expect(find.text('Fees'), findsNothing);
      expect(find.text('Where to Apply'), findsNothing);
      expect(find.text('javascript:alert(1)'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'complete long guide and multiple assistance cards fit narrow large text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = fixture();
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: SpecialCaseGuideScreen(
            parent: record,
            guide: record.raw['special_cases'][0],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Official Sources'),
        500,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(tester.takeException(), isNull);
      final two = GovernmentIdDetails.fromJson({
        ...record.raw,
        'special_cases': [
          record.raw['special_cases'][0],
          {
            ...record.raw['special_cases'][0] as Map,
            'id': 'second',
            'action_label': 'Open second fixture',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          home: IdDetailsScreen(
            idName: two.name,
            governmentId: two.id,
            recordType: 'document',
            loadDetail: (_) async => two,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Guide'));
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Open second fixture'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView).last,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Open second fixture'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Informational Only retains assistance data without offering acquisition guides',
    (tester) async {
      final record = fixture(informational: true);
      await tester.pumpWidget(
        MaterialApp(
          home: IdDetailsScreen(
            idName: record.name,
            governmentId: record.id,
            recordType: 'document',
            loadDetail: (_) async => record,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Informational Record'), findsOneWidget);
      expect(find.text('Learn about delayed registration'), findsNothing);
      expect(record.raw['special_cases'], isNotEmpty);
    },
  );
}
