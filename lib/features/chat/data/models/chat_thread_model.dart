//Convert Firestore data into ChatThread entity (Dart objects).
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ana_ifs_app/features/chat/domain/entities/chat_thread.dart';

class ChatThreadModel extends ChatThread {
  ChatThreadModel({
    required super.id,
    required super.characterId,
    required super.characterType,
    required super.sessionId,
    super.title,
    required super.status,
    super.createdAt,
    super.updatedAt,
    super.lastMessageAt,
  });

  factory ChatThreadModel.fromMap(Map<String, dynamic> data, String id) {
    return ChatThreadModel(
      id: id,
      characterId: data['characterId'],
      characterType: data['characterType'] ?? 'inner_character',
      sessionId: data['sessionId'],
      title: data['title'],
      status: data['status'] ?? 'active',
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      lastMessageAt: _parseTimestamp(data['lastMessageAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'characterId': characterId,
      'characterType': characterType,
      'sessionId': sessionId,
      'title': title,
      'status': status,
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'lastMessageAt': lastMessageAt?.toIso8601String(),
    };
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
