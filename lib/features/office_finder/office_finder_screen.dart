import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as google;
import 'package:latlong2/latlong.dart';

import '../../core/auth/auth_service.dart';
import '../../core/widgets/app_motion.dart';
import '../ids/barangay_offices.dart';
import 'map_services.dart';
import 'models/office_model.dart';
import 'office_details_screen.dart';
import 'office_finder_widgets.dart';

/// Which offices the chips show.
enum OfficeFilter { all, nearby, openNow }

/// The Office Finder list: search, filters, and one card per office. Opening
/// an office goes to [OfficeDetailsScreen].
class OfficeFinderScreen extends StatefulWidget {
  const OfficeFinderScreen({
    super.key,
    this.initialOffice,
    this.services,
    this.mapBuilder,
    this.launchDirections,
    this.showRoadEstimates,
    this.now,
  });

  /// Opens straight to this office's details, for links from other pages.
  final OfficeModel? initialOffice;
  final OfficeMapServices? services;
  final Widget Function(google.GoogleMap)? mapBuilder;
  final Future<bool> Function(Uri)? launchDirections;

  /// Null follows the server's switch (`meta.travel_times` on `GET /offices`),
  /// because travel estimates make billable Routes API calls. Tests set it.
  final bool? showRoadEstimates;

  /// The clock, for tests.
  final DateTime Function()? now;

  @override
  State<OfficeFinderScreen> createState() => _OfficeFinderScreenState();
}

class _OfficeFinderScreenState extends State<OfficeFinderScreen> {
  /// How far "Nearby" reaches, in a straight line.
  static const nearbyMeters = 10000.0;

  final _search = TextEditingController();
  late final OfficeMapServices _services;
  List<OfficeModel> _allOffices = [];
  bool _loadingOffices = true;
  String? _officesError;
  LatLng? _position;
  OfficeFilter _filter = OfficeFilter.all;
  String? _message;
  bool _locating = false;
  Timer? _clock;

  DateTime get _now => widget.now?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _services = widget.services ?? OfficeMapServices();
    AuthService.instance.addListener(_authChanged);
    if (widget.initialOffice == null) {
      _loadOffices();
      _quietLocate();
      // Keeps "Open Now" true while the list is open.
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_authChanged);
    _clock?.cancel();
    _search.dispose();
    if (widget.services == null) _services.dispose();
    super.dispose();
  }

  /// A saved or changed barangay in Account Details updates the list.
  void _authChanged() {
    if (mounted) setState(() {});
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

  /// Uses the location only if permission was already given; never prompts.
  Future<void> _quietLocate() async {
    final point = await _services.locateIfAllowed();
    if (!mounted || point == null || _position != null) return;
    setState(() => _position = point);
  }

  Future<bool> _locate() async {
    if (_locating) return false;
    setState(() {
      _locating = true;
      _message = null;
    });
    try {
      final point = await _services.locate();
      if (!mounted) return false;
      setState(() => _position = point);
      return true;
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is StateError
              ? error.message.toString()
              : 'Could not find your location. Please try again.',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _choose(OfficeFilter filter) async {
    FocusScope.of(context).unfocus();
    if (filter == OfficeFilter.nearby && _position == null) {
      if (!await _locate()) return;
    }
    if (mounted) setState(() => _filter = filter);
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

  double? _metersTo(OfficeModel office) {
    final position = _position;
    final point = _point(office);
    if (position == null || point == null) return null;
    return const Distance().distance(position, point).toDouble();
  }

  bool _isOwnBarangay(OfficeModel office) {
    final resident = BarangayOffices.residentBarangayId(
      AuthService.instance.user,
    );
    return resident != null && office.barangayId == resident;
  }

  List<OfficeModel> get _offices {
    final query = _search.text.trim().toLowerCase();
    final now = _now;
    final offices = _allOffices.where((office) {
      final records = office.records.join(' ');
      final matches =
          '${office.name} ${office.agency} ${office.agencyName} ${office.address} $records'
              .toLowerCase()
              .contains(query);
      if (!matches) return false;
      return switch (_filter) {
        OfficeFilter.all => true,
        OfficeFilter.nearby =>
          (_metersTo(office) ?? double.infinity) <= nearbyMeters,
        OfficeFilter.openNow => office.openStateAt(now)?.open ?? false,
      };
    }).toList();
    if (_position != null) {
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

  Future<void> _open(OfficeModel office) async {
    FocusScope.of(context).unfocus();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => OfficeDetailsScreen(
          office: office,
          services: _services,
          position: _position,
          officesLoaded: true,
          mapBuilder: widget.mapBuilder,
          launchDirections: widget.launchDirections,
          showRoadEstimates: widget.showRoadEstimates,
          now: widget.now,
          onPosition: (point) {
            if (mounted && _position == null) {
              setState(() => _position = point);
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initialOffice;
    if (initial != null) {
      return OfficeDetailsScreen(
        office: initial,
        services: _services,
        mapBuilder: widget.mapBuilder,
        launchDirections: widget.launchDirections,
        showRoadEstimates: widget.showRoadEstimates,
        now: widget.now,
      );
    }
    final offices = _offices;
    return Scaffold(
      backgroundColor: OfficeLook.page(context),
      body: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: CustomScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  sliver: SliverList.list(
                    children: [
                      _header(),
                      const SizedBox(height: 14),
                      _searchField(),
                      const SizedBox(height: 12),
                      _filters(),
                      if (_message != null) _messageBanner(),
                      const SizedBox(height: 8),
                      _summaryLine(offices.length),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    4,
                    16,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  sliver: SliverList.list(children: _listBody(offices)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header() {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: 'Office Finder',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
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
                    'Office Finder',
                    style: TextStyle(
                      fontSize: 28,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: OfficeLook.ink(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 2),
            child: Text(
              'Find government offices, view details, and get directions quickly and easily.',
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchField() {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: OfficeLook.cardBox(context, radius: 16),
      child: TextField(
        controller: _search,
        textInputAction: TextInputAction.search,
        onChanged: (_) => setState(() => _message = null),
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search office or agency',
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 22,
            color: colors.onSurfaceVariant,
          ),
          suffixIcon: _search.text.isNotEmpty
              ? IconButton(
                  tooltip: 'Clear search',
                  onPressed: () => setState(_search.clear),
                  icon: const Icon(Icons.cancel_rounded, size: 18),
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _filters() => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    clipBehavior: Clip.none,
    child: Row(
      children: [
        _chip(OfficeFilter.all, 'All', null),
        const SizedBox(width: 8),
        _chip(
          OfficeFilter.nearby,
          'Nearby',
          Icons.location_on_outlined,
          busy: _locating,
        ),
        const SizedBox(width: 8),
        _chip(OfficeFilter.openNow, 'Open Now', Icons.schedule_rounded),
      ],
    ),
  );

  Widget _chip(
    OfficeFilter filter,
    String label,
    IconData? icon, {
    bool busy = false,
  }) {
    final selected = _filter == filter;
    final foreground = selected ? Colors.white : OfficeLook.ink(context);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? OfficeLook.action(context) : OfficeLook.card(context),
        shape: StadiumBorder(
          side: BorderSide(
            color: selected ? Colors.transparent : OfficeLook.border(context),
          ),
        ),
        child: InkWell(
          key: ValueKey('office-filter-${filter.name}'),
          customBorder: const StadiumBorder(),
          onTap: busy ? null : () => _choose(filter),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (busy)
                  SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  )
                else if (icon != null)
                  Icon(icon, size: 18, color: foreground),
                if (busy || icon != null) const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _messageBanner() {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
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

  Widget _summaryLine(int count) {
    if (_loadingOffices || _officesError != null) return const SizedBox();
    final parts = [
      '$count ${count == 1 ? 'office' : 'offices'}',
      if (_position != null) 'nearest first',
      if (_position != null && count > 0) 'straight-line distances',
    ];
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
      child: Text(
        parts.join(' · '),
        style: TextStyle(
          fontSize: 12.5,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }

  List<Widget> _listBody(List<OfficeModel> offices) {
    if (_loadingOffices) {
      return const [
        Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_officesError != null) {
      return [
        _statePanel(
          icon: Icons.cloud_off_rounded,
          title: _officesError!,
          action: TextButton.icon(
            onPressed: _retryOffices,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ),
      ];
    }
    if (offices.isEmpty) {
      return [
        switch (_filter) {
          OfficeFilter.nearby => _statePanel(
            icon: Icons.location_searching_rounded,
            title: 'No offices nearby',
            body: 'No offices found within 10 km. Tap All to see every office.',
          ),
          OfficeFilter.openNow => _statePanel(
            icon: Icons.schedule_rounded,
            title: 'No offices open right now',
            body: 'Only offices with listed hours are shown. Tap All to see every office.',
          ),
          OfficeFilter.all => _statePanel(
            icon: Icons.travel_explore_rounded,
            title: 'No matching offices',
            body: 'Try another office name, agency, or address.',
          ),
        },
      ];
    }
    return [for (final office in offices) _officeCard(office)];
  }

  /// Empty and error states share one calm layout.
  Widget _statePanel({
    required IconData icon,
    required String title,
    String? body,
    Widget? action,
  }) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 28, 12, 8),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: OfficeLook.tint(context),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: OfficeLook.ink(context)),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700),
          ),
          if (body != null) ...[
            const SizedBox(height: 4),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
          ?action,
        ],
      ),
    );
  }

  Widget _officeCard(OfficeModel office) {
    final meters = _metersTo(office);
    final state = office.openStateAt(_now);
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: OfficeLook.cardBox(context),
        child: Material(
          type: MaterialType.transparency,
          child: MotionInkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => _open(office),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
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
                            Text(
                              office.name,
                              style: const TextStyle(
                                fontSize: 16.5,
                                height: 1.25,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (_isOwnBarangay(office)) ...[
                              const SizedBox(height: 4),
                              YourBarangayTag(office: office),
                            ],
                            const SizedBox(height: 4),
                            OfficeFact(
                              icon: Icons.location_on_outlined,
                              text: office.address,
                            ),
                            if (meters != null || state != null) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 12,
                                runSpacing: 6,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  if (meters != null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.near_me_rounded,
                                          size: 15,
                                          color: OfficeLook.ink(context),
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          OfficeLook.distance(meters),
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            color: colors.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (state != null)
                                    OfficeStatusPill(state: state),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 4),
                        child: Icon(
                          Icons.chevron_right_rounded,
                          color: OfficeLook.ink(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => _open(office),
                    style: FilledButton.styleFrom(
                      backgroundColor: OfficeLook.action(context),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    child: Text(
                      'View Office',
                      semanticsLabel: 'View ${office.name}',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
