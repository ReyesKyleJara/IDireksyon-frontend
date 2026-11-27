import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/agency_verification_card.dart';
import 'package:idireksyon_frontend/features/ids/catalog_source_card.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

/// Fake API data only. No real agency confirmation exists yet.
Map<String, dynamic> confirmationJson([
  Map<String, dynamic> overrides = const {},
]) => {
  'agency_name': 'Fixture Agency',
  'office_label': 'Fixture office',
  'outcome': 'partially_confirmed',
  'scope': 'Requirements for first-time applications (test fixture).',
  'confirmed_aspects': ['requirements'],
  'not_covered_aspects': [
    'eligibility',
    'fees',
    'processing_time',
    'validity',
    'application_process',
    'offices',
  ],
  'applies_to_all_request_paths': false,
  'request_paths': [
    {'id': 3, 'label': 'First-time application'},
  ],
  'confirmed_on': '2027-01-24',
  ...overrides,
};

Map<String, dynamic> field([List<Map<String, dynamic>>? confirmations]) => {
  'status': 'agency_confirmed',
  'confirmations': confirmations ?? [confirmationJson()],
};

Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: ListView(children: [child])),
);

AgencyConfirmation parsed([Map<String, dynamic> overrides = const {}]) =>
    AgencyConfirmation.tryParse(confirmationJson(overrides))!;

Iterable<String> visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

GovernmentIdDetails record(Map<String, dynamic> extra) =>
    GovernmentIdDetails.fromJson({
      'id': 55,
      'name': 'Fixture Passport',
      'issued_by': 'Fixture Agency',
      'research_metadata': {
        'status': 'draft',
        'hidden_sections': [],
        'sources': [
          {
            'title': 'Public reference: Fixture – General Information',
            'url': 'https://example.gov.ph/page',
            'checked_on': '2026-11-13',
          },
        ],
      },
      ...extra,
    });

Future<void> pumpOverview(
  WidgetTester tester,
  GovernmentIdDetails details,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: IdDetailsScreen(
        idName: details.name,
        governmentId: details.id,
        loadDetail: (_) async => details,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows one combined card with links and the approved date', (
    tester,
  ) async {
    await pumpOverview(
      tester,
      record({
        'agency_verification': field(),
        'verified_information': {
          'sources': [
            {'title': 'Official site', 'url': 'https://example.gov.ph/page'},
          ],
          'verification': {
            'office': 'Santa Maria Branch',
            'method': 'Phone Verification',
            'date': '2026-02-10',
          },
        },
      }),
    );

    expect(find.text('Verified Information'), findsOneWidget);
    expect(find.text('Last verified: February 10, 2026'), findsOneWidget);
    expect(find.text('Phone Verification'), findsOneWidget);
    expect(find.text('Santa Maria Branch'), findsOneWidget);
    final link = tester.widget<CatalogOfficialLink>(
      find.byWidgetPredicate(
        (widget) =>
            widget is CatalogOfficialLink && widget.label == 'Official site',
      ),
    );
    expect(link.url, 'https://example.gov.ph/page');
    expect(find.byType(CatalogSourceCard), findsNothing);
    expect(find.byType(AgencyVerificationCard), findsNothing);
  });

  testWidgets('uses Official References for website sources alone', (
    tester,
  ) async {
    await pumpOverview(
      tester,
      record({
        'verified_information': {
          'sources': [
            {'title': 'Official site', 'url': 'https://example.gov.ph/page'},
          ],
          'verification': null,
        },
      }),
    );

    expect(find.text('Official References'), findsOneWidget);
    expect(find.text('Verified Information'), findsNothing);
    expect(find.textContaining('Last verified'), findsNothing);
  });

  group('parsing', () {
    test('reads a current confirmation from the API field', () {
      final list = AgencyConfirmation.listFrom(field());

      expect(list, hasLength(1));
      final c = list.single;
      expect(c.agencyName, 'Fixture Agency');
      expect(c.officeLabel, 'Fixture office');
      expect(c.confirmedAspects, ['requirements']);
      expect(c.notCoveredAspects, contains('fees'));
      expect(c.appliesToAllRequestPaths, isFalse);
      expect(c.requestPathLabels, ['First-time application']);
      expect(c.confirmedOnLabel, '24 Jan 2027');
      expect(c.isPartial, isTrue);
    });

    test(
      'treats missing, null, empty and older responses as no confirmation',
      () {
        for (final value in <dynamic>[
          null,
          '',
          [],
          <String, dynamic>{},
          {'status': null, 'confirmations': []},
          {
            'status': 'agency_confirmation_pending',
            'confirmations': [confirmationJson()],
          },
          {
            'status': 'needs_review',
            'confirmations': [confirmationJson()],
          },
          {'status': 'agency_confirmed'},
          {'status': 'agency_confirmed', 'confirmations': 'not a list'},
          {'status': 'agency_confirmed', 'confirmations': []},
        ]) {
          expect(AgencyConfirmation.listFrom(value), isEmpty, reason: '$value');
        }
        expect(record({}).agencyConfirmations, isEmpty);
        expect(
          record({'agency_verification': null}).agencyConfirmations,
          isEmpty,
        );
      },
    );

    test('skips confirmations missing who, what or the exact scope', () {
      final list = AgencyConfirmation.listFrom(
        field([
          confirmationJson({'agency_name': ''}),
          confirmationJson({'agency_name': null}),
          confirmationJson({'scope': '  '}),
          confirmationJson({'confirmed_aspects': []}),
          confirmationJson({'confirmed_aspects': 'requirements'}),
          {'unexpected': true},
          confirmationJson({'agency_name': 'Kept Agency'}),
        ]),
      );

      expect(list.map((c) => c.agencyName), ['Kept Agency']);
    });

    test('handles unknown aspects, bad dates and overlapping lists safely', () {
      final c = parsed({
        'confirmed_aspects': ['requirements', 'new_aspect', 'requirements'],
        'not_covered_aspects': ['requirements', 'fees'],
        'confirmed_on': '2027-02-30',
        'applies_to_all_request_paths': true,
        'request_paths': 'broken',
      });

      expect(c.confirmedAspects, ['requirements', 'new_aspect']);
      expect(AgencyConfirmation.aspectLabel('new_aspect'), 'New aspect');
      expect(c.notCoveredAspects, ['fees']);
      expect(c.confirmedOn, isNull);
      expect(c.confirmedOnLabel, 'Date not recorded');
      expect(c.appliesToAllRequestPaths, isTrue);
      expect(c.requestPathLabels, isEmpty);
    });
  });

  group('card', () {
    testWidgets('states exactly what was confirmed, for which paths and when', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AgencyVerificationCard(confirmation: parsed())),
      );

      expect(
        find.text('Information Confirmed with Fixture Agency'),
        findsOneWidget,
      );
      expect(find.text('Fixture office'), findsOneWidget);
      expect(find.text('Partial confirmation'), findsOneWidget);
      expect(find.text('Confirmed by the agency'), findsOneWidget);
      expect(find.text('Requirements'), findsOneWidget);
      expect(find.text('Not covered by this confirmation'), findsOneWidget);
      expect(
        find.text(
          'Eligibility, Fees, Processing time, Validity, Application process, Offices',
        ),
        findsOneWidget,
      );
      expect(find.text('First-time application'), findsOneWidget);
      expect(
        find.text('“Requirements for first-time applications (test fixture).”'),
        findsOneWidget,
      );
      expect(find.text('24 Jan 2027'), findsOneWidget);
      expect(find.text(AgencyVerificationCard.partialNotice), findsOneWidget);
      expect(find.text(AgencyVerificationCard.disclaimer), findsOneWidget);
    });

    testWidgets('keeps the disclaimer even for a full confirmation', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          AgencyVerificationCard(
            confirmation: parsed({
              'outcome': 'confirmed',
              'confirmed_aspects': AgencyConfirmation.aspectLabels.keys
                  .toList(),
              'not_covered_aspects': [],
              'applies_to_all_request_paths': true,
              'request_paths': [],
            }),
          ),
        ),
      );

      expect(find.text('Partial confirmation'), findsNothing);
      expect(find.text(AgencyVerificationCard.partialNotice), findsNothing);
      expect(find.text('Not covered by this confirmation'), findsNothing);
      expect(find.text('All ways to apply in this guide'), findsOneWidget);
      expect(find.text(AgencyVerificationCard.disclaimer), findsOneWidget);
    });

    testWidgets('never uses approval or endorsement claims, seals or logos', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AgencyVerificationCard(confirmation: parsed())),
      );
      final banned = RegExp(
        r'verified|approved|approval|official|certified|accredited|endorsed|seal|partner',
        caseSensitive: false,
      );

      for (final text in visibleText(tester)) {
        expect(banned.hasMatch(text), isFalse, reason: text);
      }
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(Icons.verified), findsNothing);
      expect(find.byIcon(Icons.verified_user), findsNothing);
    });

    testWidgets('uses the IDireksyon light and dark theme colours', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(AgencyVerificationCard(confirmation: parsed())),
      );
      expect(
        tester.widget<Text>(find.text('Confirmed by the agency')).style?.color,
        AppTheme.primaryBlue,
      );

      final dark = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primaryBlue,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpWidget(
        host(AgencyVerificationCard(confirmation: parsed()), theme: dark),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<Text>(find.text('Confirmed by the agency')).style?.color,
        dark.colorScheme.primary,
      );
      expect(
        tester.widget<Card>(find.byType(Card)).color,
        dark.colorScheme.surfaceContainer,
      );
    });

    testWidgets('marks the heading for screen readers', (tester) async {
      await tester.pumpWidget(
        host(AgencyVerificationCard(confirmation: parsed())),
      );
      final heading = tester.widget<Semantics>(
        find
            .ancestor(
              of: find.text('Information Confirmed with Fixture Agency'),
              matching: find.byType(Semantics),
            )
            .first,
      );

      expect(heading.properties.header, isTrue);
    });

    for (final darkMode in [false, true]) {
      testWidgets('fits a narrow large-text screen (dark=$darkMode)', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 1400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1400),
              textScaler: TextScaler.linear(2),
            ),
            child: host(
              AgencyVerificationCard(
                confirmation: parsed({
                  'agency_name': 'Fixture Department of a Very Long Agency Name for Testing',
                  'request_paths': [
                    {
                      'id': 1,
                      'label': 'First-time application for adults applying in person',
                    },
                    {
                      'id': 2,
                      'label': 'Renewal through the online appointment system',
                    },
                  ],
                }),
              ),
              theme: darkMode ? ThemeData(brightness: Brightness.dark) : null,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Overview', () {
    testWidgets('shows the card below the public reference cards', (
      tester,
    ) async {
      await pumpOverview(tester, record({'agency_verification': field()}));
      await tester.scrollUntilVisible(
        find.text(AgencyVerificationCard.disclaimer),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.byType(AgencyVerificationCard), findsOneWidget);
      expect(find.byType(CatalogSourceCard), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(AgencyVerificationCard)).dy,
        greaterThan(tester.getTopLeft(find.byType(CatalogSourceCard)).dy),
      );
    });

    testWidgets('shows nothing extra without a current confirmation', (
      tester,
    ) async {
      for (final extra in <Map<String, dynamic>>[
        {},
        {'agency_verification': null},
        {
          'agency_verification': {'status': null, 'confirmations': []},
        },
      ]) {
        await pumpOverview(tester, record(extra));
        await tester.scrollUntilVisible(
          find.byType(CatalogSourceCard),
          300,
          scrollable: find.byType(Scrollable).last,
        );
        expect(
          find.byType(AgencyVerificationCard),
          findsNothing,
          reason: '$extra',
        );
        expect(find.textContaining('Information Confirmed with'), findsNothing);
      }
    });

    testWidgets('shows one card per confirmation', (tester) async {
      await pumpOverview(
        tester,
        record({
          'agency_verification': field([
            confirmationJson(),
            confirmationJson({
              'agency_name': 'Second Fixture Office',
              'confirmed_aspects': ['fees'],
              'not_covered_aspects': [],
            }),
          ]),
        }),
      );
      await tester.scrollUntilVisible(
        find.text('Information Confirmed with Second Fixture Office'),
        300,
        scrollable: find.byType(Scrollable).last,
      );

      expect(find.byType(AgencyVerificationCard), findsNWidgets(2));
    });
  });
}
