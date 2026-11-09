import 'dart:convert';

import '../../core/api_config.dart';
import '../../core/auth/auth_service.dart';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'models/office_model.dart';

class RoadEstimate {
  const RoadEstimate(this.meters, this.seconds);
  final double meters;
  final int seconds;
}

/// Published offices, the device location, and road estimates for the Office Finder.
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
    return (body['data'] as List<dynamic>)
        .cast<Map<String, dynamic>>()
        .map(OfficeModel.fromJson)
        .toList();
  }

  Future<RoadEstimate> roadEstimate(String officeId, LatLng origin) async {
    final key =
        '$officeId|${origin.latitude.toStringAsFixed(3)}|${origin.longitude.toStringAsFixed(3)}';
    final known = _estimates[key];
    if (known != null) return known;
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
      throw StateError(_estimateProblem(response));
    }
    final data =
        (jsonDecode(response.body) as Map<String, dynamic>)['data']
            as Map<String, dynamic>;
    return _estimates[key] = RoadEstimate(
      (data['distance_meters'] as num).toDouble(),
      (data['duration_seconds'] as num).toInt(),
    );
  }

  String _estimateProblem(http.Response response) {
    if (response.statusCode == 401) {
      return 'Log in again to see road distance.';
    }
    if (response.statusCode == 429) {
      return 'Too many requests. Please wait a moment, then try again.';
    }
    Object? code;
    try {
      code = (jsonDecode(response.body) as Map<String, dynamic>)['code'];
    } catch (_) {
      // Not JSON, so the general message below applies.
    }
    return switch (code) {
      'no_route' => 'No driving route was found to this office.',
      'office_no_location' =>
        'Road distance is not available for this office yet.',
      null when response.statusCode == 422 =>
        'Road distance is only available within the Philippines.',
      _ => 'Road distance is unavailable right now.',
    };
  }

  void dispose() => _client.close();
}
