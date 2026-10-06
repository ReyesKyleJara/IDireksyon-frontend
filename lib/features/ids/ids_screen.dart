import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import 'id_details_screen.dart';

class IdsScreen extends StatelessWidget {
  const IdsScreen({super.key});

  static const primaryBlue = Color(0xFF174B85);

  void _open(BuildContext context, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IdDetailsScreen(idName: title)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? const Color(0xFFA8CCFA) : primaryBlue;
    final card = dark ? colors.surfaceContainerHighest : Colors.white;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(20),
      side: BorderSide(color: colors.outlineVariant),
    );
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const PageHeader('ID Directory'),
          const SizedBox(height: 4),
          Text(
            'Browse supported government IDs and application guides',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            decoration: InputDecoration(
              hintText: 'Search IDs or Agencies',
              hintStyle: TextStyle(
                fontSize: 14,
                color: colors.onSurfaceVariant,
              ),
              prefixIcon: Icon(Icons.search_rounded, color: accent),
              filled: true,
              fillColor: card,
              contentPadding: const EdgeInsets.all(16),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: colors.outlineVariant),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: accent, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'Featured IDs',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore popular IDs to get started',
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 112 + MediaQuery.textScalerOf(context).scale(30),
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _featured(
                  context,
                  'PhilSys ID',
                  Icons.badge_rounded,
                  const Color(0xFF174B85),
                ),
                _featured(
                  context,
                  'Passport ID',
                  Icons.menu_book_rounded,
                  const Color(0xFFC84648),
                ),
                _featured(
                  context,
                  'PhilHealth',
                  Icons.health_and_safety_rounded,
                  const Color(0xFF287A45),
                ),
                _featured(
                  context,
                  "Driver's License",
                  Icons.directions_car_rounded,
                  const Color(0xFFAA7309),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const Text(
            'All IDs',
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          _idCard(
            context,
            shape,
            card,
            accent,
            'Passport ID',
            'Primary government-issued travel document',
            '50% Ready',
            Icons.menu_book_rounded,
          ),
          const SizedBox(height: 12),
          _idCard(
            context,
            shape,
            card,
            accent,
            'PhilSys ID',
            'National identification for secure verification',
            '76% Ready',
            Icons.badge_rounded,
          ),
        ],
      ),
    );
  }

  Widget _featured(
    BuildContext context,
    String title,
    IconData icon,
    Color tint,
  ) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final foreground = dark ? Color.lerp(tint, Colors.white, 0.6)! : tint;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: SizedBox(
        width: 132,
        child: Material(
          color: Color.alphaBlend(
            tint.withValues(alpha: dark ? 0.12 : 0.06),
            dark ? colors.surfaceContainerHighest : Colors.white,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: colors.outlineVariant),
          ),
          clipBehavior: Clip.antiAlias,
          child: MotionInkWell(
            onTap: () => _open(context, title),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: foreground.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: foreground, size: 26),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: colors.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _idCard(
    BuildContext context,
    ShapeBorder shape,
    Color background,
    Color accent,
    String title,
    String description,
    String readiness,
    IconData icon,
  ) {
    final colors = Theme.of(context).colorScheme;
    final green = colors.brightness == Brightness.dark
        ? const Color(0xFF95DCAF)
        : const Color(0xFF287A45);
    return Material(
      color: background,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: MotionInkWell(
        onTap: () => _open(context, title),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent, size: 26),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_rounded, size: 20, color: accent),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 14,
                          color: green,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          readiness,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: green,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Updated May 23, 2025',
                    style: TextStyle(
                      fontSize: 11,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
