/// "Last updated" and "Last reviewed" sent by the API's `review_dates` field.
///
/// Last updated: when the record's information last changed.
/// Last reviewed: when the IDireksyon team last checked the record against its
/// public sources. It is never an agency confirmation. An older API without the
/// field, or a malformed field, yields null and nothing is shown.
class ReviewDates {
  const ReviewDates({
    this.lastUpdated,
    this.lastReviewed,
    this.updatedSinceReview = false,
  });

  final DateTime? lastUpdated;
  final DateTime? lastReviewed;
  final bool updatedSinceReview;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static ReviewDates? tryParse(dynamic json) {
    if (json is! Map) return null;
    final dates = ReviewDates(
      lastUpdated: _date(json['last_updated_at']),
      lastReviewed: _date(json['last_reviewed_at']),
      updatedSinceReview: json['updated_since_review'] == true,
    );
    return dates.lastUpdated == null && dates.lastReviewed == null
        ? null
        : dates;
  }

  static DateTime? _date(dynamic value) =>
      value is String ? DateTime.tryParse(value)?.toLocal() : null;

  /// "15 Nov 2026", in the phone's time zone.
  static String label(DateTime date) =>
      '${date.day} ${_months[date.month - 1]} ${date.year}';
}
