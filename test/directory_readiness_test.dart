import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/api_service.dart';

GovernmentIdDetails catalog(
  int id,
  String name, {
  String type = 'government_id',
  String guidance = 'guided',
  String availability = 'available',
}) => GovernmentIdDetails.fromJson({
  'id': id,
  'name': name,
  'record_type': type,
  'guidance_mode': guidance,
  'application_availability': availability,
  'prerequisites': [],
});

Map<String, dynamic> document(int id) => {
  'type': 'document',
  'document_id': id,
};
Map<String, dynamic> governmentId(int id) => {
  'type': 'government_id',
  'government_id_id': id,
};
Map<String, dynamic> way(
  List<Map<String, dynamic>> items, {
  int count = 1,
  String qualification = 'none',
}) => {
  'required_count': count,
  'qualification_type': qualification,
  'items': items,
};
Map<String, dynamic> group(
  List<Map<String, dynamic>> ways, {
  String condition = 'always',
}) => {
  'condition_type': condition,
  'condition_label': condition == 'always' ? null : 'If applicable',
  'ways': ways,
};
Map<String, dynamic> checklist(
  List<Map<String, dynamic>> groups, {
  String applicant = 'all',
  String application = 'new',
  int? minAge,
}) => {
  'id': 1,
  'applicant_type': applicant,
  'application_type': application,
  'min_age': minAge,
  'groups': groups,
};
GovernmentIdDetails detail(
  GovernmentIdDetails record,
  List<Map<String, dynamic>> groups, {
  Map<String, dynamic> extra = const {},
}) => GovernmentIdDetails.fromJson({
  ...record.raw,
  'requirement_sets': [checklist(groups)],
  ...extra,
});

List<String> suggestionText(WidgetTester tester) {
  final text = tester
      .widgetList<Text>(find.byType(Text))
      .map((t) => t.data ?? '')
      .toList();
  final start = text.indexOf('Suggested for You');
  if (start < 0) return [];
  final end = text.indexOf('Commonly Needed');
  return text.sublist(start + 1, end < 0 ? text.length : end);
}

Future<void> showDirectory(
  WidgetTester tester,
  List<GovernmentIdDetails> records,
  Future<GovernmentIdDetails> Function(String, int) loader, {
  Future<Map<String, dynamic>> Function()? loadInventory,
}) async {
  tester.view.physicalSize = const Size(430, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: IdsScreen(
          loadIds: () async => records,
          loadRecordDetail: loader,
          loadInventory: loadInventory,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

// Only the explicitly opted-in local API smoke check bypasses Flutter's test
// HTTP override; normal tests remain deterministic and make no network calls.
class _LocalApiOverrides extends HttpOverrides {}

void main() {
  late AuthService previousAuth;
  late Map<String, dynamic> inventory;
  late int inventoryCalls;
  setUp(() {
    previousAuth = AuthService.instance;
    inventory = {
      'government_ids': [],
      'documents': [
        {'id': 10, 'owned': true},
      ],
    };
    inventoryCalls = 0;
    AuthService.instance = AuthService(
      baseUrl: 'http://localhost/api',
      client: MockClient((request) async {
        expect(request.url.path, '/api/auth/inventory');
        expect(request.headers['Authorization'], 'Bearer resident-test-token');
        inventoryCalls++;
        return http.Response(jsonEncode({'data': inventory}), 200);
      }),
    )..token = 'resident-test-token';
  });
  tearDown(() {
    AuthService.instance.dispose();
    AuthService.instance = previousAuth;
  });

  testWidgets(
    'signed-in inventory restores ranked top three despite empty prerequisites; only four details load',
    (tester) async {
      final national = catalog(501, 'PhilSys National ID');
      final passport = catalog(502, 'Philippine Passport');
      final nbi = catalog(501, 'NBI Clearance', type: 'document');
      final police = catalog(
        503,
        'National Police Clearance',
        type: 'document',
      );
      final records = [
        national,
        passport,
        nbi,
        police,
        for (var i = 0; i < 50; i++) catalog(1000 + i, 'Other guide $i'),
      ];
      final details = {
        ('government_id', national.id): detail(national, [
          group([
            way([document(10)]),
          ]),
        ]),
        ('government_id', passport.id): detail(passport, [
          group([
            way([
              document(10),
              document(11),
              document(12),
              document(13),
            ], count: 4),
          ]),
        ]),
        ('document', nbi.id): detail(nbi, [
          group([
            way([document(10), document(11)], count: 2),
          ]),
        ]),
        ('document', police.id): detail(police, [
          group([
            way([document(11)]),
          ]),
        ]),
      };
      final requests = <(String, int)>[];
      await showDirectory(tester, records, (type, id) async {
        requests.add((type, id));
        return details[(type, id)]!;
      });
      expect(inventoryCalls, 1);
      expect(requests, hasLength(4));
      final text = suggestionText(tester);
      expect(text.where((t) => records.any((r) => r.name == t)), [
        'PhilSys National ID',
        'NBI Clearance',
        'Philippine Passport',
      ]);
      expect(
        text,
        containsAll(['Ready Now', 'Almost Ready', 'Needs Preparation']),
      );
      expect(text, isNot(contains('National Police Clearance')));
      await tester.tap(find.text('PhilSys National ID').first);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<IdDetailsScreen>(find.byType(IdDetailsScreen))
            .governmentId,
        501,
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(requests, hasLength(4));
      // Overview preparation no longer fetches Inventory; Directory keeps its cached score.
      expect(inventoryCalls, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'empty saved inventory still produces real missing checklist calculations',
    (tester) async {
      inventory = {'government_ids': [], 'documents': []};
      final national = catalog(56, 'PhilSys National ID');
      await showDirectory(
        tester,
        [national],
        (_, _) async => detail(national, [
          group([
            way([document(10)]),
          ]),
          group([
            way([governmentId(55)]),
          ]),
        ]),
      );
      expect(
        suggestionText(tester),
        containsAll(['Needs Preparation', 'You have 0 of 2 requirements.']),
      );
      expect(inventoryCalls, 1);
    },
  );

  testWidgets(
    'best alternative and choose-N use existing helper semantics rather than all referenced items',
    (tester) async {
      final national = catalog(56, 'PhilSys National ID');
      await showDirectory(
        tester,
        [national],
        (_, _) async => detail(national, [
          group([
            way([document(11), document(12)], count: 2),
            way([document(10), document(13), document(14)], count: 1),
          ]),
        ]),
      );
      expect(
        suggestionText(tester),
        containsAll(['Ready Now', 'You have 1 of 1 requirements.']),
      );
    },
  );

  testWidgets('duplicate linked references cannot satisfy choose-two', (
    tester,
  ) async {
    final national = catalog(56, 'PhilSys National ID');
    await showDirectory(
      tester,
      [national],
      (_, _) async => detail(national, [
        group([
          way([document(10), document(10)], count: 2),
        ]),
      ]),
    );
    expect(suggestionText(tester), contains('Almost Ready'));
  });

  final reviewCases = <String, List<Map<String, dynamic>>>{
    'conditional group': [
      group([
        way([document(10)]),
      ]),
      group([
        way([document(11)]),
      ], condition: 'custom'),
    ],
    'manual group': [
      group([
        way([document(10)]),
      ]),
      group([
        way([
          {'type': 'custom', 'name': 'Verification'},
        ]),
      ]),
    ],
    'manual alternative': [
      group([
        way([document(10)]),
        way([
          {'type': 'custom', 'name': 'Manual alternative'},
        ]),
      ]),
    ],
    'qualification': [
      group([
        way([document(10)], qualification: 'custom'),
      ]),
    ],
    'copies': [
      group([
        way([
          {...document(10), 'copies': 2},
        ]),
      ]),
    ],
    'format': [
      group([
        way([
          {...document(10), 'submission_format': 'original'},
        ]),
      ]),
    ],
    'quantity': [
      group([
        way([
          {...document(10), 'quantity': 2},
        ]),
      ]),
    ],
    'instructions': [
      group([
        way([
          {...document(10), 'instructions': 'Confirm validity'},
        ]),
      ]),
    ],
    'empty required group': [
      group([
        way([document(10)]),
      ]),
      group([]),
    ],
  };
  for (final entry in reviewCases.entries) {
    testWidgets('${entry.key} cannot create false Ready Now', (tester) async {
      final national = catalog(56, 'PhilSys National ID');
      await showDirectory(tester, [
        national,
      ], (_, _) async => detail(national, entry.value));
      expect(find.text('Suggested for You'), findsOneWidget);
      expect(suggestionText(tester), contains('Almost Ready'));
      expect(
        suggestionText(tester).join(' '),
        contains('Check the guide for other requirements.'),
      );
      expect(tester.takeException(), isNull);
    });
  }

  final unknownCases = <String, Map<String, dynamic>>{
    'applicant-specific scenario': {
      'requirement_sets': [
        checklist([
          group([
            way([document(10)]),
          ]),
        ], applicant: 'adult'),
      ],
    },
    'age-specific scenario': {
      'requirement_sets': [
        checklist([
          group([
            way([document(10)]),
          ]),
        ], minAge: 18),
      ],
    },
    'multiple checklists': {
      'requirement_sets': [
        checklist([
          group([
            way([document(10)]),
          ]),
        ]),
        {
          ...checklist([
            group([
              way([document(11)]),
            ]),
          ]),
          'id': 2,
        },
      ],
    },
    'multiple request channels': {
      'request_paths': [
        {'id': 1},
        {'id': 2},
      ],
    },
    'only conditional groups': {
      'requirement_sets': [
        checklist([
          group([
            way([document(10)]),
          ], condition: 'custom'),
        ]),
      ],
    },
    'only manual items': {
      'requirement_sets': [
        checklist([
          group([
            way([
              {'type': 'custom'},
            ]),
          ]),
        ]),
      ],
    },
    'no structured checklist': {'requirement_sets': []},
    'hidden checklist': {
      'research_metadata': {
        'hidden_sections': ['requirements'],
      },
    },
    'informational detail': {'guidance_mode': 'informational_only'},
  };
  for (final entry in unknownCases.entries) {
    testWidgets('${entry.key} produces no invented suggestion', (tester) async {
      final national = catalog(56, 'PhilSys National ID');
      await showDirectory(
        tester,
        [national],
        (_, _) async => detail(national, [
          group([
            way([document(10)]),
          ]),
        ], extra: entry.value),
      );
      expect(find.text('Suggested for You'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'single request path checklist is used consistently with detail screen',
    (tester) async {
      final nbi = catalog(35, 'NBI Clearance', type: 'document');
      await showDirectory(
        tester,
        [nbi],
        (_, _) async => detail(
          nbi,
          [
            group([
              way([document(10)]),
            ]),
          ],
          extra: {
            'request_paths': [
              {
                'id': 1,
                'requirement_sets': [
                  checklist([
                    group([
                      way([document(11)]),
                    ]),
                  ]),
                ],
              },
            ],
          },
        ),
      );
      expect(
        suggestionText(tester),
        containsAll(['Needs Preparation', 'You have 0 of 1 requirements.']),
      );
    },
  );

  testWidgets('one failed candidate is skipped without losing another result', (
    tester,
  ) async {
    final national = catalog(56, 'PhilSys National ID');
    final nbi = catalog(35, 'NBI Clearance', type: 'document');
    await showDirectory(tester, [national, nbi], (type, id) async {
      if (type == 'government_id') throw Exception('Offline');
      return detail(nbi, [
        group([
          way([document(10)]),
        ]),
      ]);
    });
    expect(suggestionText(tester), contains('NBI Clearance'));
    expect(suggestionText(tester), isNot(contains('PhilSys National ID')));
    expect(find.textContaining('Offline'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('all failed detail requests hide suggestions silently', (
    tester,
  ) async {
    await showDirectory(tester, [
      catalog(56, 'PhilSys National ID'),
    ], (_, _) async => throw Exception('Offline'));
    expect(find.text('Suggested for You'), findsNothing);
    expect(find.text('Commonly Needed'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'documents use existing typed detail API and never list prerequisites',
    (tester) async {
      final nbi = catalog(35, 'NBI Clearance', type: 'document');
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        return http.Response(
          jsonEncode({
            'data': detail(nbi, [
              group([
                way([document(10)]),
              ]),
            ]).raw,
          }),
          200,
        );
      });
      addTearDown(client.close);
      await showDirectory(tester, [nbi], (type, id) {
        expect(type, 'document');
        return ApiService.getDocument(id, client: client);
      });
      expect(paths, ['/api/documents/35']);
      expect(
        suggestionText(tester),
        containsAll(['NBI Clearance', 'Ready Now']),
      );
    },
  );

  testWidgets(
    'failed inventory retries on a filter interaction without a revision change',
    (tester) async {
      final national = catalog(56, 'PhilSys National ID');
      var attempts = 0;
      var details = 0;
      await showDirectory(
        tester,
        [national],
        (_, _) async {
          details++;
          return detail(national, [
            group([
              way([document(10)]),
            ]),
          ]);
        },
        loadInventory: () async {
          if (++attempts == 1) throw Exception('Temporary failure');
          return inventory;
        },
      );
      expect(find.text('Suggested for You'), findsNothing);
      expect(details, 0);
      await tester.tap(find.widgetWithText(ChoiceChip, 'All'));
      await tester.pumpAndSettle();
      expect(attempts, 2);
      expect(details, 1);
      expect(suggestionText(tester), contains('Ready Now'));
    },
  );

  testWidgets(
    'inventory revisions rescore cached details and exclude already-owned targets',
    (tester) async {
      final national = catalog(56, 'PhilSys National ID');
      var calls = 0;
      await showDirectory(tester, [national], (_, _) async {
        calls++;
        return detail(national, [
          group([
            way([document(10)]),
          ]),
        ]);
      });
      expect(suggestionText(tester), contains('Ready Now'));
      inventory = {'government_ids': [], 'documents': []};
      AuthService.instance.inventoryRevision++;
      AuthService.instance.user = {'id': 1};
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(inventoryCalls, 2);
      expect(suggestionText(tester), contains('Needs Preparation'));
      expect(calls, 1);
      inventory = {
        'government_ids': [
          {'id': 56, 'owned': true},
        ],
        'documents': [],
      };
      AuthService.instance.inventoryRevision++;
      AuthService.instance.user = {'id': 1};
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Suggested for You'), findsNothing);
      expect(calls, 1);
    },
  );

  testWidgets(
    'signed-out sessions make no personal or candidate-detail requests',
    (tester) async {
      AuthService.instance.token = null;
      var details = 0;
      await showDirectory(tester, [catalog(56, 'PhilSys National ID')], (
        _,
        _,
      ) async {
        details++;
        throw Exception('Must not request');
      });
      expect(inventoryCalls, 0);
      expect(details, 0);
      expect(find.text('Suggested for You'), findsNothing);
    },
  );

  testWidgets(
    'late old-session inventory cannot replace the new session result',
    (tester) async {
      final national = catalog(56, 'PhilSys National ID');
      final old = Completer<Map<String, dynamic>>();
      var calls = 0;
      await showDirectory(
        tester,
        [national],
        (_, _) async => detail(national, [
          group([
            way([document(10)]),
          ]),
        ]),
        loadInventory: () {
          return ++calls == 1
              ? old.future
              : Future.value({'government_ids': [], 'documents': []});
        },
      );
      AuthService.instance.token = 'new-session';
      AuthService.instance.user = {'id': 2};
      await tester.pumpAndSettle();
      expect(suggestionText(tester), contains('Needs Preparation'));
      old.complete(inventory);
      await tester.pumpAndSettle();
      expect(suggestionText(tester), contains('Needs Preparation'));
      expect(tester.takeException(), isNull);
    },
  );

  // Run explicitly with DIRECTORY_LIVE_API=true and API_BASE_URL pointing to
  // the local server; Flutter tests otherwise default to an Android host.
  testWidgets(
    'local API checklists produce suggestions with empty saved inventory and empty prerequisites',
    (tester) async {
      final live = await tester.runAsync(
        () => HttpOverrides.runWithHttpOverrides(() async {
          final records = [
            ...await ApiService.getGovernmentIds(),
            ...await ApiService.getDocuments(),
          ];
          final selected = records
              .where(
                (r) => {
                  'PhilSys National ID',
                  'Philippine Passport',
                  'NBI Clearance',
                  'National Police Clearance',
                }.contains(r.name),
              )
              .toList();
          expect(selected, hasLength(4));
          final details = <(String, int), GovernmentIdDetails>{};
          for (final record in selected) {
            expect(record.raw['prerequisites'] ?? [], isEmpty);
            details[(
              record.recordType,
              record.id,
            )] = record.recordType == 'document'
                ? await ApiService.getDocument(record.id)
                : await ApiService.getGovernmentId(record.id);
          }
          return (records: records, details: details);
        }, _LocalApiOverrides()),
      );
      inventory = {'government_ids': [], 'documents': []};
      await showDirectory(
        tester,
        live!.records,
        (type, id) async => live.details[(type, id)]!,
      );
      final text = suggestionText(tester);
      expect(text.where((t) => t == 'Needs Preparation'), hasLength(3));
      expect(text.any((t) => t.startsWith('0 of ')), isTrue);
      expect(text, isNot(contains('Ready Now')));
      expect(inventoryCalls, 1);
      expect(tester.takeException(), isNull);
    },
    skip: !const bool.fromEnvironment('DIRECTORY_LIVE_API'),
  );
}
