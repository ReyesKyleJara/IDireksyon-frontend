import 'package:flutter/foundation.dart';

/// Shared endpoint for authentication and the Government ID API.
class ApiConfig {
  static const productionBaseUrl =
      'https://idireksyon-backend-production.up.railway.app/api';

  static final String baseUrl = resolveBaseUrl(
    override: const String.fromEnvironment('API_BASE_URL'),
    isWeb: kIsWeb,
    platform: defaultTargetPlatform,
    browserUri: Uri.base,
    debugBuild: kDebugMode,
  );

  @visibleForTesting
  static String resolveBaseUrl({
    required String override,
    required bool isWeb,
    required TargetPlatform platform,
    required Uri browserUri,
    bool debugBuild = true,
  }) {
    final configured = override.trim();
    // Installed apps must never reach a development server or plain HTTP.
    final allowed = debugBuild || isWeb || configured.startsWith('https://');
    if (configured.isNotEmpty && allowed) {
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

    if (!debugBuild) return productionBaseUrl;

    final host = platform == TargetPlatform.android ? '10.0.2.2' : '127.0.0.1';
    return 'http://$host:8000/api';
  }
}
