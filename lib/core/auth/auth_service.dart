import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';

class AuthException implements Exception {
  const AuthException(
    this.message, {
    this.fieldErrors = const {},
  });

  final String message;
  final Map<String, String> fieldErrors;

  String? field(String name) => fieldErrors[name];
}

class AuthService extends ChangeNotifier {
  AuthService({
    http.Client? client,
    String? baseUrl,
  })  : _client = client ?? http.Client(),
        baseUrl = baseUrl == null || baseUrl.trim().isEmpty
            ? ApiConfig.baseUrl
            : baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static AuthService instance = AuthService();

  final http.Client _client;

  String baseUrl;

  // Session is currently kept in memory.
  // Restarting the app requires signing in again.
  String? token;
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  // Notify mounted user-data widgets whenever a session response replaces it.
  set user(Map<String, dynamic>? value) {
    _user = value;
    notifyListeners();
  }

  Future<void> login(
    String identifier,
    String password,
  ) =>
      _authenticate(
        'login',
        {
          'identifier': identifier.trim(),
          'password': password,
        },
      );

  Future<void> logout() async {
    try {
      if (token != null) {
        await _post('logout', {});
      }
    } finally {
      token = null;
      user = null;
    }
  }

  Future<void> register({
    String? emailVerificationToken,
    required String contact,
    required bool usePhone,
    required String password,
    required String confirmation,
    required bool accepted,
  }) =>
      _authenticate(
        'register',
        {
          'email_verification_token': emailVerificationToken,
          usePhone ? 'phone' : 'email':
              contact.trim(),
          'password': password,
          'password_confirmation':
              confirmation,
          'terms_accepted': accepted,
        },
      );

  Future<String> sendSignupEmailCode(String email) async {
    final data = await _post('email-verification/send', {'email': email.trim()});
    final id = data['challenge_id'];
    if (id is! String) {
      throw const AuthException('The server returned an unexpected response.');
    }
    return id;
  }

  Future<String> verifySignupEmailCode(String challengeId, String code) async {
    final data = await _post('email-verification/verify', {
      'challenge_id': challengeId,
      'code': code.trim(),
    });
    final proof = data['email_verification_token'];
    if (proof is! String) {
      throw const AuthException('The server returned an unexpected response.');
    }
    return proof;
  }

  Future<void> _authenticate(
    String path,
    Map<String, dynamic> body,
  ) async {
    final data = await _post(path, body);

    final newToken = data['token'];
    final newUser = data['user'];

    if (newToken is! String ||
        newUser is! Map<String, dynamic>) {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
    }

    token = newToken;
    user = newUser;
  }

  Future<void> saveProfileSetup({
    required String name,
    required String dateOfBirth,
    required int barangayId,
    required List<int> governmentIdIds,
    required List<int> documentIds,
  }) async {
    if (token == null) {
      throw const AuthException(
        'Please sign in again.',
      );
    }

    final data = await _post(
      'profile-setup',
      {
        'name': name.trim(),
        'date_of_birth': dateOfBirth,
        'barangay_id': barangayId,
        'government_id_ids':
            governmentIdIds,
        'document_ids': documentIds,
      },
    );

    final profile = data['user'];

    if (profile is! Map<String, dynamic>) {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
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
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/$path',
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type':
                  'application/json',
              if (path != 'login' &&
                  path != 'register' &&
                  token != null)
                'Authorization':
                    'Bearer $token',
            },
            body: jsonEncode(body),
          )
          .timeout(
            const Duration(seconds: 20),
          );

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

      final decoded =
          jsonDecode(response.body);

      if (decoded
          is! Map<String, dynamic>) {
        throw const FormatException();
      }

      final data =
          Map<String, dynamic>.from(
        decoded,
      );

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        final fieldErrors =
            <String, String>{};

        final errors = data['errors'];

        if (errors is Map) {
          for (final entry
              in errors.entries) {
            final key =
                entry.key.toString();
            final value = entry.value;

            if (value is List &&
                value.isNotEmpty) {
              fieldErrors[key] =
                  value.first.toString();
            } else if (value is String &&
                value.isNotEmpty) {
              fieldErrors[key] = value;
            }
          }
        }

        final message =
            fieldErrors.isNotEmpty
                ? fieldErrors
                    .values.first
                : data['message']
                        ?.toString() ??
                    'Unable to complete the request. Please try again.';

        throw AuthException(
          message,
          fieldErrors: fieldErrors,
        );
      }

      return data;
    } on TimeoutException {
      throw const AuthException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
    }
  }

  Future<void> updateAccount({
    required String name,
    required String contact,
    required bool usePhone,
  }) async {
    if (token == null) {
      throw const AuthException(
        'Please sign in again.',
      );
    }

    final data =
        await _post(
      'account',
      {
        'name': name.trim(),
        usePhone ? 'phone' : 'email':
            contact.trim(),
      },
    );

    final profile = data['user'];

    if (profile is! Map<String, dynamic>) {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
    }

    user = profile;
  }

  Future<void> updatePassword({
    required String current,
    required String password,
    required String confirmation,
  }) async {
    if (token == null) {
      throw const AuthException(
        'Please sign in again.',
      );
    }

    await _post(
      'password',
      {
        'current_password': current,
        'password': password,
        'password_confirmation':
            confirmation,
      },
    );
  }

  Future<Map<String, dynamic>>
      getInventory() async {
    if (token == null) {
      throw const AuthException(
        'Please sign in again.',
      );
    }

    try {
      final response = await _client
          .get(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/inventory',
            ),
            headers: {
              'Accept':
                  'application/json',
              'Authorization':
                  'Bearer $token',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode >= 500) {
        throw const AuthException(
          'The server is unavailable. Please try again.',
        );
      }

      final body =
          jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw AuthException(
          body is Map<String, dynamic>
              ? body['message']
                      ?.toString() ??
                  'Unable to load inventory.'
              : 'Unable to load inventory.',
        );
      }

      if (body
              is! Map<String, dynamic> ||
          body['data']
              is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an unexpected inventory response.',
        );
      }

      return body['data']
          as Map<String, dynamic>;
    } on TimeoutException {
      throw const AuthException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
    }
  }

  Future<Map<String, dynamic>>
      saveInventory({
    required List<int> governmentIdIds,
    required List<int> documentIds,
  }) async {
    if (token == null) {
      throw const AuthException(
        'Please sign in again.',
      );
    }

    try {
      final response = await _client
          .put(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/inventory',
            ),
            headers: {
              'Accept':
                  'application/json',
              'Content-Type':
                  'application/json',
              'Authorization':
                  'Bearer $token',
            },
            body: jsonEncode({
              'government_id_ids':
                  governmentIdIds,
              'document_ids':
                  documentIds,
            }),
          )
          .timeout(
            const Duration(seconds: 20),
          );

      final body =
          jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        String message =
            'Unable to save inventory.';

        if (body
            is Map<String, dynamic>) {
          final errors =
              body['errors'];

          if (errors is Map &&
              errors.isNotEmpty) {
            final first =
                errors.values.first;

            if (first is List &&
                first.isNotEmpty) {
              message =
                  first.first.toString();
            }
          } else if (body['message'] !=
              null) {
            message =
                body['message']
                    .toString();
          }
        }

        throw AuthException(message);
      }

      if (body
              is! Map<String, dynamic> ||
          body['data']
              is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an unexpected inventory response.',
        );
      }

      return body['data']
          as Map<String, dynamic>;
    } on TimeoutException {
      throw const AuthException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
    }
  }

  Future<List<Map<String, dynamic>>>
      getBarangays() async {
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/barangays',
            ),
            headers: {
              'Accept':
                  'application/json',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode >= 500) {
        throw const AuthException(
          'The server is unavailable. Please try again.',
        );
      }

      final body =
          jsonDecode(response.body);

      if (response.statusCode < 200 ||
          response.statusCode >= 300) {
        throw const AuthException(
          'Unable to load barangays.',
        );
      }

      if (body
              is! Map<String, dynamic> ||
          body['data'] is! List) {
        throw const AuthException(
          'The server returned an unexpected barangay response.',
        );
      }

      return (body['data'] as List)
          .whereType<Map>()
          .map(
            (item) =>
                Map<String, dynamic>.from(
              item,
            ),
          )
          .toList();
    } on TimeoutException {
      throw const AuthException(
        'The connection timed out. Please try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Check your connection and try again.',
      );
    } on FormatException {
      throw const AuthException(
        'The server returned an unexpected response.',
      );
    }
  }
}
