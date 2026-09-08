import 'package:flutter/material.dart';

class DirectionsScreen extends StatelessWidget {
  const DirectionsScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBlue = Color(0xFFF0F5FA);
  static const Color textGrey = Color(0xFF4A5568);

  @override
  Widget build(BuildContext context) {
    final colorScheme =
        Theme.of(context).colorScheme;
    final isDark =
        Theme.of(context).brightness ==
            Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? colorScheme.surface : Colors.white,
      appBar: AppBar(
        backgroundColor:
            isDark ? colorScheme.surface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () =>
              Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Directions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'Route to selected office',
              style: TextStyle(
                fontSize: 12,
                color:
                    colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildDestinationCard(
            context,
            isDark,
          ),
          Expanded(
            child: _buildRouteMapPlaceholder(
              isDark,
            ),
          ),
          _buildActionSheet(
            context,
            isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(
    BuildContext context,
    bool isDark,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        16,
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? colorScheme.surfaceContainerHighest
              : Colors.white,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.transparent
                : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(
                      alpha: 0.03,
                    ),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: softBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'DFA Consular Office Malolos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color:
                          colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Closes 5:00 PM',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey
                              .shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteMapPlaceholder(
    bool isDark,
  ) {
    return Container(
      width: double.infinity,
      color: isDark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFE8EEF5),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 80,
            color: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade300,
          ),

          Positioned(
            bottom: 40,
            right: 60,
            child: Column(
              children: [
                const _MapPin(),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Your Location',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Positioned(
            top: 40,
            left: 60,
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'DFA Malolos',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Icon(
                  Icons.location_on,
                  color: Colors.red,
                  size: 32,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionSheet(
    BuildContext context,
    bool isDark,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        24,
        24,
        24,
        32,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? colorScheme.surface
            : Colors.white,
        borderRadius:
            const BorderRadius.vertical(
          top: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: 0.05,
            ),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment:
                MainAxisAlignment.spaceAround,
            children: [
              _buildTripStat(
                Icons.schedule_rounded,
                '24 min',
                'ETA (Light traffic)',
                context,
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey.shade200,
              ),
              _buildTripStat(
                Icons.route_rounded,
                '16.3 km',
                'Distance',
                context,
              ),
            ],
          ),

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.navigation_rounded,
                size: 18,
              ),
              label: const Text(
                'Start Directions',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 18,
              ),
              label: const Text(
                'Open in Maps',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style:
                  OutlinedButton.styleFrom(
                foregroundColor: textGrey,
                side: BorderSide(
                  color: Colors.grey.shade300,
                  width: 1.5,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(
    IconData icon,
    String primaryText,
    String secondaryText,
    BuildContext context,
  ) {
    final colorScheme =
        Theme.of(context).colorScheme;

    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(
          icon,
          size: 28,
          color: primaryBlue,
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              primaryText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              secondaryText,
              style: TextStyle(
                fontSize: 11,
                color:
                    colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _MapPin extends StatelessWidget {
  const _MapPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A8A)
            .withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: const BoxDecoration(
            color: Color(0xFF1E3A8A),
            shape: BoxShape.circle,
            border: Border.fromBorderSide(
              BorderSide(
                color: Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}