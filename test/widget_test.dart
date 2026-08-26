import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/app.dart';

void main() {
  testWidgets('home screen renders all bottom nav tabs', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const IDireksyonApp());

    expect(find.text('Requirement Checker'), findsOneWidget);
    expect(find.text('ID Sequencing'), findsOneWidget);
    expect(find.text('Document Readiness'), findsOneWidget);
    expect(find.text('Office Map'), findsOneWidget);
  });
}
