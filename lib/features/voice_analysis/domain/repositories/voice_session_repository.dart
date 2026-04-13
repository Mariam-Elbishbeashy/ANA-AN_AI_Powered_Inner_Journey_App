import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ENTITY CLASSES
// ============================================================

class VoiceSession {
  final String id;
  final String characterId;
  final String? threadId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int duration;
  final bool isActive;
  final bool guiderJoined;
  final List<String> emotionsTracked;
  final double? intensityStart;
  final double? intensityEnd;
  final Map<String, dynamic>? sessionSummary;

  VoiceSession({
    required this.id,
    required this.characterId,
    this.threadId,
    required this.startedAt,
    this.endedAt,
    this.duration = 0,
    this.isActive = true,
    this.guiderJoined = false,
    this.emotionsTracked = const [],
    this.intensityStart,
    this.intensityEnd,
    this.sessionSummary,
  });

  factory VoiceSession.fromFirestore(String id, Map<String, dynamic> map) {
    return VoiceSession(
      id: id,
      characterId: map['characterId'] ?? '',
      threadId: map['threadId'],
      startedAt: (map['startedAt'] as Timestamp).toDate(),
      endedAt: map['endedAt'] != null
          ? (map['endedAt'] as Timestamp).toDate()
          : null,
      duration: map['duration'] ?? 0,
      isActive: map['status'] == 'active',
      guiderJoined: map['guiderJoined'] ?? false,
      emotionsTracked: List<String>.from(map['emotionsTracked'] ?? []),
      intensityStart: (map['intensity']?['start'] as num?)?.toDouble(),
      intensityEnd: (map['intensity']?['end'] as num?)?.toDouble(),
      sessionSummary: map['sessionSummary'],
    );
  }
}

class VoiceMessage {
  final String id;
  final String role;
  final String content;
  final String? sender;
  final DateTime createdAt;

  VoiceMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sender,
    required this.createdAt,
  });

  factory VoiceMessage.fromFirestore(String id, Map<String, dynamic> map) {
    return VoiceMessage(
      id: id,
      role: map['role'] ?? '',
      content: map['content'] ?? '',
      sender: map['sender'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
    );
  }
}

// ============================================================
// REPOSITORY
// ============================================================

class VoiceSessionRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // STREAM SESSIONS (FIXED - REAL FIRESTORE)
  // ============================================================
  Stream<List<VoiceSession>> streamVoiceSessionsForCharacter({
    required String uid,
    required String characterId,
  }) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .where('characterId', isEqualTo: characterId)
        .orderBy('startedAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        return VoiceSession.fromFirestore(doc.id, data);
      }).toList();
    });
  }

  // ============================================================
  // GET ACTIVE SESSION
  // ============================================================
  Future<VoiceSession?> getActiveVoiceSession({
    required String uid,
    required String characterId,
  }) async {
    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .where('characterId', isEqualTo: characterId)
        .where('status', isEqualTo: 'active')
        .limit(1)
        .get();

    if (query.docs.isEmpty) return null;

    final doc = query.docs.first;
    return VoiceSession.fromFirestore(doc.id, doc.data());
  }

  // ============================================================
  // END SESSION
  // ============================================================
  Future<void> endVoiceSession({
    required String uid,
    required String sessionId,
  }) async {
    await _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId)
        .update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================
  // GET MESSAGES FOR SESSION THREAD
  // ============================================================
  Future<List<VoiceMessage>> getMessages({
    required String uid,
    required String threadId,
  }) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(uid)
        .collection('chat_threads')
        .doc(threadId)
        .collection('messages')
        .orderBy('createdAt')
        .get();

    return snapshot.docs.map((doc) {
      return VoiceMessage.fromFirestore(doc.id, doc.data());
    }).toList();
  }
}