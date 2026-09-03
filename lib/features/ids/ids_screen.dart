import 'package:flutter/material.dart';
import 'id_details_screen.dart';

class IdsScreen extends StatelessWidget {
  const IdsScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color lightBlue = Color(0xFFF0F5FA);
  static const Color successGreen = Color(0xFF287A45);
  static const Color successBackground = Color(0xFFE5F4EA);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          _buildHeader(colorScheme),
          const SizedBox(height: 20),

          _buildSearchBar(context),
          const SizedBox(height: 28),

          _buildFeaturedSection(context),
          const SizedBox(height: 32),

          _buildAllIdsSection(context),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ID Directory',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Browse supported government IDs and application guides',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // SEARCH BAR
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return TextField(
      decoration: InputDecoration(
        hintText: 'Search IDs or Agencies',
        hintStyle: TextStyle(
          fontSize: 14,
          color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
        ),
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 21,
          color: colorScheme.onSurfaceVariant,
        ),
        filled: true,
        fillColor: isDark
            ? colorScheme.surfaceContainerHighest
            : const Color(0xFFFAFAFA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.transparent
                : const Color(0xFFE8E8E8),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.transparent
                : const Color(0xFFE8E8E8),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: primaryBlue,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FEATURED IDS
  // ---------------------------------------------------------------------------

  Widget _buildFeaturedSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Featured IDs',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),

        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            children: [
              _buildFeaturedIdCard(
                context,
                title: 'PhilSys ID',
                backgroundColor: const Color(0xFFF0F5FA),
                icon: Icons.badge_rounded,
                iconColor: Colors.blue.shade700,
              ),
              const SizedBox(width: 12),

              _buildFeaturedIdCard(
                context,
                title: 'Passport ID',
                backgroundColor: const Color(0xFFFDF0F0),
                icon: Icons.menu_book_rounded,
                iconColor: Colors.red.shade700,
              ),
              const SizedBox(width: 12),

              _buildFeaturedIdCard(
                context,
                title: 'PhilHealth',
                backgroundColor: const Color(0xFFEFF9F1),
                icon: Icons.health_and_safety_rounded,
                iconColor: Colors.green.shade700,
              ),
              const SizedBox(width: 12),

              _buildFeaturedIdCard(
                context,
                title: "Driver's License",
                backgroundColor: const Color(0xFFFFF7E6),
                icon: Icons.directions_car_rounded,
                iconColor: Colors.orange.shade700,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedIdCard(
    BuildContext context, {
    required String title,
    required Color backgroundColor,
    required IconData icon,
    required Color iconColor,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 108,
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => IdDetailsScreen(
                  idName: title,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 12,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.65),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: iconColor,
                  ),
                ),
                const SizedBox(height: 9),

                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ALL IDS
  // ---------------------------------------------------------------------------

  Widget _buildAllIdsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All IDs',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 14),

        _buildIdListCard(
          context,
          title: 'Passport ID',
          description: 'Primary government-issued travel document',
          readiness: '50% Ready',
          lastUpdated: 'Last updated: May 23, 2025',
          icon: Icons.menu_book_rounded,
        ),

        const SizedBox(height: 12),

        _buildIdListCard(
          context,
          title: 'PhilSys ID',
          description: 'National identification for secure verification',
          readiness: '76% Ready',
          lastUpdated: 'Last updated: May 23, 2025',
          icon: Icons.badge_rounded,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // ID LIST CARD
  // ---------------------------------------------------------------------------

  Widget _buildIdListCard(
    BuildContext context, {
    required String title,
    required String description,
    required String readiness,
    required String lastUpdated,
    required IconData icon,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: isDark
          ? colorScheme.surfaceContainerHighest
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => IdDetailsScreen(
                idName: title,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? Colors.transparent
                  : const Color(0xFFEAEAEA),
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildIdThumbnail(
                icon: icon,
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),

                    const SizedBox(height: 8),

                    _buildReadinessBadge(readiness),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        Icon(
                          Icons.update_rounded,
                          size: 12,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.65),
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            lastUpdated,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: colorScheme.onSurfaceVariant
                                  .withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: colorScheme.onSurfaceVariant
                    .withValues(alpha: 0.45),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ID THUMBNAIL
  // ---------------------------------------------------------------------------

  Widget _buildIdThumbnail({
    required IconData icon,
  }) {
    return Container(
      width: 64,
      height: 48,
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 25,
        color: primaryBlue,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // READINESS BADGE
  // ---------------------------------------------------------------------------

  Widget _buildReadinessBadge(String readiness) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: successBackground,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        readiness,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: successGreen,
        ),
      ),
    );
  }
}