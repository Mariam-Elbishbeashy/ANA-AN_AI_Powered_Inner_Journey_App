// lib/features/video_chat/domain/entities/video_session.dart
class VideoSession {
  final String id;
  final String characterId;
  final String status;
  final String? title;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;
  final int duration;
  final List<String>? emotionsTracked;
  final bool guiderJoined;
  final Map<String, dynamic>? sessionSummary;
  final double? intensityStart;
  final double? intensityEnd;
  final double? intensityDelta;
  final String threadId;  // ADD THIS

  const VideoSession({
    required this.id,
    required this.characterId,
    required this.status,
    this.title,
    this.startedAt,
    this.endedAt,
    this.updatedAt,
    this.duration = 0,
    this.emotionsTracked,
    this.guiderJoined = false,
    this.sessionSummary,
    this.intensityStart,
    this.intensityEnd,
    this.intensityDelta,
    required this.threadId,  // ADD THIS
  });

  bool get isActive => status == 'active';
}