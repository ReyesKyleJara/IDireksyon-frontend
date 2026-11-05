import 'package:flutter/material.dart';

import '../onboarding/onboarding_screen.dart';

/// Welcome now lives inside onboarding as its final step. This route shows
/// that step on its own (with Diro, Log In and Sign Up) for returning users.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) => const OnboardingScreen.welcome();
}
