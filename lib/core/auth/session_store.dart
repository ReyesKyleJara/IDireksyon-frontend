import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SavedSession {
  const SavedSession(this.token, this.user, this.expiresAt);

  final String token;
  final Map<String, dynamic> user;
  final DateTime expiresAt;

  String encode() => jsonEncode({
    'token': token,
    'user': user,
    'expires_at': expiresAt.toUtc().toIso8601String(),
  });

  static SavedSession decode(String value) {
    final data = jsonDecode(value);
    if (data is! Map<String, dynamic> ||
        data['token'] is! String ||
        (data['token'] as String).trim().isEmpty ||
        data['user'] is! Map<String, dynamic> ||
        data['expires_at'] is! String) {
      throw const FormatException('Invalid saved session');
    }
    return SavedSession(
      data['token'] as String,
      data['user'] as Map<String, dynamic>,
      DateTime.parse(data['expires_at'] as String),
    );
  }
}

/// Only non-sensitive flags go in preferences. The token and cached profile
/// are written together to the platform's secure storage; passwords are never saved.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
            mOptions: MacOsOptions(
              accessibility: KeychainAccessibility.unlocked_this_device,
            ),
          );

  static const sessionKey = 'idireksyon.auth.session.v1';
  static const onboardingKey = 'idireksyon.onboarding.completed';
  static const installationKey = 'idireksyon.installation.initialized';
  static const signedOutKey = 'idireksyon.auth.signed_out';

  final FlutterSecureStorage _storage;

  Future<bool> get onboardingCompleted async =>
      (await SharedPreferences.getInstance()).getBool(onboardingKey) ?? false;

  Future<void> completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setBool(onboardingKey, true)) {
      throw StateError('Could not save onboarding completion.');
    }
  }

  Future<SharedPreferences> _installation() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(installationKey) != true) {
      // Apple Keychain can survive uninstall. Never reuse that old session.
      await _storage.delete(key: sessionKey);
      if (!await prefs.setBool(installationKey, true)) {
        throw StateError('Could not initialize session storage.');
      }
    }
    return prefs;
  }

  Future<SavedSession?> read() async {
    final prefs = await _installation();
    if (prefs.getBool(signedOutKey) == true) return null;
    final value = await _storage.read(key: sessionKey);
    if (value == null) return null;
    try {
      return SavedSession.decode(value);
    } on FormatException {
      await clear();
      return null;
    }
  }

  Future<void> save(SavedSession session) async {
    final prefs = await _installation();
    await _storage.write(key: sessionKey, value: session.encode());
    if (!await prefs.setBool(signedOutKey, false)) {
      throw StateError('Could not save session state.');
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    // If Keychain deletion fails, this non-sensitive marker still prevents a
    // manual logout from being undone by the next startup.
    if (!await prefs.setBool(signedOutKey, true)) {
      throw StateError('Could not clear session state.');
    }
    await _storage.delete(key: sessionKey);
  }
}
