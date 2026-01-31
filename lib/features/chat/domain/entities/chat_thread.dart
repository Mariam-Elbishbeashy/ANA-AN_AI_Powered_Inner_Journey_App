// Define the data structure for chat threads.
class ChatThread {
  final String id;
  final String characterId;
  final String characterType;
  final String sessionId;
  final String? title;
  final String status;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastMessageAt;

  ChatThread({
    required this.id,
    required this.characterId,
    required this.characterType,
    required this.sessionId,
    this.title,
    required this.status,
    this.createdAt,
    this.updatedAt,
    this.lastMessageAt,
  });
}
