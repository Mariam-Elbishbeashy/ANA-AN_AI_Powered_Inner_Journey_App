// lib/features/video_chat/domain/repositories/video_session_repository_interface.dart
import 'dart:async';
import '../entities/video_session.dart';

abstract class VideoSessionRepositoryInterface {
  Future<VideoSession> createVideoSession({
    required String uid,
    required String characterId,
    String? title,
  });

  Future<VideoSession?> getActiveVideoSession({
    required String uid,
    required String characterId,
  });

  Future<VideoSession?> getVideoSession({
    required String uid,
    required String sessionId,
  });

  Stream<List<VideoSession>> streamVideoSessionsForCharacter({
    required String uid,
    required String characterId,
    int limit = 50,
  });

  Future<void> endVideoSession({
    required String uid,
    required String sessionId,
    int duration = 0,
  });

  Future<void> setGuiderJoined({
    required String uid,
    required String sessionId,
    required bool guiderJoined,
  });

  Future<void> addEmotion({
    required String uid,
    required String sessionId,
    required String emotion,
  });

  Future<void> updateSessionSummary({
    required String uid,
    required String sessionId,
    required Map<String, dynamic> summary,
    required double intensityEnd,
    required double delta,
  });
}