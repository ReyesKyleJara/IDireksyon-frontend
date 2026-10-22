
import 'package:flutter/material.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key, this.isModal = false});

  final bool isModal;

  static const _navy = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !isModal,
        actions: isModal
            ? [IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              )]
            : null,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            const Text(
              'Terms of Service',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Guidelines for using IDireksyon and its features.',
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
              'About IDireksyon',
              'IDireksyon is an academic mobile application '
                  'designed to help users understand government '
                  'ID requirements, organize their documents, '
                  'and plan their ID application journey.',
            ),

            _section(
              context,
              '02',
              'Purpose of the application',
              'IDireksyon provides informational guidance '
                  'about supported government IDs, including '
                  'requirements, suggested preparation steps, '
                  'document tracking, and relevant office locations.',
            ),

            _section(
              context,
              '03',
              'Not an official government service',
              'IDireksyon is not affiliated with or operated '
                  'by any government agency. It does not issue '
                  'government IDs, submit applications, '
                  'process payments, or book appointments.',
            ),

            _section(
              context,
              '04',
              'Accuracy of information',
              'Government requirements, fees, office locations, '
                  'and procedures may change. While IDireksyon '
                  'aims to provide helpful information, users '
                  'should confirm current requirements through '
                  'official government sources before applying.',
            ),

            _section(
              context,
              '05',
              'User responsibilities',
              'Users are responsible for providing accurate '
                  'information when using the application, '
                  'keeping their account credentials secure, '
                  'and using IDireksyon only for lawful purposes.',
            ),

            _section(
              context,
              '06',
              'Document inventory and roadmap',
              'The document inventory and suggested roadmap '
                  'depend on the information entered by the user. '
                  'Recommendations are intended as preparation '
                  'guidance and do not guarantee eligibility, '
                  'approval, or successful issuance of an ID.',
            ),

            _section(
              context,
              '07',
              'External services',
              'Certain features may open external map services '
                  'or government websites. These services are '
                  'operated independently and may have their '
                  'own terms and privacy practices.',
            ),

            _section(
              context,
              '08',
              'Availability and updates',
              'As an academic project, IDireksyon may undergo '
                  'testing, maintenance, or changes to its '
                  'features and information. Some functions '
                  'may not always be available.',
            ),

            _section(
              context,
              '09',
              'Changes to these terms',
              'These terms may be updated as the application '
                  'is developed or its functionality changes. '
                  'Users should review the latest version '
                  'when it becomes available.',
            ),

            const SizedBox(height: 4),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEF8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: _navy,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'IDireksyon is intended for informational '
                      'and educational purposes. Official '
                      'government agencies remain the authority '
                      'for ID requirements and applications.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.55,
                        color: Color(0xFF263C5C),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 14),

            Text(
              'IDireksyon • Terms of Service',
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
