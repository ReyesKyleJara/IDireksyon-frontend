import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

Map<String, dynamic> detail(String type) => {
  'id': 1,
  'name': 'Detail fixture',
  'record_type': type,
  'application_availability': 'available',
  'acquisition_type': 'profession_based',
  'category': 'Hidden category',
  'level': 'Hidden government level',
  'resident_notice': 'Hidden research notice',
  'eligibility': 'Residents aged 18 and above',
  'validity': 'Five years',
  'processing_time': '10 working days',
  'fees': [
    {'id': 1, 'label': 'General fee', 'type': 'fixed', 'amount_min': 100},
    {
      'id': 2,
      'label': 'Method delivery fee',
      'type': 'fixed',
      'amount_min': 50,
    },
  ],
  'request_paths': [
    {
      'id': 10,
      'label': 'Online method',
      'is_request_method': true,
      'fee_ids': [2],
      'fees': [
        {
          'id': 2,
          'label': 'Method delivery fee',
          'type': 'fixed',
          'amount_min': 50,
        },
      ],
    },
  ],
};

Future<void> showDetail(
  WidgetTester tester,
  Map<String, dynamic> json, {
  bool dark = false,
  double scale = 1,
}) async {
  final record = GovernmentIdDetails.fromJson(json);
  await tester.pumpWidget(
    MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: IdDetailsScreen(
        idName: record.name,
        governmentId: record.id,
        recordType: record.recordType,
        loadDetail: (_) async => record,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final type in ['government_id', 'document']) {
    testWidgets(
      '$type hides administrative facts and keeps important information',
      (tester) async {
        await showDetail(tester, detail(type));
        for (final text in [
          'Application Availability',
          'Acquisition Type',
          'Category',
          'Government Level',
          'Research status',
          'Hidden research notice',
          'Hidden category',
          'Hidden government level',
          'Available',
          'Profession-Based',
        ]) {
          expect(find.text(text), findsNothing);
        }
        expect(find.text('Processing Time'), findsOneWidget);
        expect(find.text('10 working days'), findsOneWidget);
        expect(find.text('Eligibility'), findsOneWidget);
        expect(find.text('Residents aged 18 and above'), findsOneWidget);
        expect(find.text('Validity'), findsOneWidget);
        expect(find.text('Five years'), findsOneWidget);
        expect(find.text('Ways to Request'), findsOneWidget);
        expect(find.text('Online method'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('$type shows general costs separately from method fees', (
      tester,
    ) async {
      await showDetail(tester, detail(type));
      await tester.tap(find.text('Estimated Cost'));
      await tester.pumpAndSettle();
      expect(find.text('General fee'), findsOneWidget);
      expect(find.text('Method delivery fee'), findsNothing);
      expect(find.text('Guide'), findsNothing);
      await tester.ensureVisible(find.text('Ways to Request'));
      await tester.tap(find.text('Ways to Request'));
      await tester.pumpAndSettle();
      expect(find.text('Ways to Request'), findsOneWidget);
      expect(find.text('Application Guide'), findsNothing);
      expect(find.text('Special Cases'), findsNothing);
      await tester.tap(find.text('Online method'));
      await tester.pumpAndSettle();
      expect(find.text('Method delivery fee'), findsOneWidget);
      expect(find.text('General fee'), findsNothing);
    });
  }

  for (final value in [
    '',
    '   ',
    'Not Applicable',
    'not_applicable',
    ' N/A ',
  ]) {
    testWidgets('empty or inapplicable facts are omitted: $value', (
      tester,
    ) async {
      await showDetail(tester, {
        ...detail('document'),
        'eligibility': value,
        'validity': value,
        'processing_time': value,
        'processing_time_note': value,
        'purpose': value,
        'fees': [],
        'request_paths': [],
      });
      for (final title in [
        'Processing Time',
        'Eligibility',
        'Validity',
        'Key information',
        'Purpose',
        'Guide',
      ]) {
        expect(find.text(title), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'encoded guide methods and special cases each have their own tab on narrow large-text screens',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final json = detail('document');
      await showDetail(
        tester,
        {
          ...json,
          'request_paths': [
            {
              'id': 20,
              'label': 'General application',
              'is_request_method': false,
              'guide': [
                {'id': 1, 'title': 'Submit the application', 'blocks': []},
              ],
            },
            ...(json['request_paths'] as List),
          ],
          'special_cases': [
            {
              'title': 'Delayed Registration of Birth',
              'description': 'When no birth record exists.',
              'action_label': 'Read the special case',
            },
          ],
        },
        dark: true,
        scale: 2,
      );
      await tester.ensureVisible(find.text('Guide'));
      await tester.tap(find.text('Guide'));
      await tester.pumpAndSettle();
      expect(find.text('Application Guide'), findsOneWidget);
      expect(find.text('Submit the application'), findsOneWidget);
      expect(find.text('Online method'), findsNothing);
      expect(find.text('Delayed Registration of Birth'), findsNothing);
      await tester.ensureVisible(find.text('Ways to Request'));
      await tester.tap(find.text('Ways to Request'));
      await tester.pumpAndSettle();
      expect(find.text('Online method'), findsOneWidget);
      expect(find.text('Application Guide'), findsNothing);
      expect(find.text('Delayed Registration of Birth'), findsNothing);
      await tester.ensureVisible(find.text('Special Cases'));
      await tester.tap(find.text('Special Cases'));
      await tester.pumpAndSettle();
      expect(find.text('Delayed Registration of Birth'), findsOneWidget);
      expect(find.text('Application Guide'), findsNothing);
      expect(find.text('Online method'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('an empty general guide does not create a section or tab', (
    tester,
  ) async {
    await showDetail(tester, {
      ...detail('document'),
      'request_paths': [
        {
          'id': 1,
          'label': 'Empty general application',
          'is_request_method': false,
          'guide': [],
        },
      ],
    });
    expect(find.text('Guide'), findsNothing);
    expect(find.text('Application Guide'), findsNothing);
  });

  testWidgets(
    'special cases alone create their own tab without creating Guide',
    (tester) async {
      await showDetail(tester, {
        ...detail('document'),
        'fees': [],
        'request_paths': [],
        'special_cases': [
          {
            'title': 'Delayed Registration of Birth',
            'description': 'When no record exists.',
            'action_label': 'View special case',
          },
        ],
      });
      final tabs = tester.widget<TabBar>(find.byType(TabBar));
      expect(tabs.tabs.cast<Tab>().map((tab) => tab.text), [
        'Overview',
        'Special Cases',
      ]);
      expect(find.text('Guide'), findsNothing);
      expect(find.text('Ways to Request'), findsNothing);
      await tester.tap(find.text('Special Cases'));
      await tester.pumpAndSettle();
      expect(find.text('Delayed Registration of Birth'), findsOneWidget);
      expect(find.text('Application Guide'), findsNothing);
    },
  );

  testWidgets('empty optional content leaves Overview without empty tabs', (
    tester,
  ) async {
    await showDetail(tester, {
      ...detail('government_id'),
      'fees': [],
      'request_paths': [],
      'offices': [],
      'special_cases': [],
    });
    expect(find.byType(TabBar), findsNothing);
    for (final label in [
      'Estimated Cost',
      'Offices',
      'Guide',
      'Ways to Request',
      'Special Cases',
    ]) {
      expect(find.text(label), findsNothing);
    }
  });
}
