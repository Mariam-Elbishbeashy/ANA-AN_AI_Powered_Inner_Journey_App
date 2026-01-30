//Interact with AI server to get chat responses (Flask server).
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:ana_ifs_app/app/config/app_config.dart';
import 'package:ana_ifs_app/features/chat/data/models/guider_intervention_model.dart';

/// Response from the chat AI endpoint.
class ChatAiResponse {
  final String assistantMessage;
  final GuiderInterventionModel intervention;

  const ChatAiResponse({
    required this.assistantMessage,
    required this.intervention,
  });
}

/// Response from the guided chat AI endpoint (character + guider).
class GuidedChatResponse {
  final String characterMessage;
  final String guiderMessage;

  const GuidedChatResponse({
    required this.characterMessage,
    required this.guiderMessage,
  });
}

class ChatAiRemoteDataSource {
  ChatAiRemoteDataSource({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? AppConfig.aiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  /// Fetch a chat response from the AI server.
  /// Returns [ChatAiResponse] with assistant message and intervention data.
  Future<ChatAiResponse> fetchAssistantResponse({
    required String uid,
    required String threadId,
    required String sessionId,
    required String characterId,
    required Map<String, dynamic> characterProfile,
    required List<Map<String, String>> messages,
    bool checkIntervention = true,
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
        'checkIntervention': checkIntervention,
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

    // Parse intervention data if present
    final interventionData = decoded['intervention'] as Map<String, dynamic>?;
    final intervention = GuiderInterventionModel.fromMap(interventionData);

    return ChatAiResponse(
      assistantMessage: decoded['assistantMessage']?.toString() ?? '',
      intervention: intervention,
    );
  }

  /// Legacy method for backward compatibility.
  /// Use [fetchAssistantResponse] for full response with intervention.
  Future<String> fetchAssistantMessage({
    required String uid,
    required String threadId,
    required String sessionId,
    required String characterId,
    required Map<String, dynamic> characterProfile,
    required List<Map<String, String>> messages,
  }) async {
    final response = await fetchAssistantResponse(
      uid: uid,
      threadId: threadId,
      sessionId: sessionId,
      characterId: characterId,
      characterProfile: characterProfile,
      messages: messages,
      checkIntervention: false,
    );
    return response.assistantMessage;
  }

  /// Fetch a guided chat response where both character and Guider respond.
  /// The Guider joins as a third participant to facilitate the conversation.
  Future<GuidedChatResponse> fetchGuidedResponse({
    required String uid,
    required String threadId,
    required String sessionId,
    required String characterId,
    required Map<String, dynamic> characterProfile,
    required List<Map<String, dynamic>> messages,
  }) async {
    final uri = Uri.parse('$_baseUrl/chat_guided');
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

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI server error: ${response.statusCode}');
    }

    final decoded = json.decode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception(decoded['error'] ?? 'Unknown AI error');
    }

    return GuidedChatResponse(
      characterMessage: decoded['characterMessage']?.toString() ?? '',
      guiderMessage: decoded['guiderMessage']?.toString() ?? '',
    );
  }
}
