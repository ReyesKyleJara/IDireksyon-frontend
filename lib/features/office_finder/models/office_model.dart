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

  /// Null when the CMS has no usable coordinates for this office.
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

  /// The coordinates, when they can be shown on a map. Anything else means no
  /// pin and no directions. Matches `Office::hasUsableLocation` on the backend.
  static ({double latitude, double longitude})? usableLocation(
    dynamic latitude,
    dynamic longitude,
  ) {
    final lat = double.tryParse('$latitude');
    final lng = double.tryParse('$longitude');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180 ||
        (lat == 0 && lng == 0)) {
      return null;
    }
    return (latitude: lat, longitude: lng);
  }

  /// Reads the API's `schedules` list, which is also used on ID and document pages.
  static Map<int, OfficeDay> scheduleFrom(dynamic schedules) => {
    for (final row
        in (schedules is List ? schedules : const []).whereType<Map>())
      ?int.tryParse('${row['day_of_week']}'): OfficeDay.fromJson(row),
  };

  /// Listed days from Monday to Sunday, with neighbouring matching days merged.
  /// Days without real information are left out.
  static List<OfficeHoursLine> weeklyLines(Map<int, OfficeDay> schedule) {
    const labels = {
      1: 'Mon',
      2: 'Tue',
      3: 'Wed',
      4: 'Thu',
      5: 'Fri',
      6: 'Sat',
      0: 'Sun',
    };
    final lines = <OfficeHoursLine>[];
    String? first;
    String? last;
    String? hours;

    void close() {
      if (first != null) {
        lines.add(
          OfficeHoursLine(first == last ? first! : '$first–$last', hours!),
        );
      }
      first = last = hours = null;
    }

    for (final MapEntry(key: day, value: label) in labels.entries) {
      final text = schedule[day]?.displayHours;
      if (text == null) {
        close();
      } else if (text == hours) {
        last = label;
      } else {
        close();
        first = last = label;
        hours = text;
      }
    }
    close();
    return lines;
  }

  factory OfficeModel.fromJson(Map<String, dynamic> json) {
    final agency = json['agency'];
    final location = usableLocation(json['latitude'], json['longitude']);
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
      schedule: scheduleFrom(json['schedules']),
      latitude: location?.latitude,
      longitude: location?.longitude,
    );
  }

  String get serviceTag {
    if (records.isEmpty) {
      return agencyName.isEmpty ? 'Government office' : agencyName;
    }
    return records.length == 1
        ? records.first
        : '${records.first} and ${records.length - 1} more';
  }

  /// Today's listed hours, or null when there is nothing real to show. Office
  /// schedules use Philippine time wherever the device is.
  String? hoursOn(DateTime now) {
    final weekday = now.toUtc().add(const Duration(hours: 8)).weekday % 7;
    final hours = schedule[weekday]?.displayHours;
    return hours == null ? null : 'Today: $hours';
  }

  List<OfficeHoursLine> get weeklyHours => weeklyLines(schedule);

  /// Tidies CMS typing slips for display; the stored value is left as entered.
  static String _text(dynamic value) => value is String
      ? value
            .trim()
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll('`', '’')
            .replaceAll(RegExp(r'(?<=[A-Za-z0-9])- (?=\S)'), ' - ')
      : '';

  static String _address(Map<String, dynamic> json) {
    // A closing period stays after short abbreviations such as "St.".
    final address = _text(json['address'])
        .replaceFirst(RegExp(r'(?:[,;]+|(?<=[A-Za-z]{6})\.)$'), '');
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

/// One row of an office's weekly schedule, such as `Mon–Fri`.
class OfficeHoursLine {
  const OfficeHoursLine(this.days, this.hours);

  final String days;
  final String hours;

  @override
  String toString() => '$days: $hours';
}

class OfficeDay {
  const OfficeDay(this.status, this.hours);

  factory OfficeDay.fromJson(Map<dynamic, dynamic> json) =>
      OfficeDay('${json['status']}', [
        for (final row
            in (json['intervals'] as List<dynamic>? ?? []).whereType<Map>())
          if ((_clock(row['opens_at']), _clock(row['closes_at'])) case (
            final String opens,
            final String closes,
          ))
            '$opens - $closes',
      ]);

  /// `open`, `closed` or `unknown`.
  final String status;
  final List<String> hours;

  /// What to show for this day, or null when the CMS has no real information.
  /// A day with no research is never reported as closed.
  String? get displayHours {
    if (status == 'closed') return 'Closed';
    return status == 'open' && hours.isNotEmpty ? hours.join(', ') : null;
  }

  /// Null for anything that is not a real time, so none is ever invented.
  static String? _clock(dynamic time) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})').firstMatch('$time');
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    final clock = '${hour % 12 == 0 ? 12 : hour % 12}:${match[2]}';
    return '$clock ${hour < 12 ? 'AM' : 'PM'}';
  }
}
