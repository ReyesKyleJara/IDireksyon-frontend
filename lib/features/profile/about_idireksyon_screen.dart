
import 'package:flutter/material.dart';

class AboutIDireksyonScreen extends StatelessWidget {
  const AboutIDireksyonScreen({super.key});

  static const _navy = Color(0xFF1E3A8A);
  static const _softBlue = Color(0xFFE7EEF8);

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
              'About IDireksyon',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'A simpler way to understand your government ID journey.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: muted,
              ),
            ),

            const SizedBox(height: 30),

            // APP INTRODUCTION
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: _softBlue,
                borderRadius: BorderRadius.circular(22),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.explore_outlined,
                    color: _navy,
                    size: 31,
                  ),
                  SizedBox(height: 15),
                  Text(
                    'Know where to start.',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF182D50),
                    ),
                  ),
                  SizedBox(height: 9),
                  Text(
                    'IDireksyon helps you understand what '
                    'documents you need, which IDs to prepare '
                    'first, and where to find relevant '
                    'government offices.',
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.55,
                      color: Color(0xFF405673),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            _sectionTitle('WHAT YOU CAN DO', muted),
            const SizedBox(height: 14),

            _feature(
              context,
              Icons.fact_check_outlined,
              'Check ID requirements',
              'Find out which documents are needed '
                  'for supported government IDs.',
            ),
            _featureDivider(colors),
            _feature(
              context,
              Icons.route_outlined,
              'Plan your ID journey',
              'Get a suggested order for preparing IDs '
                  'based on your available documents.',
            ),
            _featureDivider(colors),
            _feature(
              context,
              Icons.folder_copy_outlined,
              'Manage your documents',
              'Keep track of the IDs and documents '
                  'you already have.',
            ),
            _featureDivider(colors),
            _feature(
              context,
              Icons.location_on_outlined,
              'Find government offices',
              'View relevant office locations and '
                  'open map navigation when available.',
            ),

            const SizedBox(height: 34),

            _sectionTitle('IMPORTANT TO KNOW', muted),
            const SizedBox(height: 14),

            Text(
              'IDireksyon is an informational guidance '
              'application. It is not an official government '
              'platform and does not process ID applications, '
              'book appointments, or issue government IDs.',
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 14),

            Text(
              'Requirements, fees, and office procedures '
              'may change. Always confirm the latest '
              'information through the relevant government '
              'agency before visiting an office.',
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 34),

            _sectionTitle('ABOUT THE PROJECT', muted),
            const SizedBox(height: 14),

            Text(
              'IDireksyon is developed as an academic '
              'capstone project to make government ID '
              'information easier to access and understand, '
              'particularly for residents and first-time '
              'applicants in Santa Maria, Bulacan.',
              style: TextStyle(
                fontSize: 14,
                height: 1.65,
                color: colors.onSurface,
              ),
            ),

            const SizedBox(height: 35),
            Divider(color: colors.outlineVariant),
            const SizedBox(height: 15),

            Center(
              child: Column(
                children: [
                  Text(
                    'IDireksyon',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: colors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Version 1.0.0',
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
      ),
    );
  }

  Widget _sectionTitle(String title, Color muted) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: muted,
      ),
    );
  }

  Widget _feature(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 43,
            height: 43,
            decoration: BoxDecoration(
              color: _softBlue,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              icon,
              color: _navy,
              size: 21,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _featureDivider(ColorScheme colors) {
    return Divider(
      height: 1,
      thickness: 0.6,
      indent: 57,
      color: colors.outlineVariant,
    );
  }
}
