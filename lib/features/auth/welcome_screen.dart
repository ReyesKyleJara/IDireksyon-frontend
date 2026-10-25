import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../core/theme/app_theme.dart';
import 'auth_mascot_peek.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _blue = Color(0xFF0B4295);

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: AppTheme.lightTheme,
      child: Scaffold(
        backgroundColor: AppTheme.pageBackground,
        body: SafeArea(
          child: AuthMascotPeek(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: (constraints.maxHeight - 42).clamp(
                        0.0,
                        double.infinity,
                      ),
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: SvgPicture.asset(
                                'assets/onboarding pictures/Group 105.svg',
                                width: 104,
                                height: 70,
                                excludeFromSemantics: true,
                              ),
                            ),

                            const SizedBox(height: 12),

                            const Text(
                              'IDireksyon',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 31,
                                height: 1.2,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF0A426E),
                              ),
                            ),

                            const SizedBox(height: 24),

                            const Text(
                              'Welcome!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontFamily: 'Bricolage Grotesque',
                                fontSize: 24,
                                height: 1.25,
                                fontWeight: FontWeight.w700,
                                color: Colors.black,
                              ),
                            ),

                            const SizedBox(height: 8),

                            const Text(
                              'Track your ID journey with ease.\n'
                              'Log in or sign up to get started.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Color(0xFF667085),
                              ),
                            ),

                            const SizedBox(height: 30),

                            FilledButton(
                              onPressed: () {
                                Navigator.of(context).pushNamed('/login');
                              },
                              style: FilledButton.styleFrom(
                                backgroundColor: _blue,
                                foregroundColor: Colors.white,
                                minimumSize: const Size.fromHeight(50),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Log In',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),

                            const SizedBox(height: 10),

                            OutlinedButton(
                              onPressed: () {
                                Navigator.of(context)
                                    .pushNamed('/signup/email');
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _blue,
                                minimumSize: const Size.fromHeight(50),
                                side: const BorderSide(
                                  color: _blue,
                                  width: 1.4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
