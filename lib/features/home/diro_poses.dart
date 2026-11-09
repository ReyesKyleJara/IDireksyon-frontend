import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/app_motion.dart';

/// Diro for the Home banners, switching poses every few seconds. Holds one
/// pose when the device asks for less motion or the tab is not showing.
class DiroPoses extends StatefulWidget {
  const DiroPoses({super.key, required this.size});

  final double size;

  static const poses = [
    'assets/onboarding pictures/mascot-wave-cutout.png',
    'assets/onboarding pictures/mascot-guide-cutout.png',
    'assets/onboarding pictures/mascot-prepared-cutout.png',
    'assets/onboarding pictures/mascot-tada-cutout.png',
  ];
  static const interval = Duration(seconds: 4);

  @override
  State<DiroPoses> createState() => _DiroPosesState();
}

class _DiroPosesState extends State<DiroPoses> {
  Timer? _timer;
  int _pose = 0;
  bool _precached = false;

  ImageProvider _image(String asset) => ResizeImage(
    AssetImage(asset),
    width: (widget.size * MediaQuery.devicePixelRatioOf(context)).round(),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precached) {
      _precached = true;
      for (final pose in DiroPoses.poses) {
        // Loaded ahead so a new pose never appears as a blank gap.
        unawaited(precacheImage(_image(pose), context, onError: (_, _) {}));
      }
    }
    final moving =
        !AppMotion.reduced(context) && TickerMode.valuesOf(context).enabled;
    if (!moving) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(DiroPoses.interval, (_) {
        setState(() => _pose = (_pose + 1) % DiroPoses.poses.length);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: widget.size * .82,
            height: widget.size * .82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: .08),
            ),
          ),
          AnimatedSwitcher(
            duration: AppMotion.duration(context, AppMotion.enter),
            switchInCurve: AppMotion.curve,
            switchOutCurve: AppMotion.curve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: .94, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: Image(
              key: ValueKey(_pose),
              image: _image(DiroPoses.poses[_pose]),
              width: widget.size,
              height: widget.size,
              fit: BoxFit.contain,
              gaplessPlayback: true,
            ),
          ),
        ],
      ),
    ),
  );
}
