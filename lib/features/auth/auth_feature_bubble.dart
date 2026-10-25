import 'package:flutter/material.dart';

class AuthFeatureBubble extends StatelessWidget {
  const AuthFeatureBubble({
    super.key,
    required this.message,
    required this.tail,
    this.tailOffset,
  });
  final String message;
  final AxisDirection tail;
  final double? tailOffset;

  static const messageStyle = TextStyle(
    inherit: false,
    letterSpacing: 0,
    wordSpacing: 0,
    fontFamily: 'Google Sans',
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w600,
    color: Color(0xFF164579),
  );

  static Size measure(BuildContext context, String message, double width) {
    final text = TextPainter(
      text: TextSpan(text: message, style: messageStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 20,
    )..layout(maxWidth: width - 40);
    final size = Size(width, text.height.ceilToDouble() + 48);
    text.dispose();
    return size;
  }

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: _FeatureBubblePainter(tail, tailOffset),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: messageStyle,
          maxLines: 20,
          softWrap: true,
          overflow: TextOverflow.visible,
          textWidthBasis: TextWidthBasis.parent,
        ),
      ),
    ),
  );
}

class _FeatureBubblePainter extends CustomPainter {
  const _FeatureBubblePainter(this.tail, this.tailOffset);
  final AxisDirection tail;
  final double? tailOffset;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (Offset.zero & size).deflate(8);
    final body = Path()
      ..addRRect(
        const BorderRadius.only(
          topLeft: Radius.circular(26),
          topRight: Radius.circular(26),
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(22),
        ).toRRect(r),
      );
    final horizontal =
        tail == AxisDirection.left || tail == AxisDirection.right;
    final anchor = (tailOffset ?? (horizontal ? size.height : size.width) / 2)
        .clamp(30.0, (horizontal ? size.height : size.width) - 30);
    final tip = Path();
    // The tail overlaps the body before union, leaving a single clean outline.
    switch (tail) {
      case AxisDirection.down:
        tip
          ..moveTo(anchor - 10, r.bottom - 5)
          ..quadraticBezierTo(anchor - 5, r.bottom + 4, anchor + 4, size.height)
          ..quadraticBezierTo(anchor + 3, r.bottom, anchor + 11, r.bottom - 5);
      case AxisDirection.up:
        tip
          ..moveTo(anchor - 10, r.top + 5)
          ..quadraticBezierTo(anchor - 5, r.top - 4, anchor + 4, 0)
          ..quadraticBezierTo(anchor + 3, r.top, anchor + 11, r.top + 5);
      case AxisDirection.left:
        tip
          ..moveTo(r.left + 5, anchor - 10)
          ..quadraticBezierTo(r.left - 4, anchor - 5, 0, anchor + 4)
          ..quadraticBezierTo(r.left, anchor + 3, r.left + 5, anchor + 11);
      case AxisDirection.right:
        tip
          ..moveTo(r.right - 5, anchor - 10)
          ..quadraticBezierTo(r.right + 4, anchor - 5, size.width, anchor + 4)
          ..quadraticBezierTo(r.right, anchor + 3, r.right - 5, anchor + 11);
    }
    tip.close();
    final outline = Path.combine(PathOperation.union, body, tip);
    canvas.drawShadow(outline, const Color(0x1C0B4295), 4, false);
    canvas.drawPath(
      outline,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF3F8FF)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      outline,
      Paint()
        ..color = const Color(0xFFC9DBEC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _FeatureBubblePainter oldDelegate) =>
      tail != oldDelegate.tail || tailOffset != oldDelegate.tailOffset;
}
