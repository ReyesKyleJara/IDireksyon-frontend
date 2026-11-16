import 'package:flutter/material.dart';

import '../../models/government_id.dart';
import '../../core/theme/app_theme.dart';

class FeesTab extends StatelessWidget {
  final GovernmentIdDetails? record;
  final bool embedded;
  const FeesTab({super.key, required this.record, this.embedded = false});

  Color _blue(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA8CCFA)
      : AppTheme.primaryBlue;

  Widget optionDetails(BuildContext context, CatalogFee option) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                option.displayAmount,
                maxLines: 1,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: _blue(context),
                ),
              ),
            ),
          ),
          Text(
            option.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: colors.onSurface,
            ),
          ),
          for (final detail in [option.description, option.notes])
            if (detail != null && detail.trim().isNotEmpty)
              Text(
                detail,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: colors.onSurfaceVariant,
                ),
              ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = this.record;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      shrinkWrap: embedded,
      primary: embedded ? false : null,
      physics: embedded ? const NeverScrollableScrollPhysics() : null,
      padding: embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (!embedded) ...[
          Text(
            'Cost breakdown',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: colors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Fees that may apply to this application.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (record == null) const Text('Fee information is unavailable.'),
        if (record != null && record.fees.isEmpty)
          Text(record.legacyFee ?? 'Fee information has not been added yet.'),
        if (record != null)
          for (var feeIndex = 0; feeIndex < record.fees.length; feeIndex++)
            Builder(
              builder: (context) {
                final fee = record.fees[feeIndex];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  elevation: 0,
                  color: colors.brightness == Brightness.dark
                      ? colors.surfaceContainer
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fee.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      height: 1.35,
                                      fontWeight: FontWeight.w700,
                                      color: _blue(context),
                                    ),
                                  ),
                                  if (fee.isOptional)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        'Optional fee',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (fee.type != 'options') ...[
                              const SizedBox(width: 12),
                              Flexible(
                                flex: 2,
                                child: Text(
                                  fee.displayAmount,
                                  textAlign: TextAlign.end,
                                  style: TextStyle(
                                    fontSize: 16,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: _blue(context),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (fee.notes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              fee.notes!.replaceAll(
                                'Choose one processing option. ',
                                '',
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (fee.type == 'options')
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final sideBySide =
                                    constraints.maxWidth >= 280 &&
                                    MediaQuery.textScalerOf(context).scale(1) <=
                                        1.3;
                                final options = <Widget>[];
                                for (final option in fee.options) {
                                  if (options.isNotEmpty) {
                                    options.add(
                                      sideBySide
                                          ? VerticalDivider(
                                              width: 1,
                                              color: colors.outlineVariant,
                                            )
                                          : Divider(
                                              color: colors.outlineVariant,
                                            ),
                                    );
                                  }
                                  final details = optionDetails(
                                    context,
                                    option,
                                  );
                                  options.add(
                                    sideBySide
                                        ? Expanded(child: details)
                                        : details,
                                  );
                                }
                                return sideBySide
                                    ? IntrinsicHeight(
                                        child: Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: options,
                                        ),
                                      )
                                    : Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: options,
                                      );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _blue(context).withValues(alpha: .06),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _blue(context), size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Notes',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _blue(context),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fees may change. Verify current fees with the issuing agency.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
