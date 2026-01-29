//Define the data structure for chat messages.
class ChatMessage {
  final String id;
  final String role;
  final String content;
  final DateTime? createdAt;
  final Map<String, dynamic>? metadata;

  ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    this.createdAt,
    this.metadata,
  });
}
