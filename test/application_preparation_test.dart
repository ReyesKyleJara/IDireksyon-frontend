import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/application_preparation.dart';
import 'package:idireksyon_frontend/services/requirement_readiness.dart';

Map<String, dynamic> item(int id, {String type = 'custom', int? linked}) => {
  'id': id,
  'type': type,
  'name': 'Item $id',
  if (type == 'government_id') 'government_id_id': linked,
  if (type == 'document') 'document_id': linked,
};
RequirementWay way(int count, List<Map<String, dynamic>> items) =>
    RequirementWay.fromJson({'required_count': count, 'items': items});

void main() {
  test(
    'single, choose one, choose N and all count explicit prepared items',
    () {
      final preparation = ApplicationPreparation([1, 2]);
      expect(preparation.way(way(1, [item(1)])), 1);
      expect(preparation.way(way(1, [item(3)])), 0);
      expect(preparation.way(way(1, [item(1), item(2), item(3)])), 1);
      expect(preparation.way(way(2, [item(1), item(3), item(4)])), .5);
      expect(preparation.way(way(2, [item(1), item(2), item(3)])), 1);
      expect(
        preparation.way(way(3, [item(1), item(2), item(3)])),
        closeTo(2 / 3, .001),
      );
      expect(preparation.way(way(0, [item(1)])), 0);
    },
  );

  test(
    'uses best OR pathway and custom items retain distinct CMS identities',
    () {
      final group = RequirementGroup.fromJson({
        'ways': [
          {
            'required_count': 2,
            'items': [item(1), item(2)],
          },
          {
            'required_count': 1,
            'items': [item(3)],
          },
        ],
      });
      expect(ApplicationPreparation([1]).group(group), .5);
      expect(ApplicationPreparation([3]).group(group), 1);
      expect(ApplicationPreparation([1, 2]).group(group), 1);
    },
  );

  test('duplicate linked credentials cannot inflate choose-N', () {
    final preparation = ApplicationPreparation([1, 2]);
    expect(
      preparation.way(
        way(2, [
          item(1, type: 'government_id', linked: 55),
          item(2, type: 'government_id', linked: 55),
        ]),
      ),
      .5,
    );
  });

  test('ownership and preparation remain independent', () {
    final linked = RequirementItem.fromJson(
      item(1, type: 'government_id', linked: 55),
    );
    expect(RequirementReadiness(governmentIds: [55]).owns(linked), isTrue);
    expect(ApplicationPreparation([]).owns(linked), isFalse);
    expect(
      ApplicationPreparation([1]).withItem(1, false).owns(linked),
      isFalse,
    );
  });

  test(
    'saved true/false state parses strictly and conditional groups stay noted',
    () {
      final preparation = ApplicationPreparation.fromJson({
        'items': [
          {'item_id': 1, 'prepared': true},
          {'item_id': 2, 'prepared': false},
        ],
      });
      expect(preparation.preparedItems, {1});
      expect(
        () => ApplicationPreparation.fromJson({
          'items': [
            {'item_id': 1},
          ],
        }),
        throwsFormatException,
      );
      final set = RequirementSet.fromJson({
        'id': 1,
        'groups': [
          {
            'condition_type': 'always',
            'ways': [
              {
                'required_count': 1,
                'items': [item(1)],
              },
            ],
          },
          {
            'condition_type': 'custom',
            'ways': [
              {
                'required_count': 1,
                'items': [item(2)],
              },
            ],
          },
        ],
      });
      final summary = preparationSummary(set, preparation);
      expect(summary.complete, 1);
      expect(summary.total, 1);
      expect(summary.conditional, isTrue);
    },
  );
}
