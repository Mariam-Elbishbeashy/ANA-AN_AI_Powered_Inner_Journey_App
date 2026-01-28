//Convert Firestore data into ChatMessage entity (Dart objects).
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ana_ifs_app/features/chat/domain/entities/chat_message.dart';

class ChatMessageModel extends ChatMessage {
  ChatMessageModel({
    required super.id,
    required super.role,
    required super.content,
    super.createdAt,
    super.metadata,
  });

  factory ChatMessageModel.fromMap(Map<String, dynamic> data, String id) {
    return ChatMessageModel(
      id: id,
      role: data['role'] ?? 'assistant',
      content: data['content'] ?? '',
      createdAt: _parseTimestamp(data['createdAt']),
      metadata: data['metadata'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'role': role,
      'content': content,
      'createdAt': createdAt?.toIso8601String(),
      'metadata': metadata,
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
