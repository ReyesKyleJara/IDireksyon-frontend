import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/api_config.dart';
import 'package:idireksyon_frontend/core/widgets/catalog_image.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

const _address = '/api/catalog-images/abc.jpg';

void main() {
  test('image address uses the API server and is optional', () {
    final record = GovernmentIdDetails.fromJson({
      'id': 1,
      'image_url': _address,
    });
    expect(
      record.imageUrl,
      Uri.parse(ApiConfig.baseUrl).resolve(_address).toString(),
    );
    expect(GovernmentIdDetails.fromJson({'id': 1}).imageUrl, isNull);
    expect(
      GovernmentIdDetails.fromJson({'id': 1, 'image_url': ''}).imageUrl,
      isNull,
    );
  });

  testWidgets('image fills a fixed square without stretching', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: CatalogImage(
            url: 'http://localhost/a.jpg',
            size: 56,
            fallback: Text('fallback'),
          ),
        ),
      ),
    );
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.cover);
    expect(tester.getSize(find.byType(CatalogImage)), const Size.square(56));
  });

  testWidgets('a missing or unreachable image falls back to the icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CatalogImage(url: null, size: 56, fallback: Text('fallback')),
      ),
    );
    expect(find.text('fallback'), findsOneWidget);
    expect(find.byType(Image), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(
        home: CatalogImage(
          url: 'http://localhost/missing.jpg',
          size: 56,
          fallback: Text('fallback'),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();
    expect(find.text('fallback'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('directory shows a saved image at one consistent size', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: IdsScreen(
            initialFilter: 'IDs',
            loadIds: () async => [
              GovernmentIdDetails.fromJson({
                'id': 1,
                'name': 'With image',
                'image_url': _address,
              }),
              GovernmentIdDetails.fromJson({'id': 2, 'name': 'No image'}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final images = find.byType(CatalogImage);
    expect(images, findsNWidgets(2));
    expect(tester.getSize(images.first), tester.getSize(images.last));
    expect(tester.takeException(), isNull);
  });
}
