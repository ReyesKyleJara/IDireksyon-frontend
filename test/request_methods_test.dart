import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/checklist_readiness_summary.dart';
import 'package:idireksyon_frontend/services/requirement_readiness.dart';

Map<String, dynamic> generalChecklist() => {
  'id': 1,
  'application_type': 'new',
  'applicant_type': 'all',
  'display_label': 'General requirements',
  'groups': [
    {
      'id': 1,
      'condition_type': 'always',
      'ways': [
        {
          'id': 1,
          'required_count': 1,
          'qualification_type': 'none',
          'items': [
            {
              'id': 1,
              'type': 'document',
              'document_id': 1,
              'name': 'General evidence',
            },
          ],
        },
      ],
    },
  ],
};

Map<String, dynamic> methodsRecord({bool methods = true}) => {
  'id': 28,
  'record_type': 'document',
  'name': 'PSA Birth Certificate',
  'requirement_sets': [generalChecklist()],
  'request_paths': [
    if (methods)
      for (final (id, label) in [
        (10, 'PSA CRS Outlet'),
        (11, 'PSA Helpline'),
        (12, 'PSA Serbilis'),
      ])
        {
          'id': id,
          'label': label,
          'is_request_method': true,
          'channel': id == 10 ? 'outlet' : 'online',
          'provider': 'Official issuer',
          'preparation': 'Bring the original record.',
          'application_guide_text': 'Complete the official request form.',
          'portal_url': 'https://example.gov.ph/request',
          'processing': '3 working days',
          'fees': [
            {
              'id': id,
              'label': '$label fee',
              'type': 'fixed',
              'amount_min': 155,
            },
          ],
          'guide': [
            {'id': id, 'title': 'Follow the saved method guide', 'blocks': []},
          ],
          'requirement_sets': [
            {...generalChecklist(), 'id': id},
          ],
          'troubleshooting': [
            {
              'title': 'Important warning',
              'body': 'Check with the receiving office.',
            },
          ],
        },
  ],
};

void main() {
  testWidgets(
    'methods expand inline with complete CMS details and preserve general requirements',
    (tester) async {
      final previous = AuthService.instance;
      var calls = 0;
      final auth = AuthService(
        client: MockClient((_) async {
          calls++;
          throw StateError('No writes or requests expected');
        }),
      );
      AuthService.instance = auth;
      addTearDown(() {
        AuthService.instance = previous;
        auth.dispose();
      });
      final record = GovernmentIdDetails.fromJson(methodsRecord());
      final before = jsonEncode(record.raw);
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
      await tester.tap(find.text('Ways to Request'));
      await tester.pumpAndSettle();
      expect(find.text('Ways to Request'), findsOneWidget);
      expect(find.byType(DropdownButtonFormField<int>), findsNothing);
      for (final name in ['PSA CRS Outlet', 'PSA Helpline', 'PSA Serbilis']) {
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(find.byType(RequestMethodScreen), findsNothing);
        expect(
          find.text('Complete the official request form.'),
          findsOneWidget,
        );
        expect(find.text('Bring the original record.'), findsOneWidget);
        expect(find.text('Follow the saved method guide'), findsOneWidget);
        expect(find.text('Open official request portal'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Processing time'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('3 working days'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Important warning'),
          180,
          scrollable: find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first,
        );
        expect(find.text('Check with the receiving office.'), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
        await tester.ensureVisible(find.text(name));
        await tester.tap(find.text(name));
        await tester.pumpAndSettle();
        expect(find.text('Complete the official request form.'), findsNothing);
      }
      expect(record.generalDetails.requirementSets.map((set) => set.id), [1]);
      expect(jsonEncode(record.raw), before);
      expect(calls, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('accordion details fit narrow large text in dark mode', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final json = methodsRecord();
    final method =
        (json['request_paths'] as List).first as Map<String, dynamic>;
    method['applicability'] =
        'For residents requesting their own birth certificate';
    method['appointment'] = 'not_required';
    method['fulfillment'] = ['delivery'];
    method['preparation'] = {
      'type': 'doc',
      'content': [
        {
          'type': 'paragraph',
          'content': [
            {'type': 'text', 'text': 'Prepare a clear copy of your valid ID.'},
          ],
        },
      ],
    };
    final record = GovernmentIdDetails.fromJson(json);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: IdDetailsScreen(
          idName: record.name,
          governmentId: record.id,
          loadDetail: (_) async => record,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Ways to Request'));
    await tester.tap(find.text('Ways to Request'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Open PSA CRS Outlet website'), findsOneWidget);
    expect(find.text('Prepare a clear copy of your valid ID.'), findsNothing);
    await tester.tap(find.text('PSA CRS Outlet'));
    await tester.pumpAndSettle();
    expect(find.text('Prepare a clear copy of your valid ID.'), findsOneWidget);
    expect(find.text('Appointment: Not required'), findsOneWidget);
    expect(find.text('How you receive it: Delivery'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('groups cards by CMS channel without raw subtitles', (
    tester,
  ) async {
    final json = methodsRecord();
    for (final method in json['request_paths'] as List) {
      method.remove('provider');
    }
    final record = GovernmentIdDetails.fromJson(json);
    await tester.pumpWidget(
      MaterialApp(
        home: IdDetailsScreen(
          idName: record.name,
          governmentId: record.id,
          loadDetail: (_) async => record,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ways to Request'));
    await tester.pumpAndSettle();
    expect(find.text('Face-to-face'), findsOneWidget);
    expect(find.text('Online requests'), findsOneWidget);
    expect(find.text('Other ways to request'), findsNothing);
    expect(find.text('outlet'), findsNothing);
    expect(find.text('online'), findsNothing);
    expect(
      find.text(
        'Tap a card for details. Use the website icon to open its portal.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('Submit your request in person at this service location.'),
      findsOneWidget,
    );
    expect(
      find.text('Submit your request online through this website.'),
      findsWidgets,
    );

    expect(
      tester.getTopLeft(find.text('Face-to-face')).dy,
      lessThan(tester.getTopLeft(find.text('PSA CRS Outlet')).dy),
    );
    expect(
      tester.getTopLeft(find.text('PSA CRS Outlet')).dy,
      lessThan(tester.getTopLeft(find.text('Online requests')).dy),
    );
    expect(
      tester.getTopLeft(find.text('Online requests')).dy,
      lessThan(tester.getTopLeft(find.text('PSA Helpline')).dy),
    );
  });

  testWidgets('Ways to Request is hidden when no methods exist', (
    tester,
  ) async {
    final record = GovernmentIdDetails.fromJson(methodsRecord(methods: false));
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
    expect(find.text('Ways to Request'), findsNothing);
  });

  test('method checklists do not affect general readiness', () {
    final inventory = RequirementReadiness.fromInventory({
      'government_ids': [],
      'documents': [
        {'id': 1, 'owned': true},
      ],
    });
    final base = GovernmentIdDetails.fromJson(methodsRecord(methods: false));
    final withMethods = GovernmentIdDetails.fromJson(methodsRecord());
    final before = summarizeChecklistReadiness(base, base, inventory);
    expect(before, isNotNull);
    expect(
      summarizeChecklistReadiness(withMethods, withMethods, inventory),
      before,
    );
  });
}
