import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ana_ifs_app/features/chat/domain/entities/chat_session.dart';

/// Firestore <-> Dart mapper for chat sessions.
///
/// Firestore shape (under `users/{uid}/sessions/{sessionId}`):
/// - type: "chat"
/// - characterId: string
/// - characterType: string
/// - threadId: string (points to `users/{uid}/chat_threads/{threadId}`)
/// - status: "active" | "ended"
/// - title: string?
/// - startedAt: Timestamp
/// - endedAt: Timestamp?
/// - updatedAt: Timestamp
/// - lastMessageAt: Timestamp?
class ChatSessionModel extends ChatSession {
  const ChatSessionModel({
    required super.id,
    required super.type,
    required super.characterId,
    required super.characterType,
    required super.threadId,
    required super.status,
    super.title,
    super.startedAt,
    super.endedAt,
    super.updatedAt,
    super.lastMessageAt,
  });

  factory ChatSessionModel.fromMap(Map<String, dynamic> data, String id) {
    return ChatSessionModel(
      id: id,
      type: data['type']?.toString() ?? 'chat',
      characterId: data['characterId']?.toString() ?? '',
      characterType: data['characterType']?.toString() ?? 'inner_character',
      threadId: data['threadId']?.toString() ?? '',
      status: data['status']?.toString() ?? 'active',
      title: data['title']?.toString(),
      startedAt: _parseTimestamp(data['startedAt']),
      endedAt: _parseTimestamp(data['endedAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastMessageAt: _parseTimestamp(data['lastMessageAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'characterId': characterId,
      'characterType': characterType,
      'threadId': threadId,
      'status': status,
      'title': title,
      'startedAt': startedAt?.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}

