/// Which linked offices apply to a resident, for Barangay-level IDs and
/// documents. The CMS records each office's coverage:
///
/// * `barangay` - serves one barangay only (`barangay.id` says which)
/// * `shared`   - serves residents of every barangay
/// * not set    - not yet classified
///
/// On a Barangay-level record a resident sees their own barangay's office and
/// shared offices. Other barangays' offices, and offices not yet classified,
/// are left out, so a missing assignment never shows an unrelated barangay
/// hall. Other records (municipal, national) are not changed.
class BarangayOffices {
  const BarangayOffices._();

  /// Whether offices on a record with this level are matched to the resident.
  static bool appliesTo(String? level) =>
      level?.trim().toLowerCase() == 'barangay';

  /// The resident's saved barangay, from the signed-in profile.
  static int? residentBarangayId(Map<String, dynamic>? user) =>
      _id(user?['barangay_id']);

  /// True when the office serves only the resident's own barangay.
  static bool isResidentBarangay(
    Map<String, dynamic> office,
    int? residentBarangayId,
  ) =>
      residentBarangayId != null &&
      office['coverage'] == 'barangay' &&
      office['barangay'] is Map &&
      _id((office['barangay'] as Map)['id']) == residentBarangayId;

  static List<Map<String, dynamic>> applicable(
    List<Map<String, dynamic>> offices, {
    required String? level,
    required int? residentBarangayId,
  }) {
    if (!appliesTo(level)) return offices;
    return offices
        .where(
          (office) =>
              office['coverage'] == 'shared' ||
              isResidentBarangay(office, residentBarangayId),
        )
        .toList();
  }

  static int? _id(dynamic value) =>
      value is int ? value : int.tryParse('${value ?? ''}');
}
