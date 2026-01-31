class VoiceTurnResponseModel {
  final String sessionId;
  final String transcript;
  final String replyText;
  final String replyAudioWavBase64;

  VoiceTurnResponseModel({
    required this.sessionId,
    required this.transcript,
    required this.replyText,
    required this.replyAudioWavBase64,
  });

  factory VoiceTurnResponseModel.fromJson(Map<String, dynamic> json) {
    return VoiceTurnResponseModel(
      sessionId: (json['session_id'] ?? 'default').toString(),
      transcript: (json['transcript'] ?? '').toString(),
      replyText: (json['reply_text'] ?? '').toString(),
      replyAudioWavBase64: (json['reply_audio_wav_base64'] ?? '').toString(),
    );
  }
}
