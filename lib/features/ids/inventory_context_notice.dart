import 'package:flutter/material.dart';

class InventoryContextNotice extends StatelessWidget {
  final bool unavailable;
  final VoidCallback retry;
  const InventoryContextNotice({
    super.key,
    required this.unavailable,
    required this.retry,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!unavailable) const LinearProgressIndicator(),
        const SizedBox(height: 12),
        Text(
          unavailable
              ? "We couldn't load your inventory. Your ownership information is unavailable, so personalized application information and your roadmap are paused."
              : 'Loading your inventory before personalizing your application…',
        ),
        if (unavailable)
          TextButton(onPressed: retry, child: const Text('Retry inventory')),
      ],
    ),
  );
}
