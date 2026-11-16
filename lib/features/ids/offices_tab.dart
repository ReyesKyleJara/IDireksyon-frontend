import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../office_finder/models/office_model.dart';

/// Uses only the offices already loaded for this ID/document.
class OfficesTab extends StatefulWidget {
  const OfficesTab({
    super.key,
    required this.offices,
    required this.recordType,
    this.mapBuilder,
    this.launchDirections,
  });

  final List<Map<String, dynamic>> offices;
  final String recordType;
  final Widget Function(google.GoogleMap)? mapBuilder;
  final Future<bool> Function(Uri)? launchDirections;

  @override
  State<OfficesTab> createState() => _OfficesTabState();
}

/// Google Maps styling for dark mode (same blues as the app's dark theme).
const _darkMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#1c2b3d"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#b4bdc9"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#111b28"}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#2c4058"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#22344a"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#1d3a3a"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#2c4058"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#172536"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#3a5578"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#24344a"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#0b1624"}]}
]
''';

class _OfficesTabState extends State<OfficesTab> {
  final _search = TextEditingController();
  google.GoogleMapController? _map;
  int? _selected;

  @override
  void didUpdateWidget(covariant OfficesTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    final selected = _selected;
    if (selected == null) return;
    final id = oldWidget.offices[selected]['id'];
    final index = widget.offices.indexWhere((office) => office['id'] == id);
    _selected = index < 0 ? null : index;
  }

  @override
  void dispose() {
    _search.dispose();
    _map?.dispose();
    super.dispose();
  }

  google.LatLng? _point(Map<String, dynamic> office) {
    final location = OfficeModel.usableLocation(
      office['latitude'],
      office['longitude'],
    );
    return location == null
        ? null
        : google.LatLng(location.latitude, location.longitude);
  }

  String _text(dynamic value) => value is String ? value.trim() : '';

  String _address(Map<String, dynamic> office) {
    final address = _text(office['address']);
    final city = _text(office['municipality']);
    final province = _text(office['province']);
    final parts = [
      if (address.isNotEmpty) address,
      if (city.isNotEmpty &&
          !address.toLowerCase().contains(city.toLowerCase()))
        city,
      if (province.isNotEmpty &&
          !address.toLowerCase().contains(province.toLowerCase()))
        province,
    ];
    return parts.isEmpty ? 'Address not yet added.' : parts.join(', ');
  }

  List<String> _hours(Map<String, dynamic> office) => [
    for (final line in OfficeModel.weeklyLines(
      OfficeModel.scheduleFrom(office['schedules']),
    ))
      '$line',
  ];

  void _select(int index) {
    setState(() => _selected = index);
    final point = _point(widget.offices[index]);
    if (point != null) {
      _map?.animateCamera(google.CameraUpdate.newLatLngZoom(point, 15));
    }
  }

  void _fit(List<google.LatLng> points) {
    if (points.length == 1) {
      _map?.moveCamera(google.CameraUpdate.newLatLngZoom(points.first, 14));
      return;
    }
    final lats = points.map((point) => point.latitude);
    final lngs = points.map((point) => point.longitude);
    _map?.moveCamera(
      google.CameraUpdate.newLatLngBounds(
        google.LatLngBounds(
          southwest: google.LatLng(
            lats.reduce((a, b) => a < b ? a : b) - .0001,
            lngs.reduce((a, b) => a < b ? a : b) - .0001,
          ),
          northeast: google.LatLng(
            lats.reduce((a, b) => a > b ? a : b) + .0001,
            lngs.reduce((a, b) => a > b ? a : b) + .0001,
          ),
        ),
        36,
      ),
    );
  }

  Future<void> _directions(google.LatLng point) async {
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${point.latitude},${point.longitude}',
    });
    try {
      final opened =
          await (widget.launchDirections?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps. Please try again.'),
        ),
      );
    }
  }

  /// For offices without a saved map location: a Google Maps search by name
  /// and address. It is labelled a search, never directions.
  Future<void> _searchOnMaps(Map<String, dynamic> office) async {
    final uri = Uri.https('www.google.com', '/maps/search/', {
      'api': '1',
      'query': [
        _text(office['name']),
        _address(office),
      ].where((part) => part.isNotEmpty).join(', '),
    });
    try {
      final opened =
          await (widget.launchDirections?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (opened || !mounted) return;
    } catch (_) {
      if (!mounted) return;
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not open Google Maps. Please try again.'),
        ),
      );
    }
  }

  /// Rounded square behind an icon, as on the Overview's key facts.
  Widget _tile(BuildContext context, IconData icon, {bool strong = false}) {
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? colors.primary : AppTheme.primaryBlue;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: strong
            ? accent
            : (dark ? colors.surfaceContainerHigh : const Color(0xFFE9EEF5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        icon,
        size: 22,
        color: strong ? (dark ? AppTheme.navy : Colors.white) : accent,
      ),
    );
  }

  Widget _office(int index) {
    final office = widget.offices[index];
    final point = _point(office);
    final hours = _hours(office);
    final selected = _selected == index;
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? colors.primary : AppTheme.primaryBlue;
    final muted = colors.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: ValueKey('linked-office-$index-${office['id']}'),
        color: selected
            ? (dark ? colors.surfaceContainerHigh : const Color(0xFFEAF2FC))
            : (dark ? colors.surfaceContainer : Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected
                ? accent
                : colors.outlineVariant.withValues(alpha: .4),
            width: selected ? 1.5 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: point == null ? null : () => _select(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _tile(
                      context,
                      selected
                          ? Icons.location_on_rounded
                          : Icons.location_on_outlined,
                      strong: selected,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _text(office['name']),
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: colors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _address(office),
                            style: TextStyle(
                              color: muted,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.check_circle, color: accent, size: 20),
                    ],
                  ],
                ),
                if (hours.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    decoration: BoxDecoration(
                      color: dark
                          ? colors.surfaceContainerHighest.withValues(alpha: .5)
                          : AppTheme.pageBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final line in hours)
                                Text(
                                  line,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.5,
                                    color: colors.onSurface,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                if (point != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _directions(point),
                      style: FilledButton.styleFrom(
                        backgroundColor: dark ? colors.primary : AppTheme.navy,
                        foregroundColor: dark ? AppTheme.navy : Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 46),
                        textStyle: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      icon: const Icon(Icons.directions_rounded, size: 18),
                      label: const Text('Get Directions'),
                    ),
                  )
                else
                  // No saved map location: offer a search, never directions.
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _searchOnMaps(office),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: accent,
                        side: BorderSide(color: accent.withValues(alpha: .6)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: const Size(0, 46),
                        textStyle: const TextStyle(
                          fontFamily: 'Google Sans',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Search on Google Maps'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final located = <int, google.LatLng>{
      for (var i = 0; i < widget.offices.length; i++)
        i: ?_point(widget.offices[i]),
    };
    final showSearch = widget.offices.length >= 4;
    final query = showSearch ? _search.text.trim().toLowerCase() : '';
    final visible = [
      for (var i = 0; i < widget.offices.length; i++)
        if (['name', 'municipality', 'province', 'city', 'address']
            .map((field) => _text(widget.offices[i][field]))
            .join(' ')
            .toLowerCase()
            .contains(query))
          i,
    ];
    final colors = Theme.of(context).colorScheme;
    final dark = colors.brightness == Brightness.dark;
    final accent = dark ? colors.primary : AppTheme.primaryBlue;
    final cardColor = dark ? colors.surfaceContainer : Colors.white;
    final border = colors.outlineVariant.withValues(alpha: .4);
    return ColoredBox(
      // Follows the app theme: dark in dark mode, like the other tabs.
      color: Theme.of(context).scaffoldBackgroundColor,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final mapHeight = (constraints.maxHeight * .48).clamp(160.0, 260.0);
          return ListView(
            key: const PageStorageKey('record-offices-scroll'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              if (widget.offices.isEmpty)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      _tile(context, Icons.location_off_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          widget.recordType == 'document'
                              ? 'No offices have been added for this document yet.'
                              : 'No offices have been added for this ID yet.',
                          style: TextStyle(color: colors.onSurface),
                        ),
                      ),
                    ],
                  ),
                )
              else ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Offices near Santa Maria',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.3,
                          fontWeight: FontWeight.w700,
                          color: colors.onSurface,
                        ),
                      ),
                      // The list is what the team has added so far, not every
                      // branch that exists.
                      Text(
                        '${widget.offices.length} listed so far. Other '
                        'branches may also serve you.'
                        '${located.isNotEmpty ? ' Tap an office to see it on the map.' : ''}',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.45,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (showSearch) ...[
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: TextStyle(fontSize: 14, color: colors.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search offices',
                      hintStyle: TextStyle(color: colors.onSurfaceVariant),
                      prefixIcon: Icon(Icons.search, color: accent, size: 21),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear office search',
                              icon: Icon(Icons.close, size: 18, color: accent),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: cardColor,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (located.isNotEmpty) ...[
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      height: mapHeight,
                      child: Builder(
                        builder: (_) {
                          final map = google.GoogleMap(
                            // A dark map in dark mode, so it does not glare.
                            style: dark ? _darkMapStyle : null,
                            initialCameraPosition: google.CameraPosition(
                              target: located.values.first,
                              zoom: 13,
                            ),
                            onMapCreated: (controller) {
                              if (!mounted) {
                                controller.dispose();
                                return;
                              }
                              _map = controller;
                              _fit(located.values.toList());
                            },
                            // One finger scrolls the tab; two fingers move the embedded map.
                            gestureRecognizers: {
                              Factory<ScaleGestureRecognizer>(
                                () => ScaleGestureRecognizer(),
                              ),
                            },
                            zoomControlsEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            compassEnabled: false,
                            rotateGesturesEnabled: false,
                            markers: {
                              for (final entry in located.entries)
                                google.Marker(
                                  markerId: google.MarkerId(
                                    'office-${entry.key}-${widget.offices[entry.key]['id']}',
                                  ),
                                  position: entry.value,
                                  infoWindow: google.InfoWindow(
                                    title: _text(
                                      widget.offices[entry.key]['name'],
                                    ),
                                    snippet: _address(
                                      widget.offices[entry.key],
                                    ),
                                  ),
                                  icon:
                                      google
                                          .BitmapDescriptor.defaultMarkerWithHue(
                                        _selected == entry.key
                                            ? google.BitmapDescriptor.hueYellow
                                            : google.BitmapDescriptor.hueAzure,
                                      ),
                                  onTap: () => _select(entry.key),
                                ),
                            },
                          );
                          return widget.mapBuilder?.call(map) ?? map;
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // No office has a saved map location yet.
                  Container(
                    key: const ValueKey('offices-no-map'),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _tile(context, Icons.map_outlined),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Map not available yet',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: colors.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'These offices do not have a map location yet. '
                                'You can still search for them on Google Maps.',
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.45,
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No offices match your search.',
                      style: TextStyle(color: colors.onSurface),
                    ),
                  )
                else
                  for (final index in visible) _office(index),
              ],
            ],
          );
        },
      ),
    );
  }
}
