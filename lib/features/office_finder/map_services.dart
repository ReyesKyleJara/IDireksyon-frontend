import 'dart:convert';

import '../../core/api_config.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

enum RouteTravelMode {
  drive('DRIVE', 'Drive'),
  walk('WALK', 'Walk'),
  transit('TRANSIT', 'Public transport');

  const RouteTravelMode(this.apiValue, this.label);
  final String apiValue;
  final String label;
}

class MapPlace {
  const MapPlace(this.name, this.point);
  final String name;
  final LatLng point;
}

class OfficeRoute {
  const OfficeRoute(this.points, this.meters, this.seconds, this.steps);
  final List<LatLng> points;
  final double meters;
  final double seconds;
  final List<String> steps;

  factory OfficeRoute.fromBrowserJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>)
        .map(
          (point) => LatLng(
            (point[0] as num).toDouble(),
            (point[1] as num).toDouble(),
          ),
        )
        .toList();
    if (points.length < 2) {
      throw const FormatException('Missing route geometry');
    }
    return OfficeRoute(
      points,
      (json['distanceMeters'] as num).toDouble(),
      (json['durationMillis'] as num).toDouble() / 1000,
      (json['steps'] as List<dynamic>).cast<String>(),
    );
  }

  factory OfficeRoute.fromJson(Map<String, dynamic> json) {
    final points = <LatLng>[];
    final encoded = json['polyline']['encodedPolyline'] as String;
    var index = 0, latitude = 0, longitude = 0;
    int decode() {
      var result = 0, shift = 0, byte = 0;
      do {
        if (index >= encoded.length || shift > 30) {
          throw const FormatException('Invalid route geometry');
        }
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 31) << shift;
        shift += 5;
      } while (byte >= 32);
      // JavaScript bitwise complements are unsigned in Dart web builds.
      // Arithmetic keeps negative coordinate deltas signed on every platform.
      return (result & 1) != 0 ? -(result >> 1) - 1 : result >> 1;
    }

    while (index < encoded.length) {
      latitude += decode();
      longitude += decode();
      points.add(LatLng(latitude / 1e5, longitude / 1e5));
    }
    if (points.length < 2) {
      throw const FormatException('Missing route geometry');
    }
    final steps = <String>[];
    for (final leg in json['legs'] as List<dynamic>? ?? []) {
      for (final step in leg['steps'] as List<dynamic>? ?? []) {
        final instruction =
            step['navigationInstruction']?['instructions'] as String?;
        if (instruction != null && instruction.isNotEmpty) {
          steps.add(instruction);
        } else if (step['transitDetails'] is Map<String, dynamic>) {
          final transit = step['transitDetails'] as Map<String, dynamic>;
          final line = transit['transitLine'];
          final stops = transit['stopDetails'];
          final name =
              line?['nameShort'] ?? line?['name'] ?? 'Public transport';
          final departure = stops?['departureStop']?['name'];
          final arrival = stops?['arrivalStop']?['name'];
          steps.add(
            [
              'Take $name',
              if (departure != null) 'from $departure',
              if (arrival != null) 'to $arrival',
            ].join(' '),
          );
        }
      }
    }
    return OfficeRoute(
      points,
      (json['distanceMeters'] as num).toDouble(),
      double.parse((json['duration'] as String).replaceFirst('s', '')),
      steps,
    );
  }
}

/// Google Places and Routes services used by the embedded Google map.
class OfficeMapServices {
  OfficeMapServices({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = (baseUrl ?? ApiConfig.baseUrl).replaceAll(RegExp(r'/+$'), '');
  final String _baseUrl;
  final http.Client _client;
  final Map<String, List<MapPlace>> _searchCache = {};

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
        'Allow location access in your device settings to get directions.',
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

  Future<List<MapPlace>> search(String query) async {
    final key = query.trim().toLowerCase();
    if (key.isEmpty) return [];
    if (_searchCache.containsKey(key)) return _searchCache[key]!;
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/maps/search'),
          headers: _headers,
          body: jsonEncode({
            'textQuery': query,
            'regionCode': 'PH',
            'languageCode': 'en',
            'pageSize': 5,
          }),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Place search is unavailable. Please try again.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (body['places'] as List<dynamic>? ?? [])
        .map(
          (item) => MapPlace(
            [
              item['displayName']?['text'],
              item['formattedAddress'],
            ].whereType<String>().join(', '),
            LatLng(
              (item['location']['latitude'] as num).toDouble(),
              (item['location']['longitude'] as num).toDouble(),
            ),
          ),
        )
        .toList();
    _searchCache[key] = results;
    return results;
  }

  Future<OfficeRoute> route(
    LatLng origin,
    LatLng destination, {
    RouteTravelMode mode = RouteTravelMode.drive,
  }) async {
    Map<String, dynamic> waypoint(LatLng point) => {
      'location': {
        'latLng': {'latitude': point.latitude, 'longitude': point.longitude},
      },
    };
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/maps/route'),
          headers: _headers,
          body: jsonEncode({
            'origin': waypoint(origin),
            'destination': waypoint(destination),
            'travelMode': mode.apiValue,
            'languageCode': 'en-US',
            'units': 'METRIC',
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Directions are unavailable. Please try again.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final routes = body['routes'] as List<dynamic>? ?? [];
    if (routes.isEmpty) {
      throw StateError(
        mode == RouteTravelMode.transit
            ? 'No public transport route is available from Google for this trip. Try Walk or Drive.'
            : 'No ${mode.label.toLowerCase()} route found to this office.',
      );
    }
    return OfficeRoute.fromJson(routes.first as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
