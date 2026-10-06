import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
}

class AuthService {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl =
          baseUrl ??
          const String.fromEnvironment('API_BASE_URL', defaultValue: '') {
    if (this.baseUrl.isEmpty) {
      this.baseUrl = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
          ? 'http://10.0.2.2:8000/api'
          : 'http://127.0.0.1:8000/api';
    }
  }

  static AuthService instance = AuthService();
  final http.Client _client;
  String baseUrl;
  // Keep the session in memory; restarting the app requires signing in again.
  String? token;
  Map<String, dynamic>? user;

  Future<void> login(String identifier, String password) => _authenticate(
    'login',
    {'identifier': identifier.trim(), 'password': password},
  );

  Future<void> logout() async {
    try {
      if (token != null) await _post('logout', {});
    } finally {
      token = null;
      user = null;
    }
  }

  Future<void> register({
    required String name,
    required String contact,
    required bool usePhone,
    required String password,
    required String confirmation,
    required bool accepted,
  }) => _authenticate('register', {
    'name': name.trim(),
    usePhone ? 'phone' : 'email': contact.trim(),
    'password': password,
    'password_confirmation': confirmation,
    'terms_accepted': accepted,
  });

  Future<void> _authenticate(String path, Map<String, dynamic> body) async {
    final data = await _post(path, body);
    final newToken = data['token'];
    final newUser = data['user'];
    if (newToken is! String || newUser is! Map<String, dynamic>) {
      throw const AuthException('The server returned an unexpected response.');
    }
    token = newToken;
    user = newUser;
  }

  Future<void> saveProfileSetup({
    required List<String> ids,
    required List<String> documents,
  }) async {
    if (token == null) throw const AuthException('Please sign in again.');
    final data = await _post('profile-setup', {
      'ids': ids,
      'documents': documents,
    });
    final profile = data['user'];
    if (profile is! Map<String, dynamic>) {
      throw const AuthException('The server returned an unexpected response.');
    }
    user = profile;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await _client
          .post(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (path != 'login' && path != 'register' && token != null)
                'Authorization': 'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode >= 500) {
        throw const AuthException(
          'The server is unavailable. Please try again.',
        );
      }
      if (response.statusCode == 429) {
        throw const AuthException(
          'Too many attempts. Please wait a minute and try again.',
        );
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final errors = data['errors'];
        final message = errors is Map && errors.isNotEmpty
            ? (errors.values.first as List).first.toString()
            : data['message']?.toString() ??
                  'Unable to sign in. Please try again.';
        throw AuthException(message);
      }
      return data;
    } on TimeoutException {
      throw const AuthException('The connection timed out. Please try again.');
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthException('The server returned an unexpected response.');
    }
  }

  Future<void> updateAccount({
    required String name,
    required String contact,
    required bool usePhone,
  }) async {
    if (token == null) throw const AuthException('Please sign in again.');
    final data = await _post('account', {
      'name': name.trim(),
      usePhone ? 'phone' : 'email': contact.trim(),
    });
    final profile = data['user'];
    if (profile is! Map<String, dynamic>) {
      throw const AuthException('The server returned an unexpected response.');
    }
    user = profile;
  }

  Future<void> updatePassword({
    required String current,
    required String password,
    required String confirmation,
  }) async {
    if (token == null) throw const AuthException('Please sign in again.');
    await _post('password', {
      'current_password': current,
      'password': password,
      'password_confirmation': confirmation,
    });
  }
}
