import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('Directory fits narrow screen: dark=$dark, scale=$scale', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: Scaffold(body: IdsScreen(loadIds: () async => [
              GovernmentIdDetails.fromJson({'id': 34, 'name': 'Philippine Passport', 'description': 'Travel document'}),
              GovernmentIdDetails.fromJson({'id': 5, 'name': 'National ID', 'description': 'Identification'}),
            ])),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Featured IDs'), findsOneWidget);
        expect(find.text('All IDs'), findsOneWidget);
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Philippine Passport'), findsWidgets);
        expect(find.text('National ID'), findsWidgets);
        expect(find.text('Browse IDs'), findsNothing);
        expect(find.byType(ListView), findsOneWidget);
        if (dark) {
          final title = tester.widget<Text>(find.text('Philippine Passport').first);
          expect(title.style!.color!.computeLuminance(), greaterThan(0.5));
        }

      });
    }
  }
  testWidgets('shows directory heading and search while the first request is pending', (tester) async {
    final pending = Completer<List<GovernmentIdDetails>>();
    await tester.pumpWidget(MaterialApp(home: Scaffold(
      body: IdsScreen(loadIds: () => pending.future),
    )));
    expect(find.text('ID Directory'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Loading government IDs…'), findsOneWidget);
    pending.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('No Government IDs are available yet.'), findsOneWidget);
    expect(find.text('Loading government IDs…'), findsNothing);
  });

}

