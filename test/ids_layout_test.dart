import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/ids_screen.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
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
            home: Scaffold(
              body: IdsScreen(
                loadIds: () async => [
                  GovernmentIdDetails.fromJson({
                    'id': 34,
                    'name': 'Philippine Passport',
                    'description': 'Travel document',
                  }),
                  GovernmentIdDetails.fromJson({
                    'id': 5,
                    'name': 'National ID',
                    'description': 'Identification',
                  }),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Suggested for You'), findsNothing);
        final active = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'All'),
        );
        expect(active.selectedColor, AppTheme.accentGold);
        expect(
          (dark ? AppTheme.darkTheme : AppTheme.lightTheme)
              .colorScheme
              .tertiary,
          AppTheme.accentGold,
        );
        await tester.scrollUntilVisible(
          find.text('Commonly Needed'),
          150,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('Commonly Needed'), findsOneWidget);
        await tester.ensureVisible(find.text('National ID'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text('Passport'), findsWidgets);
        expect(find.text('National ID'), findsWidgets);
        expect(find.text('Browse IDs'), findsNothing);
        expect(find.byType(ListView), findsOneWidget);
        if (dark) {
          final title = tester.widget<Text>(find.text('Passport').first);
          expect(title.style!.color!.computeLuminance(), greaterThan(0.5));
          final cards = tester
              .widgetList<Material>(
                find.descendant(
                  of: find.byType(IdsScreen),
                  matching: find.byType(Material),
                ),
              )
              .where(
                (material) =>
                    material.shape is RoundedRectangleBorder &&
                    material.color != null,
              );
          expect(cards, isNotEmpty);
          for (final card in cards) {
            expect(card.color!.computeLuminance(), lessThan(0.2));
          }
        }
      });
    }
  }
  testWidgets(
    'shows directory heading and search while the first request is pending',
    (tester) async {
      final pending = Completer<List<GovernmentIdDetails>>();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: IdsScreen(loadIds: () => pending.future)),
        ),
      );
      expect(find.text('ID Directory'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Loading directory…'), findsOneWidget);
      pending.complete([]);
      await tester.pumpAndSettle();
      expect(
        find.text('No commonly needed guides are available yet.'),
        findsOneWidget,
      );
      expect(find.text('Loading directory…'), findsNothing);
    },
  );

  testWidgets(
    'full catalog search and filters include hidden documents and references',
    (tester) async {
      final records = [
        GovernmentIdDetails.fromJson({'id': 1, 'name': 'National ID'}),
        GovernmentIdDetails.fromJson({
          'id': 1,
          'name': 'NBI Clearance',
          'record_type': 'document',
        }),
        GovernmentIdDetails.fromJson({
          'id': 9,
          'name': 'Rare reference',
          'record_type': 'document',
          'guidance_mode': 'informational_only',
          'issued_by': 'Special Agency',
        }),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: IdsScreen(loadIds: () async => records)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rare reference'), findsNothing);
      expect(find.text('All IDs'), findsNothing);
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('NBI Clearance'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Special Agency');
      await tester.pumpAndSettle();
      expect(find.text('Rare reference'), findsOneWidget);
      expect(find.text('National ID'), findsNothing);
      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Documents'));
      await tester.pumpAndSettle();
      expect(find.text('NBI Clearance'), findsOneWidget);
      expect(find.text('Rare reference'), findsOneWidget);
      expect(find.text('National ID'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'IDs'));
      await tester.pumpAndSettle();
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('NBI Clearance'), findsNothing);
    },
  );

  testWidgets(
    'category browsing separates types and preserves document detail identity',
    (tester) async {
      final records = [
        GovernmentIdDetails.fromJson({'id': 1, 'name': 'National ID'}),
        GovernmentIdDetails.fromJson({
          'id': 1,
          'name': 'NBI Clearance',
          'record_type': 'document',
        }),
        GovernmentIdDetails.fromJson({
          'id': 8,
          'name': 'Reference ID',
          'guidance_mode': 'informational_only',
        }),
      ];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdsScreen(
              loadIds: () async => records,
              loadDetail: (_) async => records[1],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Government IDs'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Government IDs'));
      await tester.pumpAndSettle();
      expect(find.text('Reference ID'), findsOneWidget);
      expect(find.text('National ID'), findsOneWidget);
      expect(find.text('NBI Clearance'), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Documents & Certifications'),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Documents & Certifications'));
      await tester.pumpAndSettle();
      expect(find.text('NBI Clearance'), findsOneWidget);
      expect(find.text('National ID'), findsNothing);
      await tester.tap(find.text('NBI Clearance'));
      await tester.pumpAndSettle();
      final detail = tester.widget<IdDetailsScreen>(
        find.byType(IdDetailsScreen),
      );
      expect(detail.recordType, 'document');
      expect(detail.governmentId, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'missing readiness hides suggestions and offers no Ready Now filter',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: IdsScreen(
              loadIds: () async => [
                GovernmentIdDetails.fromJson({'id': 1, 'name': 'National ID'}),
              ],
              loadInventory: () async => {
                'government_ids': [],
                'documents': [],
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Suggested for You'), findsNothing);
      expect(
        find.textContaining('Readiness suggestions are unavailable'),
        findsNothing,
      );
      expect(find.widgetWithText(ChoiceChip, 'Ready Now'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'common cards shorten long catalog names without hiding accessible names',
    (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const name = 'PSA Birth Certificate with a very long catalog description';
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: Scaffold(
            body: IdsScreen(
              loadIds: () async => [
                GovernmentIdDetails.fromJson({
                  'id': 1,
                  'name': name,
                  'record_type': 'document',
                }),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Birth Certificate'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Birth Certificate'), findsOneWidget);
      expect(find.byTooltip(name), findsOneWidget);
      final label = tester.widget<Text>(find.text('Birth Certificate'));
      expect(label.maxLines, 2);
      expect(label.overflow, TextOverflow.ellipsis);
      expect(tester.takeException(), isNull);
    },
  );
}
