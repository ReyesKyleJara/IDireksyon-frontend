import 'package:flutter/material.dart';

import 'active_journey_screen.dart';
import 'id_journey.dart';
import '../ids/id_details_screen.dart';
import '../office_finder/office_finder_screen.dart';

class SuggestedRoadmapScreen extends StatelessWidget {
  const SuggestedRoadmapScreen({
    super.key,
    this.targetIds = const ['Passport ID'],
    this.ownedItems = const [],
    this.existingJourneys = const [],
  });
  final List<String> targetIds;
  final List<String> ownedItems;
  final List<IdJourney> existingJourneys;

  List<_RoadmapStep> get _steps =>
      targetIds.length == 1 && targetIds.first == 'Passport ID'
      ? _passportSteps
      : [
          for (final id in targetIds)
            _RoadmapStep(
              title: id,
              subtitle:
                  'Review the requirements and application guide for this ID.',
              icon: Icons.badge_outlined,
            ),
        ];

  static const primaryBlue = Color(0xFF12499A);

  static const _passportSteps = [
    _RoadmapStep(
      title: 'Birth Certificate',
      subtitle:
          'Confirm if you have the original PSA copy and prepare photocopies',
      icon: Icons.workspace_premium_outlined,
    ),
    _RoadmapStep(
      title: 'PhilSys National ID Registration',
      subtitle: 'Get a National ID first before getting a Passport',
      icon: Icons.fact_check_outlined,
    ),
    _RoadmapStep(
      title: 'Passport Application',
      subtitle: 'Reserve your appointment through the DFA website',
      icon: Icons.edit_note_outlined,
    ),
    _RoadmapStep(
      title: 'Find DFA Office',
      subtitle: 'Find the nearest DFA Office and process your application',
      icon: Icons.location_on_outlined,
    ),
  ];

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
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
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
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Review the next steps for your ${targetIds.join(' + ')} journey.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _TargetCard(colors: colors, title: targetIds.join(' + ')),
                const SizedBox(height: 8),
                SizedBox(
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 8),
                    itemCount: _steps.length,
                    itemBuilder: (context, index) => _StepRow(
                      step: _steps[index],
                      number: index + 1,
                      isLast: index == _steps.length - 1,
                      colors: colors,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(minHeight: 48),
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => JourneyLoadingScreen(
                          journey: IdJourney(
                            targetIds: targetIds,
                            ownedItems: ownedItems,
                          ),
                          existingJourneys: existingJourneys,
                        ),
                      ),
                    ),
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

class _TargetCard extends StatelessWidget {
  const _TargetCard({required this.colors, required this.title});
  final String title;

  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 103),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.brightness == Brightness.dark
            ? colors.surfaceContainer
            : Colors.white,
        border: Border.all(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 76,
            height: 76,
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.menu_book_rounded,
              color: SuggestedRoadmapScreen.primaryBlue,
              size: 43,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _TargetMetric(
              label: 'Target ID',
              value: title,
              colors: colors,
            ),
          ),
          VerticalDivider(color: colors.outlineVariant, width: 1),
          const SizedBox(width: 16),
          Expanded(
            child: _TargetMetric(
              label: 'Overall Readiness',
              value: '0%',
              colors: colors,
              showBar: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _TargetMetric extends StatelessWidget {
  const _TargetMetric({
    required this.label,
    required this.value,
    required this.colors,
    this.showBar = false,
  });

  final String label;
  final String value;
  final ColorScheme colors;
  final bool showBar;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colors.onSurface)),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: SuggestedRoadmapScreen.primaryBlue,
          ),
        ),
        if (showBar) ...[
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(
              value: 0,
              minHeight: 7,
              backgroundColor: Color(0xFFE4E8EF),
              valueColor: AlwaysStoppedAnimation<Color>(
                SuggestedRoadmapScreen.primaryBlue,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.step,
    required this.number,
    required this.isLast,
    required this.colors,
  });
  final _RoadmapStep step;
  final int number;
  final bool isLast;
  final ColorScheme colors;

  @override
  Widget build(BuildContext context) {
    final accent = colors.brightness == Brightness.dark
        ? Colors.blue.shade200
        : SuggestedRoadmapScreen.primaryBlue;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: SuggestedRoadmapScreen.primaryBlue,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: colors.outlineVariant),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.brightness == Brightness.dark
                    ? colors.surfaceContainer
                    : Colors.white,
                border: Border.all(color: colors.outlineVariant),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(step.icon, size: 28, color: accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              step.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              step.subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.4,
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => switch (step.title) {
                          'Birth Certificate' =>
                            const PsaBirthCertificateGuideScreen(),
                          'Find DFA Office' => const OfficeFinderScreen(),
                          'Passport Application' => const IdDetailsScreen(
                            idName: 'Passport ID',
                          ),
                          'PhilSys National ID Registration' =>
                            const IdDetailsScreen(idName: 'PhilSys ID'),
                          _ => IdDetailsScreen(idName: step.title),
                        },
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      minimumSize: const Size.fromHeight(48),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Preview Guide',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
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
          icon: Icon(Icons.arrow_back_rounded, color: colors.onSurface),
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

class _RoadmapStep {
  const _RoadmapStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;
}
