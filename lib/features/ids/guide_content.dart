import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'detail_widgets.dart';

/// Read-only renderer of the CMS's restricted document JSON, never arbitrary HTML.
class GuideRichContent extends StatelessWidget {
  final dynamic value;
  const GuideRichContent(this.value, {super.key});
  @override
  Widget build(BuildContext context) => _node(value, 0);
  Widget _node(dynamic node, int depth) {
    if (depth > 12) return const SizedBox.shrink();
    if (node is String) return Text(node, style: const TextStyle(height: 1.5));
    if (node is! Map) return const SizedBox.shrink();
    final children = node['content'] is List
        ? node['content'] as List
        : const [];
    switch (node['type']) {
      case 'paragraph':
      case 'heading':
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _Paragraph(node, heading: node['type'] == 'heading'),
        );
      case 'bulletList':
      case 'orderedList':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < children.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(node['type'] == 'orderedList' ? '${i + 1}. ' : '• '),
                    Expanded(child: _node(children[i], depth + 1)),
                  ],
                ),
              ),
          ],
        );
      case 'doc':
      case 'listItem':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children.map((child) => _node(child, depth + 1)).toList(),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _Paragraph extends StatefulWidget {
  final Map node;
  final bool heading;
  const _Paragraph(this.node, {required this.heading});
  @override
  State<_Paragraph> createState() => _ParagraphState();
}

class _ParagraphState extends State<_Paragraph> {
  final _links = <TapGestureRecognizer>[];
  void _clear() {
    for (final link in _links) {
      link.dispose();
    }
    _links.clear();
  }

  @override
  void dispose() {
    _clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clear();
    final children = widget.node['content'] is List
        ? widget.node['content'] as List
        : const [];
    return Text.rich(
      TextSpan(
        children: [
          for (final node in children)
            if (node is Map) _span(context, node),
        ],
      ),
      style: TextStyle(
        fontSize: widget.heading ? 17 : 14,
        height: 1.5,
        fontWeight: widget.heading ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  InlineSpan _span(BuildContext context, Map node) {
    if (node['type'] == 'hardBreak') return const TextSpan(text: '\n');
    if (node['type'] != 'text' || node['text'] is! String) {
      return const TextSpan();
    }
    final marks = node['marks'] is List ? node['marks'] as List : const [];
    var bold = false, italic = false, underline = false;
    String? url;
    for (final mark in marks.whereType<Map>()) {
      bold |= mark['type'] == 'bold';
      italic |= mark['type'] == 'italic';
      underline |= mark['type'] == 'underline';
      if (mark['type'] == 'link' &&
          mark['attrs'] is Map &&
          safeOfficialLink(mark['attrs']['href'])) {
        url = mark['attrs']['href'];
      }
    }
    TapGestureRecognizer? recognizer;
    if (url != null) {
      final address = url;
      recognizer = TapGestureRecognizer()
        ..onTap = () => openOfficialLink(context, address);
      _links.add(recognizer);
    }
    return TextSpan(
      text: node['text'],
      recognizer: recognizer,
      style: TextStyle(
        fontWeight: bold ? FontWeight.bold : null,
        fontStyle: italic ? FontStyle.italic : null,
        decoration: underline || url != null ? TextDecoration.underline : null,
        color: url != null ? detailsBlue : null,
      ),
    );
  }
}
