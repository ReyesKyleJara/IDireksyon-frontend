import '../../core/widgets/app_motion.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_services.dart';
import 'models/office_catalog.dart';
import 'models/office_model.dart';

class OfficeFinderScreen extends StatefulWidget {
  const OfficeFinderScreen({
    super.key,
    this.initialOffice,
    this.services,
    this.tileProvider,
  });
  final OfficeModel? initialOffice;
  final OfficeMapServices? services;
  final TileProvider? tileProvider;

  @override
  State<OfficeFinderScreen> createState() => _OfficeFinderScreenState();
}

class _OfficeFinderScreenState extends State<OfficeFinderScreen> {
  static const _blue = Color(0xFF174B85);
  static const _center = LatLng(14.8527, 120.8160);
  final _map = MapController();
  final _sheet = DraggableScrollableController();
  final _search = TextEditingController();
  late final OfficeMapServices _services;
  OfficeModel? _selected;
  LatLng? _position;
  OfficeRoute? _route;
  List<MapPlace> _places = [];
  String _category = 'All offices';
  String? _message;
  bool _busy = false;
  bool _searching = false;
  bool _tileError = false;
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
    _map.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  LatLng _point(OfficeModel office) =>
      LatLng(office.latitude, office.longitude);

  void _collapse() {
    FocusScope.of(context).unfocus();
    if (_sheet.isAttached) {
      if (AppMotion.reduced(context)) {
        _sheet.jumpTo(.32);
        return;
      }
      _sheet.animateTo(
        .32,
        duration: AppMotion.duration(context),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _select(OfficeModel office) {
    _routeVersion++;
    setState(() {
      _selected = office;
      _route = null;
      _message = null;
    });
    _collapse();
    _fit([_point(office)]);
  }

  void _fit(List<LatLng> points) {
    if (points.isEmpty) return;
    final size = MediaQuery.sizeOf(context);
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: points,
        maxZoom: points.length == 1 ? 15 : 14,
        padding: EdgeInsets.fromLTRB(
          55,
          (size.height * .4).clamp(150, 250),
          70,
          size.height * .32 + 35,
        ),
      ),
    );
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
      final route = await _services.route(origin, _point(office));
      if (!mounted || version != _routeVersion) return;
      setState(() => _route = route);
      _collapse();
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
                child: FlutterMap(
                  mapController: _map,
                  options: MapOptions(
                    initialCenter: selected == null
                        ? _center
                        : _point(selected),
                    initialZoom: 12,
                    minZoom: 5,
                    maxZoom: 18,
                    backgroundColor: dark
                        ? const Color(0xFF252B31)
                        : const Color(0xFFE9E9E3),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                    onMapReady: () => _fit(
                      selected == null
                          ? offices.map(_point).toList()
                          : [_point(selected)],
                    ),
                    onTap: (_, _) => FocusScope.of(context).unfocus(),
                  ),
                  children: [
                    for (final layer in ['Base', 'Reference'])
                      TileLayer(
                        tileProvider: widget.tileProvider,
                        key: ValueKey('$dark-$layer-$_tileError'),
                        urlTemplate:
                            'https://server.arcgisonline.com/ArcGIS/rest/services/Canvas/World_${dark ? 'Dark' : 'Light'}_Gray_$layer/MapServer/tile/{z}/{y}/{x}',
                        userAgentPackageName: 'com.bayanid.idireksyon',
                        maxNativeZoom: 16,
                        errorTileCallback: (_, _, _) {
                          if (!_tileError && mounted) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (mounted && !_tileError) {
                                setState(() => _tileError = true);
                              }
                            });
                          }
                        },
                      ),
                    if (_route != null)
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _route!.points,
                            color: dark ? const Color(0xFF83B9FF) : _blue,
                            strokeWidth: 6,
                            borderStrokeWidth: 2,
                            borderColor: colors.surface,
                          ),
                        ],
                      ),
                    MarkerLayer(
                      markers: [
                        for (final office in {...offices, ?selected})
                          Marker(
                            point: _point(office),
                            width: 56,
                            height: 64,
                            child: Semantics(
                              label: office.name,
                              button: true,
                              child: GestureDetector(
                                onTap: () => _select(office),
                                child: AnimatedContainer(
                                  duration: AppMotion.duration(
                                    context,
                                    AppMotion.quick,
                                  ),
                                  margin: EdgeInsets.all(
                                    selected?.id == office.id ? 2 : 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: selected?.id == office.id
                                        ? _blue
                                        : surface,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: selected?.id == office.id
                                          ? Colors.white
                                          : _blue,
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: .18,
                                        ),
                                        blurRadius: 12,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    office.serviceTag.contains('Passport')
                                        ? Icons.badge_outlined
                                        : Icons.account_balance_rounded,
                                    color: selected?.id == office.id
                                        ? Colors.white
                                        : dark
                                        ? const Color(0xFF83B9FF)
                                        : _blue,
                                    size: 23,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        for (final place in _places)
                          Marker(
                            point: place.point,
                            width: 44,
                            height: 44,
                            child: Tooltip(
                              message: place.name,
                              child: const Icon(
                                Icons.location_on,
                                color: Color(0xFFC84648),
                                size: 40,
                              ),
                            ),
                          ),
                        if (_position != null)
                          Marker(
                            point: _position!,
                            width: 28,
                            height: 28,
                            child: Semantics(
                              label: 'Your location',
                              child: Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3488EF),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.white,
                                    width: 4,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: _blue.withValues(alpha: .25),
                                      spreadRadius: 7,
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
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
                        if (_message != null || _tileError)
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
                                        _message ?? 'Map tiles could not load. Check your connection.',
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    if (_message == null)
                                      TextButton(
                                        onPressed: () =>
                                            setState(() => _tileError = false),
                                        child: const Text('Retry'),
                                      )
                                    else
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
                          onPressed: () => _map.move(
                            _map.camera.center,
                            (_map.camera.zoom + 1).clamp(5, 18),
                          ),
                          icon: const Icon(Icons.add),
                        ),
                        IconButton(
                          tooltip: 'Zoom out',
                          onPressed: () => _map.move(
                            _map.camera.center,
                            (_map.camera.zoom - 1).clamp(5, 18),
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
              Positioned(
                left: 0,
                right: 0,
                bottom: constraints.maxHeight * _sheetSize + 3,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: surface.withValues(alpha: .94),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Esri, HERE, Garmin | © OpenStreetMap contributors',
                      style: TextStyle(fontSize: 9),
                    ),
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
                  minChildSize: .18,
                  maxChildSize: .78,
                  snap: true,
                  snapSizes: const [.32, .78],
                  builder: (context, scrollController) => Container(
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
                        Center(
                          child: Container(
                            width: 38,
                            height: 4,
                            decoration: BoxDecoration(
                              color: colors.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
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
                            const Icon(Icons.travel_explore_rounded, size: 34),
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
                                onPressed: _searching ? null : _searchPlaces,
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

  Widget _panel(Color color, {required Widget child}) => Material(
    color: color,
    elevation: 4,
    shadowColor: Colors.black.withValues(alpha: .18),
    borderRadius: BorderRadius.circular(20),
    child: child,
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
            avatar: const Icon(Icons.directions_car_outlined, size: 16),
            label: Text(
              '${(_route!.seconds / 60).ceil()} min • ${(_route!.meters / 1000).toStringAsFixed(1)} km',
            ),
            side: BorderSide.none,
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
          ? 'Driving directions from your current location, right here in IDireksyon.'
          : 'Driving route • Estimate excludes live traffic. Expand for route steps.',
      style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
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
