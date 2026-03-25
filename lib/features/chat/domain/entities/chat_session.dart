/// Represents a "chat session" with a specific character.

class ChatSession {
  final String id;

  /// session type.
  final String type;

  /// the inner character identifier used across the chat backend and Firestore
  final String characterId;

  /// example: `'inner_character'`, `'guider'` (kept for future extensibility)
  final String characterType;

  /// firestore thread document id under `users/{uid}/chat_threads/{threadId}`.
  final String threadId;

  /// `'active'` or `'ended'`.
  final String status;

  /// optional title shown in UI (e.g. character display name).
  final String? title;

  final DateTime? startedAt;
  final DateTime? endedAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;

  const ChatSession({
    required this.id,
    required this.type,
    required this.characterId,
    required this.characterType,
    required this.threadId,
    required this.status,
    this.title,
    this.startedAt,
    this.endedAt,
    this.updatedAt,
    this.lastMessageAt,
  });

  bool get isActive => status == 'active';
}

