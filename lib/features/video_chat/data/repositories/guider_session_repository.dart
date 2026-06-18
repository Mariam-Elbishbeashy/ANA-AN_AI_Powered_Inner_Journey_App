// lib/features/guider/data/repositories/guider_session_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../domain/entities/guider_session.dart';
import '../../domain/entities/guider_message.dart';

class GuiderSessionRepository {
  final FirebaseFirestore _firestore;

  GuiderSessionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

  CollectionReference<Map<String, dynamic>> _threadsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('chat_threads');
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid, String threadId) {
    return _threadsRef(uid).doc(threadId).collection('messages');
  }

  /// Stream ALL Guider video call sessions for a user
  Stream<List<GuiderSession>> streamGuiderSessions({
    required String uid,
    int limit = 100,
  }) {
    print("📡 Streaming Guider sessions for uid: $uid");

    return _sessionsRef(uid)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<GuiderSession> sessions = [];

      print("📊 Got ${snapshot.docs.length} total session documents");

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          // Check if this is a Guider session (video or chat)
          final characterType = data['characterType'];
          final type = data['type'];

          // Include if:
          // 1. characterType is 'guider' OR null (old sessions)
          // 2. AND (type is 'video' OR type is null OR type is empty)
          final isGuider = characterType == 'guider' || characterType == null;
          final isVideoType = type == 'video' || type == null || type.toString().isEmpty;

          if (!isGuider || !isVideoType) {
            print("   ⏭️ Skipped session: ${doc.id} (characterType: $characterType, type: $type)");
            continue;
          }

          print("   ✅ Processing Guider session: ${doc.id}");

          // Find thread by querying chat_threads collection
          String threadId = data['threadId'] ?? '';

          if (threadId.isEmpty) {
            print("   🔍 Looking for thread for session: ${doc.id}");
            try {
              final threadsQuery = await _threadsRef(uid)
                  .where('sessionId', isEqualTo: doc.id)
                  .limit(1)
                  .get();

              if (threadsQuery.docs.isNotEmpty) {
                threadId = threadsQuery.docs.first.id;
                print("   ✅ Found threadId: $threadId");
              } else {
                print("   ⚠️ No thread found");
              }
            } catch (e) {
              print("   ❌ Error finding thread: $e");
            }
          }

          final startedAt = _toDateTime(data['startedAt']) ?? DateTime.now();
          final endedAt = _toDateTime(data['endedAt']);
          final isActive = data['isActive'] ?? true;
          final duration = _getDuration(data);
          final hasMessages = data['hasMessages'] ?? (threadId.isNotEmpty);
          final messageCount = data['messageCount'] as int?;

          // Check if there are any emotions detected
          final hasFaceEmotion = (data['faceEmotion'] as Map<String, dynamic>?)?['totalDetections'] != null &&
              (data['faceEmotion'] as Map<String, dynamic>?)?['totalDetections'] > 0;
          final hasVoiceEmotion = (data['voiceTone'] as Map<String, dynamic>?)?['totalDetections'] != null &&
              (data['voiceTone'] as Map<String, dynamic>?)?['totalDetections'] > 0;

          final hasEmotionData = hasFaceEmotion || hasVoiceEmotion;

          // Always show sessions that have ANY content
          final hasContent = hasMessages || duration > 0 || hasEmotionData || endedAt != null;

          // Also show if it was created recently (within last hour) - for new sessions
          final isRecent = startedAt != null &&
              DateTime.now().difference(startedAt).inHours < 1;

          if (hasContent || isRecent) {
            final session = GuiderSession(
              id: doc.id,
              threadId: threadId,
              startedAt: startedAt,
              endedAt: endedAt,
              isActive: isActive,
              duration: duration,
              faceEmotion: data['faceEmotion'] as Map<String, dynamic>?,
              voiceTone: data['voiceTone'] as Map<String, dynamic>?,
              hasMessages: hasMessages,
              messageCount: messageCount,
            );

            sessions.add(session);
            print("   ✅ Added session: ${session.id}, threadId: $threadId, status: ${session.isActive ? 'active' : 'ended'}, hasMessages: $hasMessages");
          } else {
            print("   ⏭️ Skipped empty session: ${doc.id}");
          }
        } catch (e) {
          print("❌ Error parsing session: $e");
          print("   Document ID: ${doc.id}");
        }
      }

      // Sort by startedAt (newest first)
      sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));

      print("✅ Loaded ${sessions.length} Guider sessions");
      return sessions;
    }).handleError((error) {
      print("❌ Stream error: $error");
      return <GuiderSession>[];
    });
  }

  /// Get a single Guider session by ID
  Future<GuiderSession?> getSession({
    required String uid,
    required String sessionId,
  }) async {
    try {
      final doc = await _sessionsRef(uid).doc(sessionId).get();
      if (!doc.exists) return null;

      final data = doc.data()!;
      final threadId = data['threadId'] ?? '';

      return GuiderSession(
        id: doc.id,
        threadId: threadId,
        startedAt: _toDateTime(data['startedAt']) ?? DateTime.now(),
        endedAt: _toDateTime(data['endedAt']),
        isActive: data['isActive'] ?? true,
        duration: _getDuration(data),
        faceEmotion: data['faceEmotion'] as Map<String, dynamic>?,
        voiceTone: data['voiceTone'] as Map<String, dynamic>?,
        hasMessages: data['hasMessages'] ?? (threadId.isNotEmpty),
        messageCount: data['messageCount'] as int?,
      );
    } catch (e) {
      print("❌ Error getting session: $e");
      return null;
    }
  }

  /// Update session when it ends
  // lib/features/guider/data/repositories/guider_session_repository.dart

  /// Update session when it ends
  Future<void> endSession({
    required String uid,
    required String sessionId,
    required int duration,
    required bool hasMessages,
    int? messageCount,
  }) async {
    try {
      final sessionRef = _sessionsRef(uid).doc(sessionId);

      // First check if the session exists
      final doc = await sessionRef.get();

      if (doc.exists) {
        await sessionRef.update({
          'endedAt': FieldValue.serverTimestamp(),
          'isActive': false,
          'duration': duration,
          'hasMessages': hasMessages,
          'messageCount': messageCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create the session if it doesn't exist
        await sessionRef.set({
          'startedAt': DateTime.now(),
          'endedAt': DateTime.now(),
          'isActive': false,
          'duration': duration,
          'hasMessages': hasMessages,
          'messageCount': messageCount,
          'characterType': 'guider',
          'type': 'video',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      print("✅ Session ended: $sessionId, hasMessages: $hasMessages, duration: ${duration}s");
    } catch (e) {
      print("❌ Error ending session: $e");
      rethrow;
    }
  }

  /// Increment message count for a session
  Future<void> incrementMessageCount({
    required String uid,
    required String sessionId,
  }) async {
    try {
      await _sessionsRef(uid).doc(sessionId).update({
        'messageCount': FieldValue.increment(1),
        'hasMessages': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("❌ Error incrementing message count: $e");
    }
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _getDuration(Map<String, dynamic> data) {
    // Check if duration field exists
    if (data['duration'] != null) {
      if (data['duration'] is int) {
        return data['duration'];
      } else if (data['duration'] is double) {
        return (data['duration'] as double).toInt();
      } else if (data['duration'] is num) {
        return (data['duration'] as num).toInt();
      }
    }

    // Calculate duration from timestamps if available
    if (data['startedAt'] != null && data['endedAt'] != null) {
      final start = _toDateTime(data['startedAt']);
      final end = _toDateTime(data['endedAt']);
      if (start != null && end != null) {
        return end.difference(start).inSeconds;
      }
    }

    return 0;
  }

  /// Get messages from a specific thread
  Future<List<GuiderMessage>> getMessages({
    required String uid,
    required String threadId,
  }) async {
    if (threadId.isEmpty) {
      print('❌ getMessages: threadId is empty');
      return [];
    }

    try {
      print('📖 Getting messages for threadId: $threadId');

      final snapshot = await _messagesRef(uid, threadId)
          .orderBy('createdAt', descending: false)
          .get();

      print('✅ Found ${snapshot.docs.length} messages');

      if (snapshot.docs.isEmpty) {
        print('⚠️ No messages found in thread: $threadId');
        return [];
      }

      final messages = <GuiderMessage>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();
        String content = data['content'] ?? '';

        // If content is encrypted, we'll decrypt in the UI layer
        // Just store the raw content for now
        messages.add(GuiderMessage(
          id: doc.id,
          role: data['role'] ?? 'user',
          content: content,
          sender: data['sender'],
          characterId: data['characterId'],
          sessionId: data['sessionId'],
          createdAt: _toDateTime(data['createdAt']),
        ));
      }

      return messages;
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }

  /// Save a message to a thread
  Future<void> saveMessage({
    required String uid,
    required String threadId,
    required String role,
    required String content,
    String? sender,
    String? characterId,
    String? sessionId,
    bool encrypted = false,
  }) async {
    if (threadId.isEmpty) {
      print('❌ saveMessage: threadId is empty');
      return;
    }

    try {
      final messageData = {
        'role': role,
        'content': content,
        'sender': sender ?? (role == 'user' ? 'user' : 'assistant'),
        'createdAt': FieldValue.serverTimestamp(),
        if (characterId != null) 'characterId': characterId,
        if (sessionId != null) 'sessionId': sessionId,
        if (encrypted) 'encrypted': true,
      };

      await _messagesRef(uid, threadId).add(messageData);
      print('✅ Message saved to thread: $threadId');
    } catch (e) {
      print('❌ Error saving message: $e');
      rethrow;
    }
  }
}