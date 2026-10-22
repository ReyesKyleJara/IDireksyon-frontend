import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../models/government_id.dart';
import '../office_finder/map_services.dart';
import 'detail_widgets.dart';

/// Uses the existing map and routing services, with this CMS office only.
class GovernmentIdMap extends StatefulWidget {
  final GovernmentOffice office;
  const GovernmentIdMap({super.key, required this.office});
  @override
  State<GovernmentIdMap> createState() => _GovernmentIdMapState();
}

class _GovernmentIdMapState extends State<GovernmentIdMap> {
  final services = OfficeMapServices();
  final controller = MapController();
  OfficeRoute? route;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    services.dispose();
    controller.dispose();
    super.dispose();
  }

  Future<void> directions() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final origin = await services.locate();
      final result = await services.route(
        origin,
        LatLng(widget.office.latitude!, widget.office.longitude!),
      );
      if (!mounted) return;
      setState(() {
        route = result;
      });
      controller.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(result.points),
          padding: const EdgeInsets.all(40),
        ),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          error = 'Directions unavailable. Check your connection and location permission.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final destination = LatLng(
      widget.office.latitude!,
      widget.office.longitude!,
    );
    return Scaffold(
      appBar: AppBar(title: Text(widget.office.name)),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              mapController: controller,
              options: MapOptions(initialCenter: destination, initialZoom: 15),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'app.idireksyon',
                ),
                if (route != null)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: route!.points,
                        color: detailsBlue,
                        strokeWidth: 4,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: destination,
                      child: const Icon(
                        Icons.location_pin,
                        size: 42,
                        color: detailsBlue,
                      ),
                    ),
                  ],
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      onTap: () => openOfficialLink(
                        context,
                        'https://www.openstreetmap.org/copyright',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (error != null) DetailMessage(error!),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FilledButton.icon(
                onPressed: busy ? null : directions,
                icon: const Icon(Icons.directions),
                label: Text(
                  busy ? 'Getting directions…' : 'Directions from my location',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
