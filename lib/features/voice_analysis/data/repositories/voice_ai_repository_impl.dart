import 'dart:io';

import '../../domain/repositories/voice_ai_repository.dart';
import '../datasources/voice_ai_remote_data_source.dart';
import '../models/voice_turn_response_model.dart';

class VoiceAiRepositoryImpl implements VoiceAiRepository {
  final VoiceAiRemoteDataSource remote;

  VoiceAiRepositoryImpl(this.remote);

  @override
  Future<VoiceTurnResponseModel> doVoiceTurn({
    required File wavFile,
    required String sessionId,
  }) {
    return remote.sendVoiceTurn(
      wavFile: wavFile,
      sessionId: sessionId,
    );
  }
}
