import 'package:flutter/foundation.dart';

/// Shared endpoint for authentication and the Government ID API.
class ApiConfig {
  static final String baseUrl = resolveBaseUrl(
    override: const String.fromEnvironment('API_BASE_URL'),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    browserUri: Uri.base,
  );

  @visibleForTesting
  static String resolveBaseUrl({
    required String override,
    required bool isWeb,
    required TargetPlatform platform,
    required Uri browserUri,
  }) {
    final configured = override.trim();
    if (configured.isNotEmpty) {
      return configured.replaceAll(RegExp(r'/+$'), '');
    }

    if (isWeb) {
      return Uri(
        scheme: browserUri.scheme,
        host: browserUri.host,
        port: browserUri.port,
        path: '/api',
      ).toString();
    }

    final host = platform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
    return 'http://$host:8000/api';
  }
}
