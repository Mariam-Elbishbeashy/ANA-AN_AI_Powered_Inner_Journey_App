import 'package:cloud_firestore/cloud_firestore.dart';

// ============================================================
// ENTITY CLASSES
// ============================================================

// ✅ ADD THIS - VoiceToneData class for voice emotion tracking
class VoiceToneData {
  final String? dominant;
  final double averageConfidence;
  final String? startEmotion;
  final double startConfidence;
  final String? endEmotion;
  final double endConfidence;
  final List<Map<String, dynamic>> allDetections;
  final DateTime? updatedAt;

  const VoiceToneData({
    this.dominant,
    this.averageConfidence = 0.0,
    this.startEmotion,
    this.startConfidence = 0.0,
    this.endEmotion,
    this.endConfidence = 0.0,
    this.allDetections = const [],
    this.updatedAt,
  });

  factory VoiceToneData.fromJson(Map<String, dynamic> json) {
    return VoiceToneData(
      dominant: json['dominant'] as String?,
      averageConfidence: (json['averageConfidence'] as num?)?.toDouble() ?? 0.0,
      startEmotion: json['startEmotion'] as String?,
      startConfidence: (json['startConfidence'] as num?)?.toDouble() ?? 0.0,
      endEmotion: json['endEmotion'] as String?,
      endConfidence: (json['endConfidence'] as num?)?.toDouble() ?? 0.0,
      allDetections: List<Map<String, dynamic>>.from(json['allDetections'] ?? []),
      updatedAt: json['updatedAt'] != null
          ? (json['updatedAt'] as DateTime)
          : null,
    );
  }
}

// ✅ UPDATE VoiceSession class to include voiceTone (with null safety for old sessions)
class VoiceSession {
  final String id;
  final String uid;
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
  final VoiceToneData? voiceTone;

  VoiceSession({
    required this.id,
    required this.uid,
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
    this.voiceTone,
  });

  factory VoiceSession.fromFirestore(String id, Map<String, dynamic> map) {
    // Safely parse voiceTone - handle case where it doesn't exist
    VoiceToneData? voiceToneData;
    if (map['voiceTone'] != null && map['voiceTone'] is Map<String, dynamic>) {
      try {
        voiceToneData = VoiceToneData.fromJson(map['voiceTone']);
      } catch (e) {
        print('Error parsing voiceTone: $e');
        voiceToneData = null;
      }
    }

    return VoiceSession(
      id: id,
      uid: map['uid'] ?? '',
      characterId: map['characterId'] ?? '',
      threadId: map['threadId'],
      startedAt: map['startedAt'] != null
          ? (map['startedAt'] as Timestamp).toDate()
          : DateTime.now(),
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
      voiceTone: voiceToneData,
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
  // STREAM SESSIONS
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
        .where('type', isEqualTo: 'voice')
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
    final docRef = _firestore
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .doc(sessionId);

    final doc = await docRef.get();
    final data = doc.data();

    if (data == null) return;

    final startedAt = data['startedAt'] != null
        ? (data['startedAt'] as Timestamp).toDate()
        : null;

    final endedAt = DateTime.now();

    final duration = startedAt != null
        ? endedAt.difference(startedAt).inSeconds
        : 0;

    await docRef.update({
      'status': 'ended',
      'endedAt': FieldValue.serverTimestamp(),
      'duration': duration,
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