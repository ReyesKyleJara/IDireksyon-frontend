import 'dart:math' as math;

import 'package:flutter/material.dart';

/// A softly sculpted speech cloud with a tail pointing toward the guide.
class OnboardingSpeechBubble extends StatefulWidget {
  const OnboardingSpeechBubble({super.key, required this.child});
  final Widget child;

  @override
  State<OnboardingSpeechBubble> createState() => _OnboardingSpeechBubbleState();
}

class _OnboardingSpeechBubbleState extends State<OnboardingSpeechBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _float.stop();
      _float.value = 0;
    } else if (!_float.isAnimating) {
      _float.repeat();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _float,
      child: CustomPaint(
        painter: const _SpeechCloudPainter(),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 42),
          child: widget.child,
        ),
      ),
      builder: (context, child) {
        final phase = _float.value * math.pi * 2;
        return Transform.translate(
          offset: Offset(0, math.sin(phase) * 3),
          child: Transform.rotate(angle: math.sin(phase) * .006, child: child),
        );
      },
    ),
  );
}

class _SpeechCloudPainter extends CustomPainter {
  const _SpeechCloudPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height - 18;
    // Broad, shallow lobes keep the center spacious at large text sizes.
    final path = Path()
      ..moveTo(w * .09, h * .22)
      ..cubicTo(w * .04, h * .04, w * .25, -h * .02, w * .36, h * .06)
      ..cubicTo(w * .47, -h * .02, w * .65, -h * .01, w * .74, h * .07)
      ..cubicTo(w * .92, h * .02, w * 1.01, h * .17, w * .96, h * .35)
      ..cubicTo(w * 1.03, h * .54, w * .99, h * .74, w * .92, h * .79)
      ..cubicTo(w * .94, h * .94, w * .76, h * 1.03, w * .65, h * .96)
      // A curved little speech tail connects the cloud to the mascot below.
      ..quadraticBezierTo(w * .59, h + 4, w * .56, h + 18)
      ..quadraticBezierTo(w * .48, h + 14, w * .49, h * .97)
      ..cubicTo(w * .34, h * 1.03, w * .20, h * 1.01, w * .15, h * .92)
      ..cubicTo(w * .01, h * .96, -w * .01, h * .76, w * .05, h * .64)
      ..cubicTo(-w * .01, h * .49, w * .01, h * .29, w * .09, h * .22)
      ..close();
    canvas.drawShadow(path, const Color(0x120B4295), 5, false);
    canvas.drawPath(path, Paint()..color = Colors.white);
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFD8E5F1)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
  }

  @override
  bool shouldRepaint(covariant _SpeechCloudPainter oldDelegate) => false;
}
