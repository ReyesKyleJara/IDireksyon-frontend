import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_motion.dart';
import '../../core/widgets/frosted.dart';
import '../../core/widgets/page_header.dart';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';

import 'map_services.dart';
import 'models/office_model.dart';
import 'office_map_pins.dart';

enum _OfficeSort { nearest, name }

class OfficeFinderScreen extends StatefulWidget {
  const OfficeFinderScreen({
    super.key,
    this.initialOffice,
    this.services,
    this.mapBuilder,
  });
  final OfficeModel? initialOffice;
  final OfficeMapServices? services;
  final Widget Function(google.GoogleMap)? mapBuilder;

  @override
  State<OfficeFinderScreen> createState() => _OfficeFinderScreenState();
}

class _OfficeFinderScreenState extends State<OfficeFinderScreen> {
  static const _blue = AppTheme.primaryBlue;
  static const _center = LatLng(14.8527, 120.8160);

  // Panel heights, as a share of the area below the header.
  static const _peek = .2;
  static const _mid = .5;
  static const _list = .62;
  static const _full = .96;
  static const _peekLimit = .3;

  google.GoogleMapController? _map;
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  late final OfficeMapServices _services;
  OfficeMapPins? _pins;
  List<OfficeModel> _allOffices = [];
  bool _loadingOffices = true;
  String? _officesError;
  bool _searchLocated = false;
  OfficeModel? _selected;
  LatLng? _position;
  OfficeRoute? _route;
  RouteTravelMode _travelMode = RouteTravelMode.drive;
  _OfficeSort _sort = _OfficeSort.nearest;
  List<MapPlace> _places = [];
  String _category = 'All offices';
  String? _message;
  bool _busy = false;
  bool _searching = false;
  int _searchVersion = 0;
  int _routeVersion = 0;
  double _sheetSize = _list;

  bool get _peeking => _sheetSize < _peekLimit;

  List<OfficeModel> get _offices {
    final query = _search.text.trim().toLowerCase();
    final offices = _allOffices.where((office) {
      final records = office.records.join(' ');
      final categoryMatch = switch (_category) {
        'Passport' => records.contains('Passport'),
        'SSS / UMID' => RegExp('SSS|UMID').hasMatch('${office.name} $records'),
        _ => true,
      };
      return categoryMatch &&
          '${office.name} ${office.agency} ${office.agencyName} ${office.address} $records'
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
    if (_selected != null) _sheetSize = _mid;
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
    _map?.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  LatLng? _point(OfficeModel office) {
    final latitude = office.latitude;
    final longitude = office.longitude;
    return latitude == null || longitude == null
        ? null
        : LatLng(latitude, longitude);
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

  void _collapse({double size = _mid}) {
    FocusScope.of(context).unfocus();
    if (_sheet.isAttached) {
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
  }

  void _toggleSheet() => _collapse(size: _peeking ? _mid : _peek);

  IconData get _modeIcon => switch (_travelMode) {
    RouteTravelMode.drive => Icons.directions_car_outlined,
    RouteTravelMode.walk => Icons.directions_walk,
    RouteTravelMode.transit => Icons.directions_transit,
  };

  String get _routeEstimate => _route == null
      ? _travelMode.label
      : '${_travelMode.label} • ${(_route!.seconds / 60).ceil()} min • ${(_route!.meters / 1000).toStringAsFixed(1)} km';

  void _select(OfficeModel office) {
    _routeVersion++;
    setState(() {
      _selected = office;
      _route = null;
      _message = null;
    });
    _collapse();
    _fit([?_point(office)]);
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
    double bottomPadding,
    bool dark,
  ) {
    final pins = _pins;
    final map = google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: _googlePoint(
          (selected == null ? null : _point(selected)) ?? _center,
        ),
        zoom: 12,
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
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
        for (var i = 0; i < _places.length; i++)
          google.Marker(
            markerId: google.MarkerId('place-$i'),
            position: _googlePoint(_places[i].point),
            infoWindow: google.InfoWindow(title: _places[i].name),
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
      polylines: {
        if (_route != null)
          google.Polyline(
            polylineId: const google.PolylineId('office-route'),
            points: _route!.points.map(_googlePoint).toList(),
            color: dark ? const Color(0xFF83B9FF) : _blue,
            width: 6,
          ),
      },
    );
    return widget.mapBuilder?.call(map) ?? map;
  }

  Future<void> _locate({bool keepFocus = false}) async {
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
      if (!keepFocus) FocusScope.of(context).unfocus();
      _fitNearest();
    } catch (error) {
      _showError(error, 'Could not find your location. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directions() async {
    final office = _selected;
    final destination = office == null ? null : _point(office);
    if (_busy || destination == null) return;
    final version = ++_routeVersion;
    setState(() {
      _busy = true;
      _message = null;
      _route = null;
    });
    try {
      final origin = await _services.locate();
      if (!mounted || version != _routeVersion) return;
      setState(() => _position = origin);
      final route = await _services.route(
        origin,
        destination,
        mode: _travelMode,
      );
      if (!mounted || version != _routeVersion) return;
      setState(() => _route = route);
      if (!_peeking) _collapse();
      _fit(route.points);
    } catch (error) {
      if (version == _routeVersion) {
        _showError(
          error,
          'Could not load directions. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
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
    _routeVersion++;
    _searchVersion++;
    setState(() {
      _selected = null;
      _route = null;
      _places = [];
      _searching = false;
      _message = null;
    });
  }

  Future<void> _searchPlaces() async {
    final query = _search.text.trim();
    if (query.length < 2 || _searching) return;
    FocusScope.of(context).unfocus();
    if (_offices.isNotEmpty) {
      _fitNearest();
      return;
    }
    final version = ++_searchVersion;
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final places = await _services.search(query);
      if (!mounted || version != _searchVersion) return;
      setState(() {
        _places = places;
        if (places.isEmpty) {
          _message = 'No places found. Try a city or a different name.';
        }
      });
      _collapse();
      _fit(places.map((p) => p.point).toList());
    } catch (error) {
      if (version == _searchVersion) {
        _showError(
          error,
          'Search is unavailable. Check your connection and try again.',
        );
      }
    } finally {
      if (mounted && version == _searchVersion) {
        setState(() => _searching = false);
      }
    }
  }

  // Shared surfaces -----------------------------------------------------------

  bool get _dark => Theme.of(context).brightness == Brightness.dark;

  Color _surface(ColorScheme colors) =>
      _dark ? colors.surfaceContainer : Colors.white;

  Color _border(ColorScheme colors) => _dark
      ? colors.outlineVariant.withValues(alpha: .35)
      : const Color(0xFFE3ECF7);

  // Header --------------------------------------------------------------------

  Widget _backButton(ColorScheme colors) => IconButton(
    tooltip: 'Back',
    onPressed: () => Navigator.maybePop(context),
    color: colors.primary,
    icon: const Icon(Icons.arrow_back_rounded),
  );

  Widget _searchField(ColorScheme colors) {
    OutlineInputBorder border(Color color) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color),
    );
    return TextField(
      controller: _search,
      textInputAction: TextInputAction.search,
      onChanged: (text) {
        _filterChanged();
        // Results rank by distance, so the first search asks for the location.
        if (text.trim().isNotEmpty && _position == null && !_searchLocated) {
          _searchLocated = true;
          _locate(keepFocus: true);
        }
      },
      onSubmitted: (_) => _searchPlaces(),
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: 'Search offices or places',
        filled: true,
        fillColor: _surface(colors),
        isDense: true,
        prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
        suffixIcon: _searching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : _search.text.isNotEmpty
            ? IconButton(
                tooltip: 'Clear search',
                onPressed: () {
                  _search.clear();
                  _filterChanged();
                },
                icon: const Icon(Icons.cancel_rounded, size: 20),
              )
            : null,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        enabledBorder: border(_border(colors)),
        focusedBorder: border(colors.primary),
      ),
    );
  }

  Widget _locationIcon(ColorScheme colors, {double size = 18}) => _busy
      ? SizedBox.square(
          dimension: size - 2,
          child: const CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(
          _position == null ? Icons.near_me_outlined : Icons.near_me_rounded,
          size: size,
          color: colors.primary,
        );

  Widget _locationButton(ColorScheme colors) => OutlinedButton.icon(
    onPressed: _busy ? null : _locate,
    style: OutlinedButton.styleFrom(
      foregroundColor: colors.primary,
      backgroundColor: _position == null
          ? _surface(colors)
          : colors.primaryContainer,
      minimumSize: const Size.fromHeight(44),
      side: BorderSide(color: _border(colors)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700),
    ),
    icon: _locationIcon(colors),
    label: Text(
      _position == null
          ? 'Use my current location'
          : 'Using your current location',
    ),
  );

  Widget _messageBanner(ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Container(
      padding: const EdgeInsets.only(left: 14),
      decoration: BoxDecoration(
        color: _surface(colors),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border(colors)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(_message!, style: const TextStyle(fontSize: 12)),
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

  Widget _header(ColorScheme colors) {
    // Short screens keep the map usable with a single header row.
    if (MediaQuery.sizeOf(context).height < 500) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                _backButton(colors),
                Expanded(child: _searchField(colors)),
                IconButton(
                  tooltip: 'Use my current location',
                  onPressed: _busy ? null : _locate,
                  icon: _locationIcon(colors, size: 22),
                ),
              ],
            ),
            if (_message != null) _messageBanner(colors),
          ],
        ),
      );
    }
    // The arrow shares the title's line, with its left edge on the page margin.
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const BackPageHeader(
          'Office Finder',
          subtitle: 'Find government offices near you',
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _searchField(colors),
              const SizedBox(height: 8),
              _locationButton(colors),
              if (_message != null) _messageBanner(colors),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = _dark;
    final sheetColor = dark ? colors.surface : AppTheme.pageBackground;
    final offices = _offices;
    final selected = _selected;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Column(
        children: [
          SafeArea(bottom: false, child: _header(colors)),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    Positioned.fill(
                      child: _buildMap(
                        offices,
                        selected,
                        constraints.maxHeight * _sheetSize + 12,
                        dark,
                      ),
                    ),
                    if (constraints.maxHeight * (1 - _sheetSize) > 230)
                      Positioned(
                        right: 16,
                        bottom: constraints.maxHeight * _sheetSize + 16,
                        child: _mapControls(offices, colors),
                      ),
                    NotificationListener<DraggableScrollableNotification>(
                      onNotification: (notification) {
                        setState(() => _sheetSize = notification.extent);
                        return false;
                      },
                      child: DraggableScrollableSheet(
                        controller: _sheet,
                        initialChildSize: _sheetSize,
                        minChildSize: _peek,
                        maxChildSize: _full,
                        snap: true,
                        snapSizes: const [_peek, _mid, _list, _full],
                        // Intercept only the visible sheet, leaving the exposed map interactive.
                        builder: (context, scrollController) =>
                            PointerInterceptor(
                              child: Container(
                                // Keeps scrolled cards inside the rounded corners.
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: sheetColor,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(26),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: .1),
                                      blurRadius: 24,
                                      offset: const Offset(0, -4),
                                    ),
                                  ],
                                ),
                                child: ListView(
                                  controller: scrollController,
                                  padding: EdgeInsets.fromLTRB(
                                    20,
                                    8,
                                    20,
                                    MediaQuery.paddingOf(context).bottom + 24,
                                  ),
                                  children: [
                                    _sheetTop(offices, selected, colors),
                                    if (!_peeking) ...[
                                      if (selected != null)
                                        ..._details(selected, colors)
                                      else
                                        ..._officeList(offices, colors),
                                    ],
                                  ],
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
        ],
      ),
    );
  }

  Widget _mapControls(List<OfficeModel> offices, ColorScheme colors) =>
      PointerInterceptor(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: .14),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: FrostedSurface(
            borderRadius: BorderRadius.circular(18),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom in',
                    onPressed: () =>
                        _map?.animateCamera(google.CameraUpdate.zoomIn()),
                    icon: const Icon(Icons.add),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    onPressed: () =>
                        _map?.animateCamera(google.CameraUpdate.zoomOut()),
                    icon: const Icon(Icons.remove),
                  ),
                  IconButton(
                    tooltip: 'Show all offices',
                    onPressed: () => _fit(_located(offices)),
                    icon: const Icon(Icons.zoom_out_map_rounded),
                  ),
                  IconButton(
                    tooltip: 'My location',
                    onPressed: _busy ? null : _locate,
                    icon: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.my_location_rounded),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

  /// Drag handle plus the title row that stays visible when minimized.
  Widget _sheetTop(
    List<OfficeModel> offices,
    OfficeModel? selected,
    ColorScheme colors,
  ) => Column(
    children: [
      Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: colors.outlineVariant,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_peeking || selected != null)
                  Text(
                    _peeking ? (selected?.name ?? 'Offices') : 'Office details',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  )
                else
                  Text(
                    _countLabel(offices.length),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                if (_peeking)
                  Text(
                    selected == null
                        ? _countLabel(offices.length)
                        : _routeEstimate,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          // "Nearest" means nothing until the resident's location is known.
          if (!_peeking &&
              selected == null &&
              offices.length > 1 &&
              _position != null)
            _sortButton(colors),
          IconButton(
            tooltip: _peeking ? 'Expand panel' : 'Minimize panel',
            onPressed: _toggleSheet,
            icon: Icon(
              _peeking ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            ),
          ),
        ],
      ),
    ],
  );

  String _countLabel(int count) {
    if (_loadingOffices) return 'Loading offices…';
    final label = '$count ${count == 1 ? 'office' : 'offices'}';
    return _position == null ? label : '$label found near you';
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
      textStyle: Theme.of(context).textTheme.labelLarge
          ?.copyWith(fontSize: 12.5),
    ),
    icon: const Icon(Icons.swap_vert_rounded, size: 18),
    label: Text(_sort == _OfficeSort.nearest ? 'Nearest' : 'Name'),
  );

  Widget _categoryChips(ColorScheme colors) => Wrap(
    spacing: 8,
    runSpacing: 6,
    children: [
      for (final category in ['All offices', 'Passport', 'SSS / UMID'])
        ChoiceChip(
          label: Text(category),
          selected: _category == category,
          showCheckmark: false,
          backgroundColor: _surface(colors),
          selectedColor: _blue,
          labelStyle: TextStyle(
            color: _category == category ? Colors.white : colors.onSurface,
            fontWeight: FontWeight.w600,
          ),
          side: _category == category
              ? BorderSide.none
              : BorderSide(color: _border(colors)),
          shape: const StadiumBorder(),
          onSelected: (_) {
            _category = category;
            _filterChanged();
            _fit(_located(_offices));
          },
        ),
    ],
  );

  List<Widget> _officeList(List<OfficeModel> offices, ColorScheme colors) => [
    _categoryChips(colors),
    const SizedBox(height: 12),
    if (_loadingOffices)
      const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    if (_officesError != null) ...[
      const SizedBox(height: 8),
      Text(_officesError!, textAlign: TextAlign.center),
      const SizedBox(height: 6),
      Center(
        child: TextButton.icon(
          onPressed: _retryOffices,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Try again'),
        ),
      ),
    ],
    for (final office in offices) _officeCard(office, colors),
    if (!_loadingOffices &&
        _officesError == null &&
        offices.isEmpty &&
        _places.isEmpty) ...[
      const SizedBox(height: 8),
      Icon(
        Icons.travel_explore_rounded,
        size: 34,
        color: colors.onSurfaceVariant,
      ),
      const SizedBox(height: 10),
      const Text(
        'No matching offices',
        textAlign: TextAlign.center,
        style: TextStyle(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 6),
      Text(
        'Try another name or search for a place in the Philippines.',
        textAlign: TextAlign.center,
        style: TextStyle(color: colors.onSurfaceVariant),
      ),
      const SizedBox(height: 10),
      if (_search.text.trim().length >= 2)
        TextButton.icon(
          onPressed: _searching ? null : _searchPlaces,
          icon: const Icon(Icons.search),
          label: const Text('Search places on map'),
        ),
    ],
    for (final place in _places)
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.place_outlined),
        title: Text(place.name, maxLines: 3, overflow: TextOverflow.ellipsis),
        onTap: () {
          _collapse();
          _fit([place.point]);
        },
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
        width: 54,
        height: 54,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.primaryContainer,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(6),
        child: initials.isNotEmpty
            ? FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .4,
                    color: colors.onPrimaryContainer,
                  ),
                ),
              )
            : Icon(
                Icons.account_balance_outlined,
                color: colors.onPrimaryContainer,
              ),
      ),
    );
  }

  Widget _infoRow(
    ColorScheme colors,
    IconData icon,
    String text, {
    bool strong = false,
  }) {
    final color = strong ? colors.primary : colors.onSurfaceVariant;
    return Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5,
              color: color,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _officeCard(OfficeModel office, ColorScheme colors) {
    final meters = _metersTo(office);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: _surface(colors),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: _border(colors)),
        ),
        clipBehavior: Clip.antiAlias,
        child: MotionInkWell(
          onTap: () => _select(office),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
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
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          height: 1.25,
                        ),
                      ),
                      if (meters != null) ...[
                        const SizedBox(height: 4),
                        _infoRow(
                          colors,
                          Icons.location_on_rounded,
                          _distanceLabel(meters),
                          strong: true,
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        office.address,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      _infoRow(
                        colors,
                        Icons.schedule_rounded,
                        office.hoursOn(DateTime.now()),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: colors.primaryContainer,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          office.serviceTag,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: colors.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: colors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _details(OfficeModel office, ColorScheme colors) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            office.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          tooltip: 'Back to offices',
          onPressed: () {
            _filterChanged();
            _collapse(size: _list);
            _fit(_located(_offices));
          },
          icon: const Icon(Icons.close_rounded),
        ),
      ],
    ),
    const SizedBox(height: 4),
    Text(
      office.address,
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 13),
    ),
    const SizedBox(height: 12),
    Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        Chip(
          avatar: const Icon(Icons.badge_outlined, size: 16),
          label: Text(office.serviceTag),
          side: BorderSide.none,
        ),
        if (_route != null)
          Chip(
            avatar: Icon(_modeIcon, size: 16),
            label: Text(_routeEstimate),
            side: BorderSide.none,
          ),
      ],
    ),
    const SizedBox(height: 10),
    Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final mode in RouteTravelMode.values)
          ChoiceChip(
            label: Text(mode.label),
            selected: _travelMode == mode,
            selectedColor: colors.primaryContainer,
            onSelected: _busy
                ? null
                : (_) {
                    if (_travelMode == mode) return;
                    final recalculate = _route != null;
                    setState(() {
                      _travelMode = mode;
                      _route = null;
                      _message = null;
                    });
                    if (recalculate) _directions();
                  },
          ),
      ],
    ),
    const SizedBox(height: 10),
    FilledButton.icon(
      onPressed: _busy || _point(office) == null ? null : _directions,
      style: FilledButton.styleFrom(
        backgroundColor: _blue,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      icon: const Icon(Icons.route_rounded),
      label: Text(
        _busy
            ? 'Finding your route…'
            : _route == null
            ? 'Get directions'
            : 'Refresh route',
      ),
    ),
    const SizedBox(height: 12),
    if (_point(office) == null)
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          'This office has no map location yet, so directions are unavailable.',
          style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
        ),
      ),
    Text(
      _route == null
          ? '${_travelMode.label} directions from your current location.'
          : '${_travelMode.label} estimate • Expand for route steps.',
      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
    ),
    if (_travelMode == RouteTravelMode.transit)
      const Text(
        'Public transport depends on Google coverage; local jeepney and tricycle routes may be missing.',
        style: TextStyle(fontSize: 12),
      ),
    if (_travelMode == RouteTravelMode.walk)
      const Text(
        'Walking routes may lack sidewalks or pedestrian paths. Use caution.',
        style: TextStyle(fontSize: 12),
      ),
    const SizedBox(height: 8),
    Text(
      '${office.hoursOn(DateTime.now())} • Confirm before visiting',
      style: TextStyle(color: colors.onSurfaceVariant, fontSize: 12),
    ),
    if (_route != null) ...[
      const SizedBox(height: 18),
      const Text(
        'Route steps',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
      ),
      for (var i = 0; i < _route!.steps.length; i++)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 15,
            backgroundColor: colors.primaryContainer,
            child: Text(
              '${i + 1}',
              style: TextStyle(fontSize: 12, color: colors.onPrimaryContainer),
            ),
          ),
          title: Text(_route!.steps[i], style: const TextStyle(fontSize: 13)),
        ),
    ],
  ];
}
