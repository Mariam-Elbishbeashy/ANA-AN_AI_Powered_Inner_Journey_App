// lib/features/video_chat/data/datasources/video_session_remote_data_source.dart
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../models/video_session_model.dart';

class VideoSessionRemoteDataSource {
  VideoSessionRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // Backend URL - adjust to your server
  static const String _backendUrl = "http://192.168.100.7:5003";

  // Use sessions collection for local reference
  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

  CollectionReference<Map<String, dynamic>> _threadsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('chat_threads');
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid, String threadId) {
    return _threadsRef(uid).doc(threadId).collection('messages');
  }

  /// Create a new video session via backend
  Future<VideoSessionModel> createVideoSession({
    required String uid,
    required String characterId,
    String? title,
  }) async {
    try {
      // Generate unique timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      final response = await http.post(
        Uri.parse("$_backendUrl/video/create_session"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': uid,
          'characterId': characterId,
          'characterType': 'inner_character',
          'title': '${title ?? 'Video Session'} - ${timestamp.toString()}',
          'timestamp': timestamp, // Send timestamp to backend
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          // Wait for Firestore to sync
          await Future.delayed(const Duration(milliseconds: 500));

          // Fetch the created session from Firestore
          final sessionDoc = await _sessionsRef(uid).doc(data['sessionId']).get();
          if (sessionDoc.exists) {
            return VideoSessionModel.fromMap(sessionDoc.data() ?? {}, sessionDoc.id);
          } else {
            throw Exception('Session document not found after creation');
          }
        }
      }
      throw Exception('Failed to create session: ${response.body}');
    } catch (e) {
      print('❌ Error creating session via backend: $e');
      rethrow;
    }
  }

  /// Get decrypted messages for a session from the backend
  Future<List<Map<String, dynamic>>> getDecryptedMessagesForSession({
    required String uid,
    required String sessionId,
    int limit = 100,
  }) async {
    try {
      final response = await http.post(
        Uri.parse("$_backendUrl/video/get_messages"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': uid,
          'sessionId': sessionId,
          'limit': limit,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Retrieved ${data['messages']?.length ?? 0} decrypted messages for session: $sessionId');
          return List<Map<String, dynamic>>.from(data['messages'] ?? []);
        }
      }
      print('❌ Failed to get decrypted messages: ${response.body}');
      return [];
    } catch (e) {
      print('❌ Error getting decrypted messages: $e');
      return [];
    }
  }

  /// Get session history with decrypted messages for a character
  Future<List<Map<String, dynamic>>> getCharacterSessionHistory({
    required String uid,
    required String characterId,
    int limit = 50,
    bool includeMessages = false,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$_backendUrl/video/session_history?uid=$uid&characterId=$characterId&limit=$limit&includeMessages=$includeMessages"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Retrieved ${data['sessions']?.length ?? 0} sessions for character: $characterId');
          return List<Map<String, dynamic>>.from(data['sessions'] ?? []);
        }
      }
      return [];
    } catch (e) {
      print('❌ Error getting session history: $e');
      return [];
    }
  }

  /// Save a message using backend encryption (RECOMMENDED)
  /// THIS IS THE KEY METHOD - CALL THIS FOR ENCRYPTION
  Future<void> saveMessageEncrypted({
    required String uid,
    required String threadId,
    required String sessionId,
    required String role,
    required String content,
    String? sender,
    String? characterId,
  }) async {
    if (threadId.isEmpty) {
      print('❌ Cannot save encrypted message: threadId is empty');
      return;
    }

    try {
      print('🔐 Saving encrypted message via backend: role=$role, thread=$threadId, session=$sessionId');

      final response = await http.post(
        Uri.parse("$_backendUrl/video/save_message"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': uid,
          'threadId': threadId,
          'sessionId': sessionId,
          'role': role,
          'content': content,
          'sender': sender,
          'characterId': characterId,
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print('✅ Message saved encrypted via backend: id=${data['messageId']}');
          return;
        }
      }
      print('❌ Failed to save encrypted message: ${response.body}');
    } catch (e) {
      print('❌ Error saving encrypted message: $e');
    }
  }

  /// Get active video session for a character via backend
  Future<VideoSessionModel?> getActiveVideoSession({
    required String uid,
    required String characterId,
  }) async {
    try {
      final response = await http.get(
        Uri.parse("$_backendUrl/video/get_active_session?uid=$uid&characterId=$characterId"),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['session'] != null) {
          final sessionData = data['session'];
          // Fetch full session from Firestore
          final sessionDoc = await _sessionsRef(uid).doc(sessionData['id']).get();
          if (sessionDoc.exists) {
            return VideoSessionModel.fromMap(sessionDoc.data() ?? {}, sessionDoc.id);
          }
        }
      }
      return null;
    } catch (e) {
      print('❌ Error getting active session: $e');
      return null;
    }
  }

  /// Get video session by ID
  Future<VideoSessionModel?> getVideoSession({
    required String uid,
    required String sessionId,
  }) async {
    try {
      final doc = await _sessionsRef(uid).doc(sessionId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      return VideoSessionModel.fromMap(data, doc.id);
    } catch (e) {
      print('❌ Error getting video session: $e');
      return null;
    }
  }

  /// Stream all video sessions for a character
  Stream<List<VideoSessionModel>> streamVideoSessionsForCharacter({
    required String uid,
    required String characterId,
    int limit = 50,
  }) {
    return _sessionsRef(uid)
        .where('characterId', isEqualTo: characterId)
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      final List<VideoSessionModel> sessions = [];

      for (final doc in snapshot.docs) {
        try {
          final data = doc.data();
          final type = data['type'];
          final status = data['status'] ?? 'ended';
          final duration = (data['duration'] as num?)?.toInt() ?? 0;

          final isValidType = (type == 'video' || type == null);
          final hasContent = duration > 0 || status == 'active';

          if (isValidType && hasContent) {
            sessions.add(VideoSessionModel.fromMap(data, doc.id));
          }
        } catch (e) {
          print('❌ Error parsing session: $e');
        }
      }

      print('✅ Loaded ${sessions.length} video sessions for character: $characterId');
      return sessions;
    }).handleError((error) {
      print('❌ Stream error: $error');
      return <VideoSessionModel>[];
    });
  }

  /// Legacy save method - DO NOT USE FOR NEW MESSAGES
  /// This saves plaintext directly to Firestore
  @Deprecated('Use saveMessageEncrypted instead')
  Future<void> saveMessage({
    required String uid,
    required String threadId,
    required String role,
    required String content,
    String? sender,
    String? characterId,
    String? sessionId,
  }) async {
    if (threadId.isEmpty) return;

    try {
      print('⚠️ WARNING: Using deprecated saveMessage (plaintext)! Use saveMessageEncrypted instead.');

      // Save directly to Firestore (PLAINTEXT - NOT ENCRYPTED)
      final msgRef = _messagesRef(uid, threadId).doc();
      await msgRef.set({
        'id': msgRef.id,
        'role': role,
        'content': content,
        'createdAt': FieldValue.serverTimestamp(),
        if (sender != null) 'sender': sender,
        if (characterId != null) 'characterId': characterId,
        if (sessionId != null) 'sessionId': sessionId,
      });

      // Update thread's lastMessageAt
      await _threadsRef(uid).doc(threadId).update({
        'lastMessageAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Update session's lastMessageAt
      if (sessionId != null) {
        await _sessionsRef(uid).doc(sessionId).update({
          'lastMessageAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          if (role == 'user') 'userTurnCount': FieldValue.increment(1),
        });
      }

      print('✅ Message saved to Firestore (PLAINTEXT - NOT RECOMMENDED)');
    } catch (e) {
      print('❌ Error saving message: $e');
    }
  }

  /// Get all messages from a specific thread (legacy - returns unencrypted)
  Future<List<Map<String, dynamic>>> getMessages({
    required String uid,
    required String threadId,
  }) async {
    try {
      if (threadId.isEmpty) {
        print('❌ Cannot get messages: threadId is empty');
        return [];
      }

      final querySnapshot = await _messagesRef(uid, threadId)
          .orderBy('createdAt', descending: false)
          .get();

      final List<Map<String, dynamic>> messages = [];

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        messages.add({
          'id': doc.id,
          'role': data['role'] ?? 'unknown',
          'content': data['content'] ?? '',
          'sender': data['sender'],
          'characterId': data['characterId'],
          'sessionId': data['sessionId'],
          'createdAt': data['createdAt'],
        });
      }

      print('✅ Retrieved ${messages.length} messages from thread: $threadId');
      return messages;
    } catch (e) {
      print('❌ Error getting messages: $e');
      return [];
    }
  }

  /// Get messages for a specific session (legacy - returns unencrypted)
  Future<List<Map<String, dynamic>>> getMessagesForSession({
    required String uid,
    required String sessionId,
  }) async {
    try {
      final sessionDoc = await _sessionsRef(uid).doc(sessionId).get();
      if (!sessionDoc.exists) {
        print('❌ Session not found: $sessionId');
        return [];
      }

      final sessionData = sessionDoc.data() ?? {};
      final threadId = sessionData['threadId'];

      if (threadId == null || threadId.toString().isEmpty) {
        print('❌ No threadId found for session: $sessionId');
        return [];
      }

      return await getMessages(uid: uid, threadId: threadId.toString());
    } catch (e) {
      print('❌ Error getting messages for session: $e');
      return [];
    }
  }

  /// End a video session
  Future<void> endVideoSession({
    required String uid,
    required String sessionId,
    int duration = 0,
  }) async {
    try {
      final session = await getVideoSession(uid: uid, sessionId: sessionId);

      final safeDuration = duration < 0 ? 0 : duration;

      await _sessionsRef(uid).doc(sessionId).update({
        'status': 'ended',
        'endedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'duration': safeDuration,
      });

      if (session != null && session.threadId.isNotEmpty) {
        await _threadsRef(uid).doc(session.threadId).update({
          'status': 'ended',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Ended video session: $sessionId with duration: $safeDuration');
    } catch (e) {
      print('❌ Error ending video session: $e');
    }
  }

  /// Update session with Guider joined status
  Future<void> setGuiderJoined({
    required String uid,
    required String sessionId,
    required bool guiderJoined,
  }) async {
    try {
      await _sessionsRef(uid).doc(sessionId).update({
        'guiderJoined': guiderJoined,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error setting guider joined: $e');
    }
  }

  /// Add emotion to session tracking
  Future<void> addEmotion({
    required String uid,
    required String sessionId,
    required String emotion,
  }) async {
    try {
      await _sessionsRef(uid).doc(sessionId).update({
        'emotionsTracked': FieldValue.arrayUnion([emotion]),
      });
    } catch (e) {
      print('❌ Error adding emotion: $e');
    }
  }

  /// Update session with summary
  Future<void> updateSessionSummary({
    required String uid,
    required String sessionId,
    required Map<String, dynamic> summary,
    required double intensityEnd,
    required double delta,
  }) async {
    try {
      await _sessionsRef(uid).doc(sessionId).update({
        'sessionSummary': summary,
        'intensity.end': intensityEnd,
        'intensity.delta': delta,
        'intensity.updatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('❌ Error updating session summary: $e');
    }
  }
}