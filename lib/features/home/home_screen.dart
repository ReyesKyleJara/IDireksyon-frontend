import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        children: [
          _buildHeader(context),
          const SizedBox(height: 24),

          _buildHeroBanner(context),
          const SizedBox(height: 32),

          _buildQuickActions(context),
          const SizedBox(height: 32),

          _buildRecommendedHeader(context),
          const SizedBox(height: 16),

          _buildRecommendedId(
            context: context,
            title: 'Philippine Passport',
            imageColor: const Color(0xFFD0E3F3).withValues(alpha: 0.8), 
          ),
          const SizedBox(height: 12),

          _buildRecommendedId(
            context: context,
            title: 'PhilSys ID',
            imageColor: const Color(0xFFFDE8E8).withValues(alpha: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                border: Border.all(color: primaryBlue, width: 2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.badge, color: primaryBlue, size: 20),
            ),
            const SizedBox(width: 8),
            const Text(
              'IDireksyon',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color: primaryBlue,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Welcome, user!',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            // Removed hardcoded Colors.black so it naturally adapts to white in Dark Mode
            color: Theme.of(context).colorScheme.onSurface, 
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBanner(BuildContext context) {
    // The Hero banner stays blue in both light and dark mode for brand consistency
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Start / Continue\nyour ID Journey!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Answer a few questions and let us guide you to the right IDs.',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: primaryBlue,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Get Started',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward, size: 16),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text(
                  'SVG Graphic\nHere',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                icon: Icons.folder,
                iconColor: Colors.blue.shade700,
                label: 'Document\nInventory',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                icon: Icons.location_on,
                iconColor: Colors.red.shade600,
                label: 'Office\nFinder',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildQuickActionCard(
                context: context,
                icon: Icons.badge,
                iconColor: Colors.orange.shade400,
                label: 'ID\nDirectory',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    // Theme-aware colors for the card
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;
    final borderColor = isDark ? Colors.transparent : Colors.grey.shade200;

    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: isDark ? [] : [ // Only show shadow in light mode
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.2,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recommended for you',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Based on your profile and documents',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        InkWell(
          onTap: () {},
          child: Text(
            'View All',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark 
                  ? Colors.blue.shade300 
                  : primaryBlue,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecommendedId({
    required BuildContext context,
    required String title,
    required Color imageColor,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? Theme.of(context).colorScheme.surfaceContainerHighest : Colors.white;
    final borderColor = isDark ? Colors.transparent : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: imageColor,
            ),
            child: const Center(
              child: Icon(Icons.image, color: Colors.black26),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ],
      ),
    );
  }
}