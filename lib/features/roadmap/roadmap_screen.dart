import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/page_header.dart';
import 'build_roadmap_screen.dart';
import 'roadmap_widgets.dart';
import '../ids/ids_screen.dart';

class RoadmapScreen extends StatefulWidget {
  const RoadmapScreen({super.key, this.onOpenDirectory});
  final VoidCallback? onOpenDirectory;

  @override
  State<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends State<RoadmapScreen> {
  bool _showCompleted = false;

  void _openDirectory(BuildContext context) {
    if (widget.onOpenDirectory != null) {
      widget.onOpenDirectory!();
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          body: const IdsScreen(showBack: true),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PageHeader('My ID Journey'),
            const SizedBox(height: 4),
            Text(
              'Track your progress and get to the IDs you need.',
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            JourneyStatusTabs(
              showCompleted: _showCompleted,
              onChanged: (value) => setState(() => _showCompleted = value),
            ),
            const SizedBox(height: 20),
            if (_showCompleted)
              const JourneyLogEmpty(
                title: 'No completed journeys yet',
                message: 'Journeys you finish will be saved here.',
              )
            else ...[
              const _EmptyRoadmapBanner(),
              const SizedBox(height: 28),
              const Text(
                'How it works',
                style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              const RoadmapCard(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 18, 16, 18),
                  child: Column(
                    children: [
                      _StepRow(
                        number: 1,
                        title: 'Choose your goal',
                        detail: 'Pick the ID or document you want to get.',
                      ),
                      _StepRow(
                        number: 2,
                        title: 'Review what you have',
                        detail: 'Confirm the documents you already own.',
                      ),
                      _StepRow(
                        number: 3,
                        title: 'Follow your plan',
                        detail: 'Get your steps in the right order.',
                        last: true,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              RoadmapDirectoryCard(onTap: () => _openDirectory(context)),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyRoadmapBanner extends StatelessWidget {
  const _EmptyRoadmapBanner();

  @override
  Widget build(BuildContext context) {
    return RoadmapGradientCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showArt =
              constraints.maxWidth >= 320 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.5;
          return Stack(
            children: [
              if (showArt)
                const Positioned(
                  right: 20,
                  top: 0,
                  bottom: 0,
                  child: ExcludeSemantics(child: _RouteArt()),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(22, 24, showArt ? 126 : 22, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Narrow enough to break as "No active / roadmap yet"
                    // and never leave "yet" alone on a line.
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: const Text(
                        'No active roadmap yet',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          height: 1.12,
                          letterSpacing: -.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Build a step-by-step plan for the IDs you need.',
                      style: TextStyle(
                        color: Color(0xFFD5E7FA),
                        fontSize: 12.5,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const BuildRoadmapScreen(),
                        ),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              'Build My Roadmap',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          SizedBox(width: 10),
                          Icon(Icons.arrow_forward_rounded, size: 17),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A short dotted route ending at a gold flag, like the journey it leads to.
class _RouteArt extends StatelessWidget {
  const _RouteArt();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 92,
      child: Center(
        child: SizedBox(
          width: 92,
          height: 120,
          child: Stack(
            children: [
              Positioned.fill(child: CustomPaint(painter: _RoutePainter())),
              Positioned(
                right: 0,
                top: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppTheme.accentGold,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const SizedBox.square(
                    dimension: 40,
                    child: Icon(
                      Icons.flag_rounded,
                      size: 22,
                      color: Color(0xFF163F65),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final start = Offset(8, size.height - 8);
    final middle = Offset(size.width * .46, size.height * .56);
    final route = Path()
      ..moveTo(start.dx, start.dy)
      ..cubicTo(
        size.width * .62,
        size.height * .98,
        size.width * .02,
        size.height * .62,
        middle.dx,
        middle.dy,
      )
      ..cubicTo(
        size.width * .78,
        size.height * .5,
        size.width * .78,
        size.height * .46,
        size.width - 20,
        36,
      );
    final dash = Paint()
      ..color = Colors.white.withValues(alpha: .5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    for (final metric in route.computeMetrics()) {
      for (double d = 0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 3), dash);
      }
    }
    final dot = Paint()..color = Colors.white;
    canvas.drawCircle(start, 6, dot);
    canvas.drawCircle(middle, 6, dot);
  }

  @override
  bool shouldRepaint(_RoutePainter oldDelegate) => false;
}

/// A numbered stop, joined to the next one like the stops on a route.
class _StepRow extends StatelessWidget {
  const _StepRow({
    required this.number,
    required this.title,
    required this.detail,
    this.last = false,
  });

  final int number;
  final String title;
  final String detail;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$number',
                    textScaler: TextScaler.noScaling,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: colors.onPrimaryContainer,
                    ),
                  ),
                ),
                if (!last)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: colors.outlineVariant.withValues(alpha: .6),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 4, bottom: last ? 0 : 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: colors.onSurfaceVariant,
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
