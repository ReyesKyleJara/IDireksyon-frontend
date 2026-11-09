import '../../core/widgets/app_motion.dart';
import '../../core/widgets/frosted.dart';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

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
    this.showRoadEstimates = false,
  });
  final OfficeModel? initialOffice;
  final OfficeMapServices? services;
  final Widget Function(google.GoogleMap)? mapBuilder;
  final Future<bool> Function(Uri)? launchDirections;

  /// Off for closed testing: road estimates make billable Routes API calls.
  final bool showRoadEstimates;

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
    return offices;
  }

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
    _loadPins();
    _loadOffices();
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
    if (minutes < 60) return 'About $minutes min';
    final rest = minutes % 60;
    return 'About ${minutes ~/ 60} hr${rest == 0 ? '' : ' $rest min'}';
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
    _road = null;
    _roadError = null;
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
      _fitNearest();
    } catch (error) {
      _showError(error, 'Could not find your location. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Google Maps uses the device's location, so none is requested or sent here.
  Future<void> _directions() async {
    final office = _selected;
    final destination = office == null ? null : _point(office);
    if (_openingMaps || destination == null) return;
    setState(() {
      _openingMaps = true;
      _message = null;
    });
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': '${destination.latitude},${destination.longitude}',
    });
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

  /// Runs only from the button, so location is never sent without a tap.
  Future<void> _showRoadDistance() async {
    final office = _selected;
    if (office == null || _point(office) == null || _roadLoading) return;
    final version = ++_roadVersion;
    setState(() {
      _roadLoading = true;
      _roadError = null;
    });
    try {
      final origin = await _services.locate();
      if (!mounted || version != _roadVersion) return;
      setState(() => _position = origin);
      final road = await _services.roadEstimate(office.id, origin);
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _road = road;
        _roadLoading = false;
      });
    } catch (error) {
      if (!mounted || version != _roadVersion) return;
      setState(() {
        _roadLoading = false;
        _roadError = error is StateError
            ? error.message.toString()
            : 'Road distance is unavailable right now. Please try again.';
      });
    }
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

  Widget _roundButton({
    required ColorScheme colors,
    required String tooltip,
    required VoidCallback? onPressed,
    required Widget icon,
    bool active = false,
  }) => Material(
    color: active ? colors.primaryContainer : _surface(colors),
    shape: const CircleBorder(),
    elevation: 2,
    shadowColor: Colors.black38,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      color: colors.primary,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(width: 46, height: 46),
      icon: icon,
    ),
  );

  Widget _searchField(ColorScheme colors) => Material(
    color: _surface(colors),
    borderRadius: BorderRadius.circular(23),
    elevation: 2,
    shadowColor: Colors.black38,
    child: TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (_) => _filterChanged(),
      onSubmitted: (_) => _submitSearch(),
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search offices',
        isDense: true,
        border: InputBorder.none,
        prefixIcon: Icon(Icons.search_rounded, size: 21, color: colors.primary),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 42,
          minHeight: 46,
        ),
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
    ),
  );

  Widget _messageBanner(ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Material(
      color: _surface(colors),
      borderRadius: BorderRadius.circular(14),
      elevation: 2,
      shadowColor: Colors.black38,
      child: Row(
        children: [
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
        Row(
          children: [
            _roundButton(
              colors: colors,
              tooltip: 'Back',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 22),
            ),
            const SizedBox(width: 8),
            Expanded(child: _searchField(colors)),
            const SizedBox(width: 8),
            _roundButton(
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
                          ? Icons.near_me_outlined
                          : Icons.near_me_rounded,
                      size: 21,
                    ),
            ),
          ],
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
            return Stack(
              fit: StackFit.expand,
              children: [
                Positioned.fill(
                  child: _buildMap(
                    offices,
                    selected,
                    EdgeInsets.only(top: reservedTop, bottom: resting + 8),
                  ),
                ),
                if (keyboard == 0)
                  ValueListenableBuilder<double>(
                    valueListenable: _extent,
                    builder: (context, extent, child) {
                      final panel =
                          (extent == 0 ? _sizes.of(_stop) : extent) * space;
                      final room = space - panel - reservedTop;
                      // Always Positioned: a plain child would shrink the Stack to fit it.
                      return Positioned(
                        right: 12,
                        bottom: panel + 12,
                        child: room > _controlsHeight + 16
                            ? child!
                            : const SizedBox.shrink(),
                      );
                    },
                    child: _mapControls(offices, colors),
                  ),
                Positioned(
                  left: 0,
                  right: 0,
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
                  left: 0,
                  right: 0,
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            width: 40,
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
    padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            _countLabel(offices.length),
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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

  Widget _sortButton(ColorScheme colors) => TextButton.icon(
    onPressed: () => setState(() {
      _sort = _sort == _OfficeSort.nearest
          ? _OfficeSort.name
          : _OfficeSort.nearest;
    }),
    style: TextButton.styleFrom(
      foregroundColor: colors.primary,
      visualDensity: VisualDensity.compact,
      textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontSize: 13),
    ),
    icon: const Icon(Icons.swap_vert_rounded, size: 17),
    label: Text(_sort == _OfficeSort.nearest ? 'Nearest' : 'Name'),
  );

  List<Widget> _officeList(List<OfficeModel> offices, ColorScheme colors) => [
    if (_position != null && _located(offices).isNotEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
        child: Text(
          widget.showRoadEstimates
              ? 'Straight-line distances. Select an office to check road distance and time.'
              : 'Straight-line distances, not road distances.',
          style: _note(colors),
        ),
      ),
    if (_loadingOffices)
      const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (_officesError != null)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
        child: Column(
          children: [
            Text(_officesError!, textAlign: TextAlign.center),
            TextButton.icon(
              onPressed: _retryOffices,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    for (final (index, office) in offices.indexed) ...[
      if (index > 0)
        Divider(height: 1, indent: 70, endIndent: 16, color: _border(colors)),
      _officeRow(office, colors),
    ],
    if (!_loadingOffices && _officesError == null && offices.isEmpty)
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
        child: Column(
          children: [
            Icon(
              Icons.travel_explore_rounded,
              size: 30,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            const Text(
              'No matching offices',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Try another office name, agency, or address.',
              textAlign: TextAlign.center,
              style: _note(colors),
            ),
          ],
        ),
      ),
  ];

  /// Agency initials from the office name, or a civic icon when it has none.
  Widget _officeBadge(OfficeModel office, ColorScheme colors) {
    final first = office.name.split(' ').first;
    final initials = office.agency.isNotEmpty
        ? office.agency
        : (first == first.toUpperCase() ? first : '');
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(5),
        child: initials.isNotEmpty
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .3,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              )
            : Icon(
                Icons.account_balance_outlined,
                size: 19,
                color: colors.onPrimaryContainer,
              ),
      ),
    );
  }

  Widget _officeRow(OfficeModel office, ColorScheme colors) {
    final meters = _metersTo(office);
    final hours = office.hoursOn(DateTime.now());
    final facts = [if (meters != null) _distanceLabel(meters), ?hours];
    return MotionInkWell(
      onTap: () => _select(office),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 11, 12, 11),
        child: Row(
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
                  const SizedBox(height: 2),
                  Text(
                    office.address,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.3,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                  if (facts.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      facts.join('  •  '),
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                        color: colors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(office.serviceTag, style: _note(colors)),
                ],
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: colors.onSurfaceVariant,
            ),
          ],
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
        const SizedBox(width: 8),
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
    final facts = [
      if (office.agency.isNotEmpty) office.agency,
      if (meters != null) '${_distanceLabel(meters)} away',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 8, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  office.name,
                  style: const TextStyle(
                    fontSize: 17.5,
                    height: 1.25,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (facts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    facts.join('  •  '),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: colors.primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Back to offices',
            onPressed: _closeDetails,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  bool _hasMore(OfficeModel office) =>
      office.records.isNotEmpty ||
      office.weeklyHours.isNotEmpty ||
      (widget.showRoadEstimates && _point(office) != null);

  List<Widget> _essentials(OfficeModel office, ColorScheme colors) {
    final hours = office.hoursOn(DateTime.now());
    final expanded = _stop == _SheetStop.full;
    return [
      _infoRow(colors, Icons.location_on_outlined, office.address),
      if (hours != null) ...[
        const SizedBox(height: 6),
        _infoRow(colors, Icons.schedule_rounded, hours),
      ],
      const SizedBox(height: 12),
      if (_point(office) != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              FilledButton.icon(
                onPressed: _openingMaps ? null : _directions,
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primary,
                  foregroundColor: colors.onPrimary,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge
                      ?.copyWith(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                icon: const Icon(Icons.directions_rounded, size: 20),
                label: const Text('Get Directions'),
              ),
              const SizedBox(height: 6),
              Text(
                'Opens Google Maps. Pin may be approximate.',
                textAlign: TextAlign.center,
                style: _note(colors),
              ),
            ],
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Map location isn’t available for this office yet.',
            style: _note(colors),
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
    padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w700,
          color: colors.onSurfaceVariant,
        ),
      ),
    ),
  );

  List<Widget> _moreDetails(OfficeModel office, ColorScheme colors) {
    final week = office.weeklyHours;
    return [
      if (week.isNotEmpty) ...[
        _sectionLabel('Weekly hours', colors),
        for (final line in week)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Text(
                    line.days,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    line.hours,
                    style: const TextStyle(fontSize: 13.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
      ],
      if (office.records.isNotEmpty) ...[
        _sectionLabel('IDs and documents', colors),
        for (final record in office.records)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 5),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    record,
                    style: const TextStyle(fontSize: 13.5, height: 1.3),
                  ),
                ),
              ],
            ),
          ),
      ],
      if (widget.showRoadEstimates && _point(office) != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: _roadDistance(colors),
          ),
        ),
    ];
  }

  /// Separate from Get Directions, which works whatever happens here.
  List<Widget> _roadDistance(ColorScheme colors) {
    final note = _note(colors);
    final road = _road;
    if (road != null) {
      return [
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.directions_car_outlined,
              size: 17,
              color: colors.primary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_distanceLabel(road.meters)} by road • ${_durationLabel(road.seconds)} drive',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: colors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Estimated without live traffic. Actual time may differ.',
          style: note,
        ),
      ];
    }
    if (_roadLoading) {
      return [
        const SizedBox(height: 12),
        Row(
          children: [
            const SizedBox.square(
              dimension: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text('Calculating road distance…', style: note)),
          ],
        ),
      ];
    }
    return [
      const SizedBox(height: 12),
      if (_roadError != null) ...[
        Text(_roadError!, style: note.copyWith(color: colors.error)),
        const SizedBox(height: 6),
      ],
      OutlinedButton.icon(
        onPressed: _showRoadDistance,
        style: OutlinedButton.styleFrom(
          foregroundColor: colors.primary,
          minimumSize: const Size.fromHeight(44),
          side: BorderSide(color: _border(colors)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: const Icon(Icons.directions_car_outlined, size: 18),
        label: Text(
          _roadError == null ? 'Show road distance and time' : 'Try again',
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Your current location is sent to calculate the route. IDireksyon does not save it.',
        style: note,
      ),
    ];
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
