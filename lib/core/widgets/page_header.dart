import 'package:flutter/material.dart';

class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        color: Theme.of(context).colorScheme.onSurface,
      ),
    );
  }
}

/// Header for pages opened from another page: the back arrow shares the
/// title's line, its left edge on the 20px page margin, with the subtitle
/// starting under the title.
class BackPageHeader extends StatelessWidget {
  const BackPageHeader(this.title, {super.key, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 20, 20, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed: () => Navigator.maybePop(context),
                color: colors.primary,
                icon: const Icon(Icons.arrow_back_rounded),
              ),
              Expanded(child: PageHeader(title)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
