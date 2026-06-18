// lib/features/guider/domain/entities/guider_session.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class GuiderSession {
  final String id;
  final String threadId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final bool isActive;
  final int duration;
  final Map<String, dynamic>? faceEmotion;
  final Map<String, dynamic>? voiceTone;
  final bool hasMessages; // Added: indicates if session has any messages
  final int? messageCount; // Added: count of messages in session

  GuiderSession({
    required this.id,
    required this.threadId,
    required this.startedAt,
    this.endedAt,
    required this.isActive,
    required this.duration,
    this.faceEmotion,
    this.voiceTone,
    this.hasMessages = false,
    this.messageCount,
  });

  factory GuiderSession.fromMap(String id, Map<String, dynamic> map) {
    return GuiderSession(
      id: id,
      threadId: map['threadId'] ?? '',
      startedAt: (map['startedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endedAt: (map['endedAt'] as Timestamp?)?.toDate(),
      isActive: map['isActive'] ?? true,
      duration: map['duration'] ?? 0,
      faceEmotion: map['faceEmotion'] as Map<String, dynamic>?,
      voiceTone: map['voiceTone'] as Map<String, dynamic>?,
      hasMessages: map['hasMessages'] ?? false,
      messageCount: map['messageCount'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'threadId': threadId,
      'startedAt': startedAt,
      'endedAt': endedAt,
      'isActive': isActive,
      'duration': duration,
      'faceEmotion': faceEmotion,
      'voiceTone': voiceTone,
      'hasMessages': hasMessages,
      'messageCount': messageCount,
    };
  }
}