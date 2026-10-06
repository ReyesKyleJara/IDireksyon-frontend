import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import '../../core/auth/auth_service.dart';
import 'account_details_screen.dart';
import 'manage_inventory_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const primaryBlue = ProfileScreen.primaryBlue;
  bool _loggingOut = false;

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);
    String? message;
    try {
      await AuthService.instance.logout();
    } on AuthException {
      message = 'Logged out on this device. Could not confirm logout with the server.';
    }
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/login', (_) => false);
    if (message != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _loggingOut,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 28, 20, 32),
            children: [
              const PageHeader('Profile'),
              const SizedBox(height: 20),
              _buildProfileHeader(colorScheme),
              const SizedBox(height: 28),
              _buildSectionLabel('Account', colorScheme),
              const SizedBox(height: 10),
              _buildMenuItem(
                context,
                icon: Icons.person_outline_rounded,
                title: 'Account Details',
                subtitle: 'Update your personal information and password',
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AccountDetailsScreen(),
                    ),
                  );
                  if (mounted) setState(() {});
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 12),
              _buildMenuItem(
                context,
                icon: Icons.inventory_2_outlined,
                title: 'Manage Inventory',
                subtitle: 'Choose the IDs and documents you already have',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const ManageInventoryScreen(),
                    ),
                  );
                },
                colorScheme: colorScheme,
              ),
              const SizedBox(height: 28),
              OutlinedButton.icon(
                onPressed: _loggingOut ? null : _logout,
                icon: const Icon(Icons.logout_rounded),
                label: Text(_loggingOut ? 'Logging out…' : 'Log out'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: colorScheme.error,
                  side: BorderSide(
                    color: colorScheme.error.withValues(alpha: .5),
                  ),
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader(ColorScheme colorScheme) {
    return Row(
      children: [
        const _ProfileAvatar(size: 76),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AuthService.instance.user?['name'] as String? ?? 'Your account',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                (AuthService.instance.user?['email'] ??
                        AuthService.instance.user?['phone'] ??
                        'Sign in to manage your details')
                    .toString(),
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionLabel(String title, ColorScheme colorScheme) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: colorScheme.onSurface,
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required ColorScheme colorScheme,
  }) {
    return Material(
      color: colorScheme.brightness == Brightness.dark
          ? colorScheme.surfaceContainer
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: MotionInkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(icon, color: primaryBlue, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.blue.shade50,
      ),
      child: Icon(
        Icons.person_rounded,
        size: size * 0.56,
        color: ProfileScreen.primaryBlue,
      ),
    );
  }
}
