// lib/features/video_chat/data/models/video_session_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/video_session.dart';

class VideoSessionModel extends VideoSession {
  const VideoSessionModel({
    required super.id,
    required super.characterId,
    required super.status,
    super.title,
    super.startedAt,
    super.endedAt,
    super.updatedAt,
    super.duration,
    super.emotionsTracked,
    super.guiderJoined,
    super.sessionSummary,
    super.intensityStart,
    super.intensityEnd,
    super.intensityDelta,
    required super.threadId,
  });

  factory VideoSessionModel.fromMap(Map<String, dynamic> data, String id) {
    final intensity = data['intensity'] as Map<String, dynamic>?;

    // CRITICAL: Ensure duration is properly parsed
    int duration = 0;
    if (data['duration'] != null) {
      if (data['duration'] is int) {
        duration = data['duration'];
      } else if (data['duration'] is double) {
        duration = (data['duration'] as double).toInt();
      } else if (data['duration'] is String) {
        duration = int.tryParse(data['duration'] as String) ?? 0;
      } else if (data['duration'] is num) {
        duration = (data['duration'] as num).toInt();
      }
    }

    return VideoSessionModel(
      id: id,
      characterId: data['characterId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      title: data['title']?.toString(),
      startedAt: _parseTimestamp(data['startedAt']),
      endedAt: _parseTimestamp(data['endedAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      duration: duration,
      emotionsTracked: data['emotionsTracked'] != null
          ? List<String>.from(data['emotionsTracked'])
          : null,
      guiderJoined: data['guiderJoined'] == true,
      sessionSummary: data['sessionSummary'] as Map<String, dynamic>?,
      intensityStart: intensity?['start']?.toDouble(),
      intensityEnd: intensity?['end']?.toDouble(),
      intensityDelta: intensity?['delta']?.toDouble(),
      threadId: data['threadId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    final intensity = <String, dynamic>{};
    if (intensityStart != null) intensity['start'] = intensityStart;
    if (intensityEnd != null) intensity['end'] = intensityEnd;
    if (intensityDelta != null) intensity['delta'] = intensityDelta;

    return {
      'characterId': characterId,
      'status': status,
      'title': title,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'duration': duration,
      'emotionsTracked': emotionsTracked,
      'guiderJoined': guiderJoined,
      'sessionSummary': sessionSummary,
      'threadId': threadId,
      if (intensity.isNotEmpty) 'intensity': intensity,
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}