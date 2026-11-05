import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../onboarding/onboarding_hero.dart';
import '../onboarding/onboarding_screen.dart';

/// Shared layout for Log In and Sign Up that matches onboarding: Diro on the
/// navy night map up top, the form on a white rounded sheet below. Without a
/// [mascotAsset] the sheet sits right under the top bar, for long forms.
class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.title,
    required this.subtitle,
    this.mascotAsset,
    this.orbitIcons = const [],
    required this.child,
  });

  final String title;
  final String subtitle;
  final String? mascotAsset;
  final List<IconData> orbitIcons;
  final Widget child;

  static InputDecoration inputDecoration(String hint, {Widget? suffixIcon}) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF98A2B3), fontSize: 14),
      filled: true,
      fillColor: const Color(0xFFF6F9FD),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      suffixIcon: suffixIcon,
      errorMaxLines: 2,
      border: border(const Color(0xFFDCE4EE)),
      enabledBorder: border(const Color(0xFFDCE4EE)),
      focusedBorder: border(AppTheme.royalBlue, 1.5),
      errorBorder: border(const Color(0xFFB3261E)),
      focusedErrorBorder: border(const Color(0xFFB3261E), 1.5),
    );
  }

  static ButtonStyle get primaryButton => FilledButton.styleFrom(
    backgroundColor: AppTheme.royalBlue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: AppTheme.royalBlue.withValues(alpha: .55),
    minimumSize: const Size.fromHeight(56),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
  );

  static ButtonStyle get linkButton => TextButton.styleFrom(
    foregroundColor: AppTheme.royalBlue,
    padding: const EdgeInsets.symmetric(horizontal: 4),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final typing = media.viewInsets.bottom > 0;
    final canPop = Navigator.of(context).canPop();
    return Theme(
      data: AppTheme.lightTheme,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: OnboardingScreen.systemBars,
        child: Scaffold(
          backgroundColor: OnboardingScreen.navyTop,
          body: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [OnboardingScreen.navyTop, AppTheme.navy],
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final heroHeight = typing
                    ? 0.0
                    : (constraints.maxHeight * .30).clamp(170.0, 280.0);
                return Stack(
                  children: [
                    // White behind the bottom so overscroll never shows navy.
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: constraints.maxHeight * .45,
                      child: const ColoredBox(color: Colors.white),
                    ),
                    SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: constraints.maxHeight,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(height: media.padding.top),
                            SizedBox(
                              height: 52,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: canPop
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 6),
                                        child: IconButton(
                                          tooltip: 'Back',
                                          color: Colors.white,
                                          onPressed: () =>
                                              Navigator.of(context).maybePop(),
                                          icon: const Icon(
                                            Icons.arrow_back_rounded,
                                          ),
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                            if (mascotAsset case final mascot?)
                              AnimatedContainer(
                                duration: AppMotion.duration(context),
                                curve: AppMotion.curve,
                                height: heroHeight,
                                child: OnboardingHero(
                                  mascotAsset: mascot,
                                  orbitIcons: orbitIcons,
                                ),
                              )
                            else
                              const SizedBox(height: 8),
                            // The sheet always reaches the bottom of the
                            // screen, so its lower edge is never visible.
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: math.max(
                                  0,
                                  constraints.maxHeight -
                                      media.padding.top -
                                      52 -
                                      (mascotAsset == null ? 8 : heroHeight),
                                ),
                              ),
                              child: _sheet(media.padding.bottom),
                            ),
                          ],
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

  Widget _sheet(double bottomInset) => DecoratedBox(
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
      padding: EdgeInsets.fromLTRB(26, 28, 26, 24 + bottomInset),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontFamily: 'Bricolage Grotesque',
                  fontSize: 30,
                  height: 1.1,
                  letterSpacing: -.4,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.navy,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.5,
                  color: Color(0xFF526579),
                ),
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}
