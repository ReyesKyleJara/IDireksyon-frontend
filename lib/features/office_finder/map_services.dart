import 'dart:convert';

import '../../core/api_config.dart';
import '../../core/auth/auth_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models/office_model.dart';

/// A driving route: its length, time, and the points of the line on the map.
class RoadEstimate {
  const RoadEstimate(this.meters, this.seconds, [this.path = const []]);
  final double meters;
  final int seconds;

  /// Empty when Google sent no line; the time and distance still show.
  final List<LatLng> path;
}

/// A Google Maps driving-directions link to [destination]. With [origin], the
/// route starts there; without it, Google Maps starts from the device's own
/// location. Residents can switch to walking or commuting in Google Maps.
Uri googleMapsDirections(LatLng destination, LatLng? origin) =>
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      if (origin != null) 'origin': '${origin.latitude},${origin.longitude}',
      'destination': '${destination.latitude},${destination.longitude}',
      'travelmode': 'driving',
    });

/// Reads Google's encoded polyline format. Anything malformed gives an empty
/// line rather than an error, because the line is only a visual extra.
List<LatLng> decodePolyline(String? encoded) {
  if (encoded == null || encoded.isEmpty) return const [];
  final points = <LatLng>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;
  int? next() {
    var result = 0;
    var shift = 0;
    while (true) {
      if (index >= encoded.length || shift > 30) return null;
      final byte = encoded.codeUnitAt(index++) - 63;
      if (byte < 0) return null;
      result |= (byte & 0x1f) << shift;
      shift += 5;
      if (byte < 0x20) break;
    }
    return (result & 1) != 0 ? ~(result >> 1) : result >> 1;
  }

  while (index < encoded.length) {
    final dLat = next();
    final dLng = next();
    if (dLat == null || dLng == null) return const [];
    latitude += dLat;
    longitude += dLng;
    final point = (latitude / 1e5, longitude / 1e5);
    if (point.$1.abs() > 90 || point.$2.abs() > 180) return const [];
    points.add(LatLng(point.$1, point.$2));
  }
  return points;
}

/// A route Google could not find. Kept so the same question is not asked twice.
class TravelUnavailable implements Exception {
  const TravelUnavailable(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Published offices, the device location, and travel estimates for the Office Finder.
class OfficeMapServices {
  OfficeMapServices({
    http.Client? client,
    String? baseUrl,
    String? Function()? token,
  }) : _client = client ?? http.Client(),
       _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), ''),
       _token = token ?? (() => AuthService.instance.token);
  final String _baseUrl;
  final http.Client _client;
  final String? Function() _token;

  // Memory only: a repeat from about the same spot costs no second Google call.
  final Map<String, RoadEstimate> _estimates = {};
  final Map<String, TravelUnavailable> _noRoutes = {};

  /// Whether the server offers travel times, from the last office list.
  /// Off unless the server says so, because each estimate is a paid call.
  bool get travelTimes => _travelTimes;
  bool _travelTimes = false;

  /// The location without asking: null unless permission was already given.
  /// Lets the map show the resident and nearby offices as soon as it opens.
  Future<LatLng?> locateIfAllowed() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.always &&
          permission != LocationPermission.whileInUse) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LatLng(position.latitude, position.longitude);
    } catch (_) {
      // Unsupported here, timed out, or refused: the resident can still tap.
      return null;
    }
  }

  Future<LatLng> locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw StateError('Turn on location services, then try again.');
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw StateError(
        'Allow location access in your device settings to show offices near you.',
      );
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw StateError('Allow location access to use your current position.');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    return LatLng(position.latitude, position.longitude);
  }

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  Future<List<OfficeModel>> offices() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/offices'), headers: _headers)
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Offices are unavailable. Please try again.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final meta = body['meta'];
    _travelTimes = meta is Map && meta['travel_times'] == true;
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(OfficeModel.fromJson)
        .toList();
  }

  /// The driving route. Throws [TravelUnavailable] when Google has none, and
  /// [StateError] for anything that may work if tried again.
  Future<RoadEstimate> roadEstimate(String officeId, LatLng origin) async {
    // About 100 m, so a small GPS drift reuses the answer.
    final key =
        '$officeId|${origin.latitude.toStringAsFixed(3)}|${origin.longitude.toStringAsFixed(3)}';
    final known = _estimates[key];
    if (known != null) return known;
    final missing = _noRoutes[key];
    if (missing != null) throw missing;
    final token = _token();
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/auth/offices/$officeId/route'),
          headers: {
            ..._headers,
            if (token != null) 'Authorization': 'Bearer $token',
          },
          body: jsonEncode({
            'latitude': origin.latitude,
            'longitude': origin.longitude,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      final message = _estimateProblem(response);
      if (_code(response) == 'no_route') {
        throw _noRoutes[key] = TravelUnavailable(message);
      }
      throw StateError(message);
    }
    final data =
        (jsonDecode(response.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    final polyline = data['polyline'];
    return _estimates[key] = RoadEstimate(
      (data['distance_meters'] as num).toDouble(),
      (data['duration_seconds'] as num).toInt(),
      decodePolyline(polyline is String ? polyline : null),
    );
  }

  static Object? _code(http.Response response) {
    try {
      return (jsonDecode(response.body) as Map<String, dynamic>)['code'];
    } catch (_) {
      // Not JSON, so the general message applies.
      return null;
    }
  }

  String _estimateProblem(http.Response response) {
    if (response.statusCode == 401) {
      return 'Log in again to see travel time.';
    }
    if (response.statusCode == 429) {
      return 'Too many requests. Please wait a moment, then try again.';
    }
    return switch (_code(response)) {
      'no_route' => 'No driving route was found to this office.',
      'office_no_location' =>
        'Travel time is not available for this office yet.',
      null when response.statusCode == 422 =>
        'Travel time is only available within the Philippines.',
      _ => 'Travel time is unavailable right now.',
    };
  }

  void dispose() => _client.close();
}
