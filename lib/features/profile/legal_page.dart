import 'package:flutter/material.dart';

/// Shared layout for the in-app legal screens, built from the same pieces as
/// About (soft-blue intro, icon tiles) and Profile (uppercase headings,
/// grouped cards).
class LegalPage extends StatelessWidget {
  const LegalPage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.introIcon,
    required this.introTitle,
    required this.introBody,
    required this.groups,
    this.isModal = false,
  });

  final String title;
  final String subtitle;
  final IconData introIcon;
  final String introTitle;
  final List<String> introBody;
  final List<LegalGroup> groups;
  final bool isModal;

  static const _navy = Color(0xFF1E3A8A);
  static const _softBlue = Color(0xFFE7EEF8);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final muted = colors.onSurfaceVariant;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        automaticallyImplyLeading: !isModal,
        actions: isModal
            ? [
                IconButton(
                  tooltip: 'Close',
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ]
            : null,
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, height: 1.5, color: muted),
            ),
            const SizedBox(height: 24),
            _intro(),
            for (final group in groups) ...[
              _heading(group.title, muted),
              _card(colors, group.sections),
            ],
            const SizedBox(height: 28),
            Text(
              'IDireksyon by GeoBytes',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: muted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _intro() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: _softBlue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(introIcon, color: _navy, size: 31),
          const SizedBox(height: 15),
          Text(
            introTitle,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: Color(0xFF182D50),
            ),
          ),
          for (final paragraph in introBody) ...[
            const SizedBox(height: 9),
            Text(
              paragraph,
              style: const TextStyle(
                fontSize: 14,
                height: 1.55,
                color: Color(0xFF405673),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _heading(String text, Color muted) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 26, 2, 12),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
          color: muted,
        ),
      ),
    );
  }

  Widget _card(ColorScheme colors, List<LegalSection> sections) {
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < sections.length; i++) ...[
            _section(colors, sections[i]),
            if (i != sections.length - 1)
              Divider(
                height: 1,
                thickness: 0.6,
                indent: 17,
                endIndent: 17,
                color: colors.outlineVariant,
              ),
          ],
        ],
      ),
    );
  }

  Widget _section(ColorScheme colors, LegalSection section) {
    return Padding(
      padding: const EdgeInsets.all(17),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _softBlue,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(section.icon, color: _navy, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  section.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          for (final block in section.body) ...[
            const SizedBox(height: 11),
            switch (block) {
              LegalParagraph(:final text) => _paragraph(colors, text),
              LegalBullets(:final items) => _bullets(colors, items),
            },
          ],
        ],
      ),
    );
  }

  TextStyle _bodyStyle(ColorScheme colors) => TextStyle(
    fontSize: 13.5,
    height: 1.55,
    color: colors.onSurfaceVariant,
  );

  Widget _paragraph(ColorScheme colors, String text) =>
      Text(text, style: _bodyStyle(colors));

  Widget _bullets(ColorScheme colors, List<LegalItem> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      color: colors.onSurfaceVariant,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: _bodyStyle(colors),
                      children: [
                        if (items[i].lead != null)
                          TextSpan(
                            text: '${items[i].lead}: ',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                        TextSpan(text: items[i].text),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class LegalGroup {
  const LegalGroup(this.title, this.sections);

  final String title;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final List<LegalBlock> body;
}

sealed class LegalBlock {
  const LegalBlock();
}

class LegalParagraph extends LegalBlock {
  const LegalParagraph(this.text);

  final String text;
}

class LegalBullets extends LegalBlock {
  const LegalBullets(this.items);

  final List<LegalItem> items;
}

class LegalItem {
  const LegalItem(this.text, {this.lead});

  final String text;
  final String? lead;
}
