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

    // 🔥 FIX: Don't filter by type - just get all sessions and filter in code
    // This ensures sessions without 'type' field still appear
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

          final duration = _getDuration(data);
          final hasMessages = threadId.isNotEmpty;
          final hasEmotionData = _hasEmotionData(data);
          final hasEndedAt = data['endedAt'] != null;

          // Always show sessions that have ANY content
          final hasContent = hasMessages || duration > 0 || hasEmotionData || hasEndedAt;

          // Also show if it was created recently (within last hour) - for new sessions
          final startedAt = _toDateTime(data['startedAt']);
          final isRecent = startedAt != null &&
              DateTime.now().difference(startedAt).inHours < 1;

          if (hasContent || isRecent) {
            final session = GuiderSession(
              id: doc.id,
              userId: uid,
              characterId: data['characterId']?.toString(),
              status: data['status']?.toString() ?? 'active',
              title: data['title']?.toString(),
              startedAt: startedAt,
              endedAt: _toDateTime(data['endedAt']),
              updatedAt: _toDateTime(data['updatedAt']),
              duration: duration,
              emotionsTracked: data['emotionsTracked'] != null
                  ? List<String>.from(data['emotionsTracked'])
                  : null,
              sessionSummary: data['sessionSummary'] as Map<String, dynamic>?,
              faceEmotion: data['faceEmotion'] as Map<String, dynamic>?,
              voiceTone: data['voiceTone'] as Map<String, dynamic>?,
              intensityStart: (data['intensity'] as Map<String, dynamic>?)?['start']?.toDouble(),
              intensityEnd: (data['intensity'] as Map<String, dynamic>?)?['end']?.toDouble(),
              intensityDelta: (data['intensity'] as Map<String, dynamic>?)?['delta']?.toDouble(),
              threadId: threadId,
            );

            sessions.add(session);
            print("   ✅ Added session: ${session.id}, threadId: $threadId, status: ${session.status}");
          } else {
            print("   ⏭️ Skipped empty session: ${doc.id}");
          }
        } catch (e) {
          print("❌ Error parsing session: $e");
          print("   Document ID: ${doc.id}");
        }
      }

      // Sort by startedAt (newest first) - handle nulls
      sessions.sort((a, b) {
        final aDate = a.startedAt ?? DateTime(2000);
        final bDate = b.startedAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      print("✅ Loaded ${sessions.length} Guider sessions");
      return sessions;
    }).handleError((error) {
      print("❌ Stream error: $error");
      return <GuiderSession>[];
    });
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  bool _hasEmotionData(Map<String, dynamic> data) {
    final faceEmotion = data['faceEmotion'] as Map<String, dynamic>?;
    final voiceTone = data['voiceTone'] as Map<String, dynamic>?;

    final hasFaceEmotion = faceEmotion != null &&
        (faceEmotion['allDetections'] as List?)?.isNotEmpty == true;
    final hasVoiceEmotion = voiceTone != null &&
        (voiceTone['allDetections'] as List?)?.isNotEmpty == true;

    return hasFaceEmotion || hasVoiceEmotion;
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
      }

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GuiderMessage(
          id: doc.id,
          role: data['role'] ?? 'user',
          content: data['content'] ?? '',
          sender: data['sender'],
          createdAt: _toDateTime(data['createdAt']),
        );
      }).toList();
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }
}