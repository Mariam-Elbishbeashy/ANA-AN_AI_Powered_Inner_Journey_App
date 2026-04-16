// lib/features/guider/domain/entities/guider_voice_session.dart
class GuiderVoiceSession {
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
  final double? intensityStart;
  final double? intensityEnd;
  final double? intensityDelta;
  final String threadId;

  GuiderVoiceSession({
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
    this.intensityStart,
    this.intensityEnd,
    this.intensityDelta,
    required this.threadId,
  });

  bool get isActive => status == 'active';

  factory GuiderVoiceSession.fromFirestore(String id, Map<String, dynamic> map) {
    return GuiderVoiceSession(
      id: id,
      userId: map['userId'] ?? map['uid'] ?? '',
      characterId: map['characterId']?.toString(),
      status: map['status']?.toString() ?? 'active',
      title: map['title']?.toString(),
      startedAt: _toDateTime(map['startedAt']),
      endedAt: _toDateTime(map['endedAt']),
      updatedAt: _toDateTime(map['updatedAt']),
      duration: map['duration'] ?? 0,
      emotionsTracked: map['emotionsTracked'] != null
          ? List<String>.from(map['emotionsTracked'])
          : null,
      sessionSummary: map['sessionSummary'] as Map<String, dynamic>?,
      intensityStart: (map['intensity'] as Map<String, dynamic>?)?['start']?.toDouble(),
      intensityEnd: (map['intensity'] as Map<String, dynamic>?)?['end']?.toDouble(),
      intensityDelta: (map['intensity'] as Map<String, dynamic>?)?['delta']?.toDouble(),
      threadId: map['threadId']?.toString() ?? '',
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return null;
  }
}