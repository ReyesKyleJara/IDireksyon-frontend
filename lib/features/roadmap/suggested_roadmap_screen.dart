import 'package:flutter/material.dart';

import 'active_journey_screen.dart';
import '../../core/auth/auth_service.dart';
import 'id_journey.dart';
import 'roadmap_plan_panel.dart';
import '../../models/roadmap_plan.dart';
import 'suggested_journey_view.dart';

class SuggestedRoadmapScreen extends StatefulWidget {
  const SuggestedRoadmapScreen({
    super.key,
    this.targetIds = const ['Passport ID'],
    this.targetCatalogIds = const [],
    this.targetDocumentIds = const [],
    this.ownedItems = const [],
    this.existingJourneys = const [],
  });
  final List<String> targetIds;
  final List<int> targetCatalogIds;
  final List<int> targetDocumentIds;
  final List<String> ownedItems;
  final List<IdJourney> existingJourneys;

  @override
  State<SuggestedRoadmapScreen> createState() => _SuggestedRoadmapScreenState();

  static const primaryBlue = Color(0xFF12499A);
}

class _SuggestedRoadmapScreenState extends State<SuggestedRoadmapScreen> {
  RoadmapPlan? _plan;
  bool _saving = false;
  List<String> get targetIds => widget.targetIds;
  List<int> get targetCatalogIds => widget.targetCatalogIds;
  List<String> get ownedItems => widget.ownedItems;
  List<IdJourney> get existingJourneys => widget.existingJourneys;
  String get _goalTitle => targetIds
      .map((name) => name == 'Passport ID' ? 'Philippine Passport' : name)
      .join(' + ');
  bool get _passport =>
      targetIds.length == 1 && _goalTitle.toLowerCase().contains('passport');

  static const primaryBlue = Color(0xFF12499A);

  Future<void> _confirm() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final journey = IdJourney.fromJson(
        await AuthService.instance.saveJourney(
          targetCatalogIds,
          widget.targetDocumentIds,
        ),
      );
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => JourneyLoadingScreen(
            journey: journey,
            existingJourneys: existingJourneys
                .where((item) => item.id != journey.id)
                .toList(),
          ),
        ),
      );
    } on AuthException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } on FormatException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The server returned unexpected journey data. Please try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.primary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Suggested Roadmap',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: colors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _passport
                      ? 'Here’s the recommended sequence for your Passport journey.'
                      : 'Here’s the recommended sequence for your journey.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                if (targetCatalogIds.isNotEmpty ||
                    widget.targetDocumentIds.isNotEmpty)
                  RoadmapPlanPanel(
                    targetIds: targetCatalogIds,
                    targetDocumentIds: widget.targetDocumentIds,
                    guidedPresentation: true,
                    onPlan: (plan) {
                      if (mounted) setState(() => _plan = plan);
                    },
                  )
                else ...[
                  RoadmapGoalCard(
                    title: _goalTitle,
                    stepCount: targetIds.length,
                  ),
                  const SizedBox(height: 16),
                  for (var i = 0; i < targetIds.length; i++)
                    SuggestedJourneyStep(
                      number: i + 1,
                      name: targetIds[i] == 'Passport ID'
                          ? 'Philippine Passport'
                          : targetIds[i],
                      isGoal: true,
                      isLast: i == targetIds.length - 1,
                    ),
                ],
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    onPressed:
                        _saving ||
                            ((targetCatalogIds.isNotEmpty ||
                                    widget.targetDocumentIds.isNotEmpty) &&
                                (_plan == null || _plan!.blocked))
                        ? null
                        : _confirm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Confirm Suggested Journey',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PsaBirthCertificateGuideScreen extends StatelessWidget {
  const PsaBirthCertificateGuideScreen({super.key});

  static const primaryBlue = Color(0xFF12499A);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded, color: colors.primary),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PSA Birth Certificate Guide',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Step 1 of 4 • Ensure you have copy of birth certificate',
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Text(
                  'Required for Passport',
                  style: TextStyle(
                    color: primaryBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
                decoration: BoxDecoration(
                  color: colors.brightness == Brightness.dark
                      ? colors.surfaceContainer
                      : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  children: [
                    _GuideBulletRow(
                      icon: Icons.account_balance_outlined,
                      title: 'Request from the official PSA channel',
                      detail: 'Secure and official. Avoid fliers and unauthorized agents.',
                    ),
                    const SizedBox(height: 18),
                    _GuideBulletRow(
                      icon: Icons.person_outline,
                      title: 'Prepare your personal details',
                      detail: 'Full name, date of birth, place of birth, and parent\'s full names are usually required.',
                    ),
                    const SizedBox(height: 18),
                    _GuideBulletRow(
                      icon: Icons.security_outlined,
                      title: 'Ensure the document is legible & authentic',
                      detail: 'Full name, date of birth, place of birth, and parent\'s full names are usually required.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              Text(
                'If you don’t have it yet',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 12),
              _InfoLinkRow(
                label: 'PSA Serbilis',
                subtitle: 'Request your PSA Birth Certificate online',
                icon: Icons.open_in_new_rounded,
              ),
              const SizedBox(height: 10),
              _InfoLinkRow(
                label: 'PSAHelpline.ph',
                subtitle: 'Check requirements and get support',
                icon: Icons.open_in_new_rounded,
              ),
              const SizedBox(height: 22),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 14,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tips',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: colors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ChecklistItem(text: 'Print 2-3 copies'),
                    _ChecklistItem(
                      text: 'Keep the original copy in a clear envelope.',
                    ),
                    _ChecklistItem(
                      text: 'Check that your full name and birth details are correct.',
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
}

class _GuideBulletRow extends StatelessWidget {
  const _GuideBulletRow({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF1FF),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            color: PsaBirthCertificateGuideScreen.primaryBlue,
            size: 18,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoLinkRow extends StatelessWidget {
  const _InfoLinkRow({
    required this.label,
    required this.subtitle,
    required this.icon,
  });

  final String label;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            icon,
            color: PsaBirthCertificateGuideScreen.primaryBlue,
            size: 18,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: PsaBirthCertificateGuideScreen.primaryBlue,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colors.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
