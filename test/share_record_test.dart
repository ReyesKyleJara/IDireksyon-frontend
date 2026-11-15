import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/api_config.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

/// Fake API data only.
void main() {
  group('share link', () {
    test('uses the public website for the hosted backend', () {
      expect(
        ApiConfig.shareUrl(
          recordType: 'government_id',
          id: 56,
          apiBase: 'https://idireksyon-backend-production.up.railway.app/api',
        ),
        'https://www.idireksyon.online/ids/56',
      );
      expect(
        ApiConfig.shareUrl(
          recordType: 'document',
          id: 28,
          apiBase: 'https://www.idireksyon.online/api',
        ),
        'https://www.idireksyon.online/documents/28',
      );
    });

    test('keeps a local server address while developing', () {
      expect(
        ApiConfig.shareUrl(
          recordType: 'government_id',
          id: 1,
          apiBase: 'http://127.0.0.1:8000/api',
        ),
        'http://127.0.0.1:8000/ids/1',
      );
    });
  });

  testWidgets('the share button sends the record name and its public link', (
    tester,
  ) async {
    final shared = <(String, String)>[];
    final record = GovernmentIdDetails.fromJson({
      'id': 56,
      'name': 'Fixture National ID',
      'issued_by': 'Fixture Agency',
    });
    await tester.pumpWidget(
      MaterialApp(
        home: IdDetailsScreen(
          idName: record.name,
          governmentId: record.id,
          loadDetail: (_) async => record,
          shareRecord: (text, subject) async => shared.add((text, subject)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Share'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('share-record')));
    await tester.pump();

    expect(shared, hasLength(1));
    expect(shared.single.$2, 'Fixture National ID');
    expect(shared.single.$1, contains('Fixture National ID'));
    expect(shared.single.$1, contains('/ids/56'));
    // Only the public link is shared: nothing about the resident.
    expect(shared.single.$1.toLowerCase(), isNot(contains('token')));
  });
}
