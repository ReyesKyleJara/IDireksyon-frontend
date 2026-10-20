
import 'package:flutter/material.dart';

class HelpFaqScreen extends StatelessWidget {
  const HelpFaqScreen({super.key});

  static const _navy = Color(0xFF1E3A8A);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
          children: [
            const Text(
              'Help & FAQs',
              style: TextStyle(
                fontSize: 27,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Find answers to common questions about using IDireksyon.',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 30),

            const _FaqItem(
              question: 'What is IDireksyon?',
              answer:
                  'IDireksyon is an informational app that helps '
                  'you understand government ID requirements, '
                  'organize your documents, and plan which IDs '
                  'to prepare first.',
            ),
            const _FaqItem(
              question: 'How do I check ID requirements?',
              answer:
                  'Open the ID Directory, select a supported '
                  'government ID, and review its listed '
                  'requirements and instructions.',
            ),
            const _FaqItem(
              question: 'What is the Roadmap feature?',
              answer:
                  'The Roadmap suggests an order for preparing '
                  'government IDs based on your available '
                  'documents and selected goal.',
            ),
            const _FaqItem(
              question: 'How do I manage my documents?',
              answer:
                  'Go to Profile and tap My IDs & Documents. '
                  'You can update the list of documents '
                  'you already have.',
            ),
            const _FaqItem(
              question: 'Can IDireksyon apply for IDs on my behalf?',
              answer:
                  'No. IDireksyon only provides guidance. '
                  'You must complete official applications '
                  'through the relevant government agencies.',
            ),
            const _FaqItem(
              question: 'Can I book appointments through the app?',
              answer:
                  'No. IDireksyon does not currently provide '
                  'appointment booking or direct government '
                  'agency transactions.',
            ),
            const _FaqItem(
              question: 'Does IDireksyon require internet?',
              answer:
                  'Some features, including map navigation '
                  'and online account services, require '
                  'an internet connection.',
            ),
            const _FaqItem(
              question: 'Are the listed requirements always updated?',
              answer:
                  'Requirements and procedures may change. '
                  'Always confirm the latest information '
                  'with the relevant government agency.',
            ),

            const SizedBox(height: 30),

            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFE7EEF8),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    color: _navy,
                    size: 22,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'IDireksyon is an academic project '
                      'and is not affiliated with any '
                      'government agency.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFF263C5C),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
      children: [
        Theme(
          data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
          ),
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding:
                const EdgeInsets.fromLTRB(0, 0, 20, 18),
            title: Text(
              question,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.onSurface,
              ),
            ),
            iconColor: const Color(0xFF1E3A8A),
            collapsedIconColor: colors.onSurfaceVariant,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  answer,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
        Divider(
          height: 1,
          thickness: 0.6,
          color: colors.outlineVariant,
        ),
      ],
    );
  }
}
