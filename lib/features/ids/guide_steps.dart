import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../models/government_id.dart' show CatalogFee;
import 'id_details_screen.dart' show CatalogOfficialLink, CatalogRichText;

/// The Guide tab: one numbered accordion card per step.
///
/// A closed card shows the step number, its title and a short line. Opening it
/// shows the step's content in a clean form. Blocks that are linked to the
/// record (requirements, fees, offices, processing time) show the record's real
/// data for the selected application type, not a "see the other tab" note.
class GuideSteps extends StatefulWidget {
  const GuideSteps({
    super.key,
    required this.steps,
    required this.path,
    this.tabIndex,
  });

  final List<Map<String, dynamic>> steps;

  /// The selected application type: its requirements, fees, offices, etc.
  final Map<String, dynamic> path;

  /// Position of a tab by its label, or -1. Lets a step jump to that tab.
  final int Function(String label)? tabIndex;

  @override
  State<GuideSteps> createState() => _GuideStepsState();
}

class _GuideStepsState extends State<GuideSteps> {
  final _open = <int>{};

  static List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList()
      : [];

  static String _text(dynamic value) => value is String ? value.trim() : '';

  /// True for a rich-text document that has any text in it.
  static bool _hasRichText(dynamic node) {
    if (node is String) return node.trim().isNotEmpty;
    if (node is Map) {
      if (_text(node['text']).isNotEmpty) return true;
      return _hasRichText(node['content']);
    }
    if (node is List) return node.any(_hasRichText);
    return false;
  }

  Color _accent(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return colors.brightness == Brightness.dark
        ? colors.primary
        : AppTheme.primaryBlue;
  }

  void _openTab(String label) {
    final index = widget.tabIndex?.call(label) ?? -1;
    if (index >= 0) DefaultTabController.maybeOf(context)?.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return ListView(
      key: const PageStorageKey('record-guide-scroll'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Application Guide',
                style: TextStyle(
                  fontSize: 20,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: colors.onSurface,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${widget.steps.length} ${widget.steps.length == 1 ? 'step' : 'steps'}'
                '  •  Tap a step to see the details',
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ],
          ),
        ),
        for (var index = 0; index < widget.steps.length; index++)
          _step(context, index),
      ],
    );
  }

  Widget _step(BuildContext context, int index) {
    final step = widget.steps[index];
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = _accent(context);
    final open = _open.contains(index);
    final summary = _text(step['short_description']);
    final details = <Widget>[
      for (final block in _maps(step['blocks'])) ..._block(context, block),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: ValueKey('guide-step-$index'),
        color: dark ? colors.surfaceContainer : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: open
                ? accent.withValues(alpha: .55)
                : colors.outlineVariant.withValues(alpha: .4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              expanded: open,
              child: InkWell(
                onTap: () => setState(
                  () => open ? _open.remove(index) : _open.add(index),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: dark ? colors.primary : AppTheme.royalBlue,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: dark ? AppTheme.navy : Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _text(step['title']),
                              style: TextStyle(
                                fontSize: 16,
                                height: 1.3,
                                fontWeight: FontWeight.w700,
                                color: colors.onSurface,
                              ),
                            ),
                            if (summary.isNotEmpty) ...[
                              const SizedBox(height: 3),
                              Text(
                                summary,
                                // Closed: a short preview. Open: all of it.
                                maxLines: open ? null : 2,
                                overflow: open ? null : TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: AnimatedRotation(
                          turns: open ? .25 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            Icons.chevron_right_rounded,
                            color: accent,
                            size: 26,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              alignment: Alignment.topCenter,
              child: !open || details.isEmpty
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: DefaultTextStyle.merge(
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: colors.onSurface,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: details,
                        ),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// One block of a step, as clean widgets with a gap above it.
  List<Widget> _block(BuildContext context, Map<String, dynamic> block) {
    final colors = Theme.of(context).colorScheme;
    final content = block['content'] is Map
        ? Map<String, dynamic>.from(block['content'])
        : <String, dynamic>{};
    final type = '${block['type']}';
    final body = <Widget>[];

    if (type == 'official_link') {
      final url = _text(content['url']);
      if (CatalogOfficialLink.isSafe(url)) {
        final label = _text(content['label']);
        body.add(
          _LinkButton(
            url: url,
            label: label.isEmpty || label.toLowerCase() == 'official website'
                ? 'Open official website'
                : 'Open $label',
          ),
        );
        if (_text(content['description']).isNotEmpty) {
          body.add(
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _text(content['description']),
                style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant),
              ),
            ),
          );
        }
      }
    } else if (type == 'reminder') {
      for (final key in ['intro', 'body']) {
        if (_hasRichText(content[key])) {
          body.add(_note(context, CatalogRichText(value: content[key])));
        }
      }
    } else {
      for (final key in ['intro', 'body']) {
        if (_hasRichText(content[key])) {
          body.add(CatalogRichText(value: content[key]));
        }
      }
      for (final item in content['items'] as List? ?? []) {
        final value = item is Map ? item['body'] : item;
        if (_hasRichText(value)) body.add(_tick(context, value));
      }
      // Linked blocks show the selected application type's real data.
      if (type == 'requirements') body.addAll(_requirements(context));
      if (type == 'fees') body.addAll(_fees(context));
      if (type == 'offices') body.addAll(_offices(context));
      if (type == 'processing_time' &&
          _text(widget.path['processing']).isNotEmpty) {
        body.add(
          _fact(
            context,
            Icons.schedule_outlined,
            'Processing time',
            _text(widget.path['processing']),
          ),
        );
      }
    }
    if (body.isEmpty) return const [];
    final title = _text(block['section_title']);
    return [
      const SizedBox(height: 12),
      if (title.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            title,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
        ),
      ...body,
    ];
  }

  Widget _box(BuildContext context, Widget child) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: dark
            ? colors.surfaceContainerHighest.withValues(alpha: .45)
            : AppTheme.pageBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: child,
    );
  }

  Widget _note(BuildContext context, Widget child) => _box(
    context,
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(Icons.info_outline, size: 17, color: _accent(context)),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    ),
  );

  Widget _tick(BuildContext context, dynamic value) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Icon(
            Icons.check_circle_outline_rounded,
            size: 17,
            color: _accent(context),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: CatalogRichText(value: value)),
      ],
    ),
  );

  Widget _fact(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) => _box(
    context,
    Row(
      children: [
        Icon(icon, size: 20, color: _accent(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _more(BuildContext context, String tab, String label) {
    if ((widget.tabIndex?.call(tab) ?? -1) < 0) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => _openTab(tab),
        style: TextButton.styleFrom(
          foregroundColor: _accent(context),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          minimumSize: const Size(0, 40),
          textStyle: const TextStyle(
            fontFamily: 'Google Sans',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.underline,
          ),
        ),
        child: Text(label),
      ),
    );
  }

  /// "Original · 2 copies" from an item's saved format and counts.
  static String _itemDetail(Map<String, dynamic> item) {
    final copies = item['copies'];
    final quantity = item['quantity'];
    return [
      if (_text(item['submission_label']).isNotEmpty)
        _text(item['submission_label']),
      if (quantity is int && quantity > 1) '$quantity pieces',
      if (copies is int && copies > 0)
        '$copies ${copies == 1 ? 'copy' : 'copies'}',
    ].join(' · ');
  }

  List<Widget> _requirements(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(
      fontSize: 13,
      height: 1.45,
      color: colors.onSurfaceVariant,
    );
    final rows = <Widget>[];
    for (final set in _maps(widget.path['requirement_sets'])) {
      for (final group in _maps(set['groups'])) {
        final ways = _maps(group['ways'])
            .map((way) => (way, _maps(way['items'])))
            .where((way) => way.$2.isNotEmpty)
            .toList();
        if (ways.isEmpty) continue;
        final items = ways.first.$2;
        final single = ways.length == 1 && items.length == 1;
        final title = _text(group['title']);
        final required = ways.first.$1['required_count'];
        final details = items.map(_itemDetail).toSet();
        final shared = details.length == 1 ? details.first : '';
        final rule = ways.length > 1
            ? 'Choose one of these options:'
            : (required is int && required < items.length
                  ? 'Bring any $required of these:'
                  : 'Bring all of these:');
        rows.add(
          _box(
            context,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: _accent(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        single
                            ? _text(items.first['name'])
                            : (title.isEmpty ? 'Supporting documents' : title),
                        style: const TextStyle(
                          fontSize: 14.5,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (_text(group['condition_label']).isNotEmpty)
                        Text(_text(group['condition_label']), style: muted),
                      if (single) ...[
                        if (_itemDetail(items.first).isNotEmpty)
                          Text(_itemDetail(items.first), style: muted),
                        if (_text(items.first['instructions']).isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              _text(items.first['instructions']),
                              style: muted,
                            ),
                          ),
                      ] else ...[
                        Text(rule, style: muted),
                        // Said once when every item needs the same format.
                        if (ways.length == 1 && shared.isNotEmpty)
                          Text(shared, style: muted),
                        const SizedBox(height: 2),
                        if (ways.length > 1)
                          for (final way in ways.take(_shownAlternatives))
                            _dot(
                              context,
                              way.$2.map((i) => _text(i['name'])).join(' + '),
                            )
                        else
                          for (final item in items.take(_shownAlternatives))
                            _dot(
                              context,
                              _text(item['name']),
                              detail: shared.isEmpty ? _itemDetail(item) : '',
                            ),
                        if ((ways.length > 1 ? ways.length : items.length) >
                            _shownAlternatives)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '+ ${(ways.length > 1 ? ways.length : items.length) - _shownAlternatives} more accepted. '
                              'See the full checklist.',
                              style: muted,
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (rows.isEmpty) return const [];
    return [...rows, _more(context, 'Requirements', 'Open the full checklist')];
  }

  Widget _dot(BuildContext context, String text, {String detail = ''}) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 8, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: _accent(context),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: text,
                children: [
                  if (detail.isNotEmpty)
                    TextSpan(
                      text: '  ($detail)',
                      style: TextStyle(color: colors.onSurfaceVariant),
                    ),
                ],
              ),
              style: const TextStyle(fontSize: 13.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  /// "₱950" from the fee's saved type and amounts, as the Cost tab shows it.
  static String _amount(Map<String, dynamic> fee) {
    final shown = CatalogFee.fromJson(fee).displayAmount;
    if (shown == 'Varies') return 'Amount varies';
    return shown.replaceAll(RegExp(r'\.00(?!\d)'), '');
  }

  /// How many alternatives a step lists before pointing to the full checklist.
  static const _shownAlternatives = 6;

  List<Widget> _fees(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final muted = TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant);
    final rows = <Widget>[];
    for (final fee in _maps(widget.path['fees'])) {
      final options = _maps(fee['options']);
      final label = _text(fee['label']);
      if (options.isNotEmpty) {
        rows.add(
          _box(
            context,
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (label.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      label,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                Wrap(
                  spacing: 20,
                  runSpacing: 10,
                  children: [
                    for (final option in options)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _amount(option),
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.2,
                              fontWeight: FontWeight.w800,
                              color: _accent(context),
                            ),
                          ),
                          Text(
                            _text(option['label']),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (_text(option['description']).isNotEmpty)
                            Text(_text(option['description']), style: muted),
                        ],
                      ),
                  ],
                ),
                if (_text(fee['notes']).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_text(fee['notes']), style: muted),
                  ),
              ],
            ),
          ),
        );
      } else if (label.isNotEmpty) {
        rows.add(
          _box(
            context,
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label),
                      if (_text(fee['notes']).isNotEmpty)
                        Text(_text(fee['notes']), style: muted),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _amount(fee),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        );
      }
    }
    if (rows.isEmpty) return const [];
    return [...rows, _more(context, 'Cost', 'See all costs')];
  }

  List<Widget> _offices(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final offices = _maps(widget.path['offices']);
    if (offices.isEmpty) return const [];
    return [
      for (final office in offices.take(3))
        _box(
          context,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.location_on_outlined,
                size: 20,
                color: _accent(context),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _text(office['name']),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    if (_text(office['address']).isNotEmpty)
                      Text(
                        _text(office['address']),
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      _more(
        context,
        'Offices',
        offices.length > 3
            ? 'See all ${offices.length} offices and the map'
            : 'See offices and the map',
      ),
    ];
  }
}

/// Full-width button that opens an official page, as in the guide design.
class _LinkButton extends StatelessWidget {
  const _LinkButton({required this.url, required this.label});

  final String url;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => CatalogOfficialLink.open(context, url),
        iconAlignment: IconAlignment.end,
        style: FilledButton.styleFrom(
          backgroundColor: dark ? colors.primary : AppTheme.royalBlue,
          foregroundColor: dark ? AppTheme.navy : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          minimumSize: const Size(0, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(
            fontFamily: 'Google Sans',
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: const Icon(Icons.open_in_new_rounded, size: 17),
        label: Text(label, textAlign: TextAlign.center),
      ),
    );
  }
}
