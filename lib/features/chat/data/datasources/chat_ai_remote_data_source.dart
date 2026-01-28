//Interact with AI server to get chat responses (Flask server).
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ana_ifs_app/app/config/app_config.dart';

class ChatAiRemoteDataSource {
  ChatAiRemoteDataSource({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.aiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  //Fetch a chat response from the AI server.
  Future<String> fetchAssistantMessage({
    required String uid,
    required String threadId,
    required String sessionId,
    required String characterId,
    required Map<String, dynamic> characterProfile,
    required List<Map<String, String>> messages,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat');
    final response = await _client.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'uid': uid,
        'threadId': threadId,
        'sessionId': sessionId,
        'characterId': characterId,
        'characterProfile': characterProfile,
        'messages': messages,
      }),
    );

    //Handle errors from the AI server.
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI server error: ${response.statusCode}');
    }

    //Parse the response from the AI server.
    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'Unknown AI error');
    }

    //Return the chat response.
    return decoded['assistantMessage']?.toString() ?? '';
  }
}
