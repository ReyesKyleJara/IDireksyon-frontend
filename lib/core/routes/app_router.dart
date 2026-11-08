import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../../features/startup/startup_screen.dart';
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
  static const _signedInRoutes = {
    '/home',
    '/profile/setup',
    '/profile/loading',
    '/profile/complete',
  };

  static Route<dynamic> generateRoute(RouteSettings settings) {
    // Decided here, not in the page builder, so a page already on screen is
    // not swapped out while it animates away during logout. Web URLs can name
    // these routes directly; startup restores a saved session or signs out.
    if (_signedInRoutes.contains(settings.name) &&
        AuthService.instance.token == null) {
      return MaterialPageRoute(
        builder: (_) => StartupScreen(resumeRoute: settings.name),
      );
    }
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(builder: (_) => const StartupScreen());
      case '/onboarding':
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
          builder: (_) => const OnboardingScreen(initialPage: 1),
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
