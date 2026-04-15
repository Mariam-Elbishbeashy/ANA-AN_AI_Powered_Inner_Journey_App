// lib/features/video_chat/domain/entities/video_message.dart
class VideoMessage {
  final String id;
  final String role;
  final String content;
  final String? sender;
  final DateTime? createdAt;

  VideoMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sender,
    this.createdAt,
  });
}