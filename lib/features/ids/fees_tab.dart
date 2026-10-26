import 'package:flutter/material.dart';
import '../../models/government_id.dart';

class FeesTab extends StatefulWidget {
  final GovernmentIdDetails? record;
  const FeesTab({super.key, required this.record});

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

  Widget optionCard(CatalogFee option, int feeIndex, int index, bool chosen) =>
      Semantics(
        selected: chosen,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.all(16),
            backgroundColor: chosen ? Theme.of(context).colorScheme.primaryContainer : null,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: () => setState(() => selected[feeIndex] = index),
          child: SizedBox(width: double.infinity, child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(chosen ? Icons.radio_button_checked : Icons.radio_button_off),
              const SizedBox(height: 8),
              Text(option.displayAmount, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              Text(option.label, style: const TextStyle(fontWeight: FontWeight.w600)),
              if (option.description != null) Text(option.description!),
              if (option.notes != null) Text(option.notes!),
            ],
          )),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final record = widget.record;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 32), children: [
      const Text('Estimated fees', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
      const SizedBox(height: 16),
      if (record == null) const Text('Fee information is unavailable.'),
      if (record != null && record.fees.isEmpty)
        Text(record.legacyFee ?? 'Fee information has not been added yet.'),
      if (record != null)
        for (var feeIndex = 0; feeIndex < record.fees.length; feeIndex++)
          Builder(builder: (context) {
            final fee = record.fees[feeIndex];
            final choice = selected[feeIndex];
            return Card(margin: const EdgeInsets.only(bottom: 16), child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(fee.label, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                if (fee.isOptional) const Text('Optional fee'),
                if (fee.notes != null) Text(fee.notes!),
                if (fee.type == 'options') ...[
                  const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Choose one processing option')),
                  LayoutBuilder(builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 520 && MediaQuery.textScalerOf(context).scale(1) <= 1.3;
                    return Wrap(spacing: 12, runSpacing: 12, children: [
                      for (var index = 0; index < fee.options.length; index++)
                        SizedBox(width: wide ? (constraints.maxWidth - 12) / 2 : constraints.maxWidth,
                          child: optionCard(fee.options[index], feeIndex, index, choice == index)),
                    ]);
                  }),
                  const SizedBox(height: 12),
                  Text(choice != null && choice < fee.options.length
                    ? 'Selected option: ${fee.options[choice].label} — ${fee.options[choice].displayAmount}'
                    : 'Select one option to see its applicable fee.'),
                ] else Padding(padding: const EdgeInsets.only(top: 8), child: Text(fee.displayAmount)),
              ]),
            ));
          }),
      const Text('Fees may change. Verify current fees with the issuing agency.'),
    ]);
  }
}
