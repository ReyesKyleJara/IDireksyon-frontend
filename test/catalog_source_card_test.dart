import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/catalog_source_card.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

/// The exact source saved for Government ID #55 in the Passport pilot.
Map<String, dynamic> passportSource() => {
  'title': 'Public reference: DFA – Passport General Information',
  'url': 'https://consular.dfa.gov.ph/passport-general-information/',
  'checked_on': '2026-11-13',
  'scope': 'Public DFA web page on passport applications. Not yet confirmed directly with DFA.',
  'published_on': null,
  'section': 'Passport General Information',
};

Widget host(Widget child, {ThemeData? theme}) => MaterialApp(
  theme: theme,
  home: Scaffold(body: ListView(children: [child])),
);

Widget card(Map<String, dynamic> source, {ThemeData? theme}) => host(
  CatalogSourceCard(
    source: source,
    recordName: 'Philippine Passport',
    agencyName: 'Department of Foreign Affairs',
  ),
  theme: theme,
);

/// GitHub main's link is a TextButton.icon, a subclass of TextButton.
final linkButtons = find.byWidgetPredicate((widget) => widget is TextButton);

Iterable<String> visibleText(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

void main() {
  testWidgets('shows the Passport pilot as a compact public reference', (
    tester,
  ) async {
    final source = passportSource();
    final stored = jsonEncode(source);
    await tester.pumpWidget(card(source));

    expect(find.text('Philippine Passport'), findsOneWidget);
    expect(find.text('Department of Foreign Affairs'), findsOneWidget);
    expect(find.text('Public reference'), findsOneWidget);
    expect(find.text('DFA – Passport General Information'), findsOneWidget);
    expect(find.text('View DFA webpage'), findsOneWidget);
    expect(find.byIcon(Icons.open_in_new_rounded), findsOneWidget);
    expect(
      find.text(
        'Public DFA web page on passport applications. Not yet confirmed directly with DFA.',
      ),
      findsOneWidget,
    );
    expect(find.text('Checked on 13 Nov 2026'), findsOneWidget);

    // The repeated label, raw URL, old prefixes and redundant section are hidden.
    expect(
      find.text('Public reference: DFA – Passport General Information'),
      findsNothing,
    );
    expect(find.textContaining('https://'), findsNothing);
    expect(find.textContaining('Checked:'), findsNothing);
    expect(find.textContaining('Supports:'), findsNothing);
    expect(find.textContaining('Page / section'), findsNothing);
    expect(find.text('Passport General Information'), findsNothing);

    // Display changes never rewrite the stored CMS value.
    expect(jsonEncode(source), stored);
  });

  testWidgets('Overview renders saved sources with the new card', (
    tester,
  ) async {
    final record = GovernmentIdDetails.fromJson({
      'id': 55,
      'name': 'Philippine Passport',
      'issued_by': 'Department of Foreign Affairs',
      'research_metadata': {
        'status': 'draft',
        'hidden_sections': [],
        'validity_note': null,
        'sources': [passportSource()],
      },
    });
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
    await tester.scrollUntilVisible(
      find.text('Checked on 13 Nov 2026'),
      300,
      scrollable: find.byType(Scrollable).last,
    );

    expect(find.byType(CatalogSourceCard), findsOneWidget);
    expect(find.text('View DFA webpage'), findsOneWidget);
    expect(find.textContaining('Checked:'), findsNothing);
  });

  testWidgets('keeps the URL safety checks for unsafe links', (tester) async {
    for (final url in [
      'javascript:alert(1)',
      'ftp://example.gov.ph/file',
      'https://user:secret@example.gov.ph/',
      'not a url',
      '',
    ]) {
      await tester.pumpWidget(card({...passportSource(), 'url': url}));
      expect(linkButtons, findsNothing, reason: url);
      expect(find.text('View DFA webpage'), findsNothing, reason: url);
      // The rest of the reference stays readable.
      expect(find.text('Public reference'), findsOneWidget, reason: url);
    }
  });

  testWidgets('safe http and https links stay tappable', (tester) async {
    for (final url in [
      'https://consular.dfa.gov.ph/passport-general-information/',
      'http://example.gov.ph/page',
    ]) {
      await tester.pumpWidget(card({...passportSource(), 'url': url}));
      expect(linkButtons, findsOneWidget, reason: url);
    }
  });

  testWidgets('shows a section only when it adds information', (tester) async {
    await tester.pumpWidget(
      card({...passportSource(), 'section': 'Requirements for minors'}),
    );
    expect(find.text('Requirements for minors'), findsOneWidget);
  });

  testWidgets('handles missing optional fields', (tester) async {
    await tester.pumpWidget(
      host(
        const CatalogSourceCard(
          source: {
            'title': 'PSA civil registration',
            'url': 'https://psa.gov.ph/',
          },
          recordName: 'PSA Birth Certificate',
        ),
      ),
    );
    expect(find.text('PSA civil registration'), findsOneWidget);
    expect(find.text('View source webpage'), findsOneWidget);
    expect(find.text('Checked date not recorded'), findsOneWidget);
    expect(find.text('Public reference'), findsOneWidget);
  });

  testWidgets('uses the IDireksyon light and dark theme colours', (
    tester,
  ) async {
    await tester.pumpWidget(card(passportSource()));
    expect(
      tester.widget<Text>(find.text('Public reference')).style?.color,
      AppTheme.primaryBlue,
    );

    final dark = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppTheme.primaryBlue,
        brightness: Brightness.dark,
      ),
    );
    await tester.pumpWidget(card(passportSource(), theme: dark));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.text('Public reference')).style?.color,
      dark.colorScheme.primary,
    );
    expect(
      tester.widget<Card>(find.byType(Card)).color,
      dark.colorScheme.surfaceContainer,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('card wording never claims verification or endorsement', (
    tester,
  ) async {
    await tester.pumpWidget(
      card({
        'title': 'DFA – Passport General Information',
        'url': 'https://consular.dfa.gov.ph/',
        'checked_on': '2026-11-13',
      }),
    );
    final banned = RegExp(
      r'verified|approved|endorsed|official|confirmed|certified',
      caseSensitive: false,
    );
    for (final text in visibleText(tester)) {
      expect(banned.hasMatch(text), isFalse, reason: text);
    }
  });

  for (final dark in [false, true]) {
    testWidgets('fits a narrow large-text screen (dark=$dark)', (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 900),
            textScaler: TextScaler.linear(2),
          ),
          child: card({
            ...passportSource(),
            'title': 'Public reference: PhilHealth – Member Data Record and Online Member Services Information Page',
            'section':
                'Frequently asked questions about the Member Data Record',
          }, theme: dark ? ThemeData(brightness: Brightness.dark) : null),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('View PhilHealth webpage'), findsOneWidget);
    });
  }

  group('display helpers', () {
    test('removes only a leading repeated label', () {
      expect(
        CatalogSourceCard.displayTitle(
          'Public reference: DFA – Passport General Information',
        ),
        'DFA – Passport General Information',
      );
      expect(
        CatalogSourceCard.displayTitle('public reference - SSS – MySSS Card'),
        'SSS – MySSS Card',
      );
      expect(
        CatalogSourceCard.displayTitle('NBI – Public reference: guide'),
        'NBI – Public reference: guide',
      );
      expect(
        CatalogSourceCard.displayTitle('Public reference:'),
        'Public reference:',
      );
    });

    test('derives agency link labels with a neutral fallback', () {
      expect(
        CatalogSourceCard.linkLabel(
          'Public reference: DFA – Passport General Information',
        ),
        'View DFA webpage',
      );
      expect(
        CatalogSourceCard.linkLabel('Pag-IBIG Fund – Membership'),
        'View Pag-IBIG Fund webpage',
      );
      expect(
        CatalogSourceCard.linkLabel('Passport General Information'),
        'View source webpage',
      );
      expect(
        CatalogSourceCard.linkLabel(
          'Department of Foreign Affairs Office of Consular Affairs – Passports',
        ),
        'View source webpage',
      );
    });

    test('formats only valid saved dates', () {
      expect(
        CatalogSourceCard.checkedLabel('2026-11-13'),
        'Checked on 13 Nov 2026',
      );
      expect(
        CatalogSourceCard.checkedLabel('2026-01-05'),
        'Checked on 5 Jan 2026',
      );
      for (final value in [null, '', '13/11/2026', '2026-13-01']) {
        expect(
          CatalogSourceCard.checkedLabel(value),
          'Checked date not recorded',
        );
      }
    });
  });
}
