import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'models/office_model.dart';

class DirectionsScreen extends StatefulWidget {
  final OfficeModel office;

  const DirectionsScreen({super.key, required this.office});

  @override
  State<DirectionsScreen> createState() => _DirectionsScreenState();
}

class _DirectionsScreenState extends State<DirectionsScreen> {
  static const Color primaryBlue = Color(0xFF1E3A8A);
  static const Color softBlue = Color(0xFFF0F5FA);
  static const Color textGrey = Color(0xFF4A5568);

  final MapController _mapController = MapController();
  Position? _userPosition;
  bool _isLoadingLocation = false;

  Future<void> _openGoogleMaps() async {
    final Uri url = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=${widget.office.latitude},${widget.office.longitude}',
    );
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch Google Maps');
    }
  }

  Future<void> _startDirections() async {
    setState(() => _isLoadingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showLocationMessage('Turn on location services to get directions.');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _showLocationMessage(
          'Location permission is needed to start directions.',
        );
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _showLocationMessage(
          'Location permission is blocked. Enable it in Settings to continue.',
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (!mounted) return;

      setState(() => _userPosition = position);
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds(
            LatLng(position.latitude, position.longitude),
            LatLng(widget.office.latitude, widget.office.longitude),
          ),
          padding: const EdgeInsets.all(48),
        ),
      );

      final Uri url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1'
        '&origin=${position.latitude},${position.longitude}'
        '&destination=${widget.office.latitude},${widget.office.longitude}'
        '&travelmode=driving',
      );
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        _showLocationMessage('Could not open Maps.');
      }
    } catch (error) {
      if (mounted) {
        _showLocationMessage(
          'Could not determine your location. Please try again.',
        );
      }
      debugPrint('Could not get current location: $error');
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  void _showLocationMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  double? get _distanceInKilometers {
    final position = _userPosition;
    if (position == null) return null;
    return Geolocator.distanceBetween(
          position.latitude,
          position.longitude,
          widget.office.latitude,
          widget.office.longitude,
        ) /
        1000;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final officePoint = LatLng(widget.office.latitude, widget.office.longitude);
    final userPosition = _userPosition;
    final markers = <Marker>[
      Marker(
        point: officePoint,
        width: 34,
        height: 34,
        child: const _MapMarker(color: primaryBlue),
      ),
      if (userPosition != null)
        Marker(
          point: LatLng(userPosition.latitude, userPosition.longitude),
          width: 34,
          height: 34,
          child: const _MapMarker(color: Color(0xFF22C55E)),
        ),
    ];

    return Scaffold(
      backgroundColor: isDark ? colorScheme.surface : Colors.white,
      appBar: AppBar(
        backgroundColor: isDark ? colorScheme.surface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Directions',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              'Route to selected office',
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
          _buildDestinationCard(context, isDark),
          Container(
            height: 260,
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
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
              borderRadius: BorderRadius.circular(20),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: officePoint,
                  initialZoom: 14.5,
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
                  if (userPosition != null)
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: [
                            LatLng(
                              userPosition.latitude,
                              userPosition.longitude,
                            ),
                            officePoint,
                          ],
                          color: primaryBlue,
                          strokeWidth: 4,
                        ),
                      ],
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
          _buildActionSheet(context, isDark),
        ],
      ),
    );
  }

  Widget _buildDestinationCard(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? colorScheme.surfaceContainerHighest : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? Colors.transparent : Colors.grey.shade200,
          ),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: softBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_balance_rounded,
                size: 20,
                color: primaryBlue,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.office.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.office.operatingHours,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionSheet(BuildContext context, bool isDark) {
    final colorScheme = Theme.of(context).colorScheme;
    final distance = _distanceInKilometers;
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      decoration: BoxDecoration(
        color: isDark ? colorScheme.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTripStat(
                Icons.schedule_rounded,
                'Est. Time',
                'Varies by traffic',
                context,
              ),
              Container(width: 1, height: 40, color: Colors.grey.shade200),
              _buildTripStat(
                Icons.route_rounded,
                distance == null
                    ? widget.office.distance
                    : '${distance.toStringAsFixed(1)} km',
                'Distance',
                context,
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _isLoadingLocation ? null : _startDirections,
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text(
                _isLoadingLocation ? 'Locating you...' : 'Start Directions',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _openGoogleMaps,
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Open in Maps',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: textGrey,
                side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStat(
    IconData icon,
    String primaryText,
    String secondaryText,
    BuildContext context,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        const SizedBox(width: 4),
        Icon(icon, size: 28, color: primaryBlue),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              primaryText,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: colorScheme.onSurface,
              ),
            ),
            Text(
              secondaryText,
              style: TextStyle(
                fontSize: 11,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
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
        color: color.withValues(alpha: 0.18),
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
