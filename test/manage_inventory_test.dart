import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/profile/manage_inventory_screen.dart';

Map<String, dynamic> _inventory() => {
  'government_ids': [
    {'id': 2, 'name': 'Postal ID', 'owned': true},
    {'id': 1, 'name': 'Philippine Passport', 'owned': false},
    {'id': 3, 'name': 'TIN ID', 'owned': false},
  ],
  'documents': [
    {'id': 7, 'name': 'PSA Birth Certificate', 'owned': false},
    {'id': 8, 'name': 'NBI Clearance', 'owned': true},
  ],
};

Future<List<Map<String, dynamic>>> _open(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  bool dark = false,
  Map<String, dynamic>? data,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final saves = <Map<String, dynamic>>[];
  AuthService.instance = AuthService(
    client: MockClient((request) async {
      if (request.method == 'PUT') {
        saves.add(jsonDecode(request.body) as Map<String, dynamic>);
      }
      return http.Response(jsonEncode({'data': data ?? _inventory()}), 200);
    }),
  )..token = 'resident';
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ManageInventoryScreen()),
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
  return saves;
}

void main() {
  testWidgets('the header matches Office Finder and goes back', (tester) async {
    await _open(tester);
    final arrow = find.byIcon(Icons.arrow_back_rounded);
    final title = find.text('Manage Inventory');
    final subtitle = find.text('Mark the IDs and documents you already have.');
    expect(tester.getTopLeft(arrow).dx, 20);
    expect(tester.getTopLeft(title).dx, 56);
    expect(tester.getCenter(arrow).dy, tester.getCenter(title).dy);
    expect(tester.getTopLeft(subtitle).dx, 56);
    expect(tester.getTopLeft(find.byType(TextField)).dx, 20);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(ManageInventoryScreen), findsNothing);
  });

  testWidgets('tabs separate IDs from documents and list them A to Z', (
    tester,
  ) async {
    await _open(tester);
    expect(find.text('Postal ID'), findsOneWidget);
    expect(find.text('PSA Birth Certificate'), findsNothing);
    expect(
      tester.getTopLeft(find.text('Philippine Passport')).dy,
      lessThan(tester.getTopLeft(find.text('Postal ID')).dy),
    );
    expect(find.text('1 of 3 marked'), findsOneWidget);

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    expect(find.text('Postal ID'), findsNothing);
    expect(find.text('PSA Birth Certificate'), findsOneWidget);
    expect(find.text('1 of 2 marked'), findsOneWidget);
  });

  testWidgets('search and the owned filter narrow the list', (tester) async {
    await _open(tester);
    await tester.enterText(find.byType(TextField), 'pass');
    await tester.pumpAndSettle();
    expect(find.text('Philippine Passport'), findsOneWidget);
    expect(find.text('Postal ID'), findsNothing);
    expect(find.text('1 result'), findsOneWidget);

    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Owned'));
    await tester.pumpAndSettle();
    expect(find.text('Postal ID'), findsOneWidget);
    expect(find.text('Philippine Passport'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(
      find.text('Nothing matches. Try another name or filter.'),
      findsOneWidget,
    );
  });

  testWidgets('selections survive tab changes and save both lists', (
    tester,
  ) async {
    final saves = await _open(tester);
    await tester.tap(find.text('Philippine Passport'));
    await tester.pump();
    expect(find.text('2 IDs · 1 document marked'), findsOneWidget);

    await tester.tap(find.text('Documents'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NBI Clearance'));
    await tester.pump();
    expect(find.text('2 IDs · 0 documents marked'), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saves, [
      {
        'government_id_ids': [1, 2],
        'document_ids': <int>[],
      },
    ]);
    expect(find.byType(ManageInventoryScreen), findsNothing);
  });

  testWidgets('opens on documents when there are no IDs', (tester) async {
    await _open(
      tester,
      data: {
        'government_ids': <Map<String, dynamic>>[],
        'documents': [
          {'id': 7, 'name': 'PSA Birth Certificate', 'owned': false},
        ],
      },
    );
    expect(find.text('PSA Birth Certificate'), findsOneWidget);
  });

  for (final size in const [
    Size(280, 653),
    Size(320, 568),
    Size(650, 900),
    Size(844, 390),
  ]) {
    for (final dark in [false, true]) {
      testWidgets('fits $size (${dark ? 'dark' : 'light'})', (tester) async {
        await _open(tester, size: size, dark: dark);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
