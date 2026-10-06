import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import 'package:flutter_svg/flutter_svg.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _blue = Color(0xFF0B4295);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: (constraints.maxHeight - 48).clamp(
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
                          width: 120,
                          height: 81,
                          excludeFromSemantics: true,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'IDireksyon',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          height: 1.2,
                          color: _blue,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Welcome!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Bricolage Grotesque',
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Track your ID journey with ease.\nLog in or Sign Up to get started.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.7,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 32),
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/login'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _blue,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(42),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Log In'),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () =>
                            Navigator.of(context).pushNamed('/signup/email'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _blue,
                          minimumSize: const Size.fromHeight(42),
                          side: const BorderSide(color: _blue),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text('Sign Up'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
