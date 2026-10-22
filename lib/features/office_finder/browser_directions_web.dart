import 'dart:convert';
import 'dart:js_interop';

const available = true;

@JS('idireksyonComputeRoute')
external JSPromise<JSString> _computeRoute(
  JSNumber originLat,
  JSNumber originLng,
  JSNumber destinationLat,
  JSNumber destinationLng,
);

Future<Map<String, dynamic>> computeRoute(
  double originLat,
  double originLng,
  double destinationLat,
  double destinationLng,
) async {
  final result = await _computeRoute(
    originLat.toJS,
    originLng.toJS,
    destinationLat.toJS,
    destinationLng.toJS,
  ).toDart.timeout(const Duration(seconds: 20));
  final body = jsonDecode(result.toDart) as Map<String, dynamic>;
  if (body['error'] case final String message) throw StateError(message);
  return body;
}
