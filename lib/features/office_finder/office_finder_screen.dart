import 'package:flutter/material.dart';
import 'directions_screen.dart';

class OfficeFinderScreen extends StatelessWidget {
  const OfficeFinderScreen({super.key});

  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBlue = Color(0xFFF0F5FA);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Office Finder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'Find government offices near you.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndLocation(context, isDark),
          _buildMapPlaceholder(isDark),
          _buildResultsHeader(colorScheme),
          Expanded(
            child: _buildOfficeList(context, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndLocation(
    BuildContext context,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search government offices',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.grey,
                ),
                suffixIcon: const Icon(
                  Icons.my_location_rounded,
                  color: Colors.grey,
                ),
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 14,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: isDark
                        ? Colors.transparent
                        : Colors.grey.shade200,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: primaryBlue,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: isDark
                  ? primaryBlue.withValues(alpha: 0.15)
                  : softBlue,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: primaryBlue.withValues(alpha: 0.1),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.near_me_rounded,
                  size: 16,
                  color: primaryBlue,
                ),
                SizedBox(width: 8),
                Text(
                  'Use my current location',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapPlaceholder(bool isDark) {
    return Container(
      height: 200,
      width: double.infinity,
      color: isDark
          ? const Color(0xFF1E1E1E)
          : const Color(0xFFE8EEF5),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Icon(
            Icons.map_outlined,
            size: 60,
            color: isDark
                ? Colors.grey.shade800
                : Colors.grey.shade400,
          ),

          const Positioned(
            top: 40,
            left: 80,
            child: _MapPin(),
          ),

          const Positioned(
            bottom: 60,
            right: 100,
            child: _MapPin(),
          ),

          const Positioned(
            top: 80,
            right: 50,
            child: _MapPin(),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(
    ColorScheme colorScheme,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        16,
        20,
        8,
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '3 offices found near you',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Row(
            children: [
              Text(
                'Sort by: ',
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const Text(
                'Nearest',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: primaryBlue,
                ),
              ),
              const Icon(
                Icons.arrow_drop_down_rounded,
                color: primaryBlue,
                size: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeList(
    BuildContext context,
    bool isDark,
  ) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        20,
        24,
      ),
      physics: const BouncingScrollPhysics(),
      children: [
        _buildOfficeCard(
          context,
          'DFA Consular Office Malolos',
          '9.1 km',
          isDark,
        ),
        const SizedBox(height: 12),
        _buildOfficeCard(
          context,
          'DFA Consular Office San Fernando',
          '22.4 km',
          isDark,
        ),
        const SizedBox(height: 12),
        _buildOfficeCard(
          context,
          'DFA Consular Office Angeles',
          '35.2 km',
          isDark,
        ),
      ],
    );
  }

  Widget _buildOfficeCard(
    BuildContext context,
    String name,
    String distance,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: 0.02,
                  ),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: isDark
            ? colorScheme.surfaceContainerHighest
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) =>
                    const DirectionsScreen(),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? primaryBlue.withValues(
                            alpha: 0.15,
                          )
                        : softBlue,
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
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
                        name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            distance,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'SM City Malolos, McArthur Highway',
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Today: 9:00 AM - 5:00 PM',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? primaryBlue.withValues(
                                  alpha: 0.15,
                                )
                              : softBlue,
                          borderRadius:
                              BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Passport Services',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
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