import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/widgets/app_motion.dart';
import '../ids/barangay_offices.dart';
import 'map_services.dart';
import 'models/office_model.dart';
import 'office_finder_widgets.dart';
import 'office_map_pins.dart';

/// One office: today's status, hours, the route on a map, and Start Route.
class OfficeDetailsScreen extends StatefulWidget {
  const OfficeDetailsScreen({
    super.key,
    required this.office,
    this.services,
    this.position,
    this.officesLoaded = false,
    this.mapBuilder,
    this.launchDirections,
    this.showRoadEstimates,
    this.onPosition,
    this.now,
  });

  final OfficeModel office;
  final OfficeMapServices? services;

  /// The resident's location, when the list already knows it.
  final LatLng? position;

  /// False when opened straight from another page, so the server's travel
  /// switch has not been read yet.
  final bool officesLoaded;
  final Widget Function(google.GoogleMap)? mapBuilder;
  final Future<bool> Function(Uri)? launchDirections;

  /// Null follows the server's switch (`meta.travel_times` on `GET /offices`),
  /// because travel estimates make billable Routes API calls. Tests set it.
  final bool? showRoadEstimates;

  /// Tells the list about a location found here.
  final ValueChanged<LatLng>? onPosition;

  /// The clock, for tests.
  final DateTime Function()? now;

  @override
  State<OfficeDetailsScreen> createState() => _OfficeDetailsScreenState();
}

class _OfficeDetailsScreenState extends State<OfficeDetailsScreen> {
  late final OfficeMapServices _services;
  google.GoogleMapController? _map;
  OfficeMapPins? _pins;
  LatLng? _position;
  String? _message;
  bool _openingMaps = false;
  RoadEstimate? _road;
  String? _roadError;
  String? _roadMissing;
  bool _roadLoading = false;
  int _roadVersion = 0;
  Timer? _roadTimer;
  Timer? _clock;

  /// A short pause before asking, so a page opened and closed at once costs
  /// no paid call.
  static const _roadPause = Duration(milliseconds: 350);
  static const _routeBlue = Color(0xFF1E66D0);

  OfficeModel get _office => widget.office;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  bool get _travelOn => widget.showRoadEstimates ?? _services.travelTimes;

  LatLng? get _point {
    final location = OfficeModel.usableLocation(
      _office.latitude,
      _office.longitude,
    );
    return location == null
        ? null
        : LatLng(location.latitude, location.longitude);
  }

  double? get _straightMeters {
    final position = _position;
    final point = _point;
    if (position == null || point == null) return null;
    return const Distance().distance(position, point).toDouble();
  }

  bool get _ownBarangay {
    final resident = BarangayOffices.residentBarangayId(
      AuthService.instance.user,
    );
    return resident != null && _office.barangayId == resident;
  }

  @override
  void initState() {
    super.initState();
    _services = widget.services ?? OfficeMapServices();
    _position = widget.position;
    _loadPins();
    if (!widget.officesLoaded && widget.showRoadEstimates == null) {
      _readTravelSwitch();
    }
    if (_position == null) {
      _quietLocate();
    } else {
      _scheduleRoad();
    }
    // "Open Now" and "ends in" stay true while the page is open.
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _roadTimer?.cancel();
    _clock?.cancel();
    _map?.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  Future<void> _loadPins() async {
    try {
      final pins = await OfficeMapPins.load();
      if (mounted) setState(() => _pins = pins);
    } catch (_) {
      // The map keeps Google's standard markers.
    }
  }

  /// The travel switch comes with the office list.
  Future<void> _readTravelSwitch() async {
    try {
      await _services.offices();
    } catch (_) {
      // Without the list, travel time stays off; Start Route still works.
    }
    if (!mounted) return;
    setState(() {});
    _scheduleRoad();
  }

  /// Uses the location only if permission was already given; never prompts.
  Future<void> _quietLocate() async {
    final point = await _services.locateIfAllowed();
    if (!mounted || point == null || _position != null) return;
    _usePosition(point);
    _scheduleRoad();
  }

  void _usePosition(LatLng point) {
    setState(() => _position = point);
    widget.onPosition?.call(point);
    _fitRoute();
  }

  // Travel time ---------------------------------------------------------------

  void _clearRoad() {
    _roadVersion++;
    _roadTimer?.cancel();
    _road = null;
    _roadError = null;
    _roadMissing = null;
    _roadLoading = false;
  }

  /// Asks for the travel estimate once the location is already known. Without
  /// it, the page offers a button, so location is never requested unasked.
  void _scheduleRoad() {
    final origin = _position;
    if (!_travelOn || origin == null || _point == null) return;
    if (_road != null || _roadLoading) return;
    setState(() {
      _clearRoad();
      _roadLoading = true;
    });
    final version = _roadVersion;
    _roadTimer = Timer(_roadPause, () => _fetchRoad(origin, version));
  }

  Future<void> _fetchRoad(LatLng origin, int version) async {
    try {
      final road = await _services.roadEstimate(_office.id, origin);
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _road = road;
        _roadLoading = false;
      });
      _fitRoute();
    } on TravelUnavailable catch (missing) {
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _roadLoading = false;
        _roadMissing = missing.message;
      });
    } catch (error) {
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _roadLoading = false;
        _roadError = error is StateError
            ? error.message.toString()
            : 'Travel time is unavailable right now. Please try again.';
      });
    }
  }

  /// The button: asks for location if needed, then the estimate.
  Future<void> _showTravelTime() async {
    if (_point == null) return;
    setState(() {
      _clearRoad();
      _roadLoading = true;
    });
    final version = _roadVersion;
    LatLng origin;
    try {
      origin = _position ?? await _services.locate();
    } catch (error) {
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _roadLoading = false;
        _roadError = error is StateError
            ? error.message.toString()
            : 'Could not find your location. Please try again.';
      });
      return;
    }
    if (!mounted || version != _roadVersion) return;
    if (_position == null) _usePosition(origin);
    await _fetchRoad(origin, version);
  }

  // Directions ----------------------------------------------------------------

  Future<void> _startRoute() async {
    final destination = _point;
    if (_openingMaps || destination == null) return;
    setState(() {
      _openingMaps = true;
      _message = null;
    });
    final uri = googleMapsDirections(destination, _position);
    var opened = false;
    try {
      opened =
          await (widget.launchDirections?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
    } catch (_) {
      // Handled below, the same as a device that has nothing to open the link.
    }
    if (!mounted) return;
    setState(() {
      _openingMaps = false;
      if (!opened) {
        _message = 'Could not open Google Maps. Install Google Maps or a web browser, then try again.';
      }
    });
  }

  // Map -----------------------------------------------------------------------

  google.LatLng _g(LatLng point) =>
      google.LatLng(point.latitude, point.longitude);

  /// Frames the whole route, or the office and the resident, or the office.
  void _fitRoute() {
    final controller = _map;
    final office = _point;
    if (controller == null || office == null) return;
    final path = _road?.path ?? const <LatLng>[];
    final points = path.length > 1 ? path : [office, ?_position];
    if (points.length == 1) {
      controller.animateCamera(
        google.CameraUpdate.newLatLngZoom(_g(points.first), 15),
      );
      return;
    }
    final latitudes = points.map((p) => p.latitude);
    final longitudes = points.map((p) => p.longitude);
    controller.animateCamera(
      google.CameraUpdate.newLatLngBounds(
        google.LatLngBounds(
          southwest: google.LatLng(
            latitudes.reduce((a, b) => a < b ? a : b) - .0005,
            longitudes.reduce((a, b) => a < b ? a : b) - .0005,
          ),
          northeast: google.LatLng(
            latitudes.reduce((a, b) => a > b ? a : b) + .0005,
            longitudes.reduce((a, b) => a > b ? a : b) + .0005,
          ),
        ),
        40,
      ),
    );
  }

  Set<google.Polyline> get _routeLines {
    final path = _road?.path ?? const <LatLng>[];
    if (path.length < 2) return const {};
    final points = [for (final point in path) _g(point)];
    google.Polyline line(String id, Color color, int width, int z) =>
        google.Polyline(
          polylineId: google.PolylineId(id),
          points: points,
          color: color,
          width: width,
          zIndex: z,
          jointType: google.JointType.round,
          startCap: google.Cap.roundCap,
          endCap: google.Cap.roundCap,
        );
    // A white edge keeps the blue line readable over roads of any colour.
    return {
      line('route-edge', Colors.white, 9, 1),
      line('route', _routeBlue, 6, 2),
    };
  }

  Widget _buildMap(LatLng office) {
    final pins = _pins;
    final map = google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: _g(office),
        zoom: 15,
      ),
      // The page scrolls over the map, so the map itself stays still.
      scrollGesturesEnabled: false,
      zoomGesturesEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      compassEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      onMapCreated: (controller) {
        if (!mounted) {
          controller.dispose();
          return;
        }
        _map = controller;
        _fitRoute();
      },
      polylines: _routeLines,
      markers: {
        google.Marker(
          markerId: google.MarkerId('office-${_office.id}'),
          position: _g(office),
          infoWindow: google.InfoWindow(
            title: _office.name,
            snippet: _office.address,
          ),
          icon:
              pins?.selected ??
              google.BitmapDescriptor.defaultMarkerWithHue(
                google.BitmapDescriptor.hueRed,
              ),
        ),
        if (_position != null)
          google.Marker(
            markerId: const google.MarkerId('current-position'),
            position: _g(_position!),
            anchor: pins == null ? const Offset(.5, 1) : const Offset(.5, .5),
            icon:
                pins?.user ??
                google.BitmapDescriptor.defaultMarkerWithHue(
                  google.BitmapDescriptor.hueBlue,
                ),
            infoWindow: const google.InfoWindow(title: 'Your location'),
          ),
      },
    );
    return widget.mapBuilder?.call(map) ?? map;
  }

  // Page ----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final point = _point;
    return Scaffold(
      backgroundColor: OfficeLook.page(context),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // The title and Back stay put while the page scrolls.
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                  child: _pageTitle(),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 14),
                      point == null ? _noLocationCard() : _routeCard(point),
                      if (_office.records.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _recordsCard(),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pageTitle() => Row(
    children: [
      IconButton(
        tooltip: 'Back',
        onPressed: () => Navigator.maybePop(context),
        icon: const Icon(Icons.arrow_back_rounded),
      ),
      const SizedBox(width: 2),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            'Office Details',
            style: TextStyle(
              fontSize: 26,
              height: 1.2,
              fontWeight: FontWeight.w800,
              color: OfficeLook.ink(context),
            ),
          ),
        ),
      ),
    ],
  );

  Widget _messageBanner() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: OfficeLook.cardBox(context, radius: 14),
        child: Row(
          children: [
            const SizedBox(width: 14),
            Icon(Icons.info_outline_rounded, size: 18, color: colors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  _message!,
                  style: const TextStyle(fontSize: 13.5, height: 1.35),
                ),
              ),
            ),
            IconButton(
              tooltip: 'Dismiss message',
              onPressed: () => setState(() => _message = null),
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) => Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: OfficeLook.cardBox(context),
    child: child,
  );

  /// The office, its status, and four quick facts.
  Widget _summaryCard() {
    final state = _office.openStateAt(_now);
    final agency = _office.agencyName.isNotEmpty
        ? _office.agencyName
        : _office.agency;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _office.name,
                          style: const TextStyle(
                            fontSize: 19,
                            height: 1.25,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (state != null) OfficeStatusPill(state: state),
                      ],
                    ),
                    if (_ownBarangay) ...[
                      const SizedBox(height: 4),
                      YourBarangayTag(office: _office),
                    ],
                    if (agency.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        agency,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    OfficeFact(
                      icon: Icons.location_on_outlined,
                      text: _office.address,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(height: 1, color: OfficeLook.border(context)),
          const SizedBox(height: 14),
          _factsGrid(state),
        ],
      ),
    );
  }

  Widget _factsGrid(OfficeOpenState? state) {
    final week = _office.weeklyHours;
    final today = _office.todayHours(_now);
    final available = switch (today) {
      null => 'Not yet added',
      'Closed' => 'Closed today',
      _ => today,
    };
    final left = state?.minutesLeft;
    final road = _road;
    final meters = _straightMeters;
    final tiles = [
      _fact(
        Icons.calendar_month_outlined,
        'Office Hours',
        week.isEmpty ? 'Not yet added' : week.first.days,
        // The other days follow, so the whole week shows here.
        week.isEmpty
            ? null
            : [
                week.first.hours,
                for (final line in week.skip(1)) '$line',
              ].join('\n'),
      ),
      _fact(
        Icons.schedule_rounded,
        'Available Today',
        available,
        left == null ? null : '(ends in ${OfficeLook.timeLeft(left)})',
      ),
      if (_travelOn && _point != null)
        _fact(
          Icons.directions_car_outlined,
          'Est. Travel Time',
          road != null
              ? OfficeLook.duration(road.seconds)
              : _roadLoading
              ? 'Calculating…'
              : '—',
          road != null ? 'by car' : null,
        )
      else
        _fact(
          Icons.near_me_outlined,
          'Distance',
          meters == null ? '—' : OfficeLook.distance(meters),
          meters == null ? 'Location not shared' : 'straight line',
        ),
      _fact(
        Icons.description_outlined,
        'IDs & Documents',
        _office.records.isEmpty
            ? 'Not yet added'
            : '${_office.records.length} handled here',
        null,
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        // Two columns, or one on very narrow screens and large text.
        final columns = constraints.maxWidth < 280 ? 1 : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 14,
          children: [
            for (final tile in tiles) SizedBox(width: width, child: tile),
          ],
        );
      },
    );
  }

  Widget _fact(IconData icon, String label, String value, String? note) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: OfficeLook.ink(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.3,
                  color: colors.onSurfaceVariant,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14.5,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (note != null)
                Text(
                  note,
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cardTitle(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 20, color: OfficeLook.ink(context)),
      const SizedBox(width: 10),
      Expanded(
        child: Semantics(
          header: true,
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              height: 1.3,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _noLocationCard() => _card(
    child: Row(
      children: [
        Icon(
          Icons.location_off_outlined,
          size: 20,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'Map location isn’t available for this office yet.',
            style: TextStyle(fontSize: 13.5, height: 1.35),
          ),
        ),
      ],
    ),
  );

  Widget _routeCard(LatLng office) {
    final colors = Theme.of(context).colorScheme;
    return _card(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _cardTitle(
              Icons.near_me_outlined,
              'Route to ${_office.name}',
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              height: 210,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildMap(office),
                  Positioned(
                    right: 10,
                    bottom: 10,
                    child: PointerInterceptor(
                      child: Material(
                        color: OfficeLook.card(context),
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          tooltip: 'Show the whole route',
                          onPressed: _fitRoute,
                          icon: Icon(
                            Icons.navigation_rounded,
                            size: 20,
                            color: OfficeLook.ink(context),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _routeNumbers(),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _openingMaps ? null : _startRoute,
            style: FilledButton.styleFrom(
              backgroundColor: OfficeLook.action(context),
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.near_me_rounded, size: 20),
            label: const Text('Start Route'),
          ),
          if (_message != null) _messageBanner(),
          const SizedBox(height: 6),
          Text(
            'Opens Google Maps. Pin may be approximate.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  /// The time and distance boxes, or what to do to get them.
  Widget _routeNumbers() {
    final road = _road;
    final meters = _straightMeters;
    if (road != null) {
      return Semantics(
        label:
            'About ${OfficeLook.duration(road.seconds)} by car, ${OfficeLook.distance(road.meters)}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _numberBoxes([
              (
                Icons.schedule_rounded,
                'Estimated Time',
                OfficeLook.duration(road.seconds),
              ),
              (
                Icons.location_on_outlined,
                'Distance',
                OfficeLook.distance(road.meters),
              ),
            ]),
            const SizedBox(height: 6),
            _smallNote(
              'Estimated without live traffic. Actual time may differ.',
            ),
          ],
        ),
      );
    }
    if (!_travelOn) {
      if (meters == null) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _numberBoxes([
            (
              Icons.location_on_outlined,
              'Distance',
              OfficeLook.distance(meters),
            ),
          ]),
          const SizedBox(height: 6),
          _smallNote('Straight-line distance, not by road.'),
        ],
      );
    }
    return AnimatedSwitcher(
      duration: AppMotion.duration(context, AppMotion.quick),
      child: KeyedSubtree(
        key: ValueKey('$_roadLoading|$_roadMissing|$_roadError'),
        child: _travelPrompt(),
      ),
    );
  }

  Widget _travelPrompt() {
    final colors = Theme.of(context).colorScheme;
    Widget box(List<Widget> children) => Container(
      key: const ValueKey('office-travel-card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: OfficeLook.tint(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
    if (_roadLoading) {
      return box(const [
        Row(
          children: [
            SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(child: Text('Calculating travel time…')),
          ],
        ),
      ]);
    }
    final missing = _roadMissing;
    if (missing != null) {
      return box([
        Text(
          '$missing Google Maps may still suggest a way.',
          style: const TextStyle(fontSize: 13.5, height: 1.35),
        ),
      ]);
    }
    final error = _roadError;
    return box([
      Text(
        error ?? 'How long is the drive?',
        style: const TextStyle(
          fontSize: 14,
          height: 1.3,
          fontWeight: FontWeight.w700,
        ),
      ),
      if (error == null && _position == null)
        Text(
          'Uses your current location. IDireksyon does not save it.',
          style: TextStyle(fontSize: 12.5, color: colors.onSurfaceVariant),
        ),
      const SizedBox(height: 10),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: _showTravelTime,
          style: OutlinedButton.styleFrom(
            foregroundColor: OfficeLook.ink(context),
            side: BorderSide(color: OfficeLook.border(context)),
            backgroundColor: OfficeLook.card(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(11),
            ),
          ),
          icon: Icon(
            error != null ? Icons.refresh_rounded : Icons.near_me_rounded,
            size: 17,
          ),
          label: Text(error != null ? 'Try again' : 'Show travel time'),
        ),
      ),
    ]);
  }

  Widget _numberBoxes(List<(IconData, String, String)> items) => Container(
    decoration: BoxDecoration(
      color: OfficeLook.tint(context),
      borderRadius: BorderRadius.circular(12),
    ),
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: IntrinsicHeight(
      child: Row(
        children: [
          for (final (index, (icon, label, value)) in items.indexed) ...[
            if (index > 0)
              VerticalDivider(width: 1, color: OfficeLook.border(context)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Icon(icon, size: 22, color: OfficeLook.ink(context)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          Text(
                            value,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _smallNote(String text) => Text(
    text,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 12,
      height: 1.35,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _recordsCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _cardTitle(Icons.description_outlined, 'IDs and documents'),
        const SizedBox(height: 10),
        for (final record in _office.records)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OfficeFact(
              icon: Icons.check_circle_outline_rounded,
              text: record,
              strong: true,
            ),
          ),
      ],
    ),
  );
}
