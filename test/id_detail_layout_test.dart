import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:idireksyon_frontend/core/auth/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/theme/app_theme.dart';
import 'package:idireksyon_frontend/features/ids/id_details_screen.dart';
import 'package:idireksyon_frontend/features/ids/requirements_tab.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

GovernmentIdDetails fixture() {
  final sets = [
    {
      'id': 1,
      'application_type': 'new',
      'applicant_type': 'all',
      'display_label': 'All applicants • First-time application',
      'groups': [
        {
          'id': 1,
          'title': 'Proof of identity and supporting documents',
          'condition_type': 'always',
          'ways': [
            {
              'id': 1,
              'required_count': 1,
              'items': [
                {
                  'type': 'document',
                  'document_id': 28,
                  'name': 'Birth Certificate',
                  'instructions': 'Bring a clear and legible copy.',
                },
              ],
            },
            {
              'id': 2,
              'required_count': 1,
              'items': [
                {
                  'type': 'government_id',
                  'government_id_id': 55,
                  'name': 'Passport',
                },
              ],
            },
          ],
        },
      ],
    },
  ];
  return GovernmentIdDetails.fromJson({
    'id': 56,
    'name': 'PhilSys National ID with a longer supporting title',
    'issued_by': 'Philippine Statistics Authority',
    'validity': 'No expiration',
    'purpose': 'Identity verification',
    'description': 'A supporting summary of the saved acquisition guide.',
    'processing_time':
        'Delivery depends on verification and the selected request channel.',
    'processing_time_note': 'Keep the reference slip and confirm the delivery details with the issuing agency.',
    'fees': [
      {'id': 1, 'label': 'Application fee', 'type': 'free'},
    ],
    'request_paths': [
      {
        'id': 1,
        'label': 'First-time application',
        'requirement_sets': sets,
        'fees': [
          {'id': 1, 'label': 'Application fee', 'type': 'free'},
        ],
        'guide': [
          {'id': 1, 'title': 'Visit the registration center', 'blocks': []},
        ],
      },
    ],
  });
}

void main() {
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'detail overview and tabs fit narrow screen dark=$dark scale=$scale',
        (tester) async {
          tester.view.physicalSize = const Size(320, 850);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final record = fixture();
          await tester.pumpWidget(
            MaterialApp(
              theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: IdDetailsScreen(
                idName: record.name,
                governmentId: record.id,
                loadDetail: (_) async => record,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expect(
            tester.widget<AppBar>(find.byType(AppBar)).backgroundColor,
            AppTheme.navy,
          );
          expect(
            tester
                .widget<ColoredBox>(
                  find.byKey(const ValueKey('detail-brand-header')),
                )
                .color,
            AppTheme.navy,
          );
          expect(find.text('Validity: No expiration'), findsNothing);
          expect(find.text('Typical use: Identity verification'), findsNothing);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('detail-brand-header')),
              matching: find.text(record.issuedBy!),
            ),
            findsOneWidget,
          );
          final tabs = tester.widget<TabBar>(find.byType(TabBar));
          expect(tabs.indicator, isNull);
          expect(tabs.indicatorColor, AppTheme.accentGold);
          expect(tabs.tabs.cast<Tab>().map((t) => t.text), [
            'Overview',
            'Requirements',
            'Estimated Cost',
            'Guide',
          ]);
          expect(find.text('Information'), findsNothing);
          final overview = find.byKey(const ValueKey('detail-overview-scroll'));
          expect(tester.getSize(overview).height, lessThanOrEqualTo(850 * .28));
          await tester.scrollUntilVisible(
            find.text(record.processingTimeNote!),
            80,
            scrollable: find.descendant(
              of: overview,
              matching: find.byType(Scrollable),
            ),
          );
          expect(find.text(record.processingTime!), findsOneWidget);
          expect(find.text(record.processingTimeNote!), findsOneWidget);
          final overviewContent = find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byType(Scrollable),
              )
              .first;
          for (final value in [record.validity!, record.purpose!]) {
            await tester.scrollUntilVisible(
              find.text(value),
              160,
              scrollable: overviewContent,
            );
            expect(find.text(value), findsOneWidget);
          }
          final titleY = tester
              .getTopLeft(find.byKey(const ValueKey('compact-id-title')))
              .dy;
          await tester.ensureVisible(find.text('Requirements'));
          await tester.tap(find.text('Requirements'));
          await tester.pumpAndSettle();
          await tester.drag(
            find.descendant(
              of: find.byType(RequirementsTab),
              matching: find.byType(ListView),
            ),
            const Offset(0, -180),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .getTopLeft(find.byKey(const ValueKey('compact-id-title')))
                .dy,
            titleY,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  testWidgets(
    'request-method popup keeps navy text on a white surface in dark mode',
    (tester) async {
      final original = fixture();
      final record = GovernmentIdDetails.fromJson({
        ...original.raw,
        'request_paths': [
          ...original.requestPaths,
          {
            ...original.requestPaths.single,
            'id': 2,
            'label': 'Alternate channel',
          },
        ],
      });
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: IdDetailsScreen(
            idName: record.name,
            governmentId: record.id,
            loadDetail: (_) async => record,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final selector = tester.widget<DropdownButton<int>>(
        find.descendant(
          of: find.byType(DropdownButtonFormField<int>),
          matching: find.byType(DropdownButton<int>),
        ),
      );
      expect(selector.dropdownColor, Colors.white);
      expect(selector.style!.color, AppTheme.navy);
      expect(tester.takeException(), isNull);
    },
  );

  for (final fail in [false, true]) {
    testWidgets(
      'Overview is first and shows saved application preparation: failure=$fail',
      (tester) async {
        final previous = AuthService.instance;
        AuthService.instance = AuthService(
          client: MockClient((request) async {
            if (request.url.path.endsWith('/auth/inventory')) {
              return http.Response(
                jsonEncode({
                  'data': {'government_ids': [], 'documents': []},
                }),
                200,
              );
            }
            expect(
              request.url.path.endsWith(
                '/auth/requirement-preparation/government_id/1',
              ),
              isTrue,
            );
            return fail
                ? http.Response('{}', 503)
                : http.Response(
                    jsonEncode({
                      'data': {
                        'record_type': 'government_id',
                        'record_id': 1,
                        'items': [
                          {'item_id': 10, 'prepared': true},
                        ],
                      },
                    }),
                    200,
                  );
          }),
        )..token = 'test-token';
        addTearDown(() {
          AuthService.instance.dispose();
          AuthService.instance = previous;
        });
        final record = GovernmentIdDetails.fromJson({
          'id': 1,
          'name': 'Overview fixture',
          'prerequisites': [],
          'requirement_sets': [
            {
              'id': 1,
              'application_type': 'new',
              'applicant_type': 'all',
              'groups': [
                {
                  'condition_type': 'always',
                  'ways': [
                    {
                      'required_count': 2,
                      'qualification_type': 'none',
                      'items': [
                        {
                          'type': 'document',
                          'id': 10,
                          'document_id': 10,
                          'name': 'Document A',
                        },
                        {
                          'type': 'document',
                          'id': 11,
                          'document_id': 11,
                          'name': 'Document B',
                        },
                      ],
                    },
                  ],
                },
              ],
            },
          ],
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: IdDetailsScreen(
              idName: record.name,
              governmentId: 1,
              loadDetail: (_) async => record,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final tabs = tester.widget<TabBar>(find.byType(TabBar));
        expect(tabs.tabs.cast<Tab>().first.text, 'Overview');
        expect(find.text('Application preparation'), findsOneWidget);
        if (fail) {
          expect(find.text('0%'), findsNothing);
          expect(find.text('50%'), findsNothing);
        } else {
          expect(find.text('0 of 1 required groups prepared'), findsWidgets);
          final ring = tester.widget<CircularProgressIndicator>(
            find.byType(CircularProgressIndicator),
          );
          expect(ring.value, .5);
          expect(ring.color, AppTheme.accentGold);
          expect(find.text('50%'), findsOneWidget);
        }
        expect(find.text('Offices'), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
