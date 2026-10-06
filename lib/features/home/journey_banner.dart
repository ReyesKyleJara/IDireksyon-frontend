import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/widgets/app_motion.dart';

import '../roadmap/id_journey.dart';

class JourneyBanner extends StatefulWidget {
  const JourneyBanner({
    super.key,
    required this.journeys,
    required this.onOpen,
  });
  final List<IdJourney> journeys;
  final ValueChanged<IdJourney> onOpen;

  @override
  State<JourneyBanner> createState() => _JourneyBannerState();
}

class _JourneyBannerState extends State<JourneyBanner> {
  final _controller = PageController();
  int _index = 0;
  void _move(int index) {
    if (AppMotion.reduced(context)) {
      _controller.jumpToPage(index);
    } else {
      _controller.animateToPage(
        index,
        duration: AppMotion.standard,
        curve: AppMotion.curve,
      );
    }
  }

  static const _labelStyle = TextStyle(
    fontSize: 11,
    height: 1.4,
    fontWeight: FontWeight.w700,
    color: Color(0xFFD5E7FA),
  );
  static const _titleStyle = TextStyle(
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w800,
    color: Colors.white,
  );
  static const _detailStyle = TextStyle(
    fontSize: 13,
    height: 1.4,
    color: Color(0xFFD5E7FA),
  );
  static const _buttonStyle = TextStyle(
    fontSize: 14,
    height: 1.3,
    fontWeight: FontWeight.w700,
  );
  static const _detail =
      'Pick up where you left off and review your next steps.';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _textHeight(
    BuildContext context,
    String text,
    TextStyle style,
    double width, {
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: DefaultTextStyle.of(context).style.merge(style),
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final height = painter.height;
    painter.dispose();
    return height;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final width = math.max(1.0, constraints.maxWidth - 44);
      final titleHeight = widget.journeys
          .map(
            (j) =>
                _textHeight(context, j.title, _titleStyle, width, maxLines: 3),
          )
          .fold(0.0, math.max);
      final buttonHeight = math.max(
        48.0,
        _textHeight(
              context,
              'Continue journey',
              _buttonStyle,
              math.max(1.0, width - 32),
            ) +
            24,
      );
      final height =
          48 +
          _textHeight(context, 'ONGOING JOURNEY', _labelStyle, width) +
          12 +
          titleHeight +
          12 +
          _textHeight(context, _detail, _detailStyle, width) +
          16 +
          _textHeight(context, 'Overall readiness: 100%', _detailStyle, width) +
          10 +
          8 +
          20 +
          buttonHeight +
          4;
      return Column(
        children: [
          SizedBox(
            height: height,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.journeys.length,
              physics: widget.journeys.length == 1
                  ? const NeverScrollableScrollPhysics()
                  : null,
              onPageChanged: (index) => setState(() => _index = index),
              itemBuilder: (context, index) {
                final journey = widget.journeys[index];
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 24,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF103765), Color(0xFF246AA5)],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text('ONGOING JOURNEY', style: _labelStyle),
                      const SizedBox(height: 12),
                      Text(
                        journey.title,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: _titleStyle,
                      ),
                      const SizedBox(height: 12),
                      const Text(_detail, style: _detailStyle),
                      const SizedBox(height: 16),
                      Text(
                        'Overall readiness: ${journey.readinessLabel}',
                        style: _detailStyle,
                      ),
                      const SizedBox(height: 10),
                      MotionProgress(
                        value: journey.readiness,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(8),
                        backgroundColor: Colors.white.withValues(alpha: .2),
                        color: const Color(0xFFFFD576),
                        semanticsLabel: '${journey.title} overall readiness',
                        semanticsValue: journey.readinessLabel,
                      ),
                      const Spacer(),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: () {
                          journey.minimized = false;
                          widget.onOpen(journey);
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF174B85),
                          minimumSize: Size(0, buttonHeight),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Continue journey',
                          textAlign: TextAlign.center,
                          style: _buttonStyle,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          if (widget.journeys.length > 1) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: 'Previous journey',
                  onPressed: _index == 0 ? null : () => _move(_index - 1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      'Journey ${_index + 1} of ${widget.journeys.length} · Swipe to browse',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Next journey',
                  onPressed: _index == widget.journeys.length - 1
                      ? null
                      : () => _move(_index + 1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
          ],
        ],
      );
    },
  );
}
