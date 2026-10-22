import 'dart:async';
import 'dart:convert';

import '../../models/resident_inventory.dart';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  const AuthException(this.message, {this.fieldErrors = const {}});

  final String message;
  final Map<String, String> fieldErrors;

  String? field(String name) => fieldErrors[name];
}

class AuthService extends ChangeNotifier {
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

  // Session is currently kept in memory.
  // Restarting the app requires signing in again.
  String? _token;
  bool _hadAuthenticatedSession = false;
  bool get hadAuthenticatedSession => _hadAuthenticatedSession;
  int _sessionGeneration = 0;
  int _inventoryGeneration = 0;
  int get sessionGeneration => _sessionGeneration;
  String? get token => _token;
  set token(String? value) {
    if (_token == value) return;
    _token = value;
    if (value != null) _hadAuthenticatedSession = true;
    _resetOwnership();
    notifyListeners();
  }

  ResidentInventory? ownership;
  InventoryLoadState ownershipState = InventoryLoadState.idle;
  Future<void>? _ownershipRequest;

  void _resetOwnership() {
    _sessionGeneration++;
    _inventoryGeneration++;
    ownership = null;
    ownershipState = InventoryLoadState.idle;
    _ownershipRequest = null;
  }

  void _replaceSession(String? value, Map<String, dynamic>? profile) {
    _token = value;
    if (value != null) _hadAuthenticatedSession = true;
    _user = profile;
    _resetOwnership();
    notifyListeners();
  }

  void _recordOwnership(
    Map<String, dynamic> data,
    int generation,
    int inventoryGeneration,
  ) {
    if (generation != _sessionGeneration ||
        inventoryGeneration != _inventoryGeneration ||
        token == null) {
      throw const AuthException('Your session changed. Please try again.');
    }
    final next = ResidentInventory.fromJson(data);
    if (ownershipState == InventoryLoadState.loaded && ownership == next) {
      return;
    }
    ownership = next;
    ownershipState = InventoryLoadState.loaded;
    notifyListeners();
  }

  Future<void> loadOwnership({bool force = false}) {
    if (token == null) return Future.value();
    if (_ownershipRequest != null) return _ownershipRequest!;
    if (!force && ownershipState == InventoryLoadState.loaded) {
      return Future.value();
    }
    final generation = _sessionGeneration;
    final inventoryGeneration = _inventoryGeneration;
    final done = Completer<void>();
    _ownershipRequest = done.future;
    ownershipState = InventoryLoadState.loading;
    notifyListeners();
    _loadOwnership(
      generation,
      inventoryGeneration,
    ).then(done.complete, onError: done.completeError);
    return done.future;
  }

  Future<void> _loadOwnership(int generation, int inventoryGeneration) async {
    try {
      await getInventory();
    } catch (_) {
      if (generation == _sessionGeneration &&
          inventoryGeneration == _inventoryGeneration) {
        ownership = null;
        ownershipState = InventoryLoadState.unavailable;
        notifyListeners();
      }
    } finally {
      if (generation == _sessionGeneration &&
          inventoryGeneration == _inventoryGeneration) {
        _ownershipRequest = null;
      }
    }
  }

  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  // Notify mounted user-data widgets whenever a session response replaces it.
  set user(Map<String, dynamic>? value) {
    if (_user?['id'] != value?['id'] || value == null) {
      if (value == null) _token = null;
      _resetOwnership();
    }
    _user = value;
    notifyListeners();
  }

  Future<void> login(String identifier, String password) => _authenticate(
    'login',
    {'identifier': identifier.trim(), 'password': password},
  );

  Future<void> logout() async {
    final previousToken = token;
    // Clear locally before waiting for the server; a late response cannot restore it.
    _replaceSession(null, null);
    if (previousToken != null) {
      await _post('logout', {}, authToken: previousToken);
    }
  }

  Future<void> register({
    required String contact,
    required bool usePhone,
    required String password,
    required String confirmation,
    required bool accepted,
  }) => _authenticate('register', {
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

    _replaceSession(newToken, newUser);
  }

  Future<void> saveProfileSetup({
    required String name,
    required String dateOfBirth,
    required int barangayId,
    required List<int> governmentIdIds,
    required List<int> documentIds,
  }) async {
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

    final data = await _post('profile-setup', {
      'name': name.trim(),
      'date_of_birth': dateOfBirth,
      'barangay_id': barangayId,
      'government_id_ids': governmentIdIds,
      'document_ids': documentIds,
    });

    final profile = data['user'];

    if (profile is! Map<String, dynamic>) {
      throw const AuthException('The server returned an unexpected response.');
    }

    ownership = null;
    ownershipState = InventoryLoadState.idle;
    _ownershipRequest = null;
    _inventoryGeneration++;
    user = profile;
  }

  Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? authToken,
  }) async {
    final generation = _sessionGeneration;
    try {
      final response = await _client
          .post(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/$path'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              if (path != 'login' &&
                  path != 'register' &&
                  (authToken ?? token) != null)
                'Authorization': 'Bearer ${authToken ?? token}',
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

      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw const FormatException();
      }

      final data = Map<String, dynamic>.from(decoded);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final fieldErrors = <String, String>{};

        final errors = data['errors'];

        if (errors is Map) {
          for (final entry in errors.entries) {
            final key = entry.key.toString();
            final value = entry.value;

            if (value is List && value.isNotEmpty) {
              fieldErrors[key] = value.first.toString();
            } else if (value is String && value.isNotEmpty) {
              fieldErrors[key] = value;
            }
          }
        }

        final message = fieldErrors.isNotEmpty
            ? fieldErrors.values.first
            : data['message']?.toString() ??
                  'Unable to complete the request. Please try again.';

        throw AuthException(message, fieldErrors: fieldErrors);
      }

      if (!['login', 'register', 'logout'].contains(path) &&
          generation != _sessionGeneration) {
        throw const AuthException('Your session changed. Please try again.');
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
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

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
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

    await _post('password', {
      'current_password': current,
      'password': password,
      'password_confirmation': confirmation,
    });
  }

  /// Authenticated resident transport; late responses never cross account boundaries.
  Future<http.Response> residentRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    final session = _sessionGeneration;
    final bearer = token;
    if (bearer == null) {
      throw const AuthException('Please sign in to save your roadmap.');
    }
    final request = http.Request(
      method,
      Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/$path'),
    );
    request.headers.addAll({
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $bearer',
    });
    if (body != null) request.body = jsonEncode(body);
    final response = await _client
        .send(request)
        .then(http.Response.fromStream)
        .timeout(const Duration(seconds: 20));
    if (session != _sessionGeneration || bearer != token) {
      throw const AuthException('Your session changed. Please try again.');
    }
    return response;
  }

  Future<Map<String, dynamic>> getInventory() async {
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

    final generation = _sessionGeneration;
    final requestToken = token;
    final inventoryGeneration = _inventoryGeneration;
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/inventory',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $requestToken',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 500) {
        throw const AuthException(
          'The server is unavailable. Please try again.',
        );
      }

      final body = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          body is Map<String, dynamic>
              ? body['message']?.toString() ?? 'Unable to load inventory.'
              : 'Unable to load inventory.',
        );
      }

      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an unexpected inventory response.',
        );
      }

      final data = body['data'] as Map<String, dynamic>;
      _recordOwnership(data, generation, inventoryGeneration);
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

  Future<Map<String, dynamic>> saveInventory({
    required List<int> governmentIdIds,
    required List<int> documentIds,
  }) async {
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

    final generation = _sessionGeneration;
    final requestToken = token;
    try {
      final response = await _client
          .put(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/inventory',
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $requestToken',
            },
            body: jsonEncode({
              'government_id_ids': governmentIdIds,
              'document_ids': documentIds,
            }),
          )
          .timeout(const Duration(seconds: 20));

      final body = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        String message = 'Unable to save inventory.';

        if (body is Map<String, dynamic>) {
          final errors = body['errors'];

          if (errors is Map && errors.isNotEmpty) {
            final first = errors.values.first;

            if (first is List && first.isNotEmpty) {
              message = first.first.toString();
            }
          } else if (body['message'] != null) {
            message = body['message'].toString();
          }
        }

        throw AuthException(message);
      }

      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const AuthException(
          'The server returned an unexpected inventory response.',
        );
      }

      final data = body['data'] as Map<String, dynamic>;
      if (generation != _sessionGeneration || token == null) {
        throw const AuthException('Your session changed. Please try again.');
      }
      _inventoryGeneration++;
      _ownershipRequest = null;
      _recordOwnership(data, generation, _inventoryGeneration);
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

  Future<List<Map<String, dynamic>>> getBarangays() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/barangays'),
            headers: {'Accept': 'application/json'},
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode >= 500) {
        throw const AuthException(
          'The server is unavailable. Please try again.',
        );
      }

      final body = jsonDecode(response.body);

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AuthException('Unable to load barangays.');
      }

      if (body is! Map<String, dynamic> || body['data'] is! List) {
        throw const AuthException(
          'The server returned an unexpected barangay response.',
        );
      }

      return (body['data'] as List)
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
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
}
