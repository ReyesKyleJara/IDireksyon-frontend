import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/agency_confirmation.dart';

/// One direct agency confirmation, shown below the Public Reference Cards.
///
/// It states exactly what the agency confirmed, for which request paths and
/// when, what it did not cover, and that confirming information is not an
/// endorsement. No seals, logos or approval wording are ever shown.
class AgencyVerificationCard extends StatelessWidget {
  const AgencyVerificationCard({super.key, required this.confirmation});

  final AgencyConfirmation confirmation;

  static const disclaimer =
      'This confirms only the information listed above, as of the date shown. '
      'It does not mean that the agency or any government office endorses, '
      'operates, or is affiliated with IDireksyon.';

  static const partialNotice =
      'Only the information listed above was confirmed. Everything else in '
      'this guide is based on public sources and was not confirmed by the agency.';

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? colors.primary : AppTheme.primaryBlue;
    final muted = colors.onSurfaceVariant;
    final c = confirmation;
    final paths = c.appliesToAllRequestPaths
        ? 'All ways to apply in this guide'
        : (c.requestPathLabels.isEmpty
              ? 'Selected ways to apply only'
              : c.requestPathLabels.join(', '));

    Widget fact(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              letterSpacing: .2,
              fontWeight: FontWeight.w700,
              color: accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.onSurface,
            ),
          ),
        ],
      ),
    );

    return Card(
      color: dark ? colors.surfaceContainer : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(Icons.task_alt_outlined, size: 20, color: accent),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Information Confirmed with ${c.agencyName}',
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                            color: colors.onSurface,
                          ),
                        ),
                      ),
                      if (c.officeLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            c.officeLabel!,
                            style: TextStyle(fontSize: 13, color: muted),
                          ),
                        ),
                      if (c.isPartial)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Partial confirmation',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            Divider(
              height: 22,
              color: colors.outlineVariant.withValues(alpha: .5),
            ),
            fact(
              'Confirmed by the agency',
              c.confirmedAspects.map(AgencyConfirmation.aspectLabel).join(', '),
            ),
            if (c.notCoveredAspects.isNotEmpty)
              fact(
                'Not covered by this confirmation',
                c.notCoveredAspects
                    .map(AgencyConfirmation.aspectLabel)
                    .join(', '),
              ),
            fact('Applies to', paths),
            fact('Scope', '“${c.scope}”'),
            fact('Confirmed on', c.confirmedOnLabel),
            if (c.isPartial)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  partialNotice,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                    color: colors.onSurface,
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                disclaimer,
                style: TextStyle(fontSize: 12, height: 1.45, color: muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
