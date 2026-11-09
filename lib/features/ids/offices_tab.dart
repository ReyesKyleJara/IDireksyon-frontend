import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';

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
    final lat = double.tryParse('${office['latitude']}');
    final lng = double.tryParse('${office['longitude']}');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat.abs() > 90 ||
        lng.abs() > 180) {
      return null;
    }
    return google.LatLng(lat, lng);
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

  List<String> _hours(Map<String, dynamic> office) {
    const days = [
      'Sunday',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
    ];
    final schedules = office['schedules'];
    if (schedules is! List) return [];
    return [
      for (final schedule in schedules.whereType<Map>())
        if (['open', 'closed'].contains(schedule['status']))
          (() {
            final day = int.tryParse('${schedule['day_of_week']}');
            final label = day != null && day >= 0 && day < 7
                ? days[day]
                : 'Day';
            final intervals = schedule['intervals'];
            final hours = intervals is List
                ? intervals
                      .whereType<Map>()
                      .map((row) => '${row['opens_at']}–${row['closes_at']}')
                      .join(', ')
                : '';
            return '$label: ${schedule['status']}${hours.isEmpty ? '' : ' $hours'}';
          })(),
    ];
  }

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

  Widget _office(int index) {
    final office = widget.offices[index];
    final point = _point(office);
    final hours = _hours(office);
    final selected = _selected == index;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        key: ValueKey('linked-office-$index-${office['id']}'),
        color: selected ? const Color(0xFFEAF2FC) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppTheme.primaryBlue : const Color(0xFFE0EAF5),
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
                    const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.primaryBlue,
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _text(office['name']),
                        style: const TextStyle(
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.navy,
                        ),
                      ),
                    ),
                    if (selected)
                      const Icon(
                        Icons.check_circle,
                        color: AppTheme.primaryBlue,
                        size: 18,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _address(office),
                  style: const TextStyle(
                    color: Color(0xFF42556C),
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                if (hours.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        size: 16,
                        color: AppTheme.primaryBlue,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final line in hours)
                              Text(
                                line,
                                style: const TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: Color(0xFF42556C),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if (point != null) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton.icon(
                      onPressed: () => _directions(point),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.royalBlue,
                        side: const BorderSide(color: AppTheme.royalBlue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        minimumSize: const Size(0, 44),
                        textStyle: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      icon: const Icon(Icons.directions_outlined, size: 17),
                      label: const Text('Get Directions'),
                    ),
                  ),
                ],
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
    return ColoredBox(
      color: Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : AppTheme.pageBackground,
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
                    color: AppTheme.pageBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.recordType == 'document'
                        ? 'No offices have been added for this document yet.'
                        : 'No offices have been added for this ID yet.',
                    style: const TextStyle(color: AppTheme.navy),
                  ),
                )
              else ...[
                if (showSearch) ...[
                  TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(fontSize: 14, color: AppTheme.navy),
                    decoration: InputDecoration(
                      hintText: 'Search offices',
                      hintStyle: const TextStyle(color: Color(0xFF6D8098)),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: AppTheme.primaryBlue,
                        size: 21,
                      ),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear office search',
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: AppTheme.primaryBlue,
                              ),
                              onPressed: () {
                                _search.clear();
                                setState(() {});
                              },
                            ),
                      filled: true,
                      fillColor: AppTheme.pageBackground,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE0EAF5)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                if (located.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: mapHeight,
                      child: Builder(
                        builder: (_) {
                          final map = google.GoogleMap(
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
                ],
                if (visible.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text(
                      'No offices match your search.',
                      style: TextStyle(color: AppTheme.navy),
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
