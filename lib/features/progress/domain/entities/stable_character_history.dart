class StableCharacterHistory {
  final String id;
  final String userId;
  final String sourceCharacterId;
  final String characterName;
  final String displayNameEn;
  final String displayNameAr;
  final String archetype;
  final String glbFileName;
  final DateTime stableAt;
  final String stateAtSave;

  StableCharacterHistory({
    required this.id,
    required this.userId,
    required this.sourceCharacterId,
    required this.characterName,
    required this.displayNameEn,
    required this.displayNameAr,
    required this.archetype,
    required this.glbFileName,
    required this.stableAt,
    this.stateAtSave = 'stable',
  });

  String getDisplayName(String currentLanguage) {
    return currentLanguage == 'ar' ? displayNameAr : displayNameEn;
  }

  factory StableCharacterHistory.fromMap(Map<String, dynamic> data, String id) {
    return StableCharacterHistory(
      id: id,
      userId: data['userId'] ?? '',
      sourceCharacterId: data['sourceCharacterId'] ?? '',
      characterName: data['characterName'] ?? '',
      displayNameEn: data['displayNameEn'] ?? data['displayName'] ?? '',
      displayNameAr: data['displayNameAr'] ?? data['displayName'] ?? '',
      archetype: data['archetype'] ?? '',
      glbFileName: data['glbFileName'] ?? '',
      stableAt: DateTime.parse(data['stableAt']),
      stateAtSave: data['stateAtSave'] ?? 'stable',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'sourceCharacterId': sourceCharacterId,
      'characterName': characterName,
      'displayNameEn': displayNameEn,
      'displayNameAr': displayNameAr,
      'archetype': archetype,
      'glbFileName': glbFileName,
      'stableAt': stableAt.toIso8601String(),
      'stateAtSave': stateAtSave,
    };
  }
}
