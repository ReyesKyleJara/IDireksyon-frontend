/// A direct agency confirmation sent by the API's `agency_verification` field.
///
/// The backend only sends approved, current confirmations, and only while the
/// record as a whole counts as confirmed. This parser is still defensive: an
/// older API (no field), a null or empty field, any other status, or a
/// malformed entry simply yields no confirmation, never a partial claim.
class AgencyConfirmation {
  const AgencyConfirmation({
    required this.agencyName,
    required this.scope,
    required this.confirmedAspects,
    required this.notCoveredAspects,
    required this.appliesToAllRequestPaths,
    required this.requestPathLabels,
    this.officeLabel,
    this.outcome = 'confirmed',
    this.confirmedOn,
  });

  final String agencyName;
  final String? officeLabel;
  final String outcome;
  final String scope;
  final List<String> confirmedAspects;
  final List<String> notCoveredAspects;
  final bool appliesToAllRequestPaths;
  final List<String> requestPathLabels;
  final DateTime? confirmedOn;

  static const aspectLabels = {
    'eligibility': 'Eligibility',
    'requirements': 'Requirements',
    'fees': 'Fees',
    'processing_time': 'Processing time',
    'validity': 'Validity',
    'application_process': 'Application process',
    'offices': 'Offices',
  };

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Only part of the guide was confirmed (always true unless every aspect was).
  bool get isPartial =>
      outcome == 'partially_confirmed' || notCoveredAspects.isNotEmpty;

  String get confirmedOnLabel {
    final date = confirmedOn;
    return date == null
        ? 'Date not recorded'
        : '${date.day} ${_months[date.month - 1]} ${date.year}';
  }

  static String aspectLabel(String key) =>
      aspectLabels[key] ??
      (key.isEmpty
          ? key
          : '${key[0].toUpperCase()}${key.substring(1).replaceAll('_', ' ')}');

  /// Confirmations from a record's raw API data, or none.
  static List<AgencyConfirmation> listFrom(dynamic field) {
    if (field is! Map || field['status'] != 'agency_confirmed') return const [];
    final rows = field['confirmations'];
    if (rows is! List) return const [];
    return rows.map(tryParse).whereType<AgencyConfirmation>().toList();
  }

  static AgencyConfirmation? tryParse(dynamic json) {
    if (json is! Map) return null;
    final agency = _text(json['agency_name']);
    final scope = _text(json['scope']);
    final confirmed = _keys(json['confirmed_aspects']);
    // Without who confirmed it, what was confirmed, and its exact scope, nothing is shown.
    if (agency == null || scope == null || confirmed.isEmpty) return null;
    final paths = json['request_paths'] is List
        ? (json['request_paths'] as List)
              .whereType<Map>()
              .map((path) => _text(path['label']))
              .whereType<String>()
              .toList()
        : <String>[];
    final allPaths = json['applies_to_all_request_paths'] == true;
    return AgencyConfirmation(
      agencyName: agency,
      officeLabel: _text(json['office_label']),
      outcome: _text(json['outcome']) ?? 'confirmed',
      scope: scope,
      confirmedAspects: confirmed,
      notCoveredAspects: _keys(json['not_covered_aspects'])
          .where((key) => !confirmed.contains(key))
          .toList(),
      appliesToAllRequestPaths: allPaths,
      requestPathLabels: allPaths ? const [] : paths,
      confirmedOn: _date(json['confirmed_on']),
    );
  }

  static String? _text(dynamic value) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty ? null : text;
  }

  static List<String> _keys(dynamic value) => value is List
      ? value.map(_text).whereType<String>().toSet().toList()
      : <String>[];

  static DateTime? _date(dynamic value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch(_text(value) ?? '');
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    return date.month == month && date.day == day ? date : null;
  }
}
