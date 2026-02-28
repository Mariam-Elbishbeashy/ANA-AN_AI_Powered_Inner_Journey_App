// user_character.dart
class UserCharacter {
  final String id;
  final String userId;
  final String characterName; // English identifier (e.g., "Inner Critic")
  final String displayNameEn; // English display name
  final String displayNameAr; // Arabic display name
  final String archetype; // 'manager', 'firefighter', or 'exile'
  final double confidence;
  final int rank;
  final String language; // Language used for prediction
  final String glbFileName;
  final String descriptionEn; // English description
  final String descriptionAr; // Arabic description
  final DateTime predictedAt;
  final bool isHealed;
  final DateTime? healedAt;

  UserCharacter({
    required this.id,
    required this.userId,
    required this.characterName,
    required this.displayNameEn,
    required this.displayNameAr,
    required this.archetype,
    required this.confidence,
    required this.rank,
    required this.language,
    required this.glbFileName,
    required this.descriptionEn,
    required this.descriptionAr,
    required this.predictedAt,
    this.isHealed = false,
    this.healedAt,
  });

  // Helper getters for current language
  String getDisplayName(String currentLanguage) {
    return currentLanguage == 'ar' ? displayNameAr : displayNameEn;
  }

  String getDescription(String currentLanguage) {
    return currentLanguage == 'ar' ? descriptionAr : descriptionEn;
  }

  factory UserCharacter.fromMap(Map<String, dynamic> data, String id) {
    return UserCharacter(
      id: id,
      userId: data['userId'],
      characterName: data['characterName'],
      displayNameEn: data['displayNameEn'] ?? data['displayName'] ?? '',
      displayNameAr: data['displayNameAr'] ?? data['displayName'] ?? '',
      archetype: data['archetype'],
      confidence: data['confidence']?.toDouble() ?? 0.0,
      rank: data['rank'],
      language: data['language'] ?? 'en',
      glbFileName: data['glbFileName'],
      descriptionEn: data['descriptionEn'] ?? data['description'] ?? '',
      descriptionAr: data['descriptionAr'] ?? data['description'] ?? '',
      predictedAt: DateTime.parse(data['predictedAt']),
      isHealed: data['isHealed'] ?? false,
      healedAt: data['healedAt'] != null
          ? DateTime.parse(data['healedAt'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'characterName': characterName,
      'displayNameEn': displayNameEn,
      'displayNameAr': displayNameAr,
      'archetype': archetype,
      'confidence': confidence,
      'rank': rank,
      'language': language,
      'glbFileName': glbFileName,
      'descriptionEn': descriptionEn,
      'descriptionAr': descriptionAr,
      'predictedAt': predictedAt.toIso8601String(),
      'isHealed': isHealed,
      'healedAt': healedAt?.toIso8601String(),
    };
  }

  // For backward compatibility during migration
  factory UserCharacter.fromOldMap(Map<String, dynamic> data, String id) {
    return UserCharacter(
      id: id,
      userId: data['userId'],
      characterName: data['characterName'],
      displayNameEn: data['displayName'],
      displayNameAr: data['displayName'], // Will be updated when Arabic data is available
      archetype: data['archetype'],
      confidence: data['confidence']?.toDouble() ?? 0.0,
      rank: data['rank'],
      language: data['language'] ?? 'en',
      glbFileName: data['glbFileName'],
      descriptionEn: data['description'],
      descriptionAr: data['description'], // Will be updated when Arabic data is available
      predictedAt: DateTime.parse(data['predictedAt']),
      isHealed: data['isHealed'] ?? false,
      healedAt: data['healedAt'] != null
          ? DateTime.parse(data['healedAt'])
          : null,
    );
  }
}