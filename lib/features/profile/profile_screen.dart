import 'package:flutter/material.dart';
import 'manage_inventory_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color slateGrey = Color(0xFF4A5568);
  static const Color softBlue = Color(0xFFF0F5FA);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildHeader(colorScheme),
          const SizedBox(height: 24),
          
          _buildAccountCard(context, colorScheme, isDark),
          const SizedBox(height: 32),
          
          _buildInventorySection(context, colorScheme, isDark),
          const SizedBox(height: 40),
          
          _buildLogoutButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Text(
      'Profile',
      style: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.5,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, ColorScheme colorScheme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: isDark ? [] : [
          BoxShadow(
            color: primaryBlue.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            // Navigate to Account Details Screen
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: const BoxDecoration(
                    color: softBlue,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 28,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Juan Dela Cruz',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'juandelacruz@gmail.com',
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInventorySection(BuildContext context, ColorScheme colorScheme, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Inventory',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ManageInventoryScreen()),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: primaryBlue,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text(
                'Manage',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark ? Colors.transparent : colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInventoryCategory(
                title: 'Owned IDs',
                items: const [
                  _InventoryItem(icon: Icons.badge_rounded, label: 'PhilSys', iconColor: primaryBlue),
                  _InventoryItem(icon: Icons.menu_book_rounded, label: 'Passport', iconColor: primaryBlue),
                  _InventoryItem(icon: Icons.health_and_safety_rounded, label: 'PhilHealth', iconColor: primaryBlue),
                ],
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              _buildInventoryCategory(
                title: 'Available Documents',
                items: const [
                  _InventoryItem(icon: Icons.school_rounded, label: 'School ID', iconColor: slateGrey),
                  _InventoryItem(icon: Icons.description_rounded, label: 'Birth Cert.', iconColor: slateGrey),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInventoryCategory({required String title, required List<_InventoryItem> items}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: slateGrey,
          ),
        ),
        const SizedBox(height: 14),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: items,
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50, // Slightly taller for better UX
      child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text(
          'Log out',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red.shade600,
          side: BorderSide(color: Colors.red.shade200, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

class _InventoryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _InventoryItem({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 72, // Fixed width to ensure grid alignment
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surfaceContainer : const Color(0xFFF8F9FB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: iconColor),
          const SizedBox(height: 8),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}