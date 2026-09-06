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
        physics: const BouncingScrollPhysics(), // Adds premium iOS-style bounce
        children: [
          _buildHeader(colorScheme),
          const SizedBox(height: 24),

          _buildSearchBar(context),
          const SizedBox(height: 32),

          _buildFeaturedSection(context),
          const SizedBox(height: 36),

          _buildAllIdsSection(context),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ID Directory',
          style: TextStyle(
            fontSize: 28, // Slightly larger for stronger hierarchy
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Browse supported government IDs and application guides',
          style: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      // OUTSTANDING UX: Added a soft shadow to make the search bar float
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search IDs or Agencies',
          hintStyle: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 4.0),
            child: Icon(
              Icons.search_rounded,
              size: 22,
              color: primaryBlue.withValues(alpha: 0.6), // Tinted icon
            ),
          ),
          filled: true,
          fillColor: isDark
              ? colorScheme.surfaceContainerHighest
              : Colors.white, // Pure white for better contrast
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16, // Slightly taller for better touch target
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16), // Softer corners
            borderSide: BorderSide.none, // Removed hard borders in favor of shadow
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: primaryBlue,
              width: 1.5,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Featured IDs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            Icon(Icons.auto_awesome, size: 18, color: Colors.amber.shade600), // Small visual delight
          ],
        ),
        const SizedBox(height: 16),

        SizedBox(
          height: 120, // Slightly taller to accommodate shadow
          child: ListView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            clipBehavior: Clip.none, // Allows shadows to render outside the box
            children: [
              _buildFeaturedIdCard(
                context,
                title: 'PhilSys ID',
                backgroundColor: const Color(0xFFF0F5FA),
                icon: Icons.badge_rounded,
                iconColor: Colors.blue.shade700,
              ),
              const SizedBox(width: 14),
              _buildFeaturedIdCard(
                context,
                title: 'Passport ID',
                backgroundColor: const Color(0xFFFDF0F0),
                icon: Icons.menu_book_rounded,
                iconColor: Colors.red.shade700,
              ),
              const SizedBox(width: 14),
              _buildFeaturedIdCard(
                context,
                title: 'PhilHealth',
                backgroundColor: const Color(0xFFEFF9F1),
                icon: Icons.health_and_safety_rounded,
                iconColor: Colors.green.shade700,
              ),
              const SizedBox(width: 14),
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

    return Container(
      width: 110,
      // OUTSTANDING UX: Soft shadow for featured cards
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => IdDetailsScreen(idName: title)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 24, color: iconColor),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
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

  Widget _buildAllIdsSection(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'All IDs',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),

        _buildIdListCard(
          context,
          title: 'Passport ID',
          description: 'Primary government-issued travel document',
          readiness: '50% Ready',
          lastUpdated: 'May 23, 2025',
          icon: Icons.menu_book_rounded,
        ),
        const SizedBox(height: 14),
        _buildIdListCard(
          context,
          title: 'PhilSys ID',
          description: 'National identification for secure verification',
          readiness: '76% Ready',
          lastUpdated: 'May 23, 2025',
          icon: Icons.badge_rounded,
        ),
      ],
    );
  }

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

    return Container(
      // OUTSTANDING UX: Soft ambient shadow for list items
      decoration: BoxDecoration(
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => IdDetailsScreen(idName: title)),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _buildIdThumbnail(icon: icon),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.3,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildReadinessBadge(readiness),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.update_rounded,
                            size: 14,
                            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            lastUpdated,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdThumbnail({required IconData icon}) {
    return Container(
      width: 72,
      height: 52,
      decoration: BoxDecoration(
        color: lightBlue,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
      ),
      child: Icon(icon, size: 28, color: primaryBlue),
    );
  }

  Widget _buildReadinessBadge(String readiness) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: successBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: successGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, size: 12, color: successGreen),
          const SizedBox(width: 4),
          Text(
            readiness,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: successGreen,
            ),
          ),
        ],
      ),
    );
  }
}