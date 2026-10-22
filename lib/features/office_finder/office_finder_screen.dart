import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';

import 'map_services.dart';
import 'models/office_catalog.dart';
import 'models/office_model.dart';

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
  static const _blue = Color(0xFF174B85);
  static const _center = LatLng(14.8527, 120.8160);
  google.GoogleMapController? _map;
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  late final OfficeMapServices _services;
  OfficeModel? _selected;
  LatLng? _position;
  OfficeRoute? _route;
  RouteTravelMode _travelMode = RouteTravelMode.drive;
  List<MapPlace> _places = [];
  String _category = 'All offices';
  String? _message;
  bool _busy = false;
  bool _searching = false;
  int _searchVersion = 0;
  int _routeVersion = 0;
  double _sheetSize = .32;

  List<OfficeModel> get _offices {
    final query = _search.text.trim().toLowerCase();
    return officeCatalog.where((office) {
      final categoryMatch = switch (_category) {
        'Passport' => office.serviceTag.contains('Passport'),
        'SSS / UMID' => office.serviceTag.contains('UMID'),
        _ => true,
      };
      return categoryMatch &&
          '${office.name} ${office.address} ${office.serviceTag}'
              .toLowerCase()
              .contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _services = widget.services ?? OfficeMapServices();
    _selected = widget.initialOffice;
  }

  @override
  void dispose() {
    _search.dispose();
    _sheet.dispose();
    _map?.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  LatLng _point(OfficeModel office) =>
      LatLng(office.latitude, office.longitude);

  void _collapse({double size = .32}) {
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

  void _toggleSheet() {
    if (!_sheet.isAttached) return;
    FocusScope.of(context).unfocus();
    final target = _sheetSize < .24 ? .48 : .14;
    if (AppMotion.reduced(context)) {
      _sheet.jumpTo(target);
    } else {
      _sheet.animateTo(
        target,
        duration: AppMotion.duration(context),
        curve: Curves.easeOutCubic,
      );
    }
  }

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
    _collapse(size: .48);
    _fit([_point(office)]);
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
    BoxConstraints constraints,
    bool dark,
  ) {
    final map = google.GoogleMap(
      initialCameraPosition: google.CameraPosition(
        target: _googlePoint(selected == null ? _center : _point(selected)),
        zoom: 12,
      ),
      padding: EdgeInsets.only(
        top: constraints.maxHeight > 500 ? 230 : 150,
        bottom: constraints.maxHeight * _sheetSize + 12,
      ),
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
        _fit(
          selected == null ? offices.map(_point).toList() : [_point(selected)],
        );
      },
      onTap: (_) => FocusScope.of(context).unfocus(),
      markers: {
        for (final office in {...offices, ?selected})
          google.Marker(
            markerId: google.MarkerId('office-${office.id}'),
            position: _googlePoint(_point(office)),
            infoWindow: google.InfoWindow(
              title: office.name,
              snippet: office.address,
            ),
            icon: google.BitmapDescriptor.defaultMarkerWithHue(
              selected?.id == office.id
                  ? google.BitmapDescriptor.hueAzure
                  : google.BitmapDescriptor.hueRed,
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
            icon: google.BitmapDescriptor.defaultMarkerWithHue(
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

  Future<void> _locate() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final point = await _services.locate();
      if (!mounted) return;
      setState(() => _position = point);
      _collapse();
      _fit([point]);
    } catch (error) {
      _showError(error, 'Could not find your location. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _directions() async {
    final office = _selected;
    if (_busy || office == null) return;
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
        _point(office),
        mode: _travelMode,
      );
      if (!mounted || version != _routeVersion) return;
      setState(() => _route = route);
      if (_sheetSize >= .24) _collapse();
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
      _collapse();
      _fit(_offices.map(_point).toList());
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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? colors.surfaceContainer : const Color(0xFFF7F6F2);
    final offices = _offices;
    final selected = _selected;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Stack(
            children: [
              Positioned.fill(
                child: _buildMap(offices, selected, constraints, dark),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Column(
                      children: [
                        _panel(
                          surface,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(4, 5, 10, 5),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Back',
                                  onPressed: () => Navigator.maybePop(context),
                                  icon: const Icon(Icons.arrow_back_rounded),
                                ),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Office Finder',
                                        style: TextStyle(
                                          fontFamily: 'Bricolage Grotesque',
                                          fontSize: 22,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        'Your next step starts here',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    color: _blue.withValues(alpha: .1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    Icons.explore_outlined,
                                    color: dark
                                        ? const Color(0xFF83B9FF)
                                        : _blue,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _panel(
                          surface,
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onChanged: (_) => _filterChanged(),
                            onSubmitted: (_) => _searchPlaces(),
                            decoration: InputDecoration(
                              hintText: 'Search offices or places',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(16),
                                      child: SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _search.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: () {
                                        _search.clear();
                                        _filterChanged();
                                      },
                                      icon: const Icon(Icons.close_rounded),
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 16,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 40,
                          child: ListView(
                            scrollDirection: Axis.horizontal,
                            children: [
                              for (final category in [
                                'All offices',
                                'Passport',
                                'SSS / UMID',
                              ])
                                Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(category),
                                    selected: _category == category,
                                    showCheckmark: false,
                                    backgroundColor: surface,
                                    selectedColor: _blue,
                                    labelStyle: TextStyle(
                                      color: _category == category
                                          ? Colors.white
                                          : colors.onSurface,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    side: BorderSide.none,
                                    shape: const StadiumBorder(),
                                    onSelected: (_) {
                                      _category = category;
                                      _filterChanged();
                                      _collapse();
                                      _fit(_offices.map(_point).toList());
                                    },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: _panel(
                              surface,
                              child: Padding(
                                padding: const EdgeInsets.only(left: 14),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _message!,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Dismiss message',
                                      onPressed: () =>
                                          setState(() => _message = null),
                                      icon: const Icon(Icons.close, size: 18),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_sheetSize < .5 && constraints.maxHeight > 500)
                Positioned(
                  right: 16,
                  bottom: constraints.maxHeight * _sheetSize + 36,
                  child: _panel(
                    surface,
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
                          onPressed: () => _map?.animateCamera(
                            google.CameraUpdate.zoomOut(),
                          ),
                          icon: const Icon(Icons.remove),
                        ),
                        IconButton(
                          tooltip: 'Show all offices',
                          onPressed: () {
                            _collapse();
                            _fit(offices.map(_point).toList());
                          },
                          icon: const Icon(Icons.zoom_out_map_rounded),
                        ),
                        IconButton(
                          tooltip: 'My location',
                          onPressed: _busy ? null : _locate,
                          icon: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.my_location_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
              NotificationListener<DraggableScrollableNotification>(
                onNotification: (notification) {
                  setState(() => _sheetSize = notification.extent);
                  return false;
                },
                child: DraggableScrollableSheet(
                  controller: _sheet,
                  initialChildSize: .32,
                  minChildSize: .14,
                  maxChildSize: .78,
                  snap: true,
                  snapSizes: const [.14, .32, .48, .78],
                  // Intercept only the visible sheet, leaving the exposed map interactive.
                  builder: (context, scrollController) => PointerInterceptor(
                    child: Container(
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(28),
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
                          10,
                          20,
                          MediaQuery.paddingOf(context).bottom + 24,
                        ),
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _sheetSize < .24
                                          ? (selected?.name ?? 'Offices')
                                          : (selected == null
                                                ? 'Offices'
                                                : 'Office details'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    if (_sheetSize < .24)
                                      Text(
                                        selected == null
                                            ? '${offices.length} offices'
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
                              IconButton(
                                tooltip: _sheetSize < .24
                                    ? 'Expand panel'
                                    : 'Minimize panel',
                                onPressed: _toggleSheet,
                                icon: Icon(
                                  _sheetSize < .24
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                ),
                              ),
                            ],
                          ),
                          if (_sheetSize >= .24) ...[
                            if (selected != null)
                              ..._details(selected, colors)
                            else ...[
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Find your office',
                                      style: TextStyle(
                                        fontFamily: 'Bricolage Grotesque',
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${offices.length} ${offices.length == 1 ? 'office' : 'offices'}',
                                    style: TextStyle(
                                      color: colors.onSurfaceVariant,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Explore Bulacan • Tap a pin or choose an office',
                                style: TextStyle(
                                  color: colors.onSurfaceVariant,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 16),
                              for (final office in offices)
                                _officeCard(office, colors),
                              if (offices.isEmpty && _places.isEmpty) ...[
                                const Icon(
                                  Icons.travel_explore_rounded,
                                  size: 34,
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'No matching offices',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Try another name or search for a place in the Philippines.',
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 10),
                                if (_search.text.trim().length >= 2)
                                  TextButton.icon(
                                    onPressed: _searching
                                        ? null
                                        : _searchPlaces,
                                    icon: const Icon(Icons.search),
                                    label: const Text('Search places on map'),
                                  ),
                              ],
                              for (final place in _places)
                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const Icon(Icons.place_outlined),
                                  title: Text(
                                    place.name,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () {
                                    _collapse();
                                    _fit([place.point]);
                                  },
                                ),
                            ],
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
    );
  }

  Widget _panel(Color color, {required Widget child}) => PointerInterceptor(
    child: Material(
      color: color,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: .18),
      borderRadius: BorderRadius.circular(20),
      child: child,
    ),
  );

  Widget _officeCard(OfficeModel office, ColorScheme colors) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: MotionInkWell(
        onTap: () => _select(office),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _blue.withValues(alpha: .1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.account_balance_outlined,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? const Color(0xFF83B9FF)
                      : _blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      office.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      office.address,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      office.serviceTag,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    ),
  );

  List<Widget> _details(OfficeModel office, ColorScheme colors) => [
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            office.name,
            style: const TextStyle(
              fontFamily: 'Bricolage Grotesque',
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Back to offices',
          onPressed: () {
            _filterChanged();
            _fit(_offices.map(_point).toList());
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
      onPressed: _busy ? null : _directions,
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
      'Listed hours: ${office.operatingHours.replaceFirst('Today: ', '')} • Confirm before visiting',
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
            backgroundColor: _blue.withValues(alpha: .1),
            child: Text(
              '${i + 1}',
              style: TextStyle(fontSize: 12, color: colors.onSurface),
            ),
          ),
          title: Text(_route!.steps[i], style: const TextStyle(fontSize: 13)),
        ),
    ],
  ];
}
