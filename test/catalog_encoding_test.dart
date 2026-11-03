import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/api_service.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

Map<String, dynamic> encodedDocument({
  String name = 'PSA Birth Certificate — fixture',
  bool informational = false,
  List<String> hidden = const [],
}) => {
  'id': 1,
  'record_type': 'document',
  'name': name,
  'guidance_mode': informational ? 'informational_only' : 'guided',
  'description': 'Saved CMS description',
  'research_metadata': {
    'status': 'draft',
    'hidden_sections': hidden,
    'sources': [
      {
        'title': 'Official fixture source',
        'url': 'https://example.gov.ph/source',
        'checked_on': '2026-10-29',
      },
    ],
  },
  'resident_notice': 'Research is not yet reviewed.',
  'offices': [
    {
      'id': 1,
      'name': 'Saved registry counter',
      'address': 'Verified fixture address',
      'schedules': [],
    },
  ],
  'request_paths': [
    {
      'id': 10,
      'label': 'Outlet copy',
      'channel': 'outlet',
      'appointment': 'required',
      'fulfillment': ['pickup'],
      'processing': '20 minutes after complete request',
      'fees': [
        {'id': 1, 'label': 'Outlet fee', 'type': 'fixed', 'amount_min': 100},
      ],
      'offices': [
        {
          'id': 1,
          'name': 'Saved registry counter',
          'address': 'Verified fixture address',
          'schedules': [],
        },
      ],
      'requirement_sets': [],
      'guide': [
        {
          'id': 1,
          'title': 'Present the request at the saved counter',
          'blocks': [
            {
              'type': 'instructions',
              'content': {
                'items': [
                  {
                    'body': {
                      'type': 'doc',
                      'content': [
                        {
                          'type': 'paragraph',
                          'content': [
                            {
                              'type': 'text',
                              'text': 'Saved formatted instruction',
                              'marks': [
                                {'type': 'bold'},
                              ],
                            },
                          ],
                        },
                      ],
                    },
                  },
                ],
              },
            },
          ],
        },
      ],
      'troubleshooting': [
        {
          'title': 'No record found',
          'body': 'Ask the issuer to verify the record.',
        },
      ],
    },
    {
      'id': 11,
      'label': 'Online retrieval',
      'channel': 'online',
      'appointment': 'not_required',
      'fulfillment': ['download'],
      'portal_url': 'https://example.gov.ph/portal',
      'processing': 'Available after account verification',
      'fees': [],
      'offices': [],
      'requirement_sets': [],
      'guide': [],
      'troubleshooting': [],
    },
  ],
};

void main() {
  for (final transaction in [
    'copy',
    'renewal',
    'new',
    'authentication',
    'retrieval',
    'replacement',
  ]) {
    testWidgets('CMS saved API contract renders transaction $transaction', (
      tester,
    ) async {
      final json = jsonDecode(
        File('test/fixtures/catalog/$transaction.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final record = GovernmentIdDetails.fromJson(json);
      expect(record.recordType, 'document');
      expect(record.requestPaths.single['application_type'], transaction);
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
      expect(find.text(record.name), findsOneWidget);
      if (record.isInformational) {
        expect(find.text('Informational Record'), findsOneWidget);
        expect(find.byType(TabBar), findsNothing);
      } else {
        await tester.tap(find.text('Requirements'));
        await tester.pumpAndSettle();
        expect(find.text('Proof of authority'), findsOneWidget);
        await tester.tap(find.text('Guide'));
        await tester.pumpAndSettle();
        expect(
          find.text('Retrieve the record through the official channel'),
          findsOneWidget,
        );
        await tester.tap(find.text('Special cases'));
        await tester.pumpAndSettle();
        expect(find.text('No record found'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('document API uses typed endpoints even when an ID has the same numeric identifier', () async {
    final paths = <String>[];
    final client = MockClient((request) async {
      paths.add(request.url.path);
      return http.Response(
        jsonEncode({
          'data': request.url.path.endsWith('/1')
              ? encodedDocument()
              : [encodedDocument()],
        }),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final list = await ApiService.getDocuments(client: client);
    final detail = await ApiService.getDocument(list.single.id, client: client);
    expect(detail.recordType, 'document');
    expect(paths, ['/api/documents', '/api/documents/1']);
    expect(
      detail.requestPaths.first['processing'],
      '20 minutes after complete request',
    );
    expect(detail.research['sources'][0]['checked_on'], '2026-10-29');
    client.close();
  });

  testWidgets(
    'switching request method changes channel content while record offices stay available',
    (tester) async {
      final record = GovernmentIdDetails.fromJson({
        ...encodedDocument(),
        'requirements': 'Unrelated legacy checklist',
      });
      await tester.pumpWidget(
        MaterialApp(
          home: IdDetailsScreen(
            idName: record.name,
            governmentId: 1,
            recordType: 'document',
            loadDetail: (_) async => record,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Estimated Cost'));
      await tester.pumpAndSettle();
      expect(find.text('Outlet fee'), findsOneWidget);
      expect(find.text('Guide'), findsOneWidget);
      expect(find.text('Offices'), findsOneWidget);
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      expect(
        find.text('Present the request at the saved counter'),
        findsOneWidget,
      );
      expect(find.text('Saved formatted instruction'), findsOneWidget);
      expect(find.text('Passport Application Guide'), findsNothing);
      await tester.tap(find.byType(DropdownButtonFormField<int>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Online retrieval').last);
      await tester.pumpAndSettle();
      expect(find.text('Outlet fee'), findsNothing);
      expect(find.text('Offices'), findsOneWidget);
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Unrelated legacy checklist'), findsNothing);
      expect(find.text('Fulfillment: download'), findsOneWidget);
      expect(find.text('Open official request portal'), findsOneWidget);
      expect(find.text('DFA Consular Office'), findsNothing);
      await tester.ensureVisible(find.text('Offices'));
      await tester.tap(find.text('Offices'));
      await tester.pumpAndSettle();
      expect(find.text('Saved registry counter'), findsOneWidget);
      expect(find.text('Verified fixture address'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final (name, mode) in <(String, bool)>[
    ('PSA Birth Certificate', false),
    ('NBI Clearance', false),
    ('Business Permit', false),
    ('DFA Apostille', false),
    ('PhilHealth MDR', false),
    ('Seafarer’s Record Book', true),
  ]) {
    testWidgets(
      '$name renders retained CMS content with the correct guidance mode',
      (tester) async {
        final record = GovernmentIdDetails.fromJson(
          encodedDocument(name: name, informational: mode),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: IdDetailsScreen(
              idName: name,
              governmentId: 1,
              recordType: 'document',
              loadDetail: (_) async => record,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(name), findsOneWidget);
        if (mode) {
          expect(find.text('Informational Record'), findsOneWidget);
          expect(find.byType(TabBar), findsNothing);
        } else {
          expect(find.text('Estimated Cost'), findsOneWidget);
          expect(find.text('Special cases'), findsOneWidget);
        }
        expect(find.text('Example address, Bulacan'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'hidden sections do not render or erase the saved source data on narrow large-text screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final record = GovernmentIdDetails.fromJson(
        encodedDocument(
          hidden: ['fees', 'guide', 'offices', 'troubleshooting'],
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: IdDetailsScreen(
            idName: record.name,
            governmentId: 1,
            recordType: 'document',
            loadDetail: (_) async => record,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Offices'), findsNothing);
      expect(record.requestPaths.first['guide'], isNotEmpty);
      await tester.scrollUntilVisible(
        find.text('Official fixture source'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Official fixture source'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
