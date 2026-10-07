import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/models/government_id.dart';

void main() {
  test('parses scenarios alternatives references qualifications and submission details', () {
    final record = GovernmentIdDetails.fromJson({
      'id': 34, 'name': 'Passport', 'requirements': 'Old summary',
      'requirement_sets': [{
        'id': 10, 'application_type': 'new', 'application_type_label': 'First-Time Application',
        'applicant_type': 'adult', 'applicant_type_label': 'Adult',
        'display_label': 'Adult • First-Time Application', 'min_age': 18, 'max_age': null,
        'groups': [{
          'id': 20, 'title': 'Proof of identity', 'condition_type': 'spouse_surname',
          'condition_label': 'Married applicant using spouse’s surname',
          'ways': [{
            'id': 30, 'required_count': 1, 'qualification_type': 'current_address',
            'qualification_scope': 'every', 'qualification_label': 'Each selected item must: Show current address',
            'items': [{
              'id': 40, 'type': 'government_id', 'government_id_id': 5, 'name': 'National ID',
              'submission_format': 'original_photocopy', 'submission_label': 'Original + Photocopy',
              'copies': 1, 'instructions': 'Front and back.',
            }],
          }, {
            'id': 31, 'required_count': 2, 'qualification_type': 'photo_signature',
            'qualification_scope': 'at_least_one', 'qualification_label': 'At least one selected item must: Contain photo and signature',
            'items': [
              {'id': 41, 'type': 'document', 'document_id': 7, 'name': 'School Record'},
              {'id': 42, 'type': 'custom', 'name': 'Photo', 'quantity': 2},
              {'id': 43, 'type': 'custom', 'name': 'Supporting certificate'},
            ],
          }],
        }],
      }],
    });
    final set = record.requirementSets.single;
    expect(set.minAge, 18);
    expect(set.label, 'Adult • First-Time Application');
    final group = set.groups.single;
    expect(group.condition, 'Married applicant using spouse’s surname');
    expect(group.ways, hasLength(2));
    expect(group.ways.first.items.single.governmentIdId, 5);
    expect(group.ways.first.items.single.submission, 'Original + 1 photocopy');
    expect(group.ways.first.items.single.instructions, 'Front and back.');
    expect(group.ways.last.items.first.documentId, 7);
    expect(group.ways.last.items[1].quantity, 2);
    expect(group.ways.last.qualificationScope, 'at_least_one');
    expect(group.ways.last.instruction, 'Choose 2 accepted items');
  });

  test('handles missing optional data without inventing requirements', () {
    final record = GovernmentIdDetails.fromJson({'id': 1, 'name': 'ID', 'requirements': '  ', 'validity_type': 'not_applicable', 'validity': 'old value'});
    expect(record.requirementSets, isEmpty);
    expect(record.requirements, isNull);
    expect(record.validity, isNull);
    final item = RequirementItem.fromJson({'type': 'custom', 'name': 'Photo'});
    expect(item.submission, isNull);
    expect(item.copies, isNull);
  });

  test('retains zero ages and distinguishes all required from choose N', () {
    final set = RequirementSet.fromJson({'id': 1, 'min_age': 0, 'max_age': 0});
    expect(set.minAge, 0);
    expect(set.maxAge, 0);
    final way = RequirementWay.fromJson({'required_count': 2, 'items': [{'name': 'A'}, {'name': 'B'}]});
    expect(way.instruction, 'Provide all listed items');
  });
}
