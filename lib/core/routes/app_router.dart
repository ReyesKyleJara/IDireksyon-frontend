import 'package:flutter/material.dart';

import '../../features/auth/welcome_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/email_signup_screen.dart';
import '../../features/auth/phone_signup_screen.dart';

import '../../features/loading/loading_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/shell/resident_app_shell.dart';
import '../../features/profile/profile_setup_screen.dart';
import '../../features/profile/profile_complete_screen.dart';

class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const OnboardingScreen());
      case '/loading':
        return MaterialPageRoute(builder: (_) => const LoadingScreen());
      case '/welcome':
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case '/signup/email':
        return MaterialPageRoute(builder: (_) => const EmailSignupScreen());
      case '/signup/phone':
        return MaterialPageRoute(builder: (_) => const PhoneSignupScreen());
      case '/onboarding/requirements':
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen.requirements(),
        );
      case '/home':
        return MaterialPageRoute(builder: (_) => const ResidentAppShell());
      case '/profile/setup':
        return MaterialPageRoute(builder: (_) => const ProfileSetupScreen());
      case '/profile/loading':
        return MaterialPageRoute(
          builder: (_) => const LoadingScreen(nextRoute: '/profile/complete'),
        );
      case '/profile/complete':
        return MaterialPageRoute(builder: (_) => const ProfileCompleteScreen());

      default:
        return MaterialPageRoute(
          builder: (_) =>
              const Scaffold(body: Center(child: Text('Page not found'))),
        );
    }
  }
}
