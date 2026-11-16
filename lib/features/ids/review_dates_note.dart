import 'package:flutter/material.dart';

import '../../models/review_dates.dart';

/// Quiet "Last updated" / "Last reviewed" lines under a record's sources.
///
/// "Reviewed" means the IDireksyon team checked the record against its public
/// sources. It never says or implies that an agency reviewed or confirmed it.
class ReviewDatesNote extends StatelessWidget {
  const ReviewDatesNote({super.key, required this.dates, this.compact = false});

  final ReviewDates dates;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final style = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: colors.onSurfaceVariant,
    );
    final updated = dates.lastUpdated;
    final reviewed = dates.lastReviewed;
    if (compact) {
      final showReview =
          reviewed != null && (updated == null || !reviewed.isBefore(updated));
      final latest = showReview ? reviewed : updated;
      if (latest == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
        child: Text(
          '${showReview ? 'Last reviewed by the IDireksyon team' : 'Last updated'}: '
          '${ReviewDates.label(latest)}',
          style: style.copyWith(fontSize: 12),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.update_rounded,
              size: 18,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (updated != null)
                  Text(
                    'Last updated: ${ReviewDates.label(updated)}',
                    style: style,
                  ),
                Text(
                  reviewed == null
                      ? 'Not yet reviewed by the IDireksyon team'
                      : 'Last reviewed by the IDireksyon team: '
                            '${ReviewDates.label(reviewed)}',
                  style: style,
                ),
                if (reviewed != null && dates.updatedSinceReview)
                  Text(
                    'Updated after the last review.',
                    style: style.copyWith(fontStyle: FontStyle.italic),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
