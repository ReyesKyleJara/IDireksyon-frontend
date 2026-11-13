import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'id_details_screen.dart' show CatalogOfficialLink;

/// One public website reference saved in the CMS (`research_metadata.sources`).
///
/// It only says where public information came from. It never claims that an
/// agency reviewed, confirmed, or endorsed the record or IDireksyon.
class CatalogSourceCard extends StatelessWidget {
  const CatalogSourceCard({
    super.key,
    required this.source,
    required this.recordName,
    this.agencyName,
  });

  final Map<String, dynamic> source;
  final String recordName;
  final String? agencyName;

  static final _repeatedLabel = RegExp(
    r'^\s*public\s+reference\s*[:\-–—]\s*',
    caseSensitive: false,
  );
  static final _agencySeparator = RegExp(r'\s+[–—-]\s+');
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// The stored title without a leading "Public reference:", which the card
  /// already shows as its label. The CMS value itself is never changed.
  static String displayTitle(String title) {
    final shown = title.replaceFirst(_repeatedLabel, '').trim();
    return shown.isEmpty ? title.trim() : shown;
  }

  /// "View DFA webpage" when the title starts with a short agency name
  /// ("DFA – Passport General Information"); otherwise a neutral label.
  static String linkLabel(String title) {
    final parts = displayTitle(title).split(_agencySeparator);
    final agency = parts.length > 1 ? parts.first.trim() : '';
    if (agency.isEmpty ||
        agency.length > 24 ||
        agency.split(RegExp(r'\s+')).length > 3) {
      return 'View source webpage';
    }
    return 'View $agency webpage';
  }

  /// "Checked on 13 Nov 2026" from the saved YYYY-MM-DD date.
  static String checkedLabel(dynamic value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$')
        .firstMatch('${value ?? ''}'.trim());
    final month = match == null ? 0 : int.parse(match.group(2)!);
    if (match == null || month < 1 || month > 12) {
      return 'Checked date not recorded';
    }
    return 'Checked on ${int.parse(match.group(3)!)} ${_months[month - 1]} ${match.group(1)}';
  }

  /// The page/section line is hidden when the title already says the same.
  static bool showsSection(String title, dynamic section) {
    String plain(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final wanted = plain('${section ?? ''}');
    return wanted.isNotEmpty && !plain(displayTitle(title)).contains(wanted);
  }

  static bool _filled(dynamic value) =>
      value is String && value.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? colors.primary : AppTheme.primaryBlue;
    final muted = colors.onSurfaceVariant;
    final title = '${source['title'] ?? ''}';
    return Card(
      color: dark ? colors.surfaceContainer : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      // Same shape and spacing as the other ID Details cards.
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.menu_book_outlined,
                    size: 20,
                    color: accent,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recordName,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      if (_filled(agencyName))
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            agencyName!.trim(),
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              height: 22,
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
            Text(
              'Public reference',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: .2,
                fontWeight: FontWeight.w700,
                color: accent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              displayTitle(title),
              style: TextStyle(
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
            if (showsSection(title, source['section']))
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '${source['section']}'.trim(),
                  style: TextStyle(fontSize: 12, color: muted),
                ),
              ),
            // GitHub main's standard link button: safety check plus open-in-new icon.
            CatalogOfficialLink(
              url: '${source['url'] ?? ''}',
              label: linkLabel(title),
            ),
            if (_filled(source['scope']))
              Text(
                '${source['scope']}'.trim(),
                style: TextStyle(fontSize: 13, height: 1.45, color: muted),
              ),
            const SizedBox(height: 6),
            Text(
              checkedLabel(source['checked_on']),
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }
}
