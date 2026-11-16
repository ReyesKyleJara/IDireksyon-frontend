import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/features/ids/guide_steps.dart';

/// Fake API data only.
Map<String, dynamic> doc(String text) => {
  'type': 'doc',
  'content': [
    {
      'type': 'paragraph',
      'content': [
        {'type': 'text', 'text': text},
      ],
    },
  ],
};

final emptyDoc = {
  'type': 'doc',
  'content': [
    {'type': 'paragraph'},
  ],
};

Map<String, dynamic> item(String name) => {
  'name': name,
  'submission_label': 'Original',
  'copies': 1,
};

final path = <String, dynamic>{
  'label': 'First-time',
  'processing': '10–12 working days',
  'requirement_sets': [
    {
      'groups': [
        {
          'title': null,
          'ways': [
            {
              'required_count': 1,
              'items': [
                {
                  'name': 'Fixture Birth Certificate',
                  'instructions': 'Bring the PSA copy.',
                },
              ],
            },
          ],
        },
        {
          'title': 'Valid ID',
          'ways': [
            {
              'required_count': 1,
              'items': [for (var i = 1; i <= 9; i++) item('Accepted ID $i')],
            },
          ],
        },
      ],
    },
  ],
  'fees': [
    {
      'label': 'Processing Fee',
      'type': 'options',
      'options': [
        {
          'label': 'Regular',
          'type': 'fixed',
          'amount_min': '950.00',
          'currency': 'PHP',
        },
        {
          'label': 'Expedited',
          'type': 'fixed',
          'amount_min': '1200.00',
          'currency': 'PHP',
        },
      ],
    },
    {'label': 'Courier', 'type': 'varies'},
  ],
  'offices': [
    {'name': 'Fixture Office', 'address': 'Fixture Street'},
  ],
};

final steps = <Map<String, dynamic>>[
  {
    'title': 'Book an appointment',
    'short_description': 'Schedule your visit.',
    'blocks': [
      {
        'type': 'official_link',
        'content': {
          'label': 'Official website',
          'url': 'https://example.gov.ph',
        },
      },
      {
        'type': 'reminder',
        'content': {'body': doc('Courtesy lanes may not need one.')},
      },
    ],
  },
  {
    'title': 'Prepare your requirements',
    'short_description': 'Get the documents you need.',
    'blocks': [
      {
        'type': 'requirements',
        'content': {'intro': emptyDoc},
      },
    ],
  },
  {
    'title': 'Pay the fee',
    'short_description': '',
    'blocks': [
      {
        'type': 'fees',
        'content': {'intro': emptyDoc},
      },
    ],
  },
];

Future<List<int>> pump(WidgetTester tester) async {
  tester.view.physicalSize = const Size(400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final jumps = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      home: DefaultTabController(
        length: 4,
        child: Builder(
          builder: (context) {
            DefaultTabController.of(context).addListener(
              () => jumps.add(DefaultTabController.of(context).index),
            );
            return Scaffold(
              body: GuideSteps(
                steps: steps,
                path: path,
                tabIndex: (label) => const [
                  'Overview',
                  'Requirements',
                  'Cost',
                  'Offices',
                ].indexOf(label),
              ),
            );
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return jumps;
}

void main() {
  testWidgets('shows numbered steps closed, with only the title and summary', (
    tester,
  ) async {
    await pump(tester);

    expect(find.text('Application Guide'), findsOneWidget);
    for (final number in ['1', '2', '3']) {
      expect(find.text(number), findsOneWidget);
    }
    expect(find.text('Book an appointment'), findsOneWidget);
    expect(find.text('Schedule your visit.'), findsOneWidget);
    expect(find.text('Open official website'), findsNothing);
    expect(find.text('Fixture Birth Certificate'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'opens a step to a link button and a reminder, and closes again',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Book an appointment'));
      await tester.pumpAndSettle();

      expect(find.text('Open official website'), findsOneWidget);
      expect(find.text('Courtesy lanes may not need one.'), findsOneWidget);

      await tester.tap(find.text('Book an appointment'));
      await tester.pumpAndSettle();
      expect(find.text('Open official website'), findsNothing);
    },
  );

  testWidgets('shows the real requirements cleanly, shortening long lists', (
    tester,
  ) async {
    final jumps = await pump(tester);
    await tester.tap(find.text('Prepare your requirements'));
    await tester.pumpAndSettle();

    expect(find.text('Fixture Birth Certificate'), findsOneWidget);
    expect(find.text('Bring the PSA copy.'), findsOneWidget);
    expect(find.text('Valid ID'), findsOneWidget);
    expect(find.text('Bring any 1 of these:'), findsOneWidget);
    // The shared format is said once, not after every item.
    expect(find.text('Original · 1 copy'), findsOneWidget);
    expect(find.text('Accepted ID 6'), findsOneWidget);
    expect(find.text('Accepted ID 7'), findsNothing);
    expect(find.textContaining('+ 3 more accepted'), findsOneWidget);
    // No "see the other tab" filler text from the old layout.
    expect(find.textContaining('See Requirements for'), findsNothing);

    await tester.tap(find.text('Open the full checklist'));
    await tester.pumpAndSettle();
    expect(jumps, contains(1));
  });

  testWidgets('shows fee amounts for the selected application type', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Pay the fee'));
    await tester.pumpAndSettle();

    expect(find.text('₱950'), findsOneWidget);
    expect(find.text('₱1,200'), findsOneWidget);
    expect(find.text('Regular'), findsOneWidget);
    expect(find.text('Amount varies'), findsOneWidget);
    expect(find.text('See all costs'), findsOneWidget);
  });
}
