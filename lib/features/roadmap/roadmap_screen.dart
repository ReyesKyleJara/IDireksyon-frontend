import 'package:flutter/material.dart';

import '../../core/widgets/page_header.dart';
import 'build_roadmap_screen.dart';
import '../ids/ids_screen.dart';

class RoadmapScreen extends StatelessWidget {
  const RoadmapScreen({super.key, this.onOpenDirectory});

  final VoidCallback? onOpenDirectory;

  static const primaryBlue = Color(0xFF12499A);
  static const illustrationBlue = Color(0xFF0E56BD);

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = colors.onSurface;
    final secondary = colors.onSurfaceVariant;
    final card = colors.brightness == Brightness.dark
        ? colors.surfaceContainerHighest
        : Colors.white;
    final border = colors.brightness == Brightness.dark
        ? colors.outline
        : Colors.grey.shade300;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
        children: [
          const PageHeader('My Roadmap'),
          const SizedBox(height: 4),
          Text(
            'Track your progress and get to the IDs you need.',
            style: TextStyle(fontSize: 14, color: text),
          ),
          const SizedBox(height: 20),
          _Panel(
            color: card,
            border: border,
            child: Column(
              children: [
                const _RoadmapIllustration(),
                const SizedBox(height: 5),
                Text(
                  'No active roadmap yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'We’ll help you choose the right IDs, confirm your\ndocuments, and build the best order for a smoother\napplication process.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, height: 1.35, color: text),
                ),
                const SizedBox(height: 9),
                _PrimaryButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BuildRoadmapScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _Panel(
            color: card,
            border: border,
            padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
            child: Row(
              children: [
                const SizedBox(width: 106, child: _DirectoryIllustration()),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Not sure what to apply for?',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Browse available government IDs\nand guides',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.3,
                          color: secondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed:
                              onOpenDirectory ??
                              () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => Scaffold(
                                      appBar: AppBar(),
                                      body: const IdsScreen(),
                                    ),
                                  ),
                                );
                              },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryBlue,
                            side: const BorderSide(color: primaryBlue),
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Open ID Directory',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.color,
    required this.border,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(12, 12, 12, 12),
  });

  final Color color;
  final Color border;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    clipBehavior: Clip.antiAlias,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: border),
    ),
    child: child,
  );
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    constraints: const BoxConstraints(minHeight: 48),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: RoadmapScreen.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: const Text(
        'Build My Roadmap',
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    ),
  );
}

class _RoadmapIllustration extends StatelessWidget {
  const _RoadmapIllustration();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 112,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Positioned(left: 33, top: 26, child: _DocumentCard()),
        const Positioned(top: 17, child: _IdCard()),
        Positioned(
          right: 30,
          top: 33,
          child: Icon(
            Icons.account_balance,
            size: 54,
            color: Colors.blue.shade100,
          ),
        ),
        const Positioned(
          left: 40,
          bottom: 12,
          child: Icon(
            Icons.location_on,
            color: RoadmapScreen.illustrationBlue,
            size: 23,
          ),
        ),
        const Positioned(
          right: 61,
          bottom: 26,
          child: Icon(
            Icons.location_on,
            color: RoadmapScreen.illustrationBlue,
            size: 20,
          ),
        ),
        Positioned(
          bottom: 5,
          child: CustomPaint(
            size: const Size(185, 25),
            painter: _RoutePainter(),
          ),
        ),
      ],
    ),
  );
}

class _DocumentCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 42,
    constraints: const BoxConstraints(minHeight: 60),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      border: Border.all(color: Colors.blue.shade100),
      borderRadius: BorderRadius.circular(2),
    ),
    child: const Icon(Icons.person, color: Colors.blueGrey, size: 23),
  );
}

class _IdCard extends StatelessWidget {
  const _IdCard();

  @override
  Widget build(BuildContext context) => Container(
    width: 57,
    height: 42,
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: RoadmapScreen.illustrationBlue, width: 3),
      borderRadius: BorderRadius.circular(3),
    ),
    child: const Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        Icon(Icons.person, color: RoadmapScreen.illustrationBlue, size: 21),
        Icon(Icons.notes, color: RoadmapScreen.illustrationBlue, size: 20),
      ],
    ),
  );
}

class _DirectoryIllustration extends StatelessWidget {
  const _DirectoryIllustration();

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.center,
    children: [
      const Positioned(
        right: 4,
        bottom: 4,
        child: Icon(Icons.account_balance, color: Color(0xFF9DB4D0), size: 58),
      ),
      Container(
        width: 51,
        height: 51,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: RoadmapScreen.illustrationBlue, width: 4),
        ),
        child: const Icon(
          Icons.badge,
          color: RoadmapScreen.illustrationBlue,
          size: 27,
        ),
      ),
      const Positioned(
        right: 17,
        bottom: 8,
        child: Icon(
          Icons.search,
          color: RoadmapScreen.illustrationBlue,
          size: 42,
        ),
      ),
    ],
  );
}

class _RoutePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue.shade400
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..moveTo(0, 16)
      ..quadraticBezierTo(30, 2, 55, 16)
      ..quadraticBezierTo(83, 27, 105, 12)
      ..quadraticBezierTo(135, -1, size.width, 12);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
