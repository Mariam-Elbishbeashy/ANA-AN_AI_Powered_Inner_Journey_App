import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import '../models/voice_turn_response_model.dart';

class VoiceAiRemoteDataSource {
  final String baseUrl; // ex: http://10.0.2.2:5001
  final http.Client _client;

  VoiceAiRemoteDataSource({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<VoiceTurnResponseModel> sendVoiceTurn({
    required File wavFile,
    required String sessionId,
    String voice = "alloy",
  }) async {
    final uri = Uri.parse("$baseUrl/voice/turn");

    final request = http.MultipartRequest("POST", uri)
      ..fields["session_id"] = sessionId
      ..fields["voice"] = voice
    // MUST be 'file' to match Flask:
      ..files.add(await http.MultipartFile.fromPath("file", wavFile.path));

    final streamed = await request.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("Voice API error ${streamed.statusCode}: $body");
    }

    final map = json.decode(body) as Map<String, dynamic>;
    if (map["success"] == false) {
      throw Exception(map["error"]?.toString() ?? "Unknown voice API error");
    }

    return VoiceTurnResponseModel.fromJson(map);
  }
}
