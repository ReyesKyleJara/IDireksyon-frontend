import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';
import 'package:idireksyon_frontend/services/requirement_readiness.dart';

Map<String, dynamic> id(int id) => {'type': 'government_id', 'government_id_id': id};
Map<String, dynamic> doc(int id) => {'type': 'document', 'document_id': id};
RequirementWay way(int count, List<Map<String, dynamic>> items) =>
    RequirementWay.fromJson({'required_count': count, 'items': items});

void main() {
  test('single item, all partial/complete, choose one of three/many, choose N and cap', () {
    final inventory = RequirementReadiness(governmentIds: [1, 2], documents: [28]);
    expect(inventory.way(way(1, [id(3)])), 0);
    expect(inventory.way(way(1, [id(1)])), 1);
    expect(inventory.way(way(2, [doc(28), id(3)])), .5);
    expect(inventory.way(way(2, [doc(28), id(1)])), 1);
    expect(inventory.way(way(1, [id(1), id(3), id(4)])), 1);
    expect(inventory.way(way(1, List.generate(34, (i) => id(i + 1)))), 1);
    expect(inventory.way(way(2, [id(1), id(3), id(4), id(5), id(6)])), .5);
    expect(inventory.way(way(2, [id(1), id(2), id(3), id(4), id(5)])), 1);
    expect(inventory.way(way(1, [id(1), id(2)])), 1);
  });

  test('matches type and catalog ID, never names or custom text', () {
    final inventory = RequirementReadiness.fromInventory({
      'government_ids': [{'id': 55, 'owned': true}, {'id': 68, 'owned': false}],
      'documents': [{'id': 28, 'owned': true}],
    });
    expect(inventory.owns(RequirementItem.fromJson(id(55))), isTrue);
    expect(inventory.owns(RequirementItem.fromJson(doc(28))), isTrue);
    expect(inventory.owns(RequirementItem.fromJson(id(28))), isFalse);
    expect(inventory.owns(RequirementItem.fromJson(id(68))), isFalse);
    expect(inventory.owns(RequirementItem.fromJson({'type': 'custom',
      'name': 'Philippine Passport', 'government_id_id': 55})), isFalse);
    expect(() => RequirementReadiness.fromInventory({}), throwsFormatException);
  });

  test('empty and invalid ways are zero; repeated references do not inflate progress', () {
    final inventory = RequirementReadiness(governmentIds: [1]);
    expect(inventory.way(way(0, [id(1)])), 0);
    expect(inventory.way(way(1, [])), 0);
    expect(inventory.way(way(2, [id(1), id(1)])), .5);
    expect(inventory.group(RequirementGroup.fromJson({'ways': []})), 0);
  });

  // Mirrors inspected PhilSys #56 IDs/counts. Custom fallback choices remain custom.
  final philsys = RequirementGroup.fromJson({'ways': [
    {'required_count': 2, 'items': [doc(28), {'type': 'custom',
      'name': 'One government-issued ID with full name, photo and signature'}]},
    {'required_count': 1, 'items': [id(55)]},
    {'required_count': 1, 'items': [id(68)]},
    {'required_count': 1, 'items': [id(59), id(60), id(58)]},
    {'required_count': 1, 'items': [
      ...[65,81,67,66,57,64,61,71,72,80,62,70,69,63,79,82].map(id),
      ...[35,36,38,37,39,68].map(doc),
      ...List.generate(12, (i) => {'type': 'custom', 'name': 'Custom fallback $i'}),
    ]},
  ]});
  final cases = <String, (List<int>, List<int>, double)>{
    'A nothing': ([], [], 0),
    'B birth certificate only': ([], [28], .5),
    'C generic custom ID remains unresolved': ([999], [28], .5),
    'D passport': ([55], [], 1),
    'E GSIS UMID': ([68], [], 1),
    'F one LTO': ([59], [], 1),
    'G one fallback NBI': ([], [35], 1),
    'H birth certificate and passport': ([55], [28], 1),
    'I multiple fallback and valid alternatives': ([65,55,68,59], [35,36], 1),
  };
  for (final entry in cases.entries) {
    test('PhilSys ${entry.key}', () {
      final (ids, docs, expected) = entry.value;
      final inventory = RequirementReadiness(governmentIds: ids, documents: docs);
      expect(inventory.group(philsys), expected);
      if (entry.key.startsWith('B')) expect(inventory.way(philsys.ways.first), .5);
    });
  }
}
