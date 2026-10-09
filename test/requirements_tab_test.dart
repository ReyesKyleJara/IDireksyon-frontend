import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/requirements_tab.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';

Map<String, dynamic> item(String name) => {'type': 'document', 'name': name};
Map<String, dynamic> scenario(int id, String label, List<Map<String, dynamic>> groups) => {
  'id': id, 'display_label': label, 'groups': groups,
};
Map<String, dynamic> requirement(String title, List<Map<String, dynamic>> items, {int count = 1}) => {
  'id': 1, 'title': title, 'condition_type': 'always',
  'ways': [{'required_count': count, 'qualification_type': 'none', 'items': items}],
};
GovernmentIdDetails record({List<Map<String, dynamic>> sets = const [], String? legacy}) =>
    GovernmentIdDetails.fromJson({'id': 34, 'name': 'Passport', 'requirements': legacy, 'requirement_sets': sets});
Future<void> showRequirements(WidgetTester tester, GovernmentIdDetails data) => tester.pumpWidget(
  MaterialApp(home: Scaffold(body: RequirementsTab(governmentId: data))),
);

void main() {
  testWidgets('pins the ID title and tabs when requirements scroll', (tester) async {
    await tester.pumpWidget(MaterialApp(home: IdDetailsScreen(
      idName: 'Passport', governmentId: 34,
      loadDetail: (_) async => record(legacy: List.generate(100, (i) => 'Required document $i').join('\n')),
    )));
    await tester.pumpAndSettle();
    final tabs = find.byType(TabBar);
    final initialTop = tester.getTopLeft(tabs).dy;
    final list = find.descendant(of: find.byType(RequirementsTab), matching: find.byType(ListView));
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('compact-id-title')), findsOneWidget);
    final pinnedTop = tester.getTopLeft(tabs).dy;
    expect(pinnedTop, lessThan(initialTop));
    expect(pinnedTop, greaterThanOrEqualTo(kToolbarHeight));
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(tabs).dy, closeTo(pinnedTop, 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows a single requirement with submission details and no selector', (tester) async {
    await showRequirements(tester, record(sets: [scenario(1, 'Adult • First-Time Application', [
      requirement('PSA Birth Certificate', [{...item('PSA Birth Certificate'), 'submission_format': 'original_photocopy', 'submission_label': 'Original + Photocopy', 'copies': 1, 'instructions': 'Bring a clear copy.'}]),
    ])], legacy: 'Old duplicate summary'));
    expect(find.text('PSA Birth Certificate'), findsOneWidget);
    expect(find.text('Required'), findsNothing);
    expect(find.text('Original + 1 photocopy'), findsOneWidget);
    final title = tester.widget<Text>(find.text('PSA Birth Certificate'));
    final submission = tester.widget<Text>(find.text('Original + 1 photocopy'));
    expect(title.style!.fontSize, greaterThan(submission.style!.fontSize!));
    expect(find.text('01'), findsNothing);
    expect(find.text('Bring a clear copy.'), findsOneWidget);
    expect(find.text('Old duplicate summary'), findsNothing);
    expect(find.byType(DropdownButtonFormField<int>), findsNothing);
  });

  testWidgets('switches scenarios in place', (tester) async {
    await showRequirements(tester, record(sets: [
      scenario(1, 'Adult • First-Time Application', [requirement('Birth Certificate', [item('Birth Certificate')])]),
      scenario(2, 'Adult • Renewal', [requirement('Current Passport', [item('Current Passport')])]),
    ]));
    expect(find.text('Birth Certificate'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<int>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Adult • Renewal').last);
    await tester.pumpAndSettle();
    expect(find.text('Current Passport'), findsOneWidget);
    expect(find.text('Birth Certificate'), findsNothing);
  });

  testWidgets('long accepted lists start collapsed and expand inline', (tester) async {
    await showRequirements(tester, record(sets: [scenario(1, 'Adult', [
      requirement('Proof of identity', List.generate(6, (i) => item('Accepted item $i')), count: 2),
    ])]));
    expect(find.text('Choose 2 accepted items'), findsOneWidget);
    expect(find.text('Accepted item 0'), findsNothing);
    expect(find.text('View 6 accepted items'), findsOneWidget);
    await tester.tap(find.text('View 6 accepted items'));
    await tester.pumpAndSettle();
    expect(find.text('Accepted item 5'), findsOneWidget);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('View 6 accepted items'));
    await tester.pumpAndSettle();
    expect(find.text('Accepted item 0'), findsNothing);
    expect(find.text('Choose 2 accepted items'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows alternative routes conditions and qualification scopes', (tester) async {
    await showRequirements(tester, record(sets: [scenario(1, 'Adult', [{
      'id': 1, 'title': 'Proof of identity', 'condition_type': 'custom', 'condition_label': 'When the name differs',
      'ways': [
        {'required_count': 1, 'items': [item('National ID'), item('Passport')],
         'qualification_type': 'current_address', 'qualification_label': 'Each selected item must: Show current address'},
        {'required_count': 2, 'items': [item('School ID'), item('Barangay ID'), item('Certification')],
         'qualification_type': 'photo_signature', 'qualification_scope': 'at_least_one',
         'qualification_label': 'At least one selected item must: Contain photo and signature'},
      ],
    }])]));
    expect(find.text('Only if: When the name differs'), findsOneWidget);
    expect(find.text('Option 1'), findsOneWidget);
    expect(find.text('OR'), findsOneWidget);
    expect(find.text('Option 2'), findsOneWidget);
    expect(find.text('Choose 1 accepted item'), findsOneWidget);
    expect(find.text('Choose 2 accepted items'), findsOneWidget);
    expect(find.text('At least one selected item must: Contain photo and signature'), findsOneWidget);
  });

  testWidgets('uses legacy fallback and clean empty states', (tester) async {
    await showRequirements(tester, record(legacy: 'Bring the original certificate.'));
    expect(find.text('Bring the original certificate.'), findsOneWidget);
    await showRequirements(tester, record());
    expect(find.text('Requirements are not available yet.'), findsOneWidget);
    await showRequirements(tester, record(sets: [scenario(1, 'Adult', [])], legacy: 'Do not mix scenarios'));
    expect(find.text('Requirements for this application are not available yet.'), findsOneWidget);
    expect(find.text('Do not mix scenarios'), findsNothing);
  });

  testWidgets('loads detail by ID and retries after failure', (tester) async {
    final pending = Completer<GovernmentIdDetails>();
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: IdDetailsScreen(
      idName: 'Passport', governmentId: 34, loadDetail: (id) {
        expect(id, 34);
        calls++;
        return calls == 1 ? pending.future : Future.value(record(legacy: 'Live requirement'));
      },
    )));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    pending.completeError(Exception('Offline'));
    await tester.pumpAndSettle();
    expect(find.text('Could not load requirements.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Live requirement'), findsOneWidget);
    expect(calls, 2);
    expect(find.text('50%'), findsNothing);
  });

  testWidgets('directory opens the selected record by numeric ID', (tester) async {
    var requestedId = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IdsScreen(
      loadIds: () async => [record()],
      loadDetail: (id) async { requestedId = id; return record(legacy: 'Loaded from selected ID'); },
    ))));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Passport').first);
    await tester.pumpAndSettle();
    expect(requestedId, 34);
    expect(find.text('Loaded from selected ID'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory retries and supports search without more HTTP requests', (tester) async {
    var calls = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: IdsScreen(loadIds: () async {
      calls++;
      if (calls == 1) throw Exception('Offline');
      return [record()];
    }))));
    await tester.pumpAndSettle();
    expect(find.text('Could not load the ID directory.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'not a matching name');
    await tester.pumpAndSettle();
    expect(find.text('No matching IDs.'), findsOneWidget);
    expect(calls, 2);
  });

  testWidgets('name-only prototype links do not guess a database ID', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: IdDetailsScreen(idName: 'Passport ID')));
    expect(find.text('Open this ID from the ID Directory to view its current requirements.'), findsOneWidget);
    expect(find.text('Birth Certificate'), findsNothing);
  });

  testWidgets('requirements fit a narrow screen with large text', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: Scaffold(body: RequirementsTab(governmentId: record(sets: [
        scenario(1, 'Adult • First-Time Application', [requirement('Long requirement title for an accepted identification document', [item('Government ID')])]),
        scenario(2, 'Minor • First-Time Application', []),
      ]))),
    ));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final selector = find.byType(DropdownButtonFormField<int>);
    expect(tester.getTopLeft(selector).dy,
        greaterThan(tester.getBottomLeft(find.text('Applying for')).dy));
    await tester.tap(selector);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Minor • First-Time Application').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Requirements for this application are not available yet.'), findsOneWidget);
  });
  testWidgets('keeps short accepted choices collapsed without hiding qualifications', (tester) async {
    await showRequirements(tester, record(sets: [scenario(1, 'Adult', [{
      'id': 1, 'title': 'Proof of address', 'condition_type': 'always',
      'ways': [{
        'required_count': 1,
        'qualification_type': 'current_address',
        'qualification_label': 'Each selected item must: Show current address',
        'items': [item('National ID'), item('License')],
      }],
    }])]));
    expect(find.text('Choose 1 accepted item'), findsOneWidget);
    expect(find.text('Each selected item must: Show current address'), findsOneWidget);
    expect(find.text('National ID'), findsNothing);
    await tester.tap(find.text('View 2 accepted items'));
    await tester.pumpAndSettle();
    expect(find.text('National ID'), findsOneWidget);
    expect(find.text('License'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows all mandatory items without describing them as alternatives', (tester) async {
    await showRequirements(tester, record(sets: [scenario(1, 'Adult', [
      requirement('Supporting documents', [item('Birth Certificate'), item('Application Form')], count: 2),
    ])]));
    expect(find.text('Provide all listed items'), findsOneWidget);
    expect(find.text('Birth Certificate'), findsOneWidget);
    expect(find.text('Application Form'), findsOneWidget);
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text('Choose 2 accepted items'), findsNothing);
  });

  testWidgets('keeps a distinct requirement title and its selected document visible', (tester) async {
    await showRequirements(tester, record(sets: [scenario(1, 'Adult', [
      requirement('Proof of birth', [item('Birth Certificate')]),
    ])]));
    expect(find.text('Proof of birth'), findsOneWidget);
    expect(find.text('Birth Certificate'), findsOneWidget);
  });

  testWidgets('accepted choices and instructions wrap with large text on a narrow screen', (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(2)), child: child!),
      home: Scaffold(body: RequirementsTab(governmentId: record(sets: [scenario(1, 'Adult', [
        requirement('Proof of identity with a long descriptive heading', [
          {...item('Long government identification document name'),
            'instructions': 'Bring the original document and a clear copy of both sides.'},
          item('Another accepted identification document'),
        ]),
      ])]))),
    ));
    await tester.pumpAndSettle();
    final toggle = find.text('View 2 accepted items');
    final list = find.descendant(
      of: find.byType(RequirementsTab), matching: find.byType(Scrollable),
    );
    // Large text can put a built accordion below the viewport. Scroll until
    // its title can actually receive a tap, including after layout settles.
    await tester.scrollUntilVisible(toggle.hitTestable(), 150, scrollable: list);
    await tester.pumpAndSettle();
    expect(toggle.hitTestable(), findsOneWidget);
    await tester.tap(toggle.hitTestable());
    await tester.pumpAndSettle();
    final instructions = find.text('Bring the original document and a clear copy of both sides.');
    expect(instructions, findsOneWidget);
    await tester.scrollUntilVisible(instructions.hitTestable(), 150, scrollable: list);
    await tester.pumpAndSettle();
    expect(instructions.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

}
