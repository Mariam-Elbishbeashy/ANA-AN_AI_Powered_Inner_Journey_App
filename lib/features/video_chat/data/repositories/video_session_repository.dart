// lib/features/video_chat/data/repositories/video_session_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/video_message.dart';
import '../datasources/video_session_remote_data_source.dart';
import '../../domain/entities/video_session.dart';
import '../../domain/repositories/video_session_repository_interface.dart';

class VideoSessionRepository implements VideoSessionRepositoryInterface {
  final VideoSessionRemoteDataSource _remoteDataSource;

  VideoSessionRepository({VideoSessionRemoteDataSource? remoteDataSource})
      : _remoteDataSource = remoteDataSource ?? VideoSessionRemoteDataSource();

  @override
  Future<VideoSession> createVideoSession({
    required String uid,
    required String characterId,
    String? title,
  }) async {
    return await _remoteDataSource.createVideoSession(
      uid: uid,
      characterId: characterId,
      title: title,
    );
  }

  @override
  Future<VideoSession?> getActiveVideoSession({
    required String uid,
    required String characterId,
  }) async {
    return await _remoteDataSource.getActiveVideoSession(
      uid: uid,
      characterId: characterId,
    );
  }

  @override
  Future<VideoSession?> getVideoSession({
    required String uid,
    required String sessionId,
  }) async {
    return await _remoteDataSource.getVideoSession(
      uid: uid,
      sessionId: sessionId,
    );
  }

  @override
  Stream<List<VideoSession>> streamVideoSessionsForCharacter({
    required String uid,
    required String characterId,
    int limit = 50,
  }) {
    return _remoteDataSource.streamVideoSessionsForCharacter(
      uid: uid,
      characterId: characterId,
      limit: limit,
    );
  }

  @override
  Future<void> endVideoSession({
    required String uid,
    required String sessionId,
    int duration = 0,
  }) async {
    await _remoteDataSource.endVideoSession(
      uid: uid,
      sessionId: sessionId,
      duration: duration,
    );
  }

  @override
  Future<void> setGuiderJoined({
    required String uid,
    required String sessionId,
    required bool guiderJoined,
  }) async {
    await _remoteDataSource.setGuiderJoined(
      uid: uid,
      sessionId: sessionId,
      guiderJoined: guiderJoined,
    );
  }

  @override
  Future<void> addEmotion({
    required String uid,
    required String sessionId,
    required String emotion,
  }) async {
    await _remoteDataSource.addEmotion(
      uid: uid,
      sessionId: sessionId,
      emotion: emotion,
    );
  }

  @override
  Future<void> updateSessionSummary({
    required String uid,
    required String sessionId,
    required Map<String, dynamic> summary,
    required double intensityEnd,
    required double delta,
  }) async {
    await _remoteDataSource.updateSessionSummary(
      uid: uid,
      sessionId: sessionId,
      summary: summary,
      intensityEnd: intensityEnd,
      delta: delta,
    );
  }

  /// Save a message to Firestore
  Future<void> saveMessage({
    required String uid,
    required String threadId,
    required String role,
    required String content,
    String? sender,
    String? characterId,
    String? sessionId,
  }) async {
    await _remoteDataSource.saveMessage(
      uid: uid,
      threadId: threadId,
      role: role,
      content: content,
      sender: sender,
      characterId: characterId,
      sessionId: sessionId,
    );
  }

  /// Get messages from Firestore (READ ONLY)
  Future<List<VideoMessage>> getMessages({
    required String uid,
    required String threadId,
  }) async {
    if (threadId.isEmpty) {
      print('❌ getMessages: threadId is empty');
      return [];
    }

    try {
      print('📖 Getting messages for threadId: $threadId');

      final messagesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages');

      final snapshot = await messagesRef
          .orderBy('createdAt', descending: false)
          .get();

      print('✅ Found ${snapshot.docs.length} messages');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        DateTime? dateTime;
        if (createdAt is Timestamp) {
          dateTime = createdAt.toDate();
        } else if (createdAt is DateTime) {
          dateTime = createdAt;
        }

        return VideoMessage(
          id: doc.id,
          role: data['role'] ?? 'user',
          content: data['content'] ?? '',
          sender: data['sender'],
          createdAt: dateTime,
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }
}