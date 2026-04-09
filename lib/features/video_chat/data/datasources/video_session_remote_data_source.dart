// lib/features/video_chat/data/datasources/video_session_remote_data_source.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/video_session_model.dart';

class VideoSessionRemoteDataSource {
  VideoSessionRemoteDataSource({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  // CRITICAL: Use the SAME sessions collection as chat (NOT video_sessions)
  CollectionReference<Map<String, dynamic>> _sessionsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('sessions');
  }

  CollectionReference<Map<String, dynamic>> _threadsRef(String uid) {
    return _firestore.collection('users').doc(uid).collection('chat_threads');
  }

  CollectionReference<Map<String, dynamic>> _messagesRef(String uid, String threadId) {
    return _threadsRef(uid).doc(threadId).collection('messages');
  }

  /// Create a new video session
  Future<VideoSessionModel> createVideoSession({
    required String uid,
    required String characterId,
    String? title,
  }) async {
    final sessionDoc = _sessionsRef(uid).doc();
    final threadDoc = _threadsRef(uid).doc();

    final batch = _firestore.batch();

    // Create session document with type "video"
    batch.set(sessionDoc, {
      'type': 'video',  // CRITICAL: Mark as video type
      'characterId': characterId,
      'characterType': 'inner_character',
      'threadId': threadDoc.id,
      'title': title,
      'status': 'active',
      'startedAt': FieldValue.serverTimestamp(),
      'endedAt': null,
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
      'duration': 0,
      'guiderJoined': false,
      'emotionsTracked': [],
      'intensity': {},
      'sessionSummary': null,
    });

    // Create thread document
    batch.set(threadDoc, {
      'characterId': characterId,
      'characterType': 'inner_character',
      'sessionId': sessionDoc.id,
      'title': title,
      'status': 'active',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': null,
    });

    await batch.commit();

    final snapshot = await sessionDoc.get();
    return VideoSessionModel.fromMap(snapshot.data() ?? {}, sessionDoc.id);
  }

  /// Get active video session for a character
  Future<VideoSessionModel?> getActiveVideoSession({
    required String uid,
    required String characterId,
  }) async {
    final query = await _sessionsRef(uid)
        .where('characterId', isEqualTo: characterId)
        .where('type', isEqualTo: 'video')
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;
    final doc = query.docs.first;
    return VideoSessionModel.fromMap(doc.data(), doc.id);
  }

  /// Get video session by ID
  Future<VideoSessionModel?> getVideoSession({
    required String uid,
    required String sessionId,
  }) async {
    final doc = await _sessionsRef(uid).doc(sessionId).get();
    if (!doc.exists) return null;
    final data = doc.data() ?? {};
    if (data['type'] != 'video') return null;
    return VideoSessionModel.fromMap(data, doc.id);
  }

  /// Stream all video sessions for a character
  Stream<List<VideoSessionModel>> streamVideoSessionsForCharacter({
    required String uid,
    required String characterId,
    int limit = 50,
  }) {
    return _sessionsRef(uid)
        .where('characterId', isEqualTo: characterId)
        .where('type', isEqualTo: 'video')
        .orderBy('startedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => VideoSessionModel.fromMap(doc.data(), doc.id))
        .toList());
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
    if (threadId.isEmpty) return;

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
  }

  /// End a video session
  Future<void> endVideoSession({
    required String uid,
    required String sessionId,
    int duration = 0,
  }) async {
    final session = await getVideoSession(uid: uid, sessionId: sessionId);

    await _sessionsRef(uid).doc(sessionId).update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'duration': duration,
    });

    if (session != null && session.threadId.isNotEmpty) {
      await _threadsRef(uid).doc(session.threadId).update({
        'status': 'ended',
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Update session with Guider joined status
  Future<void> setGuiderJoined({
    required String uid,
    required String sessionId,
    required bool guiderJoined,
  }) async {
    await _sessionsRef(uid).doc(sessionId).update({
      'guiderJoined': guiderJoined,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Add emotion to session tracking
  Future<void> addEmotion({
    required String uid,
    required String sessionId,
    required String emotion,
  }) async {
    await _sessionsRef(uid).doc(sessionId).update({
      'emotionsTracked': FieldValue.arrayUnion([emotion]),
    });
  }

  /// Update session with summary
  Future<void> updateSessionSummary({
    required String uid,
    required String sessionId,
    required Map<String, dynamic> summary,
    required double intensityEnd,
    required double delta,
  }) async {
    await _sessionsRef(uid).doc(sessionId).update({
      'sessionSummary': summary,
      'intensity.end': intensityEnd,
      'intensity.delta': delta,
      'intensity.updatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}