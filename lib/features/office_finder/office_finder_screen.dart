import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'directions_screen.dart';
import 'models/office_model.dart';

class SearchLocationResult {
  final String name;
  final String address;
  final double latitude;
  final double longitude;

  const SearchLocationResult({
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
  });
}

class OfficeFinderScreen extends StatefulWidget {
  const OfficeFinderScreen({super.key});

  @override
  State<OfficeFinderScreen> createState() => _OfficeFinderScreenState();
}

class _OfficeFinderScreenState extends State<OfficeFinderScreen> {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBlue = Color(0xFFF0F5FA);
  static const LatLng _defaultCenter = LatLng(14.8527, 120.8160);

  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();

  final List<OfficeModel> offices = const [
    OfficeModel(
      id: '1',
      name: 'DFA Consular Office Malolos',
      address: 'SM City Malolos, McArthur Highway',
      distance: '9.1 km',
      operatingHours: 'Today: 9:00 AM - 5:00 PM',
      serviceTag: 'Passport Services',
      latitude: 14.8527,
      longitude: 120.8160,
    ),
    OfficeModel(
      id: '2',
      name: 'SSS Santa Maria Branch',
      address: 'Poblacion, Santa Maria, Bulacan',
      distance: '2.4 km',
      operatingHours: 'Today: 8:00 AM - 5:00 PM',
      serviceTag: 'SS ID / UMID',
      latitude: 14.8188,
      longitude: 120.9578,
    ),
    OfficeModel(
      id: '3',
      name: 'Bulacan Provincial Capitol',
      address: 'Malolos, Bulacan',
      distance: '11.4 km',
      operatingHours: 'Today: 8:00 AM - 5:00 PM',
      serviceTag: 'Government Service',
      latitude: 14.8433,
      longitude: 120.8120,
    ),
  ];

  List<OfficeModel> _filteredOffices = [];
  List<SearchLocationResult> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filteredOffices = List<OfficeModel>.from(offices);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchLocations(String query) async {
    final queryText = query.trim();
    if (queryText.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    if (queryText.length < 2) {
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=5&q=${Uri.encodeQueryComponent(queryText)}',
      );

      final response = await http.get(
        uri,
        headers: {
          'User-Agent': 'IDireksyon/1.0 (idireksyon.app)',
          'Accept-Language': 'en',
        },
      );

      if (!mounted) {
        return;
      }

      if (response.statusCode == 200) {
        final List<dynamic> body = jsonDecode(response.body) as List<dynamic>;
        final results = body.map<SearchLocationResult>((item) {
          final map = item as Map<String, dynamic>;
          return SearchLocationResult(
            name: (map['display_name'] ?? queryText).toString(),
            address: (map['display_name'] ?? '').toString(),
            latitude:
                double.tryParse(map['lat']?.toString() ?? '') ??
                _defaultCenter.latitude,
            longitude:
                double.tryParse(map['lon']?.toString() ?? '') ??
                _defaultCenter.longitude,
          );
        }).toList();

        setState(() {
          _searchResults = results;
        });

        if (results.isNotEmpty) {
          final first = results.first;
          _mapController.move(LatLng(first.latitude, first.longitude), 13);
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _searchResults = [];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _applyOfficeFilter(String value) {
    final query = value.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredOffices = List<OfficeModel>.from(offices);
      } else {
        _filteredOffices = offices.where((office) {
          final haystack = [
            office.name,
            office.address,
            office.serviceTag,
          ].join(' ').toLowerCase();

          return haystack.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final markers = <Marker>[];
    for (final office in _filteredOffices) {
      markers.add(
        Marker(
          point: LatLng(office.latitude, office.longitude),
          width: 34,
          height: 34,
          child: const _MapMarker(color: primaryBlue),
        ),
      );
    }

    for (final result in _searchResults) {
      markers.add(
        Marker(
          point: LatLng(result.latitude, result.longitude),
          width: 34,
          height: 34,
          child: const _MapMarker(color: Color(0xFF22C55E)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Office Finder',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'Find government offices, buildings, and places.',
              style: TextStyle(
                fontSize: 12,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildSearchAndLocation(context, isDark),
          Container(
            height: 240,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: FlutterMap(
                mapController: _mapController,
                options: const MapOptions(
                  initialCenter: _defaultCenter,
                  initialZoom: 11.5,
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Base/MapServer/tile/{z}/{y}/{x}'
                        : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Base/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.bayanid.idireksyon',
                  ),
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Dark_Gray_Reference/MapServer/tile/{z}/{y}/{x}'
                        : 'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_Light_Gray_Reference/MapServer/tile/{z}/{y}/{x}',
                    userAgentPackageName: 'com.bayanid.idireksyon',
                  ),
                  MarkerLayer(markers: markers),
                  const RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution(
                        'Esri, HERE, Garmin, (c) OpenStreetMap contributors',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_searchResults.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.12)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search results',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._searchResults.take(3).map((result) {
                    return InkWell(
                      onTap: () {
                        _mapController.move(
                          LatLng(result.latitude, result.longitude),
                          15,
                        );
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 16,
                              color: primaryBlue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                result.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: colorScheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          _buildResultsHeader(colorScheme),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _filteredOffices.length,
              itemBuilder: (context, index) {
                final office = _filteredOffices[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _buildOfficeCard(context, office, isDark),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndLocation(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: primaryBlue.withValues(alpha: 0.04),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                _applyOfficeFilter(value);
                _searchLocations(value);
              },
              decoration: InputDecoration(
                hintText: 'Search government offices or places',
                hintStyle: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: Colors.grey,
                ),
                suffixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : const Icon(Icons.my_location_rounded, color: Colors.grey),
                filled: true,
                fillColor: isDark
                    ? colorScheme.surfaceContainerHighest
                    : Colors.white,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              _mapController.move(_defaultCenter, 11.5);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? primaryBlue.withValues(alpha: 0.15) : softBlue,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: primaryBlue.withValues(alpha: 0.1)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.near_me_rounded, size: 16, color: primaryBlue),
                  SizedBox(width: 8),
                  Text(
                    'Use default city view',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Offices found near you',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            '${_filteredOffices.length} results',
            style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeCard(
    BuildContext context,
    OfficeModel office,
    bool isDark,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Material(
        color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            _mapController.move(LatLng(office.latitude, office.longitude), 15);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DirectionsScreen(office: office),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isDark
                        ? primaryBlue.withValues(alpha: 0.15)
                        : softBlue,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.account_balance_rounded,
                    color: primaryBlue,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        office.name,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            size: 12,
                            color: primaryBlue,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            office.distance,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: primaryBlue,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              office.address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            office.operatingHours,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? primaryBlue.withValues(alpha: 0.15)
                              : softBlue,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          office.serviceTag,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: primaryBlue,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MapMarker extends StatelessWidget {
  final Color color;

  const _MapMarker({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: const Border.fromBorderSide(
              BorderSide(color: Colors.white, width: 2),
            ),
          ),
        ),
      ),
    );
  }
}
