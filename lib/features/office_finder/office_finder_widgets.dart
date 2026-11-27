import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'models/office_model.dart';

/// Shared looks for the Office Finder list and the Office Details page.
abstract final class OfficeLook {
  static bool dark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color card(BuildContext context) => dark(context)
      ? Theme.of(context).colorScheme.surfaceContainer
      : Colors.white;

  static Color page(BuildContext context) => dark(context)
      ? Theme.of(context).colorScheme.surface
      : const Color(0xFFF6F8FC);

  static Color border(BuildContext context) => dark(context)
      ? Theme.of(context).colorScheme.outlineVariant.withValues(alpha: .35)
      : const Color(0xFFE3E9F2);

  /// Soft grey-blue used for icon tiles and inner boxes.
  static Color tint(BuildContext context) => dark(context)
      ? Theme.of(context).colorScheme.surfaceContainerHigh
      : const Color(0xFFEDF3FB);

  /// The solid navy of the main buttons. Lighter in dark mode so it shows.
  static Color action(BuildContext context) =>
      dark(context) ? AppTheme.primaryBlue : AppTheme.navy;

  static Color ink(BuildContext context) =>
      dark(context) ? Theme.of(context).colorScheme.onSurface : AppTheme.navy;

  static List<BoxShadow> shadow(BuildContext context) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: dark(context) ? .25 : .06),
      blurRadius: 14,
      offset: const Offset(0, 4),
    ),
  ];

  static BoxDecoration cardBox(BuildContext context, {double radius = 18}) =>
      BoxDecoration(
        color: card(context),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border(context)),
        boxShadow: shadow(context),
      );

  static String distance(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  static String duration(int seconds) {
    final minutes = (seconds / 60).ceil().clamp(1, 1 << 31);
    if (minutes < 60) return '$minutes min';
    final rest = minutes % 60;
    return '${minutes ~/ 60} hr${rest == 0 ? '' : ' $rest min'}';
  }

  /// "7h 19m", for how long an office stays open.
  static String timeLeft(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }
}

/// "Open Now" in green or "Closed" in red. Nothing when hours are unknown.
class OfficeStatusPill extends StatelessWidget {
  const OfficeStatusPill({super.key, required this.state});

  final OfficeOpenState state;

  static const _green = Color(0xFF1E8E3E);
  static const _red = Color(0xFFD93025);

  @override
  Widget build(BuildContext context) {
    final dark = OfficeLook.dark(context);
    final color = state.open ? _green : _red;
    final text = dark
        ? (state.open ? const Color(0xFF81C995) : const Color(0xFFF28B82))
        : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: dark ? .22 : .1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: text, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          // Wraps under very large text instead of spilling out.
          Flexible(
            child: Text(
              state.open ? 'Open Now' : 'Closed',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// "Your Barangay" tag for the resident's own barangay hall.
class YourBarangayTag extends StatelessWidget {
  const YourBarangayTag({super.key, required this.office});

  final OfficeModel office;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey('finder-your-barangay-${office.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Your Barangay',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    );
  }
}

/// A small icon with text, such as the address or distance on a card.
class OfficeFact extends StatelessWidget {
  const OfficeFact({
    super.key,
    required this.icon,
    required this.text,
    this.strong = false,
  });

  final IconData icon;
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 16, color: OfficeLook.ink(context)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.35,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w400,
              color: strong ? colors.onSurface : colors.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
