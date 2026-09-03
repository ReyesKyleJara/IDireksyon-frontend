import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/main.dart';

void main() {
  testWidgets('IDireksyon app launches', (WidgetTester tester) async {
    await tester.pumpWidget(const IDireksyonApp());

    expect(find.text('IDireksyon'), findsOneWidget);
  });
}