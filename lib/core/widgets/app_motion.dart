import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

abstract final class AppMotion {
  static const quick = Duration(milliseconds: 150);
  static const standard = Duration(milliseconds: 240);
  static const enter = Duration(milliseconds: 320);
  static const curve = Curves.easeOutCubic;

  static bool reduced(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context);
  static Duration duration(BuildContext context, [Duration value = standard]) =>
      reduced(context) ? Duration.zero : value;
}

class MotionProgress extends StatelessWidget {
  const MotionProgress({
    super.key,
    required this.value,
    this.minHeight,
    this.borderRadius,
    this.backgroundColor,
    this.color,
    this.semanticsLabel,
    this.semanticsValue,
  });
  final double value;
  final double? minHeight;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Color? color;
  final String? semanticsLabel;
  final String? semanticsValue;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: value, end: value),
    duration: AppMotion.duration(context, AppMotion.enter),
    curve: AppMotion.curve,
    builder: (context, progress, _) => LinearProgressIndicator(
      value: progress,
      minHeight: minHeight,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      color: color,
      semanticsLabel: semanticsLabel,
      semanticsValue: semanticsValue,
    ),
  );
}

/// Theme-level transitions cover named routes and direct MaterialPageRoutes.
/// Apple platforms retain the native interactive back gesture.
class AppPageTransitions extends PageTransitionsBuilder {
  const AppPageTransitions();

  @override
  Duration get transitionDuration => AppMotion.enter;
  @override
  Duration get reverseTransitionDuration => AppMotion.standard;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) return child;
    final platform = Theme.of(context).platform;
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      return const CupertinoPageTransitionsBuilder().buildTransitions(
        route,
        context,
        animation,
        secondaryAnimation,
        child,
      );
    }
    return FadeTransition(
      opacity: animation.drive(CurveTween(curve: Curves.easeOut)),
      child: SlideTransition(
        position: animation.drive(
          Tween(
            begin: const Offset(0, .025),
            end: Offset.zero,
          ).chain(CurveTween(curve: AppMotion.curve)),
        ),
        child: child,
      ),
    );
  }
}

/// Keeps InkWell's keyboard, focus, semantics and cancellation behavior.
class MotionInkWell extends StatefulWidget {
  const MotionInkWell({
    super.key,
    this.onTap,
    this.borderRadius,
    required this.child,
  });
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Widget child;

  @override
  State<MotionInkWell> createState() => _MotionInkWellState();
}

class _MotionInkWellState extends State<MotionInkWell> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed && widget.onTap != null && !AppMotion.reduced(context)
        ? .985
        : 1,
    duration: AppMotion.duration(context, AppMotion.quick),
    curve: AppMotion.curve,
    child: InkWell(
      onTap: widget.onTap,
      borderRadius: widget.borderRadius,
      onHighlightChanged: (value) => setState(() => _pressed = value),
      child: widget.child,
    ),
  );
}

/// Animates tab entry without remounting its forms or scroll positions.
class MotionTab extends StatefulWidget {
  const MotionTab({super.key, required this.active, required this.child});
  final bool active;
  final Widget child;

  @override
  State<MotionTab> createState() => _MotionTabState();
}

class _MotionTabState extends State<MotionTab>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppMotion.standard,
    value: 1,
  );
  late final _opacity = _controller.drive(CurveTween(curve: AppMotion.curve));
  late final _slide = _controller.drive(
    Tween(
      begin: const Offset(0, .012),
      end: Offset.zero,
    ).chain(CurveTween(curve: AppMotion.curve)),
  );

  @override
  void didUpdateWidget(MotionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      if (AppMotion.reduced(context)) {
        _controller.value = 1;
      } else {
        _controller.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TickerMode(
    enabled: widget.active,
    child: AppMotion.reduced(context)
        ? widget.child
        : FadeTransition(
            opacity: _opacity,
            child: SlideTransition(position: _slide, child: widget.child),
          ),
  );
}
