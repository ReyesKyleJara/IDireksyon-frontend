import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/frosted.dart';

/// Same gradient, corners and shadow as Home's "Get started" banner.
class RoadmapGradientCard extends StatelessWidget {
  const RoadmapGradientCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryBlue.withValues(alpha: .18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppTheme.navy, Color(0xFF246AA5)],
            ),
          ),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: frostedBannerEdge,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Same surface as Home's cards and quick-action tiles.
class RoadmapCard extends StatelessWidget {
  const RoadmapCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return Material(
      color: dark ? colors.surfaceContainer : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: dark
              ? colors.outlineVariant.withValues(alpha: .35)
              : const Color(0xFFE3ECF7),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// The "Not sure what to apply for?" link to the ID Directory.
class RoadmapDirectoryCard extends StatelessWidget {
  const RoadmapDirectoryCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RoadmapCard(
      child: MotionInkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              const _DirectoryBadge(),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Not sure what to apply for?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Browse available government IDs and guides',
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.35,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Open ID Directory',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: colors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: colors.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home's ID Directory quick-action icon.
class _DirectoryBadge extends StatelessWidget {
  const _DirectoryBadge();

  @override
  Widget build(BuildContext context) {
    const tint = AppTheme.progressGold;
    final dark = Theme.of(context).colorScheme.brightness == Brightness.dark;
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color.lerp(tint, Colors.white, .18)!, tint],
          ),
          boxShadow: [
            BoxShadow(
              color: tint.withValues(alpha: dark ? .2 : .28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: const SizedBox.square(
          dimension: 50,
          child: Icon(Icons.badge_rounded, color: Colors.white, size: 25),
        ),
      ),
    );
  }
}

/// The navy heading card used on each step of building a roadmap.
class RoadmapStepHeader extends StatelessWidget {
  const RoadmapStepHeader({
    super.key,
    required this.step,
    required this.title,
    required this.subtitle,
    this.child,
  });

  final String step, title, subtitle;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return RoadmapGradientCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              step,
              style: const TextStyle(
                color: Color(0xFFD5E7FA),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w800,
                height: 1.15,
                letterSpacing: -.4,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFD5E7FA),
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
            if (child != null) ...[const SizedBox(height: 14), child!],
          ],
        ),
      ),
    );
  }
}

/// Stays on screen so the next step never has to be scrolled to.
class RoadmapBottomBar extends StatelessWidget {
  const RoadmapBottomBar({super.key, this.note, required this.action});

  final Widget? note;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return FrostedSurface(
      opacity: .82,
      border: Border(
        top: BorderSide(
          color: dark
              ? colors.outlineVariant.withValues(alpha: .35)
              : const Color(0xFFE3ECF7),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (note != null) ...[note!, const SizedBox(height: 8)],
              action,
            ],
          ),
        ),
      ),
    );
  }
}

ButtonStyle roadmapPrimaryButtonStyle(BuildContext context) {
  final colors = Theme.of(context).colorScheme;
  return ElevatedButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    elevation: 0,
    backgroundColor: AppTheme.primaryBlue,
    foregroundColor: Colors.white,
    disabledBackgroundColor: colors.surfaceContainerHigh,
    disabledForegroundColor: colors.onSurfaceVariant,
    textStyle: const TextStyle(
      fontFamily: 'Google Sans',
      fontSize: 14,
      fontWeight: FontWeight.w700,
    ),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Switches the journey log between ongoing and finished journeys.
class JourneyStatusTabs extends StatelessWidget {
  const JourneyStatusTabs({
    super.key,
    required this.showCompleted,
    required this.onChanged,
    this.inProgress = 0,
    this.completed = 0,
  });

  final bool showCompleted;
  final ValueChanged<bool> onChanged;
  final int inProgress, completed;

  static String _label(String name, int count) =>
      count > 0 ? '$name ($count)' : name;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return SegmentedButton<bool>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: false,
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_label('In Progress', inProgress)),
          ),
        ),
        ButtonSegment(
          value: true,
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(_label('Completed', completed)),
          ),
        ),
      ],
      selected: {showCompleted},
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: dark ? colors.surfaceContainer : Colors.white,
        foregroundColor: colors.onSurface,
        selectedBackgroundColor: AppTheme.primaryBlue,
        selectedForegroundColor: Colors.white,
        side: BorderSide(
          color: dark
              ? colors.outlineVariant.withValues(alpha: .35)
              : const Color(0xFFE3ECF7),
        ),
      ),
    );
  }
}

/// Shown when a journey log tab has nothing in it.
class JourneyLogEmpty extends StatelessWidget {
  const JourneyLogEmpty({
    super.key,
    required this.title,
    required this.message,
  });

  final String title, message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return RoadmapCard(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        child: Column(
          children: [
            Icon(
              Icons.history_rounded,
              size: 40,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded tile for a government ID or document.
class RoadmapRecordIcon extends StatelessWidget {
  const RoadmapRecordIcon({super.key, required this.document, this.size = 42});

  final bool document;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    // The same colors as Home's Document Inventory and ID Directory tiles.
    final tint = document
        ? colors.primary
        : (dark ? AppTheme.accentGold : AppTheme.progressGold);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: tint.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(size * .29),
        ),
        child: Icon(
          document ? Icons.description_rounded : Icons.badge_rounded,
          color: tint,
          size: size * .52,
        ),
      ),
    );
  }
}
