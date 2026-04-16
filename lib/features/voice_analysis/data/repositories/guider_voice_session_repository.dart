// lib/features/guider/data/repositories/guider_voice_session_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../domain/entities/guider_voice_session.dart';
import '../../domain/entities/guider_voice_message.dart';

class GuiderVoiceSessionRepository {
  final FirebaseFirestore _firestore;

  GuiderVoiceSessionRepository({FirebaseFirestore? firestore})
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

  /// Stream ALL Guider voice sessions for a user
  Stream<List<GuiderVoiceSession>> streamGuiderVoiceSessions({
    required String uid,
    int limit = 100,
  }) {
    print("📡 Streaming Guider voice sessions for uid: $uid");

    return _sessionsRef(uid)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .asyncMap((snapshot) async {
      final List<GuiderVoiceSession> sessions = [];

      print("📊 Got ${snapshot.docs.length} total session documents");

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();

          final characterType = data['characterType'];
          final type = data['type'];

          // Filter for Guider voice sessions
          final isVoiceType = type == 'voice' || type == 'guider_voice';

          final isGuider =
              (characterType == 'guider') ||
                  (data['threadId']?.toString().startsWith('guider_') ?? false);

          if (!isGuider || !isVoiceType) {
            continue;
          }

          print("   ✅ Processing Guider voice session: ${doc.id}");

          // Find thread
          String threadId = data['threadId'] ?? '';

          if (threadId.isEmpty) {
            try {
              final threadsQuery = await _threadsRef(uid)
                  .where('sessionId', isEqualTo: doc.id)
                  .limit(1)
                  .get();

              if (threadsQuery.docs.isNotEmpty) {
                threadId = threadsQuery.docs.first.id;
              }
            } catch (e) {
              print("   ❌ Error finding thread: $e");
            }
          }

          final duration = _getDuration(data);
          final hasMessages = threadId.isNotEmpty;
          final hasEndedAt = data['endedAt'] != null;

          final hasContent = hasMessages || duration > 0 || hasEndedAt;

          if (hasContent) {
            final session = GuiderVoiceSession(
              id: doc.id,
              userId: uid,
              characterId: data['characterId']?.toString(),
              status: data['status']?.toString() ?? 'active',
              title: data['title']?.toString(),
              startedAt: _toDateTime(data['startedAt']),
              endedAt: _toDateTime(data['endedAt']),
              updatedAt: _toDateTime(data['updatedAt']),
              duration: duration,
              emotionsTracked: data['emotionsTracked'] != null
                  ? List<String>.from(data['emotionsTracked'])
                  : null,
              sessionSummary: data['sessionSummary'] as Map<String, dynamic>?,
              intensityStart: (data['intensity'] as Map<String, dynamic>?)?['start']?.toDouble(),
              intensityEnd: (data['intensity'] as Map<String, dynamic>?)?['end']?.toDouble(),
              intensityDelta: (data['intensity'] as Map<String, dynamic>?)?['delta']?.toDouble(),
              threadId: threadId,
            );

            sessions.add(session);
          }
        } catch (e) {
          print("❌ Error parsing session: $e");
        }
      }

      sessions.sort((a, b) {
        final aDate = a.startedAt ?? DateTime(2000);
        final bDate = b.startedAt ?? DateTime(2000);
        return bDate.compareTo(aDate);
      });

      print("✅ Loaded ${sessions.length} Guider voice sessions");
      return sessions;
    }).handleError((error) {
      print("❌ Stream error: $error");
      return <GuiderVoiceSession>[];
    });
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  int _getDuration(Map<String, dynamic> data) {
    if (data['duration'] != null) {
      if (data['duration'] is int) {
        return data['duration'];
      } else if (data['duration'] is double) {
        return (data['duration'] as double).toInt();
      } else if (data['duration'] is num) {
        return (data['duration'] as num).toInt();
      }
    }

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
  Future<List<GuiderVoiceMessage>> getMessages({
    required String uid,
    required String threadId,
  }) async {
    if (threadId.isEmpty) {
      return [];
    }

    try {
      final snapshot = await _messagesRef(uid, threadId)
          .orderBy('createdAt', descending: false)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return GuiderVoiceMessage(
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