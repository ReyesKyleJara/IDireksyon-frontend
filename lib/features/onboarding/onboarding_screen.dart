import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/auth/auth_service.dart';
import '../../core/widgets/app_motion.dart';
import 'onboarding_hero.dart';

class OnboardingSlide {
  const OnboardingSlide({
    required this.title,
    required this.body,
    required this.mascot,
    required this.orbitIcons,
  });

  final String title;
  final String body;
  final String mascot;
  final List<IconData> orbitIcons;
}

const _art = 'assets/onboarding pictures';

const onboardingSlides = [
  OnboardingSlide(
    title: 'Hi! I’m Diro, your ID guide.',
    body: 'I’ll help you find the government ID you need, where to go, and how to get there.',
    mascot: '$_art/mascot-guide-cutout.png',
    orbitIcons: [
      Icons.badge_rounded,
      Icons.place_rounded,
      Icons.account_balance_rounded,
      Icons.directions_walk_rounded,
    ],
  ),
  OnboardingSlide(
    title: 'Let’s get you prepared.',
    body: 'Keep your requirements in one place. I’ll guide you through what to prepare, step by step.',
    mascot: '$_art/mascot-prepared-cutout.png',
    orbitIcons: [
      Icons.checklist_rounded,
      Icons.description_rounded,
      Icons.verified_rounded,
      Icons.event_available_rounded,
    ],
  ),
  OnboardingSlide(
    title: 'Welcome to IDireksyon!',
    body: 'Track your ID journey with ease. Log in or sign up to get started.',
    mascot: '$_art/mascot-tada-cutout.png',
    orbitIcons: [
      Icons.badge_rounded,
      Icons.route_rounded,
      Icons.checklist_rounded,
      Icons.place_rounded,
    ],
  ),
];

/// Intro slides and the Welcome (log in / sign up) step in one immersive
/// screen. [OnboardingScreen.welcome] shows only the final step, for people
/// returning to the app.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.initialPage = 0})
    : welcomeOnly = false;
  const OnboardingScreen.welcome({super.key})
    : initialPage = 2,
      welcomeOnly = true;

  final int initialPage;
  final bool welcomeOnly;

  static const navyTop = Color(0xFF0A2A55);
  static const navyBottom = Color(0xFF1B5AA3);

  /// White status icons over the navy top; a plain white Android navigation
  /// bar (no divider, no contrast scrim) so it blends into the white sheet
  /// instead of showing as a dark line at the bottom.
  static const systemBars = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarDividerColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
    systemNavigationBarContrastEnforced: false,
  );

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static final _last = onboardingSlides.length - 1;

  late int _page = widget.initialPage.clamp(0, _last);
  int _direction = 1;
  bool _openingAuth = false;

  @override
  void initState() {
    super.initState();
    if (_onWelcome) _rememberCompletion();
  }

  Future<void> _rememberCompletion() async {
    try {
      await AuthService.instance.sessionStore.completeOnboarding();
    } catch (_) {
      // Auth navigation retries the write and shows a recoverable error.
    }
  }

  Future<void> _openAuth(String route) async {
    if (_openingAuth) return;
    _openingAuth = true;
    try {
      await AuthService.instance.sessionStore.completeOnboarding();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save onboarding progress. Please try again.',
            ),
          ),
        );
      }
    } finally {
      _openingAuth = false;
    }
  }

  OnboardingSlide get _slide => onboardingSlides[_page];
  bool get _onWelcome => _page == _last;

  void _go(int page) {
    if (widget.welcomeOnly) return;
    final target = page.clamp(0, _last);
    if (target == _page) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = target > _page ? 1 : -1;
      _page = target;
    });
    if (_onWelcome) _rememberCompletion();
  }

  void _onSwipe(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (velocity < -250) _go(_page + 1);
    if (velocity > 250) _go(_page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Theme(
      data: AppTheme.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: OnboardingScreen.systemBars,
        child: PopScope(
          canPop: widget.welcomeOnly || _page == 0,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _go(_page - 1);
          },
          child: Scaffold(
            backgroundColor: OnboardingScreen.navyTop,
            body: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragEnd: widget.welcomeOnly ? null : _onSwipe,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      OnboardingScreen.navyTop,
                      AppTheme.navy,
                      OnboardingScreen.navyBottom,
                    ],
                    stops: [0, .45, 1],
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: padding.top),
                            const SizedBox(height: 24),
                            Expanded(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: (constraints.maxHeight * .30)
                                      .clamp(160.0, 340.0),
                                ),
                                child: OnboardingHero(
                                  mascotAsset: _slide.mascot,
                                  orbitIcons: _slide.orbitIcons,
                                  direction: _direction,
                                ),
                              ),
                            ),
                            _RiseIn(
                              enabled: !widget.welcomeOnly,
                              child: _sheet(padding.bottom),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheet(double bottomInset) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(36)),
        boxShadow: [
          BoxShadow(
            color: Color(0x40041A38),
            blurRadius: 30,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(26, 26, 26, 22 + bottomInset),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Dots sit at the very top of the sheet, and the sheet keeps
                // one height for every slide, so they never move.
                if (!widget.welcomeOnly) ...[
                  Center(
                    child: _PageDots(
                      page: _page,
                      count: onboardingSlides.length,
                      onSelect: _go,
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                Stack(
                  children: [
                    // Invisible copies reserve the tallest slide's height.
                    if (!widget.welcomeOnly)
                      for (final slide in onboardingSlides)
                        Visibility(
                          visible: false,
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: _SlideCopy(slide: slide),
                        ),
                    _SlideSwitcher(
                      direction: _direction,
                      child: _SlideCopy(key: ValueKey(_page), slide: _slide),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                AnimatedSwitcher(
                  duration: AppMotion.duration(context, AppMotion.enter),
                  switchInCurve: AppMotion.curve,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SizeTransition(sizeFactor: animation, child: child),
                  ),
                  child: _onWelcome ? _authButtons() : _nextButton(),
                ),
                const SizedBox(height: 14),
                // Outside the switcher so it stays put on every slide.
                const Text(
                  'IDireksyon is an independent informational guide and is '
                  'not affiliated with or operated by any Philippine '
                  'government agency.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: Color(0xFF526579),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static final _filled = FilledButton.styleFrom(
    backgroundColor: AppTheme.royalBlue,
    foregroundColor: Colors.white,
    minimumSize: const Size.fromHeight(56),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  /// Same height as [_authButtons] so the sheet never jumps between slides.
  Widget _nextButton() => Column(
    key: const ValueKey('next'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(
        onPressed: () => _go(_page + 1),
        style: _filled,
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text('Next')),
            SizedBox(width: 10),
            Icon(Icons.arrow_forward_rounded, size: 20),
          ],
        ),
      ),
      const SizedBox(height: 12),
      // Small link, but its slot keeps the Sign Up button's height.
      ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Center(
          child: TextButton(
            onPressed: () => _openAuth('/login'),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.royalBlue,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: const Size(0, 36),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text('I already have an account'),
          ),
        ),
      ),
    ],
  );

  Widget _authButtons() => Column(
    key: const ValueKey('auth'),
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FilledButton(
        onPressed: () => _openAuth('/login'),
        style: _filled,
        child: const Text('Log In'),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        onPressed: () => _openAuth('/signup/email'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppTheme.royalBlue,
          minimumSize: const Size.fromHeight(56),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          side: const BorderSide(color: AppTheme.royalBlue, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        child: const Text('Sign Up'),
      ),
    ],
  );
}

class _SlideCopy extends StatelessWidget {
  const _SlideCopy({super.key, required this.slide});
  final OnboardingSlide slide;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          slide.title,
          style: const TextStyle(
            fontFamily: 'Bricolage Grotesque',
            fontSize: 30,
            height: 1.1,
            letterSpacing: -.4,
            fontWeight: FontWeight.w800,
            color: AppTheme.navy,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          slide.body,
          style: const TextStyle(
            fontSize: 15,
            height: 1.55,
            color: Color(0xFF526579),
          ),
        ),
      ],
    );
  }
}

/// Slides copy in from the side the user is moving toward.
class _SlideSwitcher extends StatelessWidget {
  const _SlideSwitcher({required this.direction, required this.child});
  final int direction;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    duration: AppMotion.duration(context, const Duration(milliseconds: 380)),
    switchInCurve: AppMotion.curve,
    switchOutCurve: Curves.easeIn,
    layoutBuilder: (current, previous) =>
        Stack(alignment: Alignment.topLeft, children: [...previous, ?current]),
    transitionBuilder: (child, animation) {
      final incoming = child.key == this.child.key;
      final dx = (incoming ? .12 : -.12) * direction;
      return FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: Offset(dx, 0),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      );
    },
    child: child,
  );
}

/// The sheet rises into place the first time the screen appears.
class _RiseIn extends StatelessWidget {
  const _RiseIn({required this.child, this.enabled = true});
  final Widget child;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled || AppMotion.reduced(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 560),
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Transform.translate(
        offset: Offset(0, 60 * (1 - t)),
        child: Opacity(opacity: t, child: child),
      ),
    );
  }
}

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.page,
    required this.count,
    required this.onSelect,
  });
  final int page;
  final int count;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Page ${page + 1} of $count',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(count, (index) {
            final active = index == page;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onSelect(index),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 8),
                child: AnimatedContainer(
                  duration: AppMotion.duration(context, AppMotion.enter),
                  curve: AppMotion.curve,
                  width: active ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: active
                        ? AppTheme.royalBlue
                        : const Color(0xFFD4DEEA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
