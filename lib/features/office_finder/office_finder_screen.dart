import 'dart:async';

import '../../core/widgets/app_motion.dart';
import '../../core/widgets/frosted.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/auth/auth_service.dart';
import '../../core/theme/app_theme.dart';
import '../ids/barangay_offices.dart';
import 'map_services.dart';
import 'models/office_model.dart';
import 'office_map_pins.dart';

enum _OfficeSort { nearest, name }

/// Where the panel rests: just the title, the essentials, or everything.
enum _SheetStop { peek, mid, full }

class OfficeFinderScreen extends StatefulWidget {
  const OfficeFinderScreen({
    super.key,
    this.initialOffice,
    this.services,
    this.mapBuilder,
    this.launchDirections,
    this.showRoadEstimates,
  });
  final OfficeModel? initialOffice;
  final OfficeMapServices? services;
  final Widget Function(google.GoogleMap)? mapBuilder;
  final Future<bool> Function(Uri)? launchDirections;

  /// Null follows the server's switch (`meta.travel_times` on `GET /offices`),
  /// because travel estimates make billable Routes API calls. Tests set it.
  final bool? showRoadEstimates;

  @override
  State<OfficeFinderScreen> createState() => _OfficeFinderScreenState();
}

/// Panel heights as a share of the space it can use.
class _SheetSizes {
  const _SheetSizes(this.peek, this.mid, this.full);

  final double peek;
  final double mid;
  final double full;

  double of(_SheetStop stop) => switch (stop) {
    _SheetStop.peek => peek,
    _SheetStop.mid => mid,
    _SheetStop.full => full,
  };
}

class _OfficeFinderScreenState extends State<OfficeFinderScreen> {
  static const _center = LatLng(14.8527, 120.8160);

  /// The office list's resting height, so the map stays the main view.
  static const _listRestShare = .36;
  static const _controlsHeight = 132.0;

  /// From this width the panel floats on the left, beside the map, instead of
  /// covering its bottom. Tablets in landscape and desktop browsers.
  static const _wideFrom = 840.0;
  static const _sideWidth = 420.0;

  google.GoogleMapController? _map;
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  final _extent = ValueNotifier<double>(0);
  late final OfficeMapServices _services;
  OfficeMapPins? _pins;
  List<OfficeModel> _allOffices = [];
  bool _loadingOffices = true;
  String? _officesError;
  OfficeModel? _selected;
  LatLng? _position;
  _OfficeSort _sort = _OfficeSort.nearest;
  String? _message;
  bool _busy = false;
  bool _openingMaps = false;
  RoadEstimate? _road;
  String? _roadError;
  bool _roadLoading = false;
  int _roadVersion = 0;

  /// Google had no route for this mode. Shown as a calm note, with no retry.
  String? _roadMissing;
  Timer? _roadTimer;

  /// A short pause before asking, so quickly tapping through offices or
  /// modes only costs a call for the one the resident stops on.
  static const _roadPause = Duration(milliseconds: 350);

  // Measured from the content, so the panel is only ever as tall as it needs.
  double _peekHeight = 88;
  double _midHeight = 260;
  double _fullHeight = 420;
  double _topBarHeight = 62;

  _SheetStop _stop = _SheetStop.mid;
  _SheetSizes _sizes = const _SheetSizes(.1, .3, .5);

  // The same list object is kept between builds: a new one makes the panel re-snap.
  List<double> _snaps = const [];
  double _panelSpace = 0;
  bool _moveScheduled = false;
  ScrollController? _panelScroll;

  List<OfficeModel> get _offices {
    final query = _search.text.trim().toLowerCase();
    final offices = _allOffices.where((office) {
      final records = office.records.join(' ');
      return '${office.name} ${office.agency} ${office.agencyName} ${office.address} $records'
          .toLowerCase()
          .contains(query);
    }).toList();
    if (_sort == _OfficeSort.name) {
      offices.sort((a, b) => a.name.compareTo(b.name));
    } else if (_position != null) {
      offices.sort((a, b) {
        final first = _metersTo(a);
        final second = _metersTo(b);
        // Offices without coordinates cannot be ranked, so they come last.
        if (first == null || second == null) {
          if (first != null) return -1;
          if (second != null) return 1;
          return a.name.compareTo(b.name);
        }
        return first.compareTo(second);
      });
    }
    // The resident's own barangay hall comes first; everything else keeps the
    // order chosen above. Other barangays' halls are still listed.
    final own = offices.where(_isOwnBarangay).toList();
    if (own.isNotEmpty) {
      offices.removeWhere(_isOwnBarangay);
      offices.insertAll(0, own);
    }
    return offices;
  }

  bool _isOwnBarangay(OfficeModel office) {
    final resident = BarangayOffices.residentBarangayId(
      AuthService.instance.user,
    );
    return resident != null && office.barangayId == resident;
  }

  /// A saved or changed barangay in Account Details updates the list.
  void _authChanged() {
    if (mounted) setState(() {});
  }

  Widget _yourBarangay(OfficeModel office, ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Container(
      key: ValueKey('finder-your-barangay-${office.id}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Your Barangay',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: colors.primary,
        ),
      ),
    ),
  );

  Future<void> _loadOffices() async {
    try {
      final offices = await _services.offices();
      if (!mounted) return;
      setState(() {
        _allOffices = offices;
        _loadingOffices = false;
        _officesError = null;
      });
      if (_selected == null) _fit(_located(_offices));
      // The switch arrives with the list, after an office may be open.
      if (_road == null && !_roadLoading) _scheduleRoad();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingOffices = false;
        _officesError = error is StateError
            ? error.message.toString()
            : 'Could not load offices. Check your connection and try again.';
      });
    }
  }

  void _retryOffices() {
    setState(() {
      _loadingOffices = true;
      _officesError = null;
    });
    _loadOffices();
  }

  @override
  void initState() {
    super.initState();
    _services = widget.services ?? OfficeMapServices();
    _selected = widget.initialOffice;
    AuthService.instance.addListener(_authChanged);
    _loadPins();
    _loadOffices();
    _quietLocate();
  }

  bool get _travelOn => widget.showRoadEstimates ?? _services.travelTimes;

  /// Uses the location only if permission was already given; never prompts.
  Future<void> _quietLocate() async {
    final point = await _services.locateIfAllowed();
    if (!mounted || point == null || _position != null) return;
    setState(() => _position = point);
    if (_selected == null) {
      _fitNearest();
    } else {
      _scheduleRoad();
    }
  }

  Future<void> _loadPins() async {
    try {
      final pins = await OfficeMapPins.load();
      if (mounted) setState(() => _pins = pins);
    } catch (_) {
      // The map keeps Google's standard markers.
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_authChanged);
    _roadTimer?.cancel();
    _search.dispose();
    _sheet.dispose();
    _extent.dispose();
    _map?.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  LatLng? _point(OfficeModel office) {
    final location = OfficeModel.usableLocation(
      office.latitude,
      office.longitude,
    );
    return location == null
        ? null
        : LatLng(location.latitude, location.longitude);
  }

  List<LatLng> _located(List<OfficeModel> offices) => [
    for (final office in offices) ?_point(office),
  ];

  double? _metersTo(OfficeModel office) {
    final position = _position;
    final point = _point(office);
    if (position == null || point == null) return null;
    return const Distance().distance(position, point).toDouble();
  }

  /// Frames the resident with the nearest results, or every office if unknown.
  void _fitNearest() {
    final position = _position;
    final located = _located(_offices);
    final nearest = _search.text.trim().isEmpty ? 3 : 1;
    _fit(position == null ? located : [position, ...located.take(nearest)]);
  }

  static String _distanceLabel(double meters) => meters < 1000
      ? '${meters.round()} m'
      : '${(meters / 1000).toStringAsFixed(1)} km';

  static String _durationLabel(int seconds) {
    final minutes = (seconds / 60).ceil().clamp(1, 1 << 31);
    if (minutes < 60) return '$minutes min';
    final rest = minutes % 60;
    return '${minutes ~/ 60} hr${rest == 0 ? '' : ' $rest min'}';
  }

  // Panel ---------------------------------------------------------------------

  /// Fits the three resting points to the content and the space available.
  _SheetSizes _sizesFor(
    double space,
    double reservedTop,
    double safeBottom,
    bool typing,
  ) {
    double round(double value) => (value * 1000).roundToDouble() / 1000;
    final limit = round(((space - reservedTop) / space).clamp(.2, 1.0));
    final peek = round(((_peekHeight + safeBottom) / space).clamp(.05, limit));
    final full = round((_fullHeight / space).clamp(peek, limit));
    final wanted = _selected != null
        ? _midHeight + safeBottom
        // Results get all the room there is above the keyboard.
        : (typing ? space : space * _listRestShare);
    return _SheetSizes(peek, round((wanted / space).clamp(peek, full)), full);
  }

  /// Fades content in as the panel opens, so none is left cut off at its edge.
  Widget _revealed(double from, double to, Widget child) =>
      ValueListenableBuilder<double>(
        valueListenable: _extent,
        child: child,
        builder: (context, extent, child) {
          final current = extent == 0 ? _sizes.of(_stop) : extent;
          final opacity = to <= from
              ? 1.0
              : ((current - from) / (to - from)).clamp(0.0, 1.0);
          return IgnorePointer(
            ignoring: opacity == 0,
            child: Opacity(opacity: opacity, child: child),
          );
        },
      );

  void _useSizes(_SheetSizes sizes) {
    _sizes = sizes;
    final snaps = sizes.mid > sizes.peek && sizes.mid < sizes.full
        ? [sizes.mid]
        : const <double>[];
    if (snaps.length != _snaps.length ||
        (snaps.isNotEmpty && snaps.first != _snaps.first)) {
      _snaps = snaps;
    }
  }

  void _measured(void Function() update) {
    if (!mounted) return;
    setState(update);
    _moveAfterFrame();
  }

  /// Runs after the frame so the panel already has its new limits.
  void _moveAfterFrame() {
    if (_moveScheduled) return;
    _moveScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _moveScheduled = false;
      if (!mounted) return;
      if (_sheet.isAttached) _extent.value = _sheet.size;
      _moveSheet();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  void _moveSheet() {
    if (!_sheet.isAttached) return;
    final size = _sizes.of(_stop);
    if ((_sheet.size - size).abs() < .002) return;
    if (AppMotion.reduced(context)) {
      _sheet.jumpTo(size);
      return;
    }
    _sheet.animateTo(
      size,
      duration: AppMotion.duration(context),
      curve: Curves.easeOutCubic,
    );
  }

  void _goTo(_SheetStop stop) {
    FocusScope.of(context).unfocus();
    setState(() => _stop = stop);
    _moveAfterFrame();
  }

  void _toggleSheet() =>
      _goTo(_stop == _SheetStop.peek ? _SheetStop.mid : _SheetStop.peek);

  /// Remembers where the panel came to rest after a drag.
  bool _onSheetMoved(DraggableScrollableNotification notification) {
    _extent.value = notification.extent;
    for (final stop in _SheetStop.values) {
      if ((notification.extent - _sizes.of(stop)).abs() < .004) {
        if (stop != _stop) {
          void remember() {
            if (mounted) setState(() => _stop = stop);
          }

          // A panel fitting new limits reports this while the tree is building.
          SchedulerBinding.instance.schedulerPhase ==
                  SchedulerPhase.persistentCallbacks
              ? SchedulerBinding.instance.addPostFrameCallback(
                  (_) => remember(),
                )
              : remember();
        }
        break;
      }
    }
    return false;
  }

  /// Forgets the estimate and ignores any reply still on its way.
  void _clearRoad() {
    _roadVersion++;
    _roadTimer?.cancel();
    _road = null;
    _roadError = null;
    _roadMissing = null;
    _roadLoading = false;
  }

  void _select(OfficeModel office) {
    setState(() {
      _selected = office;
      _message = null;
      _clearRoad();
    });
    _showPanelTop();
    _goTo(_SheetStop.mid);
    _fit([?_point(office)]);
    _scheduleRoad();
  }

  /// Asks for the travel estimate once the location is already known. Without
  /// it, the card offers a button, so location is never requested unasked.
  void _scheduleRoad() {
    final office = _selected;
    final origin = _position;
    if (!_travelOn || office == null || origin == null) return;
    if (_point(office) == null) return;
    setState(() {
      _clearRoad();
      _roadLoading = true;
    });
    final version = _roadVersion;
    _roadTimer = Timer(_roadPause, () => _fetchRoad(office, origin, version));
  }

  Future<void> _fetchRoad(
    OfficeModel office,
    LatLng origin,
    int version,
  ) async {
    try {
      final road = await _services.roadEstimate(office.id, origin);
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _road = road;
        _roadLoading = false;
      });
      // Frames the whole drive, so the line is seen from start to office.
      if (road.path.length > 1) _fit(road.path);
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

  void _closeDetails() {
    _filterChanged();
    _showPanelTop();
    _goTo(_SheetStop.mid);
    _fit(_located(_offices));
  }

  /// New content starts at its top, not at the old content's scroll position.
  void _showPanelTop() {
    final scroll = _panelScroll;
    if (scroll != null && scroll.hasClients) scroll.jumpTo(0);
  }

  void _fit(List<LatLng> points) {
    if (points.isEmpty) return;
    final controller = _map;
    if (controller == null) return;
    if (points.length == 1) {
      controller.animateCamera(
        google.CameraUpdate.newLatLngZoom(_googlePoint(points.first), 15),
      );
      return;
    }
    final latitudes = points.map((p) => p.latitude);
    final longitudes = points.map((p) => p.longitude);
    final south = latitudes.reduce((a, b) => a < b ? a : b);
    final north = latitudes.reduce((a, b) => a > b ? a : b);
    final west = longitudes.reduce((a, b) => a < b ? a : b);
    final east = longitudes.reduce((a, b) => a > b ? a : b);
    controller.animateCamera(
      google.CameraUpdate.newLatLngBounds(
        google.LatLngBounds(
          southwest: google.LatLng(south - .0001, west - .0001),
          northeast: google.LatLng(north + .0001, east + .0001),
        ),
        50,
      ),
    );
  }

  google.LatLng _googlePoint(LatLng point) =>
      google.LatLng(point.latitude, point.longitude);

  Widget _buildMap(
    List<OfficeModel> offices,
    OfficeModel? selected,
    EdgeInsets padding,
  ) {
    final pins = _pins;
    final map = google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: _googlePoint(
          (selected == null ? null : _point(selected)) ?? _center,
        ),
        zoom: 12,
      ),
      padding: padding,
      compassEnabled: false,
      zoomControlsEnabled: false,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      rotateGesturesEnabled: false,
      minMaxZoomPreference: const google.MinMaxZoomPreference(5, 18),
      onMapCreated: (controller) {
        if (!mounted) {
          controller.dispose();
          return;
        }
        _map = controller;
        _fit(_located(selected == null ? offices : [selected]));
      },
      onTap: (_) => FocusScope.of(context).unfocus(),
      polylines: _routeLines(selected),
      markers: {
        for (final office in {...offices, ?selected})
          if (_point(office) case final point?)
            google.Marker(
              markerId: google.MarkerId('office-${office.id}'),
              position: _googlePoint(point),
              infoWindow: google.InfoWindow(
                title: office.name,
                snippet: office.address,
              ),
              icon: selected?.id == office.id
                  ? pins?.selected ??
                        google.BitmapDescriptor.defaultMarkerWithHue(
                          google.BitmapDescriptor.hueAzure,
                        )
                  : pins?.office ??
                        google.BitmapDescriptor.defaultMarkerWithHue(
                          google.BitmapDescriptor.hueRed,
                        ),
              onTap: () => _select(office),
            ),
        if (_position != null)
          google.Marker(
            markerId: const google.MarkerId('current-position'),
            position: _googlePoint(_position!),
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

  /// The driving route as a blue line with a white edge, like Google Maps,
  /// so it stays readable over roads of any colour.
  Set<google.Polyline> _routeLines(OfficeModel? selected) {
    final path = _road?.path ?? const <LatLng>[];
    if (selected == null || path.length < 2) return const {};
    final points = [for (final point in path) _googlePoint(point)];
    return {
      google.Polyline(
        polylineId: const google.PolylineId('route-edge'),
        points: points,
        color: Colors.white,
        width: 9,
        zIndex: 1,
        jointType: google.JointType.round,
        startCap: google.Cap.roundCap,
        endCap: google.Cap.roundCap,
      ),
      google.Polyline(
        polylineId: const google.PolylineId('route'),
        points: points,
        color: _routeBlue,
        width: 6,
        zIndex: 2,
        jointType: google.JointType.round,
        startCap: google.Cap.roundCap,
        endCap: google.Cap.roundCap,
      ),
    };
  }

  /// Brighter than the app's primary blue, so the line stands out on the map.
  static const _routeBlue = Color(0xFF1E66D0);

  Future<void> _locate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final point = await _services.locate();
      if (!mounted) return;
      setState(() {
        _position = point;
        _sort = _OfficeSort.nearest;
      });
      FocusScope.of(context).unfocus();
      if (_selected == null) {
        _fitNearest();
      } else if (_road == null) {
        _scheduleRoad();
      }
    } catch (error) {
      _showError(error, 'Could not find your location. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directions() async {
    final office = _selected;
    final destination = office == null ? null : _point(office);
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

  /// The card's button: asks for location if needed, then the estimate.
  Future<void> _showRoadDistance() async {
    final office = _selected;
    if (office == null || _point(office) == null) return;
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
    setState(() => _position = origin);
    await _fetchRoad(office, origin, version);
  }

  void _showError(Object error, String fallback) {
    if (mounted) {
      setState(
        () => _message = error is StateError
            ? error.message.toString()
            : fallback,
      );
    }
  }

  void _filterChanged() {
    setState(() {
      _selected = null;
      _message = null;
      _clearRoad();
    });
  }

  void _submitSearch() {
    FocusScope.of(context).unfocus();
    if (_offices.isNotEmpty) _fitNearest();
  }

  // Shared surfaces -----------------------------------------------------------

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color _surface(ColorScheme colors) =>
      _dark ? colors.surfaceContainer : Colors.white;

  Color _border(ColorScheme colors) => _dark
      ? colors.outlineVariant.withValues(alpha: .35)
      : const Color(0xFFE3ECF7);

  TextStyle _note(ColorScheme colors) =>
      TextStyle(fontSize: 12.5, height: 1.35, color: colors.onSurfaceVariant);

  // Floating search bar -------------------------------------------------------

  /// Soft shadow for things that float over the map.
  List<BoxShadow> get _floatShadow => [
    BoxShadow(
      color: Colors.black.withValues(alpha: _dark ? .3 : .12),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
  ];

  Widget _barButton({
    required ColorScheme colors,
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
    bool active = false,
  }) => Padding(
    padding: const EdgeInsets.all(4),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: active ? colors.primary : Colors.transparent,
        foregroundColor: active ? colors.onPrimary : colors.primary,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 42, height: 42),
      icon: icon,
    ),
  );

  Widget _searchField(ColorScheme colors) => TextField(
    controller: _search,
    textInputAction: TextInputAction.search,
    onChanged: (_) => _filterChanged(),
    onSubmitted: (_) => _submitSearch(),
    style: const TextStyle(fontSize: 15),
    decoration: InputDecoration(
      hintText: 'Search offices',
      isDense: true,
      border: InputBorder.none,
      filled: false,
      prefixIcon: Icon(
        Icons.search_rounded,
        size: 20,
        color: colors.onSurfaceVariant,
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 30, minHeight: 46),
      suffixIcon: _search.text.isNotEmpty
          ? IconButton(
              tooltip: 'Clear search',
              onPressed: () {
                _search.clear();
                _filterChanged();
              },
              icon: const Icon(Icons.cancel_rounded, size: 18),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(vertical: 13),
    ),
  );

  Widget _messageBanner(ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: _surface(colors),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border(colors)),
        boxShadow: _floatShadow,
      ),
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

  Widget _topBar(ColorScheme colors) => Semantics(
    container: true,
    explicitChildNodes: true,
    label: 'Office Finder',
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: _surface(colors),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _border(colors)),
            boxShadow: _floatShadow,
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Row(
              children: [
                _barButton(
                  colors: colors,
                  tooltip: 'Back',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back_rounded, size: 22),
                ),
                Expanded(child: _searchField(colors)),
                Container(width: 1, height: 26, color: _border(colors)),
                _barButton(
                  colors: colors,
                  tooltip: _position == null
                      ? 'Use my current location'
                      : 'Using your current location',
                  active: _position != null,
                  onPressed: _busy ? null : _locate,
                  icon: _busy
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          _position == null
                              ? Icons.my_location_rounded
                              : Icons.near_me_rounded,
                          size: 20,
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_message != null) _messageBanner(colors),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final offices = _offices;
    final selected = _selected;
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final safeBottom = keyboard > 0 ? 0.0 : media.padding.bottom;
    return PopScope(
      // The system back gesture closes details before leaving the screen.
      canPop: selected == null || widget.initialOffice != null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _closeDetails();
      },
      child: Scaffold(
        // The panel moves above the keyboard; the map underneath keeps its size.
        resizeToAvoidBottomInset: false,
        body: LayoutBuilder(
          builder: (context, constraints) {
            final space = constraints.maxHeight - keyboard;
            final reservedTop = media.padding.top + _topBarHeight + 16;
            _useSizes(_sizesFor(space, reservedTop, safeBottom, keyboard > 0));
            if (space != _panelSpace) {
              _panelSpace = space;
              _moveAfterFrame();
            }
            final resting = _sizes.of(_stop) * space;
            final wide = constraints.maxWidth >= _wideFrom;
            // The panel and search bar share one column on wide screens.
            final sideRight = wide
                ? constraints.maxWidth - _sideWidth - 16
                : 0.0;
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _buildMap(
                    offices,
                    selected,
                    wide
                        ? EdgeInsets.only(left: _sideWidth + 16, top: 16)
                        : EdgeInsets.only(
                            top: reservedTop,
                            bottom: resting + 8,
                          ),
                  ),
                ),
                if (keyboard == 0)
                  ValueListenableBuilder<double>(
                    valueListenable: _extent,
                    builder: (context, extent, child) {
                      final panel =
                          (extent == 0 ? _sizes.of(_stop) : extent) * space;
                      final room = wide ? space : space - panel - reservedTop;
                      // Always Positioned: a plain child would shrink the Stack to fit it.
                      return Positioned(
                        right: wide ? 16 : 12,
                        bottom: wide ? 24 : panel + 12,
                        child: room > _controlsHeight + 16
                            ? child!
                            : const SizedBox.shrink(),
                      );
                    },
                    child: _mapControls(offices, colors),
                  ),
                Positioned(
                  left: wide ? 16 : 0,
                  right: sideRight,
                  top: 0,
                  bottom: keyboard,
                  child: NotificationListener<DraggableScrollableNotification>(
                    onNotification: _onSheetMoved,
                    child: DraggableScrollableSheet(
                      controller: _sheet,
                      initialChildSize: _sizes.of(_stop),
                      minChildSize: _sizes.peek,
                      maxChildSize: _sizes.full,
                      snap: true,
                      snapSizes: _snaps,
                      // Intercept only the visible sheet, leaving the exposed map interactive.
                      builder: (context, scrollController) =>
                          PointerInterceptor(
                            child: _panel(
                              scrollController,
                              offices,
                              selected,
                              colors,
                              safeBottom,
                            ),
                          ),
                    ),
                  ),
                ),
                Positioned(
                  left: wide ? 4 : 0,
                  right: wide ? sideRight - 12 : 0,
                  top: 0,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                      child: PointerInterceptor(
                        child: _Measured(
                          onHeight: (height) =>
                              _measured(() => _topBarHeight = height),
                          child: _topBar(colors),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _mapControls(List<OfficeModel> offices, ColorScheme colors) {
    Widget button(String tooltip, IconData icon, VoidCallback onPressed) =>
        IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 42, height: 42),
          icon: Icon(icon, size: 20),
        );
    return PointerInterceptor(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .14),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: FrostedSurface(
          borderRadius: BorderRadius.circular(14),
          child: Material(
            type: MaterialType.transparency,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                button(
                  'Zoom in',
                  Icons.add,
                  () => _map?.animateCamera(google.CameraUpdate.zoomIn()),
                ),
                button(
                  'Zoom out',
                  Icons.remove,
                  () => _map?.animateCamera(google.CameraUpdate.zoomOut()),
                ),
                button(
                  'Show all offices',
                  Icons.zoom_out_map_rounded,
                  () => _fit(_located(offices)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _panel(
    ScrollController scrollController,
    List<OfficeModel> offices,
    OfficeModel? selected,
    ColorScheme colors,
    double safeBottom,
  ) {
    _panelScroll = scrollController;
    final top = selected == null
        ? _listTop(offices, colors)
        : _detailsTop(selected, colors);
    final essentials = selected == null
        ? const <Widget>[]
        : _essentials(selected, colors);
    final more = selected == null
        ? _officeList(offices, colors)
        : _moreDetails(selected, colors);
    return Container(
      // Keeps scrolled content inside the rounded corners.
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _dark ? colors.surfaceContainerLow : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .12),
            blurRadius: 18,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SingleChildScrollView(
        controller: scrollController,
        child: _Measured(
          onHeight: (height) => _measured(() => _fullHeight = height),
          child: Padding(
            padding: EdgeInsets.only(bottom: safeBottom + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Measured(
                  onHeight: (height) => _measured(() => _midHeight = height),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Measured(
                        onHeight: (height) =>
                            _measured(() => _peekHeight = height),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_handle(colors), top],
                        ),
                      ),
                      _revealed(
                        _sizes.peek,
                        _sizes.mid,
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: essentials,
                        ),
                      ),
                    ],
                  ),
                ),
                _revealed(
                  selected == null ? _sizes.peek : _sizes.mid,
                  selected == null ? _sizes.peek + .05 : _sizes.full,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: more,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _handle(ColorScheme colors) => Tooltip(
    message: _stop == _SheetStop.peek ? 'Expand panel' : 'Minimize panel',
    child: InkWell(
      key: const ValueKey('office-sheet-handle'),
      onTap: _toggleSheet,
      child: SizedBox(
        height: 22,
        child: Center(
          child: Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.outlineVariant,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    ),
  );

  // Office list ---------------------------------------------------------------

  Widget _listTop(List<OfficeModel> offices, ColorScheme colors) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 2, 14, 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _countLabel(offices.length),
                style: const TextStyle(
                  fontSize: 17,
                  height: 1.25,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                _position == null
                    ? 'Government offices in IDireksyon'
                    : _sort == _OfficeSort.nearest
                    ? 'Nearest to you first'
                    : 'Sorted by name',
                style: _note(colors),
              ),
            ],
          ),
        ),
        // "Nearest" means nothing until the resident's location is known.
        if (offices.length > 1 && _position != null) _sortButton(colors),
      ],
    ),
  );

  String _countLabel(int count) {
    if (_loadingOffices) return 'Loading offices…';
    return '$count ${count == 1 ? 'office' : 'offices'}';
  }

  Widget _sortButton(ColorScheme colors) => OutlinedButton.icon(
    onPressed: () => setState(() {
      _sort = _sort == _OfficeSort.nearest
          ? _OfficeSort.name
          : _OfficeSort.nearest;
    }),
    style: OutlinedButton.styleFrom(
      foregroundColor: colors.primary,
      visualDensity: VisualDensity.compact,
      side: BorderSide(color: _border(colors)),
      shape: const StadiumBorder(),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
    ),
    icon: const Icon(Icons.swap_vert_rounded, size: 17),
    label: Text(_sort == _OfficeSort.nearest ? 'Nearest' : 'Name'),
  );

  List<Widget> _officeList(List<OfficeModel> offices, ColorScheme colors) => [
    if (_position != null && _located(offices).isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
        child: Text(
          _travelOn
              ? 'Straight-line distances. Select an office to see travel time.'
              : 'Straight-line distances, not road distances.',
          style: _note(colors).copyWith(fontSize: 12),
        ),
      ),
    if (_loadingOffices)
      const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (_officesError != null)
      _statePanel(
        colors,
        icon: Icons.cloud_off_rounded,
        title: _officesError!,
        action: TextButton.icon(
          onPressed: _retryOffices,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    for (final office in offices) _officeRow(office, colors),
    if (!_loadingOffices && _officesError == null && offices.isEmpty)
      _statePanel(
        colors,
        icon: Icons.travel_explore_rounded,
        title: 'No matching offices',
        body: 'Try another office name, agency, or address.',
      ),
  ];

  /// Empty and error states share one calm layout.
  Widget _statePanel(
    ColorScheme colors, {
    required IconData icon,
    required String title,
    String? body,
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
    child: Column(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 21, color: colors.onPrimaryContainer),
        ),
        const SizedBox(height: 8),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        if (body != null) ...[
          const SizedBox(height: 4),
          Text(body, textAlign: TextAlign.center, style: _note(colors)),
        ],
        ?action,
      ],
    ),
  );

  /// Agency initials from the office name, or a civic icon when it has none.
  Widget _officeBadge(
    OfficeModel office,
    ColorScheme colors, {
    double size = 44,
  }) {
    final first = office.name.split(' ').first;
    final initials = office.agency.isNotEmpty
        ? office.agency
        : (first == first.toUpperCase() ? first : '');
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          borderRadius: BorderRadius.circular(size * .3),
        ),
        padding: const EdgeInsets.all(6),
        child: initials.isNotEmpty
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              )
            : Icon(
                Icons.account_balance_rounded,
                size: size * .45,
                color: colors.onPrimaryContainer,
              ),
      ),
    );
  }

  /// A small labelled fact, such as a distance or today's hours.
  Widget _metaChip(ColorScheme colors, IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: _dark ? colors.surfaceContainerHigh : AppTheme.pageBackground,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: colors.primary),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              fontWeight: FontWeight.w600,
              color: colors.primary,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _officeRow(OfficeModel office, ColorScheme colors) {
    final meters = _metersTo(office);
    final hours = office.hoursOn(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      child: Material(
        color: _surface(colors),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: _border(colors)),
        ),
        clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: () => _select(office),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _officeBadge(office, colors),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        office.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.3,
                        ),
                      ),
                      if (_isOwnBarangay(office)) _yourBarangay(office, colors),
                      const SizedBox(height: 2),
                      Text(
                        office.address,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      if (meters != null || hours != null) ...[
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (meters != null)
                              _metaChip(
                                colors,
                                Icons.near_me_rounded,
                                _distanceLabel(meters),
                              ),
                            if (hours != null)
                              _metaChip(colors, Icons.schedule_rounded, hours),
                          ],
                        ),
                      ],
                      const SizedBox(height: 6),
                      Text(office.serviceTag, style: _note(colors)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Office details ------------------------------------------------------------

  Widget _infoRow(ColorScheme colors, IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(icon, size: 17, color: colors.primary),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              color: colors.onSurface,
            ),
          ),
        ),
      ],
    ),
  );

  /// Stays visible when the panel is minimized.
  Widget _detailsTop(OfficeModel office, ColorScheme colors) {
    final meters = _metersTo(office);
    final agency = office.agencyName.isNotEmpty
        ? office.agencyName
        : office.agency;
    // The travel card shows the real drive; this is only a quick hint.
    final facts = [
      if (agency.isNotEmpty) agency,
      if (meters != null && !_travelOn) '${_distanceLabel(meters)} away',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 10, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _officeBadge(office, colors, size: 46),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  office.name,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (_isOwnBarangay(office)) _yourBarangay(office, colors),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    facts.join('  •  '),
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filledTonal(
            tooltip: 'Back to offices',
            onPressed: _closeDetails,
            style: IconButton.styleFrom(
              backgroundColor: _dark
                  ? colors.surfaceContainerHigh
                  : AppTheme.pageBackground,
              foregroundColor: colors.onSurfaceVariant,
            ),
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 19),
          ),
        ],
      ),
    );
  }

  bool _hasMore(OfficeModel office) =>
      office.records.isNotEmpty || office.weeklyHours.isNotEmpty;

  List<Widget> _essentials(OfficeModel office, ColorScheme colors) {
    final hours = office.hoursOn(DateTime.now());
    final expanded = _stop == _SheetStop.full;
    final located = _point(office) != null;
    return [
      _infoRow(colors, Icons.location_on_outlined, office.address),
      if (hours != null) ...[
        const SizedBox(height: 8),
        _infoRow(colors, Icons.schedule_rounded, hours),
      ],
      const SizedBox(height: 14),
      if (located)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_travelOn) ...[
                _travelCard(colors),
                const SizedBox(height: 10),
              ],
              FilledButton.icon(
                onPressed: _openingMaps ? null : _directions,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 15.5, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.directions_rounded, size: 21),
                label: const Text('Get Directions'),
              ),
              const SizedBox(height: 6),
              Text(
                'Opens Google Maps. Pin may be approximate.',
                textAlign: TextAlign.center,
                style: _note(colors).copyWith(fontSize: 12),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _dark
                  ? colors.surfaceContainerHigh
                  : AppTheme.pageBackground,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_off_outlined,
                  size: 18,
                  color: colors.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Map location isn’t available for this office yet.',
                    style: _note(colors),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (_hasMore(office))
        Align(
          child: TextButton.icon(
            onPressed: () => _goTo(expanded ? _SheetStop.mid : _SheetStop.full),
            style: TextButton.styleFrom(
              foregroundColor: colors.primary,
              visualDensity: VisualDensity.compact,
              textStyle: Theme.of(context).textTheme.labelLarge
                  ?.copyWith(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            icon: Icon(
              expanded
                  ? Icons.keyboard_arrow_down_rounded
                  : Icons.keyboard_arrow_up_rounded,
              size: 18,
            ),
            label: Text(expanded ? 'Less details' : 'More details'),
          ),
        ),
      if (!_hasMore(office)) const SizedBox(height: 4),
    ];
  }

  Widget _sectionLabel(String text, ColorScheme colors) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: colors.onSurface,
        ),
      ),
    ),
  );

  /// Solid card for a group of detail rows.
  Widget _detailCard(ColorScheme colors, List<Widget> rows) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: _surface(colors),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border(colors)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: rows,
      ),
    ),
  );

  List<Widget> _moreDetails(OfficeModel office, ColorScheme colors) {
    final week = office.weeklyHours;
    const text = TextStyle(fontSize: 13.5, height: 1.3);
    return [
      if (week.isNotEmpty) ...[
        _sectionLabel('Weekly hours', colors),
        _detailCard(colors, [
          for (final line in week)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 80,
                    child: Text(
                      line.days,
                      style: text.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Text(line.hours, style: text)),
                ],
              ),
            ),
        ]),
      ],
      if (office.records.isNotEmpty) ...[
        _sectionLabel('IDs and documents', colors),
        _detailCard(colors, [
          for (final record in office.records)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 1),
                    child: Icon(
                      Icons.description_outlined,
                      size: 16,
                      color: colors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(record, style: text)),
                ],
              ),
            ),
        ]),
      ],
    ];
  }

  // Travel time ---------------------------------------------------------------

  /// The driving time and distance on the app's navy banner. Get Directions
  /// below works whatever happens here, and Google Maps offers other modes.
  Widget _travelCard(ColorScheme colors) => Semantics(
    container: true,
    child: Container(
      key: const ValueKey('office-travel-card'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppTheme.navy, AppTheme.primaryBlue],
        ),
      ),
      child: AnimatedSize(
        duration: AppMotion.duration(context),
        curve: AppMotion.curve,
        alignment: Alignment.topCenter,
        child: AnimatedSwitcher(
          duration: AppMotion.duration(context, AppMotion.quick),
          child: KeyedSubtree(
            key: ValueKey(_travelState),
            child: _travelResult(),
          ),
        ),
      ),
    ),
  );

  /// Changes whenever the card shows something different, for the transition.
  String get _travelState =>
      '${_road != null}|$_roadLoading|$_roadMissing|$_roadError|${_position != null}';

  static const _onBanner = Colors.white;
  static const _onBannerSoft = Color(0xD9FFFFFF);

  Widget _bannerIcon(IconData icon) => Container(
    width: 38,
    height: 38,
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: .14),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Icon(icon, size: 20, color: _onBanner),
  );

  /// Solid white, like the other banner buttons in the app.
  Widget _bannerButton(String label, IconData icon) => FilledButton.icon(
    onPressed: _showRoadDistance,
    style: FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.navy,
      minimumSize: const Size(0, 38),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
    icon: Icon(icon, size: 17),
    label: Text(label),
  );

  Widget _travelResult() {
    const soft = TextStyle(fontSize: 12, height: 1.35, color: _onBannerSoft);
    final road = _road;
    if (road != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label:
                'About ${_durationLabel(road.seconds)} by car, ${_distanceLabel(road.meters)}',
            excludeSemantics: true,
            child: Row(
              children: [
                _bannerIcon(Icons.directions_car_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Estimated travel time', style: soft),
                      Text(
                        _durationLabel(road.seconds),
                        style: const TextStyle(
                          fontSize: 24,
                          height: 1.15,
                          fontWeight: FontWeight.w800,
                          color: _onBanner,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _distanceLabel(road.meters),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _onBanner,
                      ),
                    ),
                    const Text('by car', style: soft),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Estimated without live traffic. Actual time may differ.',
            style: soft,
          ),
        ],
      );
    }
    if (_roadLoading) {
      return const Row(
        children: [
          SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: _onBanner),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Calculating travel time…',
              style: TextStyle(fontSize: 14, color: _onBanner),
            ),
          ),
        ],
      );
    }
    final missing = _roadMissing;
    if (missing != null) {
      return Row(
        children: [
          _bannerIcon(Icons.info_outline_rounded),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$missing Google Maps may still suggest a way.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: _onBanner,
              ),
            ),
          ),
        ],
      );
    }
    final error = _roadError;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _bannerIcon(Icons.directions_car_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    error ?? 'How long is the drive?',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: _onBanner,
                    ),
                  ),
                  if (error == null && _position == null)
                    const Text(
                      'Uses your current location. IDireksyon does not save it.',
                      style: soft,
                    ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        error != null
            ? _bannerButton('Try again', Icons.refresh_rounded)
            : _bannerButton('Show travel time', Icons.near_me_rounded),
      ],
    );
  }
}

/// Reports its child's height after layout, whenever it changes.
class _Measured extends SingleChildRenderObjectWidget {
  const _Measured({required this.onHeight, required Widget super.child});

  final ValueChanged<double> onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasured(onHeight);

  @override
  void updateRenderObject(BuildContext context, _RenderMeasured renderObject) {
    renderObject.onHeight = onHeight;
  }
}

class _RenderMeasured extends RenderProxyBox {
  _RenderMeasured(this.onHeight);

  ValueChanged<double> onHeight;
  double? _last;

  @override
  void performLayout() {
    super.performLayout();
    final height = size.height;
    if (height == _last) return;
    _last = height;
    SchedulerBinding.instance.addPostFrameCallback((_) => onHeight(height));
  }
}
