// lib/features/guider/domain/entities/guider_voice_message.dart
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

  factory GuiderVoiceMessage.fromFirestore(String id, Map<String, dynamic> map) {
    return GuiderVoiceMessage(
      id: id,
      role: map['role']?.toString() ?? 'user',
      content: map['content']?.toString() ?? '',
      sender: map['sender']?.toString(),
      createdAt: _toDateTime(map['createdAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return null;
  }
}