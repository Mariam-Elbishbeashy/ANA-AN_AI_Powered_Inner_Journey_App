import 'dart:io';
import '../../data/models/voice_turn_response_model.dart';

abstract class VoiceAiRepository {
  Future<VoiceTurnResponseModel> doVoiceTurn({
    required File wavFile,
    required String sessionId,
  });
}
