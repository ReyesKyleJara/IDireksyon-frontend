import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

const _blur = 14.0;

/// Thin light edge that makes the gradient banners read as glass.
const frostedBannerEdge = BoxDecoration(
  borderRadius: BorderRadius.all(Radius.circular(26)),
  border: Border.fromBorderSide(BorderSide(color: Color(0x2EFFFFFF))),
);

/// Frosted accent for bars and controls that sit on top of other content.
/// Blurs what is behind [child] under a translucent app-surface tint, and
/// becomes a solid surface when the device asks for high contrast.
class FrostedSurface extends StatelessWidget {
  const FrostedSurface({
    super.key,
    required this.child,
    this.borderRadius = BorderRadius.zero,
    this.border,
    this.opacity = .78,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final solid = MediaQuery.highContrastOf(context);
    final surface = DecoratedBox(
      decoration: BoxDecoration(
        color: (dark ? colors.surfaceContainer : Colors.white).withValues(
          alpha: solid ? 1 : opacity,
        ),
        borderRadius: borderRadius,
        border:
            border ??
            Border.all(
              color: dark
                  ? colors.outlineVariant.withValues(alpha: .35)
                  : Colors.white.withValues(alpha: .7),
            ),
      ),
      child: child,
    );
    if (solid) return surface;
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: _blur, sigmaY: _blur),
        child: surface,
      ),
    );
  }
}
