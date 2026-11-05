import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../api_config.dart';
import '../../models/roadmap_plan.dart';
import '../../services/application_preparation.dart';

class AuthException implements Exception {
  const AuthException(this.message, {this.fieldErrors = const {}, this.retryAfterSeconds});

  final String message;
  final int? retryAfterSeconds;
  final Map<String, String> fieldErrors;

  String? field(String name) => fieldErrors[name];
}

class AuthService extends ChangeNotifier {
  AuthService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl == null || baseUrl.trim().isEmpty
          ? ApiConfig.baseUrl
          : baseUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static AuthService instance = AuthService();

  final http.Client _client;

  String baseUrl;

  // Session is currently kept in memory.
  // Restarting the app requires signing in again.
  String? token;
  int inventoryRevision = 0;
  int preparationRevision = 0;
  Map<String, dynamic>? _user;

  Map<String, dynamic>? get user => _user;

  // Notify mounted user-data widgets whenever a session response replaces it.
  set user(Map<String, dynamic>? value) {
    _user = value;
    notifyListeners();
  }

  Future<Map<String, dynamic>> getRequirementPreparation(
    String recordType,
    int recordId,
  ) => _requirementPreparation(recordType, recordId);

  Future<Map<String, dynamic>> saveRequirementPreparation(
    String recordType,
    int recordId,
    int itemId,
    bool prepared,
  ) => _requirementPreparation(
    recordType,
    recordId,
    change: {'item_id': itemId, 'prepared': prepared},
  );

  Future<Map<String, dynamic>> _requirementPreparation(
    String recordType,
    int recordId, {
    Map<String, dynamic>? change,
  }) async {
    final session = token;
    if (session == null) throw const AuthException('Please sign in again.');
    if (!['government_id', 'document'].contains(recordType) || recordId <= 0) {
      throw const AuthException('Invalid application.');
    }
    final uri = Uri.parse(
      '$baseUrl/auth/requirement-preparation/$recordType/$recordId',
    );
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $session',
      'Content-Type': 'application/json',
    };
    try {
      final response =
          await (change == null
                  ? _client.get(uri, headers: headers)
                  : _client.put(
                      uri,
                      headers: headers,
                      body: jsonEncode(change),
                    ))
              .timeout(const Duration(seconds: 20));
      if (token != session) {
        throw const AuthException(
          'Your session changed. Please reload this checklist.',
        );
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw const AuthException(
          'Could not save or load your checklist. Please try again.',
        );
      }
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic> ||
          body['data'] is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final data = body['data'] as Map<String, dynamic>;
      if (data['record_type'] != recordType || data['record_id'] != recordId) {
        throw const FormatException();
      }
      ApplicationPreparation.fromJson(data);
      if (change != null) {
        final rows = data['items'] as List;
        if (!rows.any(
          (row) =>
              row['item_id'] == change['item_id'] &&
              row['prepared'] == change['prepared'],
        )) {
          throw const FormatException();
        }
        preparationRevision++;
        notifyListeners();
      }
      return data;
    } on TimeoutException {
      throw const AuthException(
        'The connection timed out. Please reload and try again.',
      );
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Please try again.',
      );
    } on FormatException {
      throw const AuthException(
        'The server returned an unexpected checklist response.',
      );
    }
  }

  Future<void> login(String identifier, String password) => _authenticate(
    'login',
    {'identifier': identifier.trim(), 'password': password},
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

  // Deletion failures must leave the resident signed in.
  Future<void> deleteAccount({required String password}) async {
    final session = token;
    if (session == null) throw const AuthException('Please sign in again.');
    final result = await _post('account/delete', {'password': password});
    if (result['message'] != 'Account deleted.') {
      throw const AuthException(
        'The server returned an unexpected deletion response.',
      );
    }
    if (token != session) {
      throw const AuthException(
        'Your session changed. Please reload before continuing.',
      );
    }
    token = null;
    user = null;
  }

  Future<String> sendPasswordResetEmail(String email) async {
    final data = await _post('forgot-password', {'email': email.trim()});
    final message = data['message'];
    if (message is! String || message.trim().isEmpty) {
      throw const AuthException('The server returned an unexpected response.');
    }
    return message;
  }

  Future<RoadmapPlan> roadmapPlan(
    List<int> targets, {
    List<int> documentTargets = const [],
    Map<String, dynamic>? resolution,
  }) async {
    if (token == null) throw const AuthException('Please sign in again.');
    final response = await _post('roadmap-plan', {
      'target_government_id_ids': targets,
      if (documentTargets.isNotEmpty) 'target_document_ids': documentTargets,
      'resolution': ?resolution,
    });
    try {
      final plan = RoadmapPlan.fromJson(
        Map<String, dynamic>.from(response['data'] as Map),
      );
      if (!listEquals(plan.targetIds, targets) ||
          !listEquals(plan.targetDocumentIds, documentTargets)) {
        throw const FormatException();
      }
      return plan;
    } catch (_) {
      throw const AuthException(
        'The server returned an unexpected roadmap response.',
      );
    }
  }

  Future<void> register({
    String? emailVerificationToken,
    required String contact,
    required bool usePhone,
    required String password,
    required String confirmation,
    required bool accepted,
  }) => _authenticate('register', {
    'email_verification_token': emailVerificationToken,
    usePhone ? 'phone' : 'email': contact.trim(),
    'password': password,
    'password_confirmation': confirmation,
    'terms_accepted': accepted,
  });

  final Map<String, DateTime> _signupResendAt = {};

  int signupResendSeconds(String email) {
    final deadline = _signupResendAt[email.trim().toLowerCase()];
    if (deadline == null) return 0;
    final seconds = (deadline.difference(DateTime.now()).inMilliseconds / 1000).ceil();
    return seconds > 0 ? seconds : 0;
  }

  String _signupCooldownMessage(int seconds) =>
      'A code was already requested. You can resend in ${seconds}s.';

  Future<String> sendSignupEmailCode(String email) async {
    final key = email.trim().toLowerCase();
    final remaining = signupResendSeconds(key);
    if (remaining > 0) {
      throw AuthException(_signupCooldownMessage(remaining), retryAfterSeconds: remaining);
    }
    try {
      final data = await _post('email-verification/send', {
        'email': key,
      });
      final id = data['challenge_id'];
      if (id is! String) {
        throw const AuthException('The server returned an unexpected response.');
      }
      final seconds = (data['resend_after'] as num?)?.toInt() ?? 60;
      _signupResendAt[key] = DateTime.now().add(Duration(seconds: seconds));
      return id;
    } on AuthException catch (error) {
      final seconds = error.retryAfterSeconds;
      if (seconds != null) {
        _signupResendAt[key] = DateTime.now().add(Duration(seconds: seconds));
      }
      rethrow;
    }
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
        Map<String, dynamic>? cooldown;
        try {
          final decoded = jsonDecode(response.body);
          if (decoded is Map<String, dynamic>) cooldown = decoded;
        } on FormatException {
          // A proxy may return a non-JSON response; still honor Retry-After.
        }
        final seconds = int.tryParse('${cooldown?['remaining_seconds']}') ??
            int.tryParse(response.headers['retry-after'] ?? '');
        throw AuthException(
          path == 'email-verification/send' && seconds != null
              ? (cooldown?['message']?.toString() ?? _signupCooldownMessage(seconds))
              : 'Too many attempts. Please wait a minute and try again.',
          retryAfterSeconds: seconds,
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
    int? barangayId,
  }) async {
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

    final data = await _post('account', {
      'name': name.trim(),
      'barangay_id': ?barangayId,
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

  Future<List<Map<String, dynamic>>> getJourneys() async {
    final response = await _journeyRequest('GET', 'journeys');
    final data = response['data'];
    if (data is! List) {
      throw const AuthException('The server returned unexpected journey data.');
    }
    if (data.any((item) => item is! Map)) {
      throw const AuthException('The server returned unexpected journey data.');
    }
    return data.map((item) => Map<String, dynamic>.from(item as Map)).toList();
  }

  Future<Map<String, dynamic>> saveJourney(
    List<int> targets,
    List<int> documents,
  ) async {
    final response = await _journeyRequest('POST', 'journeys', {
      'target_government_id_ids': targets,
      'target_document_ids': documents,
    });
    if (response['data'] is! Map) {
      throw const AuthException('The server returned unexpected journey data.');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<Map<String, dynamic>> completeJourneyStep(
    int journeyId,
    String identity,
  ) async {
    final response = await _journeyRequest(
      'PUT',
      'journeys/$journeyId/completion',
      {'step_identity': identity},
    );
    if (response['data'] is! Map) {
      throw const AuthException('The server returned unexpected journey data.');
    }
    return Map<String, dynamic>.from(response['data'] as Map);
  }

  Future<Map<String, dynamic>> _journeyRequest(
    String method,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    final session = token;
    if (session == null) throw const AuthException('Please sign in again.');
    try {
      final request = http.Request(
        method,
        Uri.parse('${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/$path'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $session',
      });
      if (payload != null) request.body = jsonEncode(payload);
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 20));
      if (token != session) {
        throw const AuthException(
          'Your session changed. Please reload before continuing.',
        );
      }
      if (response.statusCode >= 500) {
        throw const AuthException(
          'Unable to save or load your journey. Please try again.',
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AuthException(
          decoded['message']?.toString() ??
              'Unable to update your journey. Please try again.',
        );
      }
      return decoded;
    } on TimeoutException {
      throw const AuthException('The connection timed out. Please try again.');
    } on http.ClientException {
      throw const AuthException(
        'Cannot connect to the server. Please try again.',
      );
    } on FormatException {
      throw const AuthException('The server returned unexpected journey data.');
    }
  }

  Future<Map<String, dynamic>> getInventory() async {
    if (token == null) {
      throw const AuthException('Please sign in again.');
    }

    try {
      final response = await _client
          .get(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/inventory',
            ),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
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

      return body['data'] as Map<String, dynamic>;
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

    try {
      final response = await _client
          .put(
            Uri.parse(
              '${baseUrl.replaceAll(RegExp(r'/$'), '')}/auth/inventory',
            ),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
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

      inventoryRevision++;
      notifyListeners();
      return body['data'] as Map<String, dynamic>;
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
