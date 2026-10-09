import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';

import 'id_details_screen.dart';
import '../../models/government_id.dart';
import '../../services/api_service.dart';

class IdsScreen extends StatefulWidget {
  final Future<List<GovernmentIdDetails>> Function()? loadIds;
  final Future<GovernmentIdDetails> Function(int)? loadDetail;
  const IdsScreen({super.key, this.loadIds, this.loadDetail});

  @override
  State<IdsScreen> createState() => _IdsScreenState();
}

class _IdsScreenState extends State<IdsScreen> {
  late Future<List<GovernmentIdDetails>> _ids;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _ids = _load();
  }

  Future<List<GovernmentIdDetails>> _load() =>
      widget.loadIds?.call() ?? ApiService.getGovernmentIds();

  static const primaryBlue = Color(0xFF174B85);

  void _open(BuildContext context, GovernmentIdDetails record) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IdDetailsScreen(idName: record.name, governmentId: record.id, loadDetail: widget.loadDetail)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<GovernmentIdDetails>>(
      future: _ids,
      builder: (context, snapshot) {
        return _directory(context, snapshot.data ?? [],
          loading: snapshot.connectionState != ConnectionState.done,
          failed: snapshot.hasError,
        );
      },
    );
  }

  Widget _directory(BuildContext context, List<GovernmentIdDetails> records,
      {required bool loading, required bool failed}) {
    final query = _search.toLowerCase().trim();
    final visible = records.where((record) =>
      record.name.toLowerCase().contains(query) ||
      (record.issuedBy ?? '').toLowerCase().contains(query)).toList();
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final background = dark ? colors.surface : const Color(0xFFFCFCF8);
    return ColoredBox(
      color: background,
      child: SafeArea(
        child: ListView.builder(
          key: const PageStorageKey('id-directory-list'),
          padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
          itemCount: 1 + (loading || failed ? 0 : visible.length),
          itemBuilder: (context, index) {
            if (index > 0) return _idCard(context, visible[index - 1], index - 1);
            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('ID Directory', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: colors.onSurface)),
              const SizedBox(height: 5),
              Text('Browse supported government IDs\nand application guides.',
                style: TextStyle(fontSize: 13, height: 1.45, color: colors.onSurfaceVariant)),
              const SizedBox(height: 18),
              TextField(
                onChanged: (value) => setState(() { _search = value; }),
                decoration: InputDecoration(
                  hintText: 'Search IDs or Agencies',
                  hintStyle: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
                  prefixIcon: Icon(Icons.search_rounded, size: 19, color: colors.onSurfaceVariant),
                  filled: true,
                  fillColor: dark ? colors.surfaceContainer : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                    borderSide: BorderSide(color: colors.outlineVariant)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(9),
                    borderSide: const BorderSide(color: primaryBlue, width: 1.5)),
                ),
              ),
              if (loading) ...[
                const SizedBox(height: 24),
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 12),
                Text('Loading government IDs…', style: TextStyle(fontSize: 13, color: colors.onSurfaceVariant)),
              ] else if (failed) ...[
                const SizedBox(height: 24),
                const Text('Could not load the ID directory.'),
                TextButton(onPressed: () {
                  final request = _load();
                  setState(() { _ids = request; });
                }, child: const Text('Retry')),
              ] else ...[
                if (visible.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const Text('Featured IDs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  LayoutBuilder(builder: (context, constraints) {
                    final width = ((constraints.maxWidth - 24) / 4).clamp(88.0, 150.0).toDouble();
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        for (var i = 0; i < visible.take(4).length; i++)
                          _featured(context, visible[i], i, width),
                      ]),
                    );
                  }),
                ],
                const SizedBox(height: 24),
                const Text('All IDs', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                if (visible.isEmpty)
                  Padding(padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(records.isEmpty ? 'No Government IDs are available yet.' : 'No matching IDs.')),
              ],
            ]);
          },
        ),
      ),
    );
  }

  static const _pastels = [Color(0xFFCDDEFB), Color(0xFFF7DDD7), Color(0xFFE0EED1), Color(0xFFD4DFF7)];

  Widget _featured(BuildContext context, GovernmentIdDetails record, int index, double width) {
    final colors = Theme.of(context).colorScheme;
    final tint = _pastels[index % _pastels.length];
    final dark = colors.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: SizedBox(width: width, child: Material(
        color: dark ? Color.alphaBlend(tint.withValues(alpha: 0.15), colors.surfaceContainer) : tint,
        borderRadius: BorderRadius.circular(12), clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: () => _open(context, record),
          child: Padding(padding: const EdgeInsets.fromLTRB(8, 12, 8, 12), child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 68, child: Center(child: _DirectoryArt(name: record.name))),
              const SizedBox(height: 10),
              Text(record.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, height: 1.25, fontWeight: FontWeight.w700, color: colors.onSurface)),
              if (record.issuedBy != null) ...[
                const SizedBox(height: 3),
                Text(record.issuedBy!, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9, height: 1.25, color: colors.onSurfaceVariant)),
              ],
            ],
          )),
        ),
      )),
    );
  }

  Widget _idCard(BuildContext context, GovernmentIdDetails record, int index) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final tint = _pastels[index % _pastels.length];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: dark ? colors.surfaceContainer : Colors.white,
        elevation: dark ? 0 : 1,
        shadowColor: const Color(0x140C2545),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.45))),
        clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: () => _open(context, record),
          child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
            Container(
              width: 72, height: 104,
              decoration: BoxDecoration(
                color: dark ? tint.withValues(alpha: 0.12) : tint.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: _DirectoryArt(name: record.name),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(record.name, style: TextStyle(fontSize: 15, height: 1.3,
                fontWeight: FontWeight.w800, color: colors.onSurface)),
              if (record.description != null) ...[
                const SizedBox(height: 4),
                Text(record.description!, maxLines: 3, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, height: 1.4, color: colors.onSurfaceVariant)),
              ],
              if (record.issuedBy != null) ...[
                const SizedBox(height: 8),
                Text(record.issuedBy!, style: TextStyle(fontSize: 10, height: 1.3,
                  fontWeight: FontWeight.w500, color: colors.onSurfaceVariant)),
              ],
            ])),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 20, color: colors.onSurfaceVariant),
          ])),
        ),
      ),
    );
  }


}

// Decorative illustrations only; names never determine requirements or API IDs.
class _DirectoryArt extends StatelessWidget {
  const _DirectoryArt({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final passport = name.toLowerCase().contains('passport');
    return ExcludeSemantics(child: Transform.rotate(
      angle: passport ? 0.07 : -0.06,
      child: Container(
        width: passport ? 42 : 58, height: passport ? 58 : 40,
        decoration: BoxDecoration(
          color: passport ? const Color(0xFF82363E) : const Color(0xFFF8FBFF),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: passport ? const Color(0xFF632731) : const Color(0xFFB7C8E4)),
          boxShadow: const [BoxShadow(color: Color(0x200C2545), blurRadius: 5, offset: Offset(1, 3))],
        ),
        child: passport
            ? const Icon(Icons.public_rounded, color: Color(0xFFDDBA76), size: 25)
            : const Padding(padding: EdgeInsets.all(5), child: Row(children: [
                Icon(Icons.person_rounded, color: Color(0xFF527BAE), size: 22),
                SizedBox(width: 3),
                Expanded(child: Icon(Icons.notes_rounded, color: Color(0xFF8EACD1), size: 18)),
              ])),
      ),
    ));
  }
}
