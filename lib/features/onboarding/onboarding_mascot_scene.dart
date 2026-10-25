import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A contained, decorative scene with a gently animated mascot and garden.
class OnboardingMascotScene extends StatefulWidget {
  const OnboardingMascotScene({
    super.key,
    required this.isRequirements,
    required this.height,
  });
  final bool isRequirements;
  final double height;

  @override
  State<OnboardingMascotScene> createState() => _OnboardingMascotSceneState();
}

class _OnboardingMascotSceneState extends State<OnboardingMascotScene>
    with SingleTickerProviderStateMixin {
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _idle.stop();
      _idle.value = 0;
    } else if (!_idle.isAnimating) {
      _idle.repeat();
    }
  }

  @override
  void dispose() {
    _idle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: IgnorePointer(
      child: SizedBox(
        height: widget.height,
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _idle,
            child: Image.asset(
              widget.isRequirements
                  ? 'assets/onboarding pictures/mascot-prepared-cutout.png'
                  : 'assets/onboarding pictures/mascot-guide-cutout.png',
              fit: BoxFit.contain,
            ),
            builder: (context, child) {
              final phase = _idle.value * math.pi * 2;
              final bob = math.sin(phase * 2);
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _GardenPainter(phase)),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(28, 10, 28, 24),
                    child: Transform.translate(
                      offset: Offset(0, -4 * bob),
                      child: Transform.rotate(
                        angle:
                            math.sin(phase) *
                            (widget.isRequirements ? -.018 : .018),
                        alignment: Alignment.bottomCenter,
                        child: Transform.scale(
                          scaleY: 1 + .008 * bob,
                          alignment: Alignment.bottomCenter,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _GardenPainter extends CustomPainter {
  const _GardenPainter(this.phase);
  final double phase;

  @override
  void paint(Canvas canvas, Size size) {
    final ground = Offset(size.width / 2, size.height - 20);
    canvas.drawOval(
      Rect.fromCenter(center: ground, width: size.width * .72, height: 25),
      Paint()..color = const Color(0xFFE9EEE3),
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: ground.translate(0, -2),
        width: 105 + 5 * math.sin(phase * 2),
        height: 10,
      ),
      Paint()..color = const Color(0x190B4295),
    );
    _grass(canvas, Offset(size.width * .14, ground.dy), 1);
    _grass(canvas, Offset(size.width * .86, ground.dy - 2), -1);
    // Only three drifting leaves, all confined to the illustration area.
    _leaf(
      canvas,
      Offset(
        size.width * .13 + 10 * math.sin(phase),
        size.height * .40 + 12 * math.cos(phase),
      ),
      -.5 + .25 * math.sin(phase),
      8,
      const Color(0xFFB5CFA0),
    );
    _leaf(
      canvas,
      Offset(
        size.width * .87 + 7 * math.cos(phase),
        size.height * .26 + 10 * math.sin(phase),
      ),
      .8 + .3 * math.cos(phase),
      7,
      const Color(0xFFC9DDB4),
    );
    _leaf(
      canvas,
      Offset(
        size.width * .91 + 5 * math.sin(phase),
        size.height * .65 + 7 * math.cos(phase),
      ),
      -.7 + .2 * math.sin(phase),
      5,
      const Color(0xFFD5DDB4),
    );
    final sparklePaint = Paint()..color = const Color(0xFFE6C678);
    for (final point in [
      Offset(size.width * .21, size.height * .18),
      Offset(size.width * .80, size.height * .48),
    ]) {
      final radius = 2.3 + .6 * math.sin(phase);
      canvas.drawCircle(point, radius, sparklePaint);
    }
  }

  void _grass(Canvas canvas, Offset base, double direction) {
    final paint = Paint()
      ..color = const Color(0xFFACC89C)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final sway = math.sin(phase + direction) * 3;
    for (var blade = -1; blade <= 1; blade++) {
      final path = Path()
        ..moveTo(base.dx + blade * 4, base.dy)
        ..quadraticBezierTo(
          base.dx + blade * 6 + sway,
          base.dy - 9,
          base.dx + blade * 9 + sway,
          base.dy - 17 + blade.abs() * 5,
        );
      canvas.drawPath(path, paint);
    }
  }

  void _leaf(
    Canvas canvas,
    Offset center,
    double angle,
    double radius,
    Color color,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    final leaf = Path()
      ..moveTo(-radius, 0)
      ..quadraticBezierTo(0, -radius * 1.1, radius, 0)
      ..quadraticBezierTo(0, radius * 1.1, -radius, 0);
    canvas.drawPath(leaf, Paint()..color = color);
    canvas.drawLine(
      Offset(-radius * .5, 0),
      Offset(radius * .6, 0),
      Paint()
        ..color = const Color(0x7792AF7E)
        ..strokeWidth = .8,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GardenPainter oldDelegate) =>
      phase != oldDelegate.phase;
}
