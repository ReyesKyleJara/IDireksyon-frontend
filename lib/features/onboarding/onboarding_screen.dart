import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import 'onboarding_mascot_scene.dart';
import 'onboarding_speech_bubble.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key}) : isRequirements = false;
  const OnboardingScreen.requirements({super.key}) : isRequirements = true;

  final bool isRequirements;
  static const Color primaryBlue = Color(0xFF0B4295);

  void _continue(BuildContext context) {
    if (isRequirements) {
      Navigator.of(context)
          .pushNamedAndRemoveUntil('/welcome', (route) => false);
    } else {
      Navigator.of(context).pushNamed('/onboarding/requirements');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            height: 36,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: isRequirements
                                  ? IconButton(
                                      tooltip: 'Back',
                                      padding: EdgeInsets.zero,
                                      onPressed: () =>
                                          Navigator.of(context).maybePop(),
                                      icon: const Icon(
                                        Icons.arrow_back_rounded,
                                        color: primaryBlue,
                                        size: 22,
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                          const Spacer(),
                          _message(),
                          const SizedBox(height: 8),
                          OnboardingMascotScene(
                            isRequirements: isRequirements,
                            height: (constraints.maxHeight * .36).clamp(
                              210.0,
                              300.0,
                            ),
                          ),
                          const SizedBox(height: 32),
                          const Spacer(),
                          Semantics(
                            label: 'Page ${isRequirements ? 2 : 1} of 2',
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(2, (index) {
                                final active =
                                    index == (isRequirements ? 1 : 0);
                                return Container(
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  width: active ? 22 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: active
                                        ? primaryBlue
                                        : const Color(0xFFD4DEEA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 24),
                          FilledButton(
                            onPressed: () => _continue(context),
                            style: FilledButton.styleFrom(
                              backgroundColor: primaryBlue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 54),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Text(
                              isRequirements ? 'Get Started' : 'Next',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
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
    );
  }

  Widget _message() {
    return OnboardingSpeechBubble(
      child: Column(
        children: [
          Text(
            isRequirements
                ? 'Let’s get you prepared.'
                : 'Hi! I’m Diro, your ID guide.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontSize: 25,
              height: 1.18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF163D70),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isRequirements
                ? 'Keep your requirements in one place. I’ll guide you through what to prepare, step by step.'
                : 'I’ll help you find the government ID you need, where to go, and how to get there.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              height: 1.55,
              color: Color(0xFF526579),
            ),
          ),
        ],
      ),
    );
  }
}
