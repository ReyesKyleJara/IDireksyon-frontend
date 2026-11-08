import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;

import '../../core/theme/app_theme.dart';

/// Map icons drawn in the app's colors. Shapes are painted directly so they
/// do not depend on an icon font having loaded on web.
class OfficeMapPins {
  const OfficeMapPins(this.office, this.selected, this.user);
  final google.BitmapDescriptor office;
  final google.BitmapDescriptor selected;
  final google.BitmapDescriptor user;

  static const _scale = 3.0;

  static Future<OfficeMapPins> load() async => OfficeMapPins(
    await _render(
      const Size(40, 48),
      (canvas) => _pin(canvas, AppTheme.royalBlue, Colors.white),
    ),
    await _render(const Size(48, 58), (canvas) {
      canvas.scale(1.2);
      _pin(canvas, AppTheme.navy, AppTheme.accentGold);
    }),
    await _render(const Size(44, 44), _userDot),
  );

  static Future<google.BitmapDescriptor> _render(
    Size size,
    void Function(Canvas) paint,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(_scale);
    paint(canvas);
    final image = await recorder.endRecording().toImage(
      (size.width * _scale).ceil(),
      (size.height * _scale).ceil(),
    );
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return google.BitmapDescriptor.bytes(
      bytes!.buffer.asUint8List(),
      imagePixelRatio: _scale,
    );
  }

  static void _pin(Canvas canvas, Color fill, Color outline) {
    final shape = Path()
      ..addOval(Rect.fromCircle(center: const Offset(20, 18), radius: 16))
      ..moveTo(9, 29)
      ..lineTo(31, 29)
      ..lineTo(20, 45)
      ..close();
    canvas
      ..drawPath(
        shape,
        Paint()
          ..color = outline
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..strokeJoin = StrokeJoin.round,
      )
      ..drawPath(shape, Paint()..color = fill);
    // A civic building: roof, three columns and a base.
    final white = Paint()..color = Colors.white;
    canvas.drawPath(
      Path()
        ..moveTo(11.5, 15)
        ..lineTo(20, 9.5)
        ..lineTo(28.5, 15)
        ..close(),
      white,
    );
    for (final x in [13.0, 18.5, 24.0]) {
      canvas.drawRect(Rect.fromLTWH(x, 16.5, 3, 7), white);
    }
    canvas.drawRect(const Rect.fromLTWH(11.5, 24.5, 17, 2.2), white);
  }

  static void _userDot(Canvas canvas) {
    const center = Offset(22, 22);
    canvas
      ..drawCircle(
        center,
        22,
        Paint()..color = AppTheme.royalBlue.withValues(alpha: .18),
      )
      ..drawCircle(center, 10, Paint()..color = Colors.white)
      ..drawCircle(center, 7, Paint()..color = const Color(0xFF1A73E8));
  }
}
