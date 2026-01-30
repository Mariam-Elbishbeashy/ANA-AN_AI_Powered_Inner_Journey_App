/// Interact with AI server to get Guider responses (Flask server).
/// The Guider has access to all character conversations and can create healing plans.
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ana_ifs_app/app/config/app_config.dart';

class GuiderAiRemoteDataSource {
  static const Duration _requestTimeout = Duration(seconds: 60);

  GuiderAiRemoteDataSource({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.aiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Fetch a response from The Guider.
  /// The Guider sees all character conversations and can create healing plans.
  Future<String> fetchGuiderResponse({
    required String uid,
    required List<Map<String, dynamic>> messages,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat_guider');
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uid': uid,
            'messages': messages,
          }),
        )
        .timeout(_requestTimeout);

    // Handle errors from the AI server.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI server error: ${response.statusCode}');
    }

    // Parse the response from the AI server.
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'Unknown AI error');
    }

    // Return the guider response.
    return decoded['assistantMessage']?.toString() ?? '';
  }

  /// Get the current healing plan for the user.
  Future<Map<String, dynamic>?> getActivePlan({
    required String uid,
  }) async {
    final uri = Uri.parse('$_baseUrl/plans/active?uid=$uid');
    final response = await _client
        .get(
          uri,
          headers: {'Content-Type': 'application/json'},
        )
        .timeout(_requestTimeout);

    if (response.statusCode == 404) {
      return null; // No active plan
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI server error: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      return null;
    }

    return decoded['plan'] as Map<String, dynamic>?;
  }
}
