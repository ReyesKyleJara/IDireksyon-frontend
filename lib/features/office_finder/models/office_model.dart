/// A published office from `GET /api/offices`.
class OfficeModel {
  final String id;
  final String name;

  /// Agency acronym, or empty when the CMS has none.
  final String agency;
  final String agencyName;
  final String address;

  /// IDs and documents handled here.
  final List<String> records;

  /// Keyed by the CMS `day_of_week` (0 = Sunday … 6 = Saturday).
  final Map<int, OfficeDay> schedule;

  /// Null until the CMS has coordinates for this office.
  final double? latitude;
  final double? longitude;

  const OfficeModel({
    required this.id,
    required this.name,
    this.agency = '',
    this.agencyName = '',
    required this.address,
    this.records = const [],
    this.schedule = const {},
    this.latitude,
    this.longitude,
  });

  factory OfficeModel.fromJson(Map<String, dynamic> json) {
    final agency = json['agency'];
    final latitude = _coordinate(json['latitude'], 90);
    final longitude = _coordinate(json['longitude'], 180);
    final located = latitude != null && longitude != null;
    return OfficeModel(
      id: '${json['id']}',
      name: _text(json['name']),
      agency: agency is Map ? _text(agency['acronym']) : '',
      agencyName: agency is Map ? _text(agency['name']) : '',
      address: _address(json),
      records: (json['records'] as List<dynamic>? ?? [])
          .map(_text)
          .where((record) => record.isNotEmpty)
          .toList(),
      schedule: {
        for (final row
            in (json['schedules'] as List<dynamic>? ?? []).whereType<Map>())
          ?int.tryParse('${row['day_of_week']}'): OfficeDay.fromJson(row),
      },
      latitude: located ? latitude : null,
      longitude: located ? longitude : null,
    );
  }

  String get serviceTag {
    if (records.isEmpty) {
      return agencyName.isEmpty ? 'Government office' : agencyName;
    }
    return records.length == 1
        ? records.first
        : '${records.first} +${records.length - 1}';
  }

  /// Today's listed hours. Office schedules use Philippine time wherever the
  /// device is, and a day with no research is never reported as closed.
  String hoursOn(DateTime now) {
    final weekday = now.toUtc().add(const Duration(hours: 8)).weekday % 7;
    final today = schedule[weekday];
    if (today == null ||
        today.status == 'unknown' ||
        (today.status == 'open' && today.hours.isEmpty)) {
      return 'Hours not listed';
    }
    return today.status == 'closed'
        ? 'Today: Closed'
        : 'Today: ${today.hours.join(', ')}';
  }

  static String _text(dynamic value) => value is String ? value.trim() : '';

  static double? _coordinate(dynamic value, double limit) {
    final parsed = double.tryParse('$value');
    return parsed == null || !parsed.isFinite || parsed.abs() > limit
        ? null
        : parsed;
  }

  static String _address(Map<String, dynamic> json) {
    final address = _text(json['address']);
    final lower = address.toLowerCase();
    final parts = [
      if (address.isNotEmpty) address,
      for (final place in [
        _text(json['municipality']),
        _text(json['province']),
      ])
        if (place.isNotEmpty && !lower.contains(place.toLowerCase())) place,
    ];
    return parts.isEmpty ? 'Address not yet added.' : parts.join(', ');
  }
}

class OfficeDay {
  const OfficeDay(this.status, this.hours);

  factory OfficeDay.fromJson(Map<dynamic, dynamic> json) =>
      OfficeDay('${json['status']}', [
        for (final row
            in (json['intervals'] as List<dynamic>? ?? []).whereType<Map>())
          '${_clock('${row['opens_at']}')} - ${_clock('${row['closes_at']}')}',
      ]);

  /// `open`, `closed` or `unknown`.
  final String status;
  final List<String> hours;

  static String _clock(String time) {
    final parts = time.split(':');
    final hour = int.tryParse(parts.first) ?? 0;
    final minute = parts.length > 1 ? parts[1].padLeft(2, '0') : '00';
    return '${hour % 12 == 0 ? 12 : hour % 12}:$minute ${hour < 12 ? 'AM' : 'PM'}';
  }
}
