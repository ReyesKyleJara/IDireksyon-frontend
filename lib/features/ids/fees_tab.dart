import 'package:flutter/material.dart';

import '../../models/government_id.dart';
import '../../core/theme/app_theme.dart';

class FeesTab extends StatefulWidget {
  final GovernmentIdDetails? record;
  final bool embedded;
  const FeesTab({super.key, required this.record, this.embedded = false});

  @override
  State<FeesTab> createState() => _FeesTabState();
}

class _FeesTabState extends State<FeesTab> {
  final Map<int, int> selected = {};

  @override
  void didUpdateWidget(covariant FeesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record?.id != widget.record?.id) selected.clear();
  }

  Color get _blue => Theme.of(context).brightness == Brightness.dark
      ? const Color(0xFFA8CCFA)
      : AppTheme.primaryBlue;

  Widget optionCard(CatalogFee option, int feeIndex, int index, bool chosen) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: chosen,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          foregroundColor: _blue,
          padding: const EdgeInsets.all(12),
          backgroundColor: chosen
              ? _blue.withValues(alpha: .07)
              : colors.brightness == Brightness.dark
              ? colors.surfaceContainer
              : Colors.white,
          side: BorderSide(
            color: chosen
                ? _blue.withValues(alpha: .6)
                : colors.outlineVariant.withValues(alpha: .55),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () => setState(() => selected[feeIndex] = index),
        child: SizedBox(
          width: double.infinity,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  chosen ? Icons.radio_button_checked : Icons.radio_button_off,
                  size: 19,
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.displayAmount,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      option.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurface,
                      ),
                    ),
                    if (option.description != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          option.description!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (option.notes != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          option.notes!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    final colors = Theme.of(context).colorScheme;
    return ListView(
      shrinkWrap: widget.embedded,
      primary: widget.embedded ? false : null,
      physics: widget.embedded ? const NeverScrollableScrollPhysics() : null,
      padding: widget.embedded
          ? EdgeInsets.zero
          : const EdgeInsets.fromLTRB(18, 12, 18, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.payments_outlined, color: _blue, size: 22),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Total Estimated Cost',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _blue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'See the applicable fee breakdown below.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Cost Overview',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: _blue,
          ),
        ),
        const SizedBox(height: 9),
        if (record == null) const Text('Fee information is unavailable.'),
        if (record != null && record.fees.isEmpty)
          Text(record.legacyFee ?? 'Fee information has not been added yet.'),
        if (record != null)
          for (var feeIndex = 0; feeIndex < record.fees.length; feeIndex++)
            Builder(
              builder: (context) {
                final fee = record.fees[feeIndex];
                final choice = selected[feeIndex];
                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  elevation: 0,
                  color: colors.brightness == Brightness.dark
                      ? colors.surfaceContainer
                      : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: .5),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fee.label,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _blue,
                          ),
                        ),
                        if (fee.isOptional)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Optional fee',
                              style: TextStyle(
                                fontSize: 11,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (fee.notes != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 5),
                            child: Text(
                              fee.notes!,
                              style: TextStyle(
                                fontSize: 12,
                                height: 1.4,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ),
                        if (fee.type == 'options') ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 9),
                            child: Text(
                              'Choose one processing option',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final wide =
                                  constraints.maxWidth >= 520 &&
                                  MediaQuery.textScalerOf(context).scale(1) <=
                                      1.3;
                              return Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  for (
                                    var index = 0;
                                    index < fee.options.length;
                                    index++
                                  )
                                    SizedBox(
                                      width: wide
                                          ? (constraints.maxWidth - 12) / 2
                                          : constraints.maxWidth,
                                      child: optionCard(
                                        fee.options[index],
                                        feeIndex,
                                        index,
                                        choice == index,
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 9),
                          Text(
                            choice != null && choice < fee.options.length
                                ? 'Selected option: ${fee.options[choice].label} — ${fee.options[choice].displayAmount}'
                                : 'Select one option to see its applicable fee.',
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ] else
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              fee.displayAmount,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _blue,
                              ),
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
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            color: _blue.withValues(alpha: .045),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline_rounded, color: _blue, size: 17),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Important Notes',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _blue,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Fees may change. Verify current fees with the issuing agency.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
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
