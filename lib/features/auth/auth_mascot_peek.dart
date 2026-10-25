import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'auth_feature_bubble.dart';

/// Random peeks are chosen only from currently unoccupied screen margins.
class AuthMascotPeek extends StatefulWidget {
  const AuthMascotPeek({super.key, required this.child});
  final Widget child;

  @override
  State<AuthMascotPeek> createState() => _AuthMascotPeekState();
}

class _AuthMascotPeekState extends State<AuthMascotPeek>
    with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();
  final _surfaceKey = GlobalKey();
  final _random = math.Random();
  late final AnimationController _peek = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..addListener(_onTick);

  static const _poses = [
    'assets/onboarding pictures/mascot-guide-cutout.png',
    'assets/onboarding pictures/mascot-prepared-cutout.png',
    'assets/onboarding pictures/mascot-wave-cutout.png',
    'assets/onboarding pictures/mascot-tada-cutout.png',
  ];
  static const _features = [
    'Find the government ID you need.',
    'See what requirements to prepare.',
    'Follow your ID journey step by step.',
    'Find offices on the map.',
    'Keep track of your ID progress.',
  ];
  final _edgeBag = <_PeekEdge>[];
  int _featureIndex = 0;
  _PeekSpot? _spot;
  _PeekSpot? _previous;
  int _pose = 0;
  int _lastTurn = 0;
  bool _placementPending = false;
  bool _newTurn = true;
  Size? _size;

  bool get _canAnimate =>
      !MediaQuery.disableAnimationsOf(context) &&
      MediaQuery.viewInsetsOf(context).bottom == 0 &&
      MediaQuery.textScalerOf(context).scale(16) <= 22.4 &&
      TickerMode.valuesOf(context).enabled;

  @override
  void initState() {
    super.initState();
    PaintingBinding.instance.systemFonts.addListener(_onFontsChanged);
  }

  void _onFontsChanged() {
    if (!mounted) return;
    setState(() => _spot = null);
    _requestPlacement();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_canAnimate) {
      if (!_peek.isAnimating) _peek.repeat();
      _requestPlacement();
    } else {
      _peek.stop();
      _peek.value = 0;
      _spot = null;
    }
  }

  @override
  void didUpdateWidget(covariant AuthMascotPeek oldWidget) {
    super.didUpdateWidget(oldWidget);
    _requestPlacement();
  }

  void _onTick() {
    final turn = (_peek.lastElapsedDuration?.inMilliseconds ?? 0) ~/ 4000;
    if (turn != _lastTurn) {
      _newTurn = true;
      _requestPlacement();
    }
    _lastTurn = turn;
  }

  void _requestPlacement() {
    if (_placementPending) return;
    _placementPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _placementPending = false;
      if (!mounted || !_canAnimate) return;
      _place();
    });
  }

  List<Rect> _occupied(RenderBox surface) {
    final rectangles = <Rect>[];
    void visit(Element element) {
      final widget = element.widget;
      if (widget is Text ||
          widget is EditableText ||
          widget is TextField ||
          widget is ButtonStyleButton ||
          widget is Checkbox ||
          widget is SvgPicture) {
        final render = element.findRenderObject();
        if (render is RenderBox && render.hasSize && render.attached) {
          final origin = render.localToGlobal(Offset.zero, ancestor: surface);
          if (render is RenderParagraph) {
            final length = render.text.toPlainText().length;
            for (final box in render.getBoxesForSelection(
              TextSelection(baseOffset: 0, extentOffset: length),
            )) {
              rectangles.add(box.toRect().shift(origin).inflate(12));
            }
          } else {
            rectangles.add((origin & render.size).inflate(12));
          }
        }
        return;
      }
      element.visitChildren(visit);
    }

    _contentKey.currentContext?.visitChildElements(visit);
    return rectangles;
  }

  void _place() {
    final surface = _surfaceKey.currentContext?.findRenderObject();
    if (surface is! RenderBox || !surface.hasSize) return;
    final viewport = Offset.zero & surface.size;
    final occupied = _occupied(surface);
    bool safe(_PeekSpot spot) {
      // The complete travel corridor includes rotation, bob, and bounce.
      final corridor = spot.corridor(viewport);
      return !occupied.any(
        (rect) =>
            rect.overlaps(corridor) || rect.overlaps(spot.bubble.inflate(10)),
      );
    }

    if (!_newTurn && _spot != null && safe(_spot!)) return;
    final nextFeature = _newTurn && _previous != null
        ? (_featureIndex + 1) % _features.length
        : _featureIndex;
    final bubbleWidth = math.min(182.0, viewport.width * .45);
    final bubbleSize = AuthFeatureBubble.measure(
      context,
      _features[nextFeature],
      bubbleWidth,
    );
    final preferredSize = surface.size.width < 360 ? 230.0 : 264.0;
    final candidates = <_PeekSpot>[];
    for (final size in [
      preferredSize,
      preferredSize * .84,
      preferredSize * .68,
      math.max(132.0, preferredSize * .54),
    ]) {
      for (final edge in _PeekEdge.values) {
        final horizontal = edge == _PeekEdge.top || edge == _PeekEdge.bottom;
        final extent = horizontal ? viewport.width : viewport.height;
        for (final fraction in [.98, .88]) {
          final reveal = size * fraction;
          for (double along = 0; along <= extent - size; along += 28) {
            final position = switch (edge) {
              _PeekEdge.left => Offset(-size + reveal, along),
              _PeekEdge.right => Offset(viewport.width - reveal, along),
              _PeekEdge.top => Offset(along, -size + reveal),
              _PeekEdge.bottom => Offset(along, viewport.height - reveal),
            };
            final visible = (position & Size.square(size)).intersect(viewport);
            const gap = 26.0;
            final options = <(Offset, AxisDirection)>[
              for (final y in [
                visible.top + 8,
                visible.center.dy - bubbleSize.height / 2,
                visible.bottom - bubbleSize.height - 8,
              ]) ...[
                (Offset(visible.right + gap, y), AxisDirection.left),
                (
                  Offset(visible.left - bubbleSize.width - gap, y),
                  AxisDirection.right,
                ),
              ],
              for (final x in [
                visible.left + 8,
                visible.center.dx - bubbleSize.width / 2,
                visible.right - bubbleSize.width - 8,
              ]) ...[
                (
                  Offset(x, visible.top - bubbleSize.height - gap),
                  AxisDirection.down,
                ),
                (Offset(x, visible.bottom + gap), AxisDirection.up),
              ],
            ];
            for (final (origin, tail) in options) {
              if (bubbleSize.height > viewport.height - 16) continue;
              final bubble =
                  Offset(
                    origin.dx.clamp(8.0, viewport.width - bubbleSize.width - 8),
                    origin.dy.clamp(
                      8.0,
                      viewport.height - bubbleSize.height - 8,
                    ),
                  ) &
                  bubbleSize;
              if (bubble.overlaps(visible.inflate(4))) continue;
              final candidate = _PeekSpot(edge, position, size, bubble, tail);
              if (safe(candidate) &&
                  !candidate.corridor(viewport).overlaps(bubble.inflate(4))) {
                candidates.add(candidate);
              }
            }
          }
        }
      }
    }
    // Choose a direction before comparing reveal sizes, so roomy top/bottom
    // placements cannot crowd left/right out of the random rotation.
    final available = candidates.map((spot) => spot.edge).toSet();
    var edges = _edgeBag.where(available.contains).toList();
    if (edges.isEmpty && available.isNotEmpty) {
      _edgeBag
        ..clear()
        ..addAll(available.toList()..shuffle(_random));
      edges = List.of(_edgeBag);
    }
    final edge = edges.isEmpty ? null : edges.first;
    if (edge != null) _edgeBag.remove(edge);
    final directional = candidates.where((spot) => spot.edge == edge).toList();
    final maxArea = directional.fold<double>(
      0,
      (area, spot) => math.max(area, spot.visibleArea(viewport)),
    );
    var choices = directional
        .where((spot) => spot.visibleArea(viewport) >= maxArea * .72)
        .toList();
    final different = choices
        .where(
          (spot) =>
              _previous == null ||
              spot.edge != _previous!.edge ||
              (spot.position - _previous!.position).distance > 70,
        )
        .toList();
    if (different.isNotEmpty) choices = different;
    final next = choices.isEmpty
        ? null
        : choices[_random.nextInt(choices.length)];
    setState(() {
      _spot = next;
      if (next != null) {
        _previous = next;
        _featureIndex = nextFeature;
      }
      if (_newTurn) {
        _pose =
            (_pose + 1 + _random.nextInt(_poses.length - 1)) % _poses.length;
      }
      _newTurn = false;
    });
  }

  @override
  void dispose() {
    PaintingBinding.instance.systemFonts.removeListener(_onFontsChanged);
    _peek.dispose();
    super.dispose();
  }

  double _reveal(double seconds) {
    if (seconds < .12 || seconds >= 3.6) return 0;
    if (seconds < .95) {
      return Curves.easeOutBack.transform((seconds - .12) / .83);
    }
    if (seconds < 2.45) return 1;
    return 1 - Curves.easeInOutCubic.transform((seconds - 2.45) / 1.15);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (_size != constraints.biggest) {
        _size = constraints.biggest;
        _spot = null;
        _requestPlacement();
      }
      return ClipRect(
        child: Stack(
          key: _surfaceKey,
          fit: StackFit.expand,
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (_) {
                _requestPlacement();
                return false;
              },
              child: KeyedSubtree(key: _contentKey, child: widget.child),
            ),
            if (_canAnimate && _spot != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: ExcludeSemantics(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _peek,
                        builder: (context, _) {
                          final spot = _spot!;
                          final local = _peek.value * 4;
                          final reveal = _reveal(local);
                          final curious = math.sin(
                            (local - .95).clamp(0.0, 1.5) / 1.5 * math.pi,
                          );
                          // Fade and drift from a face-safe pose, rather than
                          // sliding a forehead-first crop across the screen edge.
                          final drift = (1 - reveal.clamp(0.0, 1.0)) * 8;
                          final position =
                              spot.position +
                              switch (spot.edge) {
                                _PeekEdge.left => Offset(-drift, 0),
                                _PeekEdge.right => Offset(drift, 0),
                                _PeekEdge.top => Offset(0, -drift),
                                _PeekEdge.bottom => Offset(0, drift),
                              };
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                key: const ValueKey('auth-random-peek'),
                                left: position.dx,
                                top: position.dy,
                                width: spot.size,
                                height: spot.size,
                                child: Opacity(
                                  opacity: reveal.clamp(0.0, 1.0),
                                  child: Transform.rotate(
                                    angle:
                                        (spot.edge == _PeekEdge.top
                                            ? math.pi
                                            : 0) +
                                        .04 * curious,
                                    child: Transform(
                                      alignment: Alignment.center,
                                      transform: Matrix4.rotationY(
                                        spot.edge == _PeekEdge.right
                                            ? math.pi
                                            : 0,
                                      ),
                                      child: Image.asset(
                                        _poses[_pose],
                                        fit: BoxFit.contain,
                                        gaplessPlayback: true,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fromRect(
                                key: const ValueKey('auth-feature-bubble'),
                                rect: spot.bubble,
                                child: Opacity(
                                  opacity: reveal.clamp(0.0, 1.0),
                                  child: Transform.scale(
                                    scale: .96 + .04 * reveal.clamp(0.0, 1.0),
                                    child: AuthFeatureBubble(
                                      message: _features[_featureIndex],
                                      tail: spot.tail,
                                      tailOffset:
                                          spot.tail == AxisDirection.left ||
                                              spot.tail == AxisDirection.right
                                          ? position.dy +
                                                spot.size *
                                                    (spot.edge == _PeekEdge.top
                                                        ? .40
                                                        : .60) -
                                                spot.bubble.top
                                          : position.dx +
                                                spot.size * .50 -
                                                spot.bubble.left,
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
              ),
          ],
        ),
      );
    },
  );
}

enum _PeekEdge { left, right, top, bottom }

class _PeekSpot {
  const _PeekSpot(this.edge, this.position, this.size, this.bubble, this.tail);
  final _PeekEdge edge;
  final Offset position;
  final double size;
  final Rect bubble;
  final AxisDirection tail;

  Rect corridor(Rect viewport) =>
      (position & Size.square(size)).inflate(18).intersect(viewport);

  double visibleArea(Rect viewport) {
    final visible = (position & Size.square(size)).intersect(viewport);
    return visible.width * visible.height;
  }
}
