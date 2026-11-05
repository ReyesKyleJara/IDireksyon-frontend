import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';

/// The immersive top half of onboarding: Diro floats in a navy "night map"
/// with breathing rings, twinkling stars and feature icons orbiting in 3D.
///
/// All children are positioned, so this never reports an intrinsic height
/// of its own; callers size it (it is safe inside an [IntrinsicHeight]).
class OnboardingHero extends StatefulWidget {
  const OnboardingHero({
    super.key,
    required this.mascotAsset,
    required this.orbitIcons,
    this.direction = 1,
  });

  final String mascotAsset;
  final List<IconData> orbitIcons;

  /// +1 when moving forward through slides, -1 when moving back.
  final int direction;

  static const diroKey = ValueKey('onboarding-diro');

  @override
  State<OnboardingHero> createState() => _OnboardingHeroState();
}

class _OnboardingHeroState extends State<OnboardingHero>
    with TickerProviderStateMixin {
  // One slow loop drives the orbit; faster motions are harmonics of it.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 24),
  );
  late final AnimationController _jump = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  bool get _reduced => AppMotion.reduced(context);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_reduced || !TickerMode.valuesOf(context).enabled) {
      _loop.stop();
      _loop.value = 0;
    } else if (!_loop.isAnimating) {
      _loop.repeat();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _jump.dispose();
    super.dispose();
  }

  void _hop() {
    if (_reduced || _jump.isAnimating) return;
    _jump.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              final diro = math.min(math.min(h * .80, w * .70), 340.0);
              final center = Offset(w / 2, h * .50);
              final orbit = _Orbit(
                center: center.translate(0, diro * .14),
                rx: math.min(w * .43, diro * .92),
                ry: math.min(w * .43, diro * .92) * .28,
              );
              return AnimatedBuilder(
                animation: Listenable.merge([_loop, _jump]),
                builder: (context, _) {
                  final t = _loop.value;
                  final phase = t * math.pi * 2;
                  final bob = math.sin(phase * 4);
                  final hop = math.sin(
                    math.pi * Curves.easeOut.transform(_jump.value),
                  );
                  final chips = _orbitChips(orbit, phase);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _NightMapPainter(
                            phase: phase,
                            center: center,
                            diro: diro,
                            orbit: orbit,
                          ),
                        ),
                      ),
                      ...chips.where((c) => c.depth < 0).map((c) => c.widget),
                      Positioned(
                        left: center.dx - diro / 2,
                        top: center.dy - diro / 2,
                        width: diro,
                        height: diro,
                        child: Semantics(
                          label: 'Diro, your ID guide',
                          image: true,
                          child: GestureDetector(
                            onTap: _hop,
                            child: Transform.translate(
                              key: OnboardingHero.diroKey,
                              offset: Offset(0, -6 * bob - 34 * hop),
                              child: Transform.rotate(
                                angle: .025 * math.sin(phase * 2) +
                                    .06 * hop,
                                alignment: Alignment.bottomCenter,
                                child: _mascot(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      ...chips.where((c) => c.depth >= 0).map((c) => c.widget),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _mascot() => AnimatedSwitcher(
    duration: AppMotion.duration(context, const Duration(milliseconds: 460)),
    switchInCurve: Curves.easeOutBack,
    switchOutCurve: Curves.easeIn,
    transitionBuilder: (child, animation) {
      final incoming = child.key == ValueKey(widget.mascotAsset);
      final dx = (incoming ? .18 : -.18) * widget.direction;
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: Offset(dx, 0),
            end: Offset.zero,
          ).animate(animation),
          child: ScaleTransition(
            scale: Tween(begin: .82, end: 1.0).animate(animation),
            child: child,
          ),
        ),
      );
    },
    child: Image.asset(
      widget.mascotAsset,
      key: ValueKey(widget.mascotAsset),
      fit: BoxFit.contain,
      excludeFromSemantics: true,
    ),
  );

  List<_Chip> _orbitChips(_Orbit orbit, double phase) {
    final icons = widget.orbitIcons;
    return [
      for (var i = 0; i < icons.length; i++)
        () {
          final angle = phase + i * math.pi * 2 / icons.length;
          final depth = math.sin(angle);
          final near = (depth + 1) / 2; // 0 = far behind, 1 = closest
          final pos = orbit.at(angle);
          const size = 46.0;
          final scale = .70 + .30 * near;
          return _Chip(
            depth,
            Positioned(
              left: pos.dx - size / 2,
              top: pos.dy - size / 2,
              width: size,
              height: size,
              child: ExcludeSemantics(
                child: Opacity(
                  opacity: .45 + .55 * near,
                  child: Transform.scale(
                    scale: scale,
                    child: _OrbitChip(icon: icons[i], gold: i.isOdd),
                  ),
                ),
              ),
            ),
          );
        }(),
    ];
  }
}

class _Chip {
  const _Chip(this.depth, this.widget);
  final double depth;
  final Widget widget;
}

class _Orbit {
  const _Orbit({required this.center, required this.rx, required this.ry});
  final Offset center;
  final double rx;
  final double ry;

  Offset at(double angle) =>
      center + Offset(rx * math.cos(angle), ry * math.sin(angle));
}

class _OrbitChip extends StatelessWidget {
  const _OrbitChip({required this.icon, required this.gold});
  final IconData icon;
  final bool gold;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: gold ? AppTheme.accentGold : Colors.white,
      boxShadow: [
        BoxShadow(
          color: (gold ? AppTheme.accentGold : const Color(0xFF7DB4FF))
              .withValues(alpha: .45),
          blurRadius: 18,
        ),
      ],
    ),
    child: Center(
      child: AnimatedSwitcher(
        duration: AppMotion.duration(context),
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: Icon(
          icon,
          key: ValueKey(icon),
          size: 22,
          color: gold ? AppTheme.navy : AppTheme.royalBlue,
        ),
      ),
    ),
  );
}

class _NightMapPainter extends CustomPainter {
  _NightMapPainter({
    required this.phase,
    required this.center,
    required this.diro,
    required this.orbit,
  });

  final double phase;
  final Offset center;
  final double diro;
  final _Orbit orbit;

  static final _stars = () {
    final random = math.Random(11);
    return List.generate(
      16,
      (_) => (
        Offset(random.nextDouble(), random.nextDouble() * .9),
        random.nextDouble() * math.pi * 2,
        random.nextDouble() < .35,
      ),
    );
  }();

  @override
  void paint(Canvas canvas, Size size) {
    // Halo that lifts Diro's blue off the navy background.
    canvas.drawCircle(
      center,
      diro * .78,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFF6FB0FF).withValues(alpha: .42),
            const Color(0xFF3C82E0).withValues(alpha: .12),
            Colors.transparent,
          ],
          stops: const [0, .55, 1],
        ).createShader(Rect.fromCircle(center: center, radius: diro * .78)),
    );

    // Breathing rings, the Home banner motif at a larger scale.
    final breathe = 1 + .02 * math.sin(phase * 3);
    for (final (factor, width, alpha) in [
      (.44, 30.0, .05),
      (.66, 18.0, .045),
      (.92, 1.2, .14),
      (1.22, 1.0, .09),
    ]) {
      canvas.drawCircle(
        center,
        diro * factor * breathe,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = width
          ..color = Colors.white.withValues(alpha: alpha),
      );
    }

    // Dashed orbit track the icon chips ride on.
    final track = Path()
      ..addOval(
        Rect.fromCenter(
          center: orbit.center,
          width: orbit.rx * 2,
          height: orbit.ry * 2,
        ),
      );
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: .22);
    final march = (phase / (math.pi * 2)) * 120;
    for (final metric in track.computeMetrics()) {
      for (var d = march % 12; d < metric.length; d += 12) {
        canvas.drawPath(metric.extractPath(d, d + 5), dash);
      }
    }

    // Twinkling stars: gold sparkles and soft white dots.
    for (final (pos, offset, gold) in _stars) {
      final p = Offset(pos.dx * size.width, pos.dy * size.height);
      if ((p - center).distance < diro * .5) continue;
      final twinkle = (math.sin(phase * 6 + offset) + 1) / 2;
      if (gold) {
        _sparkle(canvas, p, 3 + 3 * twinkle, .35 + .65 * twinkle);
      } else {
        canvas.drawCircle(
          p,
          1.2 + .8 * twinkle,
          Paint()..color = Colors.white.withValues(alpha: .25 + .5 * twinkle),
        );
      }
    }

    // Soft ground shadow under Diro.
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, diro * .50),
        width: diro * .42 + 10 * math.sin(phase * 4),
        height: 12,
      ),
      Paint()
        ..color = const Color(0xFF041A38).withValues(alpha: .35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
  }

  void _sparkle(Canvas canvas, Offset c, double r, double opacity) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(
      path,
      Paint()..color = AppTheme.accentGold.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _NightMapPainter old) =>
      phase != old.phase || center != old.center || diro != old.diro;
}
