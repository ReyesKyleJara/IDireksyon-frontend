
import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/profile/profile_avatar.dart';
import '../../core/widgets/page_header.dart';

import 'account_details_screen.dart';
import 'password_security_screen.dart';
import 'manage_inventory_screen.dart';
import 'about_idireksyon_screen.dart';
import 'help_faq_screen.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const primaryBlue = ProfileScreen.primaryBlue;

  bool _loggingOut = false;

  // PERSONAL INFORMATION
  Future<void> _openAccountDetails() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AccountDetailsScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // PASSWORD & SECURITY
  Future<void> _openPasswordSecurity() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PasswordSecurityScreen(),
      ),
    );
  }

  // DOCUMENT INVENTORY
  Future<void> _openInventory() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ManageInventoryScreen(),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  // HELP & FAQS
  void _openHelpFaq() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const HelpFaqScreen(),
      ),
    );
  }

  // ABOUT IDIREKSYON
  void _openAbout() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AboutIDireksyonScreen(),
      ),
    );
  }

  // PRIVACY POLICY
  void _openPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const PrivacyPolicyScreen(),
      ),
    );
  }

  // TERMS OF SERVICE
  void _openTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const TermsOfServiceScreen(),
      ),
    );
  }
  

Future<void> _confirmLogout() async {
  if (_loggingOut) return;

  final shouldLogout = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      final colors = Theme.of(dialogContext).colorScheme;

      return AlertDialog(
        backgroundColor: colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text(
          'Log out of IDireksyon?',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: Text(
          "You'll need to sign in again to access your account.",
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: colors.onSurfaceVariant,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext, false);
            },
            style: TextButton.styleFrom(
              foregroundColor: colors.onSurfaceVariant,
            ),
            child: const Text('Stay here'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: ProfileScreen.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Log out'),
          ),
        ],
      );
    },
  );

  if (!mounted || shouldLogout != true) return;

  await _logout();
}


  // LOGOUT
  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    String? message;

    try {
      await AuthService.instance.logout();
    } on AuthException {
      message =
          'Logged out on this device. Could not confirm logout with the server.';
    }

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (_) => false,
    );

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _loggingOut,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 30),
            children: [
              const PageHeader('Profile'),
              const SizedBox(height: 18),

              // PROFILE HEADER
              AnimatedBuilder(
                animation: AuthService.instance,
                builder: (context, _) {
                  final user = AuthService.instance.user;

                  final name =
                      (user?['name'] ?? 'Your account').toString();

                  final contact = (user?['email'] ??
                          user?['phone'] ??
                          'No contact information')
                      .toString();

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        const ProfileAvatar(size: 76),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                contact,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),

              const SizedBox(height: 18),

              // MY IDS & DOCUMENTS
              Material(
                color: const Color(0xFFE7EEF8),
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: _openInventory,
                  borderRadius: BorderRadius.circular(22),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius:
                                BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.folder_copy_outlined,
                            color: primaryBlue,
                            size: 27,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'My IDs & Documents',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF182D50),
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                'Manage what you already have',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF52647D),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_outward_rounded,
                          color: primaryBlue,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // MY ACCOUNT
              _heading('MY ACCOUNT', muted),
              _group(colors, [
                _entry(
                  Icons.person_outline_rounded,
                  'Personal information',
                  _openAccountDetails,
                ),
                _entry(
                  Icons.lock_outline_rounded,
                  'Password & security',
                  _openPasswordSecurity,
                ),
              ]),

              // HELP & INFORMATION
              _heading('HELP & INFORMATION', muted),
              _group(colors, [
                _entry(
                  Icons.help_outline_rounded,
                  'Help & FAQs',
                  _openHelpFaq,
                ),
                _entry(
                  Icons.info_outline_rounded,
                  'About IDireksyon',
                  _openAbout,
                ),
                _entry(
                  Icons.privacy_tip_outlined,
                  'Privacy Policy',
                  _openPrivacyPolicy,
                ),
                _entry(
                  Icons.article_outlined,
                  'Terms of Service',
                  _openTermsOfService,
                ),
              ]),

              const SizedBox(height: 24),

              // LOG OUT
              
OutlinedButton.icon(
  onPressed: _loggingOut ? null : _confirmLogout,
  icon: const Icon(
    Icons.logout_rounded,
    size: 19,
  ),
  label: Text(
    _loggingOut ? 'Logging out…' : 'Log out',
    style: const TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
  ),
  style: OutlinedButton.styleFrom(
    foregroundColor: ProfileScreen.primaryBlue,
    backgroundColor: colors.surface,
    minimumSize: const Size.fromHeight(52),
    side: BorderSide(
      color: colors.outlineVariant,
      width: 1,
    ),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
    ),
  ),
),


              const SizedBox(height: 15),

              Text(
                'IDireksyon',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: muted,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // SECTION HEADING
  Widget _heading(String title, Color muted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }

  // PROFILE MENU ENTRY
  _ProfileEntry _entry(
    IconData icon,
    String label,
    VoidCallback onTap,
  ) {
    return _ProfileEntry(icon, label, onTap);
  }

  // GROUPED SETTINGS
  Widget _group(
    ColorScheme colors,
    List<_ProfileEntry> entries,
  ) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            InkWell(
              onTap: entries[i].onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 17,
                  vertical: 18,
                ),
                child: Row(
                  children: [
                    Icon(
                      entries[i].icon,
                      size: 21,
                      color: colors.onSurfaceVariant,
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        entries[i].label,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: colors.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),

            if (i != entries.length - 1)
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 52,
                endIndent: 16,
                color: colors.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }
}

// PROFILE ENTRY MODEL
class _ProfileEntry {
  const _ProfileEntry(
    this.icon,
    this.label,
    this.onTap,
  );

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}
