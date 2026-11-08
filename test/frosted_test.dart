import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/widgets/frosted.dart';

Widget _app({bool highContrast = false}) => MediaQuery(
  data: MediaQueryData(highContrast: highContrast),
  child: const MaterialApp(
    home: Scaffold(body: FrostedSurface(child: Text('Surface'))),
  ),
);

void main() {
  testWidgets('blurs normally', (tester) async {
    await tester.pumpWidget(_app());
    expect(find.byType(BackdropFilter), findsOneWidget);
  });

  testWidgets('high contrast removes the blur', (tester) async {
    await tester.pumpWidget(_app(highContrast: true));
    expect(find.byType(BackdropFilter), findsNothing);
  });
}
