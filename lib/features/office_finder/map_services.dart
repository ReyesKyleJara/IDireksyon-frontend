import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

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

  factory OfficeRoute.fromJson(Map<String, dynamic> json) {
    final coordinates = json['geometry']['coordinates'] as List<dynamic>;
    final points = coordinates
        .map((p) => LatLng((p[1] as num).toDouble(), (p[0] as num).toDouble()))
        .toList();
    if (points.length < 2) {
      throw const FormatException('Missing route geometry');
    }
    final steps = <String>[];
    for (final leg in json['legs'] as List<dynamic>) {
      for (final step in leg['steps'] as List<dynamic>) {
        final maneuver = step['maneuver'] as Map<String, dynamic>;
        final type = maneuver['type'] as String;
        final modifier = (maneuver['modifier'] as String? ?? '').replaceAll(
          '_',
          ' ',
        );
        final road = step['name'] as String? ?? '';
        final action = switch (type) {
          'depart' => 'Head $modifier',
          'arrive' => 'Arrive at your destination',
          'roundabout' || 'rotary' =>
            'Take the roundabout${maneuver['exit'] == null ? '' : ', exit ${maneuver['exit']}'}',
          _ => '${type.replaceAll('_', ' ')} $modifier',
        };
        final instruction =
            '${action.trim()}${road.isEmpty || type == 'arrive' ? '' : ' onto $road'}';
        steps.add('${instruction[0].toUpperCase()}${instruction.substring(1)}');
      }
    }
    return OfficeRoute(
      points,
      (json['distance'] as num).toDouble(),
      (json['duration'] as num).toDouble(),
      steps,
    );
  }
}

/// Public endpoints are defaults for development. Use managed endpoints at scale.
class OfficeMapServices {
  OfficeMapServices({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final Map<String, List<MapPlace>> _searchCache = {};
  DateTime? _lastSearch;

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

  Future<List<MapPlace>> search(String query) async {
    final key = query.trim().toLowerCase();
    if (_searchCache.containsKey(key)) return _searchCache[key]!;
    // Nominatim requires explicit search, caching and at most one request/second.
    final last = _lastSearch;
    if (last != null && DateTime.now().difference(last).inMilliseconds < 1100) {
      throw StateError('Please wait a moment before searching again.');
    }
    _lastSearch = DateTime.now();
    const endpoint = String.fromEnvironment(
      'GEOCODING_URL',
      defaultValue: 'https://nominatim.openstreetmap.org/search',
    );
    final response = await _client
        .get(
          Uri.parse(endpoint).replace(
            queryParameters: {
              'q': query,
              'format': 'jsonv2',
              'limit': '5',
              'countrycodes': 'ph',
            },
          ),
          headers: {
            'User-Agent': 'IDireksyon/1.0 (idireksyon.app)',
            'Accept-Language': 'en',
          },
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw StateError('Place search is unavailable. Please try again.');
    }
    final results = (jsonDecode(response.body) as List<dynamic>)
        .map(
          (item) => MapPlace(
            item['display_name'] as String,
            LatLng(
              double.parse(item['lat'] as String),
              double.parse(item['lon'] as String),
            ),
          ),
        )
        .toList();
    _searchCache[key] = results;
    return results;
  }

  Future<OfficeRoute> route(LatLng origin, LatLng destination) async {
    const endpoint = String.fromEnvironment(
      'ROUTING_URL',
      defaultValue: 'https://router.project-osrm.org',
    );
    final uri = Uri.parse(
      '$endpoint/route/v1/driving/'
      '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}'
      '?overview=full&geometries=geojson&steps=true',
    );
    final response = await _client
        .get(uri)
        .timeout(const Duration(seconds: 20));
    if (response.statusCode != 200) {
      throw StateError('Directions are unavailable. Please try again.');
    }
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    if (body['code'] != 'Ok' || (body['routes'] as List).isEmpty) {
      throw StateError('No driving route found to this office.');
    }
    return OfficeRoute.fromJson(body['routes'][0] as Map<String, dynamic>);
  }

  void dispose() => _client.close();
}
