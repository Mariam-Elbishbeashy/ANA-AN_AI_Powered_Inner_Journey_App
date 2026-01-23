class UserCharacter {
  final String id;
  final String userId;
  final String characterName;
  final String displayName;
  final String archetype; // 'manager', 'firefighter', or 'exile'
  final double confidence;
  final int rank; // 1, 2, or 3
  final String language; // Language used for prediction
  final String glbFileName; // Name of the 3D model file
  final String description;
  final DateTime predictedAt;

  UserCharacter({
    required this.id,
    required this.userId,
    required this.characterName,
    required this.displayName,
    required this.archetype,
    required this.confidence,
    required this.rank,
    required this.language,
    required this.glbFileName,
    required this.description,
    required this.predictedAt,
  });

  factory UserCharacter.fromMap(Map<String, dynamic> data, String id) {
    return UserCharacter(
      id: id,
      userId: data['userId'],
      characterName: data['characterName'],
      displayName: data['displayName'],
      archetype: data['archetype'],
      confidence: data['confidence']?.toDouble() ?? 0.0,
      rank: data['rank'],
      language: data['language'] ?? 'en',
      glbFileName: data['glbFileName'],
      description: data['description'],
      predictedAt: DateTime.parse(data['predictedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'characterName': characterName,
      'displayName': displayName,
      'archetype': archetype,
      'confidence': confidence,
      'rank': rank,
      'language': language,
      'glbFileName': glbFileName,
      'description': description,
      'predictedAt': predictedAt.toIso8601String(),
    };
  }
}
