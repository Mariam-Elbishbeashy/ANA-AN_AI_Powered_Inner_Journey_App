// lib/features/guider/domain/entities/guider_session.dart
class GuiderSession {
  final String id;
  final String userId;
  final String? characterId;
  final String status;
  final String? title;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;
  final int duration;
  final List<String>? emotionsTracked;
  final Map<String, dynamic>? sessionSummary;
  final Map<String, dynamic>? faceEmotion;
  final Map<String, dynamic>? voiceTone;
  final double? intensityStart;
  final double? intensityEnd;
  final double? intensityDelta;
  final String threadId;

  const GuiderSession({
    required this.id,
    required this.userId,
    this.characterId,
    required this.status,
    this.title,
    this.startedAt,
    this.endedAt,
    this.updatedAt,
    this.duration = 0,
    this.emotionsTracked,
    this.sessionSummary,
    this.faceEmotion,
    this.voiceTone,
    this.intensityStart,
    this.intensityEnd,
    this.intensityDelta,
    required this.threadId,
  });

  bool get isActive => status == 'active';
}