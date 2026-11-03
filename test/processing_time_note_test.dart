import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';

void main() {
  for (final type in ['government_id', 'document']) {
    for (final note in [null, '', '   ', '  HIT verification may delay release.  ']) {
      testWidgets('$type displays only a nonblank processing note: $note', (tester) async {
        final record = GovernmentIdDetails.fromJson({
          'id': 1,
          'name': 'Processing fixture',
          'record_type': type,
          'processing_time': '1–10 working days',
          if (note != null) 'processing_time_note': note,
        });
        final hasNote = note != null && note.trim().isNotEmpty;
        expect(record.processingTimeNote, hasNote ? note.trim() : null);
        await tester.pumpWidget(MaterialApp(home: IdDetailsScreen(
          idName: record.name,
          governmentId: 1,
          recordType: type,
          loadDetail: (_) async => record,
        )));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('1–10 working days'), 200,
            scrollable: find.byType(Scrollable).first);
        expect(find.text('1–10 working days'), findsOneWidget);
        expect(find.text('HIT verification may delay release.'), hasNote ? findsOneWidget : findsNothing);
        if (hasNote) {
          expect(tester.getTopLeft(find.text('HIT verification may delay release.')).dy,
              greaterThan(tester.getTopLeft(find.text('1–10 working days')).dy));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }
}
