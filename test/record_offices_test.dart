import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/api_service.dart';

Map<String, dynamic> record(String type, String name) => {
  'id': 7,
  'record_type': type,
  'name': name,
  'offices': [
    {
      'id': 1,
      'name': '$name main office',
      'address': 'Saved record address',
      'latitude': 14.8,
      'longitude': 120.9,
      'schedules': [
        {
          'day_of_week': 1,
          'status': 'open',
          'intervals': [
            {'opens_at': '08:00:00', 'closes_at': '17:00:00'},
          ],
        },
      ],
    },
  ],
  'request_paths': [
    {
      'id': 10,
      'label': 'In person',
      'provider': 'Counter provider',
      'requirement_sets': [],
      'fees': [],
      'offices': [
        {
          'id': 99,
          'name': 'Path-only legacy office',
          'address': 'Channel address',
          'schedules': [],
        },
      ],
    },
    {
      'id': 11,
      'label': 'Online',
      'provider': 'Online provider',
      'requirement_sets': [],
      'fees': [],
      'offices': [],
    },
  ],
};

void main() {
  for (final (type, name) in [
    ('government_id', 'PhilSys National ID'),
    ('government_id', 'Philippine Passport'),
    ('document', 'NBI Clearance'),
  ]) {
    testWidgets(
      '$name offices come from the record and stay unchanged across request methods',
      (tester) async {
        final paths = <String>[];
        final json = record(type, name);
        final before = jsonEncode(json['request_paths']);
        final client = MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'data': json}), 200);
        });
        addTearDown(client.close);
        final data = type == 'document'
            ? await ApiService.getDocument(7, client: client)
            : await ApiService.getGovernmentId(7, client: client);
        expect(paths, [
          type == 'document' ? '/api/documents/7' : '/api/government-ids/7',
        ]);
        expect(data.offices.single['name'], '$name main office');
        expect(data.forPath(data.requestPaths.last).offices, data.offices);
        await tester.pumpWidget(
          MaterialApp(
            home: IdDetailsScreen(
              idName: data.name,
              governmentId: data.id,
              recordType: type,
              loadDetail: (_) async => data,
              officesMapBuilder: (_) => const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Offices'));
        await tester.pumpAndSettle();
        expect(find.text('$name main office'), findsOneWidget);
        expect(find.text('Saved record address'), findsOneWidget);
        expect(find.text('Get Directions'), findsOneWidget);
        expect(find.text('Monday: open 08:00:00–17:00:00'), findsOneWidget);
        expect(find.text('Path-only legacy office'), findsNothing);
        await tester.tap(find.byType(DropdownButtonFormField<int>));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Online').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Offices'));
        await tester.pumpAndSettle();
        expect(find.text('$name main office'), findsOneWidget);
        expect(find.text('Saved record address'), findsOneWidget);
        expect(find.text('Get Directions'), findsOneWidget);
        expect(find.text('Monday: open 08:00:00–17:00:00'), findsOneWidget);
        expect(find.text('Path-only legacy office'), findsNothing);
        expect(jsonEncode(data.raw['request_paths']), before);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final type in ['government_id', 'document']) {
    testWidgets(
      '$type empty state does not fall back to Request Method offices',
      (tester) async {
        final data = GovernmentIdDetails.fromJson({
          ...record(type, 'Empty fixture'),
          'offices': [],
        });
        await tester.pumpWidget(
          MaterialApp(
            home: IdDetailsScreen(
              idName: data.name,
              governmentId: data.id,
              recordType: type,
              loadDetail: (_) async => data,
              officesMapBuilder: (_) => const SizedBox(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Offices'));
        await tester.pumpAndSettle();
        expect(
          find.text(
            type == 'document'
                ? 'No offices have been added for this document yet.'
                : 'No offices have been added for this ID yet.',
          ),
          findsOneWidget,
        );
        expect(find.text('Path-only legacy office'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final (type, name) in [
    ('government_id', 'Philippine Passport'),
    ('document', 'NBI Clearance'),
  ]) {
    testWidgets(
      '$name shows linked offices regardless of status after reload',
      (tester) async {
        var status = 'draft';
        var requests = 0;
        final json = record(type, name);
        final client = MockClient((_) async {
          requests++;
          return http.Response(
            jsonEncode({
              'data': {
                ...json,
                'offices': [
                  for (final office in json['offices'] as List)
                    {...office, 'status': status},
                ],
              },
            }),
            200,
          );
        });
        addTearDown(client.close);
        for (final nextStatus in ['draft', 'active', 'inactive']) {
          status = nextStatus;
          final data = type == 'document'
              ? await ApiService.getDocument(7, client: client)
              : await ApiService.getGovernmentId(7, client: client);
          await tester.pumpWidget(
            MaterialApp(
              home: IdDetailsScreen(
                key: ValueKey(status),
                idName: data.name,
                governmentId: data.id,
                recordType: type,
                loadDetail: (_) async => data,
                officesMapBuilder: (_) => const SizedBox(),
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Offices'));
          await tester.pumpAndSettle();
          expect(find.text('$name main office'), findsOneWidget);
          expect(find.text('Get Directions'), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
        expect(requests, 3);
      },
    );
  }
}
