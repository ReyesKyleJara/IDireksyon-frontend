import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/requirements_tab.dart';
import 'package:idireksyon_frontend/features/ids/inventory_readiness_card.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

GovernmentIdDetails fixture({int id = 55, String type = 'government_id'}) =>
    GovernmentIdDetails.fromJson({
      'id': id,
      'record_type': type,
      'name': 'Target $id',
      'requirement_sets': [
        {
          'id': id,
          'application_type': 'new',
          'applicant_type': 'all',
          'groups': [
            {
              'id': id,
              'title': 'Supporting requirements',
              'condition_type': 'always',
              'ways': [
                {
                  'id': id,
                  'required_count': 2,
                  'items': [
                    {
                      'id': id * 10,
                      'type': 'government_id',
                      'government_id_id': 1,
                      'name': 'National ID',
                    },
                    {
                      'id': id * 10 + 1,
                      'type': 'custom',
                      'name': 'Completed application form',
                      'instructions': 'Bring the completed and signed form.',
                    },
                  ],
                },
              ],
            },
          ],
        },
      ],
    });

void main() {
  late AuthService previous;
  late AuthService auth;
  late Map<String, Map<int, bool>> stored;
  late List<http.Request> writes;
  late List<int> owned;
  Completer<http.Response>? pending;
  var fail = false;

  setUp(() {
    previous = AuthService.instance;
    stored = {};
    writes = [];
    owned = [];
    fail = false;
    pending = null;
    auth = AuthService(
      baseUrl: 'http://localhost/api',
      client: MockClient((request) async {
        if (request.url.path.endsWith('/inventory')) {
          expectSync(
            request.method,
            'GET',
          ); // This screen must NEVER write Inventory.
          return http.Response(
            jsonEncode({
              'data': {
                'government_ids': [
                  {'id': 1, 'owned': owned.contains(1)},
                ],
                'documents': [],
              },
            }),
            200,
          );
        }
        final parts = request.url.pathSegments;
        expectSync(parts[2], 'requirement-preparation');
        final type = parts[3];
        final id = int.parse(parts[4]);
        final key = '$type:$id';
        final selections = stored.putIfAbsent(key, () => {});
        if (request.method == 'PUT') {
          writes.add(request);
          if (pending != null) return pending!.future;
          if (fail) return http.Response('{}', 503);
          final body = jsonDecode(request.body);
          selections[body['item_id'] as int] = body['prepared'] as bool;
        }
        final effective = <int, bool>{
          if (owned.contains(1)) id * 10: true,
          ...selections,
        };
        return http.Response(
          jsonEncode({
            'data': {
              'record_type': type,
              'record_id': id,
              'items': [
                for (final entry in effective.entries)
                  {'item_id': entry.key, 'prepared': entry.value},
              ],
            },
          }),
          200,
        );
      }),
    )..token = 'resident';
    AuthService.instance = auth;
  });

  tearDown(() {
    AuthService.instance = previous;
    auth.dispose();
  });

  Future<void> show(
    WidgetTester tester, {
    int id = 55,
    String type = 'government_id',
    bool overview = false,
    double scale = 1,
  }) async {
    final record = fixture(id: id, type: type);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: Scaffold(
          body: Column(
            children: [
              if (overview) ApplicationPreparationCard(record: record),
              Expanded(child: RequirementsTab(governmentId: record)),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Checkbox box(WidgetTester tester, int id) =>
      tester.widget<Checkbox>(find.byKey(ValueKey('prepare-item-$id')));
  Future<void> tapItem(WidgetTester tester, int id) async {
    final control = find.byKey(ValueKey('prepare-item-$id'));
    await tester.scrollUntilVisible(
      control.hitTestable(),
      100,
      scrollable: find
          .descendant(
            of: find.byType(RequirementsTab),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(control);
    await tester.pumpAndSettle();
  }

  Future<void> confirm(WidgetTester tester, {bool remove = false}) async {
    final action = find.text(
      remove ? 'Remove from checklist' : 'Yes, mark as prepared',
    );
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'both confirmation dialogs match the compact white and navy app styling',
    (tester) async {
      final font = FontLoader('Google Sans')
        ..addFont(rootBundle.load('assets/fonts/GoogleSans-Regular.woff2'));
      await font.load();
      await show(tester);
      for (final prepared in [false, true]) {
        await tapItem(tester, 550);
        final dialog = tester.widget<AlertDialog>(find.byType(AlertDialog));
        expect(dialog.backgroundColor, Colors.white);
        expect(dialog.surfaceTintColor, Colors.transparent);
        expect(dialog.titleTextStyle!.color, AppTheme.navy);
        expect(dialog.titleTextStyle!.fontSize, 20);
        expect(dialog.contentTextStyle!.fontSize, 14);
        expect(
          tester
              .getSize(
                find
                    .descendant(
                      of: find.byType(AlertDialog),
                      matching: find.byType(Material),
                    )
                    .first,
              )
              .width,
          lessThanOrEqualTo(420),
        );
        final primary = tester.widget<FilledButton>(
          find.widgetWithText(
            FilledButton,
            prepared ? 'Remove from checklist' : 'Yes, mark as prepared',
          ),
        );
        expect(
          primary.style!.backgroundColor!.resolve({}),
          AppTheme.primaryBlue,
        );
        expect(primary.style!.foregroundColor!.resolve({}), Colors.white);
        await confirm(tester, remove: prepared);
      }
    },
  );

  testWidgets(
    'confirmation and Cancel preserve readiness; confirming autosaves and reloads without Inventory writes',
    (tester) async {
      await show(tester);
      expect(find.text('You have this'), findsNothing);
      expect(box(tester, 550).value, isFalse);
      await tapItem(tester, 550);
      expect(find.text('Confirm requirement'), findsOneWidget);
      expect(
        find.text(
          'Are you sure you already have this requirement and want to mark it as prepared for this application?',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'This only updates your checklist for this application. It will not change your saved Inventory.',
        ),
        findsOneWidget,
      );
      expect(writes, isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(box(tester, 550).value, isFalse);
      expect(find.text('Not yet complete'), findsOneWidget);
      await tapItem(tester, 550);
      await confirm(tester);
      expect(box(tester, 550).value, isTrue);
      expect(find.text('1 of 2 prepared'), findsOneWidget);
      expect(writes, hasLength(1));
      expect(auth.inventoryRevision, 0);
      expect(owned, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await show(tester);
      expect(box(tester, 550).value, isTrue);
      expect(find.text('1 of 2 prepared'), findsOneWidget);
    },
  );

  testWidgets(
    'owned defaults refresh both the checklist and yellow percentage',
    (tester) async {
      owned = [1];
      await show(tester, overview: true);
      expect(box(tester, 550).value, isTrue);
      expect(find.text('50%'), findsOneWidget);
      owned = [];
      auth.inventoryRevision++;
      auth.user = {'id': 1};
      await tester.pumpAndSettle();
      expect(box(tester, 550).value, isFalse);
      expect(find.text('0%'), findsOneWidget);
      expect(writes, isEmpty);
    },
  );

  testWidgets(
    'unchecking requires confirmation and autosaves while retaining owned Inventory',
    (tester) async {
      owned = [1];
      await show(tester);
      expect(box(tester, 550).value, isTrue);
      expect(writes, isEmpty);
      expect(find.text('You have this'), findsNothing);
      await tapItem(tester, 550);
      expect(find.text('Remove from checklist?'), findsOneWidget);
      expect(
        find.text(
          'This requirement is already added to your Own IDs/Documents. Unchecking it only removes it from this application’s checklist.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Your saved Inventory will not be changed.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(box(tester, 550).value, isTrue);
      expect(writes, isEmpty);
      await tapItem(tester, 550);
      await confirm(tester, remove: true);
      expect(box(tester, 550).value, isFalse);
      expect(find.text('Added to Own IDs/Documents'), findsOneWidget);
      expect(owned, [1]);
      expect(stored['government_id:55']![550], isFalse);
      await tester.pumpWidget(const SizedBox());
      await show(tester);
      expect(box(tester, 550).value, isFalse);
      expect(owned, [1]);
    },
  );

  testWidgets(
    'custom preparation persists and Overview refreshes immediately after saved changes',
    (tester) async {
      stored['government_id:55'] = {550: true};
      await show(tester, overview: true);
      expect(find.text('50%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .color,
        AppTheme.accentGold,
      );
      expect(find.text('0 of 1 required groups prepared'), findsNWidgets(2));
      await tapItem(tester, 551);
      await confirm(tester);
      expect(find.text('Requirement met'), findsOneWidget);
      expect(find.text('1 of 1 required groups prepared'), findsNWidgets(2));
      expect(stored['government_id:55']![551], isTrue);
      expect(find.text('100%'), findsOneWidget);
      expect(
        tester
            .widget<CircularProgressIndicator>(
              find.byType(CircularProgressIndicator),
            )
            .value,
        1,
      );
      await tester.pumpWidget(const SizedBox());
      await show(tester);
      expect(box(tester, 551).value, isTrue);
      expect(find.text('Requirement met'), findsOneWidget);
    },
  );

  testWidgets(
    'different targets and target types preserve separate selections',
    (tester) async {
      stored['government_id:55'] = {550: true};
      await show(tester);
      expect(box(tester, 550).value, isTrue);
      await show(tester, id: 56);
      expect(box(tester, 560).value, isFalse);
      await show(tester, type: 'document');
      expect(box(tester, 550).value, isFalse);
      await show(tester);
      expect(box(tester, 550).value, isTrue);
      expect(writes, isEmpty);
    },
  );

  testWidgets(
    'failed autosave rolls back optimistic state and leaves inventory and saved readiness unchanged',
    (tester) async {
      await show(tester);
      pending = Completer<http.Response>();
      await tapItem(tester, 551);
      await tester.tap(find.text('Yes, mark as prepared'));
      await tester.pumpAndSettle();
      expect(box(tester, 551).value, isTrue);
      expect(find.text('Saving…'), findsOneWidget);
      expect(box(tester, 550).onChanged, isNull);
      pending!.complete(http.Response('{}', 503));
      await tester.pumpAndSettle();
      expect(box(tester, 551).value, isFalse);
      expect(find.text('Not yet complete'), findsOneWidget);
      expect(
        find.text(
          'Could not save your checklist. Your previous selection was restored. Please try again.',
        ),
        findsOneWidget,
      );
      expect(stored['government_id:55'], isEmpty);
      expect(auth.preparationRevision, 0);
      expect(owned, isEmpty);
    },
  );

  testWidgets('failed uncheck restores the previous prepared selection', (
    tester,
  ) async {
    stored['government_id:55'] = {550: true};
    await show(tester);
    fail = true;
    await tapItem(tester, 550);
    await confirm(tester, remove: true);
    expect(box(tester, 550).value, isTrue);
    expect(stored['government_id:55']![550], isTrue);
    expect(owned, isEmpty);
  });

  testWidgets('narrow large-text layout and both dialogs remain usable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 650);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await show(tester, scale: 2, overview: true);
    await tapItem(tester, 551);
    await confirm(tester);
    await tapItem(tester, 551);
    await confirm(tester, remove: true);
    expect(box(tester, 551).value, isFalse);
    expect(tester.takeException(), isNull);
  });
}
