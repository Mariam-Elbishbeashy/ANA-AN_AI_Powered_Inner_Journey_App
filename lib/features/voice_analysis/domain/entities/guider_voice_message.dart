// lib/features/guider/domain/entities/guider_voice_message.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ana_ifs_app/core/security/message_encryption.dart';

class GuiderVoiceMessage {
  final String id;
  final String role;
  final String content;
  final String? sender;
  final DateTime? createdAt;

  GuiderVoiceMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sender,
    this.createdAt,
  });

  factory GuiderVoiceMessage.fromFirestore(String id, Map<String, dynamic> map, String uid) {
    String decryptedContent = '';
    final encryptedContent = map['content']?.toString() ?? '';

    if (encryptedContent.isNotEmpty) {
      decryptedContent = MessageEncryption.decryptMessage(encryptedContent, uid);
      print("📝 Decrypted Guider message: ${decryptedContent.substring(0, decryptedContent.length > 50 ? 50 : decryptedContent.length)}...");
    }

    return GuiderVoiceMessage(
      id: id,
      role: map['role']?.toString() ?? 'user',
      content: decryptedContent,
      sender: map['sender']?.toString(),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  Map<String, dynamic> toMapForFirestore(String uid) {
    final encryptedContent = MessageEncryption.encryptMessage(content, uid);

    return {
      'role': role,
      'content': encryptedContent,
      'sender': sender,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    return null;
  }
}