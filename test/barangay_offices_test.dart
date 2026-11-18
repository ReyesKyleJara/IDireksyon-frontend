import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/features/ids/barangay_offices.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

const bulac = 3, catmon = 4;

Map<String, dynamic> hall(int id, String barangay, int barangayId) => {
  'id': id,
  'name': '$barangay Barangay Hall',
  'address': 'Saved address',
  'coverage': 'barangay',
  'barangay': {'id': barangayId, 'name': barangay},
};

final shared = {'id': 20, 'name': 'Municipal Hall', 'coverage': 'shared'};
final unclassified = {'id': 30, 'name': 'Unclassified Office'};

Map<String, dynamic> recordJson(
  String? level, {
  List<Map<String, dynamic>>? offices,
}) => {
  'id': 7,
  'record_type': 'government_id',
  'name': 'Barangay ID',
  'level': level,
  'offices':
      offices ??
      [
        hall(1, 'Bulac', bulac),
        hall(2, 'Catmon', catmon),
        shared,
        unclassified,
      ],
  'request_paths': [
    {
      'id': 50,
      'label': 'Walk-in',
      'is_request_method': true,
      'offices':
          offices ?? [hall(1, 'Bulac', bulac), hall(2, 'Catmon', catmon)],
    },
  ],
};

void main() {
  tearDown(() => AuthService.instance.user = null);

  group('BarangayOffices.applicable', () {
    final offices = List<Map<String, dynamic>>.from(
      recordJson('Barangay')['offices'],
    );
    List<String> names(String? level, int? resident) => [
      for (final office in BarangayOffices.applicable(
        offices,
        level: level,
        residentBarangayId: resident,
      ))
        '${office['name']}',
    ];

    test('keeps own barangay and shared offices on Barangay records', () {
      expect(names('Barangay', bulac), [
        'Bulac Barangay Hall',
        'Municipal Hall',
      ]);
      expect(names(' barangay ', catmon), [
        'Catmon Barangay Hall',
        'Municipal Hall',
      ]);
    });

    test('keeps only shared offices when no barangay is saved', () {
      expect(names('Barangay', null), ['Municipal Hall']);
    });

    test('leaves municipal and national records unchanged', () {
      for (final level in ['National', 'Municipal / LGU', null]) {
        expect(names(level, bulac), hasLength(4));
      }
    });

    test('reads the saved barangay whether sent as a number or text', () {
      expect(BarangayOffices.residentBarangayId({'barangay_id': 3}), 3);
      expect(BarangayOffices.residentBarangayId({'barangay_id': '3'}), 3);
      expect(BarangayOffices.residentBarangayId({'barangay_id': null}), null);
      expect(BarangayOffices.residentBarangayId(null), null);
    });
  });

  Future<void> openOffices(
    WidgetTester tester,
    Map<String, dynamic> json,
  ) async {
    final data = GovernmentIdDetails.fromJson(json);
    await tester.pumpWidget(
      MaterialApp(
        home: IdDetailsScreen(
          idName: data.name,
          governmentId: data.id,
          loadDetail: (_) async => data,
          officesMapBuilder: (_) => const SizedBox(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Offices'));
    await tester.pumpAndSettle();
  }

  testWidgets('labels the resident\'s own barangay office only', (
    tester,
  ) async {
    AuthService.instance.user = {
      'id': 1,
      'barangay_id': bulac,
      'barangay_name': 'Bulac',
    };
    await openOffices(tester, recordJson('Barangay'));

    expect(find.text('Bulac Barangay Hall'), findsOneWidget);
    expect(find.text('Municipal Hall'), findsOneWidget);
    expect(find.text('Catmon Barangay Hall'), findsNothing);
    expect(find.text('Unclassified Office'), findsNothing);
    expect(find.text('Your Barangay'), findsOneWidget);
    expect(find.byKey(const ValueKey('your-barangay-1')), findsOneWidget);
    expect(
      find.textContaining('Other branches may also serve you'),
      findsNothing,
    );
  });

  testWidgets('explains a missing barangay office instead of showing others', (
    tester,
  ) async {
    AuthService.instance.user = {
      'id': 1,
      'barangay_id': 9,
      'barangay_name': 'Tumana',
    };
    await openOffices(
      tester,
      recordJson('Barangay', offices: [hall(1, 'Bulac', bulac)]),
    );

    expect(find.text('Bulac Barangay Hall'), findsNothing);
    expect(
      find.text(
        'The office for Barangay Tumana has not been added for this ID yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('keeps the Offices tab for a Barangay record with no offices', (
    tester,
  ) async {
    AuthService.instance.user = {'id': 1, 'barangay_id': bulac};
    await openOffices(tester, recordJson('Barangay', offices: []));
    expect(
      find.text(
        'The office for your barangay has not been added for this ID yet.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'asks residents without a barangay to set it, keeping shared offices',
    (tester) async {
      AuthService.instance.user = {'id': 1, 'barangay_id': null};
      await openOffices(tester, recordJson('Barangay'));

      expect(
        find.byKey(const ValueKey('offices-set-barangay')),
        findsOneWidget,
      );
      expect(find.text('Go to Account Details'), findsOneWidget);
      expect(find.text('Municipal Hall'), findsOneWidget);
      expect(find.text('Bulac Barangay Hall'), findsNothing);
      expect(find.text('Your Barangay'), findsNothing);

      // Saving a barangay updates the open tab.
      AuthService.instance.user = {'id': 1, 'barangay_id': bulac};
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('offices-set-barangay')), findsNothing);
      expect(find.text('Bulac Barangay Hall'), findsOneWidget);
      expect(find.text('Your Barangay'), findsOneWidget);
    },
  );

  testWidgets('shows every linked office on national records, unlabelled', (
    tester,
  ) async {
    AuthService.instance.user = {'id': 1, 'barangay_id': bulac};
    // Tall enough that all four office cards are built.
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openOffices(tester, recordJson('National'));

    for (final name in [
      'Bulac Barangay Hall',
      'Catmon Barangay Hall',
      'Municipal Hall',
      'Unclassified Office',
    ]) {
      expect(find.text(name), findsOneWidget);
    }
    expect(find.text('Your Barangay'), findsNothing);
    expect(find.byKey(const ValueKey('offices-set-barangay')), findsNothing);
  });

  testWidgets('request method offices follow the same barangay rule', (
    tester,
  ) async {
    AuthService.instance.user = {'id': 1, 'barangay_id': catmon};
    final data = GovernmentIdDetails.fromJson(recordJson('Barangay'));
    await tester.pumpWidget(
      MaterialApp(
        home: RequestMethodScreen(
          record: data,
          method: Map<String, dynamic>.from(
            (recordJson('Barangay')['request_paths'] as List).first,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Catmon Barangay Hall'), findsOneWidget);
    expect(find.text('Bulac Barangay Hall'), findsNothing);
  });
}
