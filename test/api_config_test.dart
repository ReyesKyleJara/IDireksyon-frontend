import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idireksyon_frontend/core/api_config.dart';

void main() {
  String resolve({
    String override = '',
    bool web = false,
    TargetPlatform platform = TargetPlatform.android,
    String page = 'http://localhost:5173/',
  }) => ApiConfig.resolveBaseUrl(
    override: override,
    isWeb: web,
    platform: platform,
    browserUri: Uri.parse(page),
  );

  test('web uses the browser host, including browsers on phones', () {
    expect(resolve(web: true), 'http://localhost:5173/api');
    expect(
      resolve(web: true, page: 'http://192.168.1.20:5173/'),
      'http://192.168.1.20:5173/api',
    );
  });

  test('native defaults use the emulator or desktop loopback', () {
    expect(resolve(), 'http://10.0.2.2:8000/api');
    expect(
      resolve(platform: TargetPlatform.windows),
      'http://127.0.0.1:8000/api',
    );
  });

  test('explicit endpoint overrides platform defaults and removes slashes', () {
    for (final web in [true, false]) {
      expect(
        resolve(web: web, override: ' http://192.168.1.20:9000/api/// '),
        'http://192.168.1.20:9000/api',
      );
    }
  });
}
