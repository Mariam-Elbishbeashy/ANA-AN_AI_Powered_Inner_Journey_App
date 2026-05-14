// lib/features/video_chat/data/repositories/video_session_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
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

  /// Save a message - NOW USES ENCRYPTED VERSION
  /// This is the main method called from video_call_screen.dart
  Future<void> saveMessage({
    required String uid,
    required String threadId,
    required String role,
    required String content,
    String? sender,
    String? characterId,
    String? sessionId,
  }) async {
    // ALWAYS use encrypted version if sessionId is provided
    if (sessionId != null && sessionId.isNotEmpty) {
      await _remoteDataSource.saveMessageEncrypted(
        uid: uid,
        threadId: threadId,
        sessionId: sessionId,
        role: role,
        content: content,
        sender: sender,
        characterId: characterId,
      );
    } else {
      // Fallback to legacy (but still try encrypted if possible)
      debugPrint('⚠️ Warning: Saving without sessionId - using legacy method!');
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
  }

  /// Save a message with encryption (direct call)
  Future<void> saveMessageEncrypted({
    required String uid,
    required String threadId,
    required String sessionId,
    required String role,
    required String content,
    String? sender,
    String? characterId,
  }) async {
    await _remoteDataSource.saveMessageEncrypted(
      uid: uid,
      threadId: threadId,
      sessionId: sessionId,
      role: role,
      content: content,
      sender: sender,
      characterId: characterId,
    );
  }

  /// Get messages from Firestore (legacy - returns unencrypted)
  /// Used for backward compatibility
  Future<List<VideoMessage>> getMessages({
    required String uid,
    required String threadId,
  }) async {
    if (threadId.isEmpty) {
      debugPrint('❌ getMessages: threadId is empty');
      return [];
    }

    try {
      debugPrint('📖 Getting messages for threadId: $threadId');

      final messagesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages');

      final snapshot = await messagesRef
          .orderBy('createdAt', descending: false)
          .get();

      debugPrint('✅ Found ${snapshot.docs.length} messages');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        final createdAt = data['createdAt'];
        DateTime? dateTime;
        if (createdAt is Timestamp) {
          dateTime = createdAt.toDate();
        } else if (createdAt is DateTime) {
          dateTime = createdAt;
        }

        // Check if message is encrypted
        final content = data['contentCiphertext'] != null
            ? '[Encrypted message]'  // Don't try to decrypt here - use getDecryptedMessagesForSession
            : (data['content'] ?? '');

        return VideoMessage(
          id: doc.id,
          role: data['role'] ?? 'user',
          content: content,
          sender: data['sender'],
          createdAt: dateTime,
        );
      }).toList();
    } catch (e) {
      debugPrint('❌ Error getting messages: $e');
      return [];
    }
  }

  /// Get decrypted messages for a session (recommended for new code)
  Future<List<VideoMessage>> getDecryptedMessagesForSession({
    required String uid,
    required String sessionId,
  }) async {
    final messagesData = await _remoteDataSource.getDecryptedMessagesForSession(
      uid: uid,
      sessionId: sessionId,
    );

    return messagesData.map((data) {
      final createdAt = data['createdAt'];
      DateTime? dateTime;
      if (createdAt is String) {
        dateTime = DateTime.tryParse(createdAt);
      } else if (createdAt is Timestamp) {
        dateTime = createdAt.toDate();
      } else if (createdAt is DateTime) {
        dateTime = createdAt;
      }

      return VideoMessage(
        id: data['id'] ?? '',
        role: data['role'] ?? 'user',
        content: data['content'] ?? '',
        sender: data['sender'],
        createdAt: dateTime,
      );
    }).toList();
  }

  /// Get session history with decrypted messages for a character
  Future<List<VideoSession>> getCharacterSessionHistory({
    required String uid,
    required String characterId,
    int limit = 50,
    bool includeMessages = false,
  }) async {
    final sessionsData = await _remoteDataSource.getCharacterSessionHistory(
      uid: uid,
      characterId: characterId,
      limit: limit,
      includeMessages: includeMessages,
    );

    return sessionsData.map((data) {
      final startedAt = data['startedAt'];
      DateTime? startedAtDate;
      if (startedAt is String) {
        startedAtDate = DateTime.tryParse(startedAt);
      } else if (startedAt is Timestamp) {
        startedAtDate = startedAt.toDate();
      } else if (startedAt is DateTime) {
        startedAtDate = startedAt;
      }

      final endedAt = data['endedAt'];
      DateTime? endedAtDate;
      if (endedAt is String) {
        endedAtDate = DateTime.tryParse(endedAt);
      } else if (endedAt is Timestamp) {
        endedAtDate = endedAt.toDate();
      } else if (endedAt is DateTime) {
        endedAtDate = endedAt;
      }

      return VideoSession(
        id: data['id'] ?? '',
        threadId: data['threadId'] ?? '',
        characterId: data['characterId'] ?? '',
        status: data['status'] ?? 'ended',
        startedAt: startedAtDate,
        endedAt: endedAtDate,
        duration: data['duration'] ?? 0,
        title: data['title'],
        guiderJoined: data['guiderJoined'] ?? false,
      );
    }).toList();
  }
}