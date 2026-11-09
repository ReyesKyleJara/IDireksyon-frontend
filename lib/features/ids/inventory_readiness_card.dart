import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../../models/government_id.dart';
import '../../services/application_preparation.dart';

/// Detail readiness uses explicit application preparation, separate from Directory ownership scores.
class ApplicationPreparationCard extends StatefulWidget {
  const ApplicationPreparationCard({super.key, required this.record});
  final GovernmentIdDetails record;

  @override
  State<ApplicationPreparationCard> createState() =>
      _ApplicationPreparationCardState();
}

class _ApplicationPreparationCardState
    extends State<ApplicationPreparationCard> {
  late final AuthService _auth = AuthService.instance;
  ApplicationPreparation? _preparation;
  int _revision = -1, _inventoryRevision = -1, _generation = 0;
  String? _token;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _auth.addListener(_refresh);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant ApplicationPreparationCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.record.id != widget.record.id ||
        oldWidget.record.recordType != widget.record.recordType) {
      unawaited(_load());
    }
  }

  void _refresh() {
    if (_revision == _auth.preparationRevision &&
        _inventoryRevision == _auth.inventoryRevision &&
        _token == _auth.token) {
      return;
    }
    _revision = _auth.preparationRevision;
    _inventoryRevision = _auth.inventoryRevision;
    _token = _auth.token;
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final record = widget.record;
    setState(() {
      _preparation = null;
      _loading = _token != null;
    });
    if (_token == null) return;
    try {
      final data = await _auth.getRequirementPreparation(
        record.recordType,
        record.id,
      );
      final preparation = ApplicationPreparation.fromJson(data);
      if (mounted && generation == _generation) {
        setState(() => _preparation = preparation);
      }
    } catch (_) {
      // An unavailable response must not be shown as zero preparation.
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  void dispose() {
    _generation++;
    _auth.removeListener(_refresh);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final set = widget.record.requirementSets.firstOrNull;
    final preparation = _preparation;
    final summary = preparation == null || set == null
        ? null
        : preparationSummary(set, preparation);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Application preparation',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: colors.primary,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          summary == null || summary.total == 0
              ? (_loading
                    ? 'Loading saved checklist…'
                    : _token == null
                    ? 'Sign in to view your progress.'
                    : 'Preparation is unavailable for this checklist.')
              : '${summary.complete} of ${summary.total} required groups prepared',
          style: const TextStyle(fontSize: 13),
        ),
        if (summary != null && summary.total > 0) ...[
          const SizedBox(height: 6),
          Text(
            summary.conditional
                ? 'Some items depend on your situation. The issuing office makes the final check.'
                : 'Based on your saved checklist for this application.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: colors.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
    final ring = summary == null || summary.total == 0
        ? null
        : SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: summary.completion,
                    strokeWidth: 6,
                    strokeCap: StrokeCap.round,
                    color: AppTheme.accentGold,
                    backgroundColor: colors.outlineVariant.withValues(
                      alpha: .5,
                    ),
                    semanticsLabel: 'Application preparation',
                    semanticsValue: '${(summary.completion * 100).round()}%',
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(11),
                  child: FittedBox(
                    child: Text(
                      '${(summary.completion * 100).round()}%',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
    return Container(
      key: const ValueKey('application-preparation-card'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .4)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (ring == null) return details;
          if (constraints.maxWidth < 250 ||
              MediaQuery.textScalerOf(context).scale(12) > 18) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [ring, const SizedBox(height: 14), details],
            );
          }
          return Row(
            children: [
              ring,
              const SizedBox(width: 16),
              Expanded(child: details),
            ],
          );
        },
      ),
    );
  }
}
