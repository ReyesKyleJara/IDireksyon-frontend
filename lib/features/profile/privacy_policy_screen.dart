
import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _navy = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            const Text(
              'Privacy Policy',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'How IDireksyon handles information '
              'you provide while using the app.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: muted,
              ),
            ),
            const SizedBox(height: 32),

            _section(
              context,
              '01',
              'Introduction',
              'IDireksyon is an academic mobile application '
                  'designed to help users understand government '
                  'ID requirements, organize their documents, '
                  'and plan their ID application journey.',
            ),

            _section(
              context,
              '02',
              'Information you provide',
              'Depending on the features you use, IDireksyon '
                  'may handle your name, email address or mobile '
                  'number, account credentials, profile photo, '
                  'and information about the IDs and documents '
                  'you indicate that you already have.',
            ),

            _section(
              context,
              '03',
              'How your information is used',
              'Your information is used to support your account, '
                  'save your document inventory, and provide '
                  'guidance based on the information you enter. '
                  'It may also be used to support the operation '
                  'and security of the application.',
            ),

            _section(
              context,
              '04',
              'Profile photos',
              'Profile photos are selected by you and are '
                  'currently stored on your device. You can '
                  'change or remove your photo through the '
                  'Edit Profile screen.',
            ),

            _section(
              context,
              '05',
              'Location and maps',
              'IDireksyon includes an Office Finder feature '
                  'that may use map and location services. '
                  'Location access, when requested, helps '
                  'provide location-related functionality. '
                  'External map services may process information '
                  'according to their own privacy practices.',
            ),

            _section(
              context,
              '06',
              'Data protection',
              'IDireksyon is designed to use account '
                  'authentication and appropriate safeguards '
                  'to help protect user information. '
                  'No application can guarantee absolute '
                  'security, so users should also keep '
                  'their account credentials private.',
            ),

            _section(
              context,
              '07',
              'Your choices',
              'You can update your account details, change '
                  'your password, manage your document inventory, '
                  'and change or remove your locally stored '
                  'profile photo through the available '
                  'application features.',
            ),

            _section(
              context,
              '08',
              'Changes to this notice',
              'This privacy notice may be revised as '
                  'IDireksyon is developed and its features '
                  'or data-handling practices change.',
            ),

            const SizedBox(height: 10),

            Container(
              padding: const EdgeInsets.all(17),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEF8),
                borderRadius: BorderRadius.circular(17),
              ),
              child: const Text(
                'IDireksyon is an academic project and '
                'is not an official government application. '
                'This notice should be reviewed against '
                'the final implementation before deployment.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.55,
                  color: Color(0xFF263C5C),
                ),
              ),
            ),

            const SizedBox(height: 28),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 14),

            Text(
              'IDireksyon • Privacy information',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String number,
    String title,
    String description,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 27),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _navy,
                ),
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
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              height: 1.65,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
