import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import '../loading/loading_screen.dart';
import '../ids/id_details_screen.dart';
import '../office_finder/office_finder_screen.dart';
import '../shell/resident_app_shell.dart';
import 'build_roadmap_screen.dart';
import 'id_journey.dart';
import 'suggested_roadmap_screen.dart';

class JourneyLoadingScreen extends StatelessWidget {
  const JourneyLoadingScreen({
    super.key,
    this.journey,
    this.existingJourneys = const [],
  });
  final IdJourney? journey;
  final List<IdJourney> existingJourneys;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: LoadingScreen(
      onComplete: (context) {
        for (final existing in existingJourneys) {
          existing.minimized = true;
        }
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => ResidentAppShell(
              initialIndex: 1,
              journeys: [...existingJourneys, journey ?? IdJourney()],
            ),
          ),
          (_) => false,
        );
      },
    ),
  );
}

class ActiveJourneyScreen extends StatefulWidget {
  const ActiveJourneyScreen({
    super.key,
    this.journeys = const [],
    this.initialJourney,
  });
  final List<IdJourney> journeys;
  final IdJourney? initialJourney;

  @override
  State<ActiveJourneyScreen> createState() => _ActiveJourneyScreenState();
}

class _ActiveJourneyScreenState extends State<ActiveJourneyScreen> {
  late final List<IdJourney> _journeys = widget.journeys.isEmpty
      ? [IdJourney()]
      : widget.journeys;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final displayedJourneys = [
      if (widget.initialJourney != null &&
          _journeys.contains(widget.initialJourney))
        widget.initialJourney!,
      ..._journeys.where((journey) => journey != widget.initialJourney),
    ];
    final accent = colors.brightness == Brightness.dark
        ? Colors.blue.shade200
        : const Color(0xFF12499A);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const PageHeader('My ID Journey'),
          const SizedBox(height: 6),
          Text(
            'Minimize a journey to keep your progress in view while planning another ID.',
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => BuildRoadmapScreen(existingJourneys: _journeys),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add another ID journey',
              textAlign: TextAlign.center,
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: accent,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              side: BorderSide(color: accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 20),
          for (var i = 0; i < displayedJourneys.length; i++) ...[
            _JourneyCard(
              key: ObjectKey(displayedJourneys[i]),
              journey: displayedJourneys[i],
              number: _journeys.indexOf(displayedJourneys[i]) + 1,
              onToggle: () => setState(
                () => displayedJourneys[i].minimized =
                    !displayedJourneys[i].minimized,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    super.key,
    required this.journey,
    required this.number,
    required this.onToggle,
  });
  final IdJourney journey;
  final int number;
  final VoidCallback onToggle;

  List<({String title, String detail, IconData icon, Widget page})> get _steps {
    if (journey.targetIds.length == 1 &&
        journey.targetIds.first == 'Passport ID') {
      return [
        (
          title: 'Birth Certificate',
          detail: 'Prepare your PSA copy and supporting documents.',
          icon: Icons.workspace_premium_outlined,
          page: const PsaBirthCertificateGuideScreen(),
        ),
        (
          title: 'PhilSys National ID Registration',
          detail: 'Review the requirements for your National ID.',
          icon: Icons.badge_outlined,
          page: const IdDetailsScreen(idName: 'PhilSys ID'),
        ),
        (
          title: 'Passport Application',
          detail: 'Check requirements and plan your DFA appointment.',
          icon: Icons.menu_book_outlined,
          page: const IdDetailsScreen(idName: 'Passport ID'),
        ),
        (
          title: 'Find DFA Office',
          detail: 'Find an office for your passport application.',
          icon: Icons.location_on_outlined,
          page: const OfficeFinderScreen(),
        ),
      ];
    }
    return [
      for (final id in journey.targetIds)
        (
          title: id,
          detail: 'Review the requirements and application guide for this ID.',
          icon: Icons.badge_outlined,
          page: IdDetailsScreen(idName: id),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? Colors.blue.shade200 : const Color(0xFF12499A);
    final steps = _steps;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: dark ? colors.surfaceContainer : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: .6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'JOURNEY $number',
            style: TextStyle(
              fontSize: 10,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            journey.title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onToggle,
              icon: Icon(
                journey.minimized
                    ? Icons.expand_more_rounded
                    : Icons.expand_less_rounded,
              ),
              label: Text(
                journey.minimized ? 'Expand progress' : 'Minimize progress',
              ),
              style: TextButton.styleFrom(
                foregroundColor: accent,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Overall readiness',
                  style: TextStyle(
                    fontSize: 13,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                journey.readinessLabel,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: journey.readiness,
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
            backgroundColor: colors.outlineVariant.withValues(alpha: .5),
            color: accent,
            semanticsLabel: '${journey.title} overall readiness',
            semanticsValue: journey.readinessLabel,
          ),
          if (!journey.minimized) ...[
            const SizedBox(height: 24),
            const Text(
              'Your next steps',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < steps.length; i++) ...[
              Material(
                color: i == 0
                    ? (dark
                          ? colors.surfaceContainerHigh
                          : const Color(0xFFEFF5FD))
                    : (dark ? colors.surfaceContainer : Colors.white),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: i == 0 ? accent : colors.outlineVariant,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: MotionInkWell(
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => steps[i].page)),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(steps[i].icon, size: 24, color: accent),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STEP ${i + 1}',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                steps[i].title,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                steps[i].detail,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (i < steps.length - 1) const SizedBox(height: 12),
            ],
          ],
        ],
      ),
    );
  }
}
