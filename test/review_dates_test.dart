import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/ids/catalog_source_card.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/review_dates_note.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

/// Fake API data only.
GovernmentIdDetails details(Map<String, dynamic> extra) =>
    GovernmentIdDetails.fromJson({
      'id': 55,
      'name': 'Fixture Passport',
      'issued_by': 'Fixture Agency',
      'research_metadata': {
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

Iterable<String> texts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((text) => text.data ?? text.textSpan?.toPlainText() ?? '');

Future<void> pumpNote(WidgetTester tester, ReviewDates dates) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(body: ReviewDatesNote(dates: dates)),
    ),
  );
}

void main() {
  group('parsing', () {
    test('reads both dates and the updated-since-review flag', () {
      final dates = ReviewDates.tryParse({
        'last_updated_at': '2026-11-07T00:00:00.000000Z',
        'last_reviewed_at': '2026-11-05T00:00:00.000000Z',
        'updated_since_review': true,
      })!;
      expect(dates.lastUpdated, DateTime.utc(2026, 11, 7).toLocal());
      expect(dates.lastReviewed, DateTime.utc(2026, 11, 5).toLocal());
      expect(dates.updatedSinceReview, isTrue);
    });

    test('older or malformed responses show nothing', () {
      expect(details({}).reviewDates, isNull);
      expect(ReviewDates.tryParse(null), isNull);
      expect(ReviewDates.tryParse('2026-11-07'), isNull);
      expect(
        ReviewDates.tryParse({
          'last_updated_at': 'not a date',
          'last_reviewed_at': 12,
        }),
        isNull,
      );
    });
  });

  group('ReviewDatesNote', () {
    testWidgets('shows both dates and when the record changed after review', (
      tester,
    ) async {
      await pumpNote(
        tester,
        ReviewDates(
          lastUpdated: DateTime(2026, 11, 7),
          lastReviewed: DateTime(2026, 11, 5),
          updatedSinceReview: true,
        ),
      );
      expect(find.text('Last updated: 7 Nov 2026'), findsOneWidget);
      expect(
        find.text('Last reviewed by the IDireksyon team: 5 Nov 2026'),
        findsOneWidget,
      );
      expect(find.text('Updated after the last review.'), findsOneWidget);
    });

    testWidgets('says when the team has not reviewed it yet', (tester) async {
      await pumpNote(tester, ReviewDates(lastUpdated: DateTime(2026, 11, 7)));
      expect(
        find.text('Not yet reviewed by the IDireksyon team'),
        findsOneWidget,
      );
      expect(find.text('Updated after the last review.'), findsNothing);
    });

    testWidgets('never claims agency verification or confirmation', (
      tester,
    ) async {
      await pumpNote(
        tester,
        ReviewDates(
          lastUpdated: DateTime(2026, 11, 7),
          lastReviewed: DateTime(2026, 11, 5),
          updatedSinceReview: true,
        ),
      );
      final shown = texts(tester).join(' ').toLowerCase();
      for (final word in [
        'verified',
        'confirmed',
        'official',
        'agency',
        'endorse',
      ]) {
        expect(shown, isNot(contains(word)));
      }
    });
  });

  testWidgets('appears on the Overview below the public reference card', (
    tester,
  ) async {
    final record = details({
      'review_dates': {
        'last_updated_at': '2026-11-07T00:00:00.000000Z',
        'last_reviewed_at': null,
        'updated_since_review': false,
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
      find.byType(ReviewDatesNote),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester.getTopLeft(find.byType(ReviewDatesNote)).dy,
      greaterThan(tester.getTopLeft(find.byType(CatalogSourceCard)).dy),
    );
  });
}
