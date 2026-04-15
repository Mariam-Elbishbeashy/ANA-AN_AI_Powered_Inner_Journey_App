// lib/features/guider/domain/entities/guider_message.dart
import 'package:equatable/equatable.dart';

class GuiderMessage extends Equatable {
  final String id;
  final String role;
  final String content;
  final String? sender;
  final String? characterId;
  final String? sessionId;
  final DateTime? createdAt;

  const GuiderMessage({
    required this.id,
    required this.role,
    required this.content,
    this.sender,
    this.characterId,
    this.sessionId,
    this.createdAt,
  });

  @override
  List<Object?> get props => [id, role, content, sender, characterId, sessionId, createdAt];
}