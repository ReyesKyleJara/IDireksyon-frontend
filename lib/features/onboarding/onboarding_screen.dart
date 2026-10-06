import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

import 'package:flutter_svg/flutter_svg.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key}) : isRequirements = false;

  const OnboardingScreen.requirements({super.key}) : isRequirements = true;

  final bool isRequirements;

  static const Color primaryBlue = Color(0xFF0B4295);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.pageBackground,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final panelHeight =
                327.0 + (MediaQuery.textScalerOf(context).scale(24) - 24) * 5;
            final pageHeight = constraints.maxHeight.clamp(
              panelHeight + 313.0,
              double.infinity,
            );

            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: pageHeight),
                child: Column(
                  children: [
                    SizedBox(
                      height: pageHeight - panelHeight,
                      width: double.infinity,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 0,
                            bottom: -22,
                            left: 0,
                            right: 0,
                            child: Image.asset(
                              isRequirements
                                  ? 'assets/onboarding pictures/onboarding-requirements.png'
                                  : 'assets/onboarding pictures/onboarding-hero.png',
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(minHeight: panelHeight),
                      decoration: const BoxDecoration(
                        color: AppTheme.pageBackground,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(22),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x10000000),
                            blurRadius: 4,
                            offset: Offset(0, -1),
                          ),
                        ],
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 520),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 50, 16, 52),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/onboarding pictures/Group 105.svg',
                                      width: 50,
                                      height: 35,
                                      excludeFromSemantics: true,
                                    ),
                                    const SizedBox(width: 8),
                                    const Flexible(
                                      child: Text(
                                        'IDireksyon',
                                        style: TextStyle(
                                          fontFamily: 'Bricolage Grotesque',
                                          fontSize: 32,
                                          height: 1.1,
                                          fontWeight: FontWeight.w800,
                                          color: primaryBlue,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isRequirements
                                      ? 'Track Your Requirements in\nOne Place'
                                      : 'Simplify Your Government\nID Journey',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontFamily: 'Bricolage Grotesque',
                                    fontSize: 24,
                                    height: 1.25,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isRequirements
                                      ? 'No more confusion. Just a clear step-by-step roadmap'
                                      : 'Know exactly what to get, where to go, and what to prepare',
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 13,
                                    height: 1.3,
                                  ),
                                ),
                                const SizedBox(height: 64),
                                SizedBox(
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: () {
                                      if (isRequirements) {
                                        Navigator.of(context)
                                            .pushNamedAndRemoveUntil(
                                              '/welcome',
                                              (route) => false,
                                            );
                                      } else {
                                        Navigator.of(
                                          context,
                                        ).pushNamed('/onboarding/requirements');
                                      }
                                    },
                                    style: FilledButton.styleFrom(
                                      backgroundColor: primaryBlue,
                                      foregroundColor: Colors.white,
                                      minimumSize: const Size(0, 44),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    child: Text(
                                      isRequirements ? 'Get Started' : 'Next',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
