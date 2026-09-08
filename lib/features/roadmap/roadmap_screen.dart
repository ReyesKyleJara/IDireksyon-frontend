import 'package:flutter/material.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final backgroundColor = theme.scaffoldBackgroundColor;
    final cardColor = isDark
        ? theme.colorScheme.surfaceContainerHighest
        : Colors.white;

    final borderColor = isDark
        ? Colors.transparent
        : Colors.grey.shade200;

    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor = theme.colorScheme.onSurfaceVariant;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
        children: [
          // HEADER
          Text(
            'Roadmap',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your personalized ID journey',
            style: TextStyle(
              fontSize: 13,
              color: secondaryTextColor,
            ),
          ),

          const SizedBox(height: 24),

          // CURRENT GOAL
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: borderColor,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.flag_outlined,
                    color: primaryBlue,
                    size: 25,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'CURRENT GOAL',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: secondaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get a Philippine Passport',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // PROGRESS
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: primaryBlue,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Progress',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '3 of 5 steps',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 14),

                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: 0.6,
                    minHeight: 8,
                    backgroundColor:
                        Colors.white.withValues(alpha: 0.2),
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(
                      Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                Text(
                  'You are making progress!',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // NEXT STEP HEADER
          Text(
            'Next Step',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),

          const SizedBox(height: 12),

          // NEXT STEP CARD
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primaryBlue.withValues(alpha: 0.25),
                width: 1.2,
              ),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Text(
                          '3',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Apply for Passport',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Text(
                  'You have the documents needed to start this step.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: secondaryTextColor,
                  ),
                ),

                const SizedBox(height: 16),

                // WHY THIS STEP
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: primaryBlue.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 19,
                        color: isDark
                            ? Colors.blue.shade300
                            : primaryBlue,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          'Why this is your next step: your required documents are currently marked as available.',
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: secondaryTextColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Row(
                      mainAxisAlignment:
                          MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Requirements',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 6),
                        Icon(
                          Icons.arrow_forward,
                          size: 17,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // JOURNEY HEADER
          Text(
            'Your Journey',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),

          const SizedBox(height: 16),

          // TIMELINE
          _buildTimelineStep(
            context: context,
            number: '1',
            title: 'Prepare Birth Certificate',
            subtitle: 'Completed',
            status: RoadmapStatus.completed,
            isLast: false,
          ),

          _buildTimelineStep(
            context: context,
            number: '2',
            title: 'Prepare Valid Identification',
            subtitle: 'Completed',
            status: RoadmapStatus.completed,
            isLast: false,
          ),

          _buildTimelineStep(
            context: context,
            number: '3',
            title: 'Apply for Passport',
            subtitle: 'Ready to start',
            status: RoadmapStatus.current,
            isLast: false,
          ),

          _buildTimelineStep(
            context: context,
            number: '4',
            title: 'Complete Biometrics',
            subtitle: 'After application',
            status: RoadmapStatus.locked,
            isLast: false,
          ),

          _buildTimelineStep(
            context: context,
            number: '5',
            title: 'Claim Passport',
            subtitle: 'Upcoming',
            status: RoadmapStatus.upcoming,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineStep({
    required BuildContext context,
    required String number,
    required String title,
    required String subtitle,
    required RoadmapStatus status,
    required bool isLast,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final textColor = theme.colorScheme.onSurface;
    final secondaryTextColor =
        theme.colorScheme.onSurfaceVariant;

    Color circleColor;
    Color iconColor;

    IconData? icon;

    switch (status) {
      case RoadmapStatus.completed:
        circleColor = Colors.green.shade600;
        iconColor = Colors.white;
        icon = Icons.check;
        break;

      case RoadmapStatus.current:
        circleColor = primaryBlue;
        iconColor = Colors.white;
        icon = null;
        break;

      case RoadmapStatus.locked:
        circleColor = isDark
            ? Colors.grey.shade700
            : Colors.grey.shade300;
        iconColor = secondaryTextColor;
        icon = Icons.lock_outline;
        break;

      case RoadmapStatus.upcoming:
        circleColor = isDark
            ? Colors.grey.shade700
            : Colors.grey.shade300;
        iconColor = secondaryTextColor;
        icon = null;
        break;
    }

    final lineColor = isDark
        ? Colors.grey.shade700
        : Colors.grey.shade300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // TIMELINE COLUMN
        SizedBox(
          width: 42,
          child: Column(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  border: status == RoadmapStatus.upcoming
                      ? Border.all(
                          color: secondaryTextColor
                              .withValues(alpha: 0.3),
                          width: 1,
                        )
                      : null,
                ),
                child: Center(
                  child: icon != null
                      ? Icon(
                          icon,
                          size: 17,
                          color: iconColor,
                        )
                      : Text(
                          number,
                          style: TextStyle(
                            color: iconColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                ),
              ),

              if (!isLast)
                Container(
                  width: 2,
                  height: 58,
                  color: lineColor,
                ),
            ],
          ),
        ),

        const SizedBox(width: 12),

        // STEP CONTENT
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(
              top: 2,
              bottom: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight:
                        status == RoadmapStatus.current
                            ? FontWeight.w800
                            : FontWeight.w700,
                    color: status == RoadmapStatus.locked ||
                            status == RoadmapStatus.upcoming
                        ? secondaryTextColor
                        : textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: status == RoadmapStatus.completed
                        ? Colors.green.shade600
                        : secondaryTextColor,
                    fontWeight:
                        status == RoadmapStatus.current
                            ? FontWeight.w600
                            : FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum RoadmapStatus {
  completed,
  current,
  locked,
  upcoming,
}