//Convert (loads) JSON data into InnerCharacterProfile entity (Dart objects).
class InnerCharacterProfile {
  final String id;
  final String displayName;
  final String displayNameAr;
  final String role;
  final String shortDescription;
  final String shortDescriptionAr;
  final String whyIExist;
  final String whyIExistAr;
  final List<String> triggers;
  final List<String> triggersAr;
  final String coreBelief;
  final String coreBeliefAr;
  final String intention;
  final String intentionAr;
  final String fear;
  final String fearAr;
  final List<String> whatINeed;
  final List<String> whatINeedAr;

  InnerCharacterProfile({
    required this.id,
    required this.displayName,
    required this.displayNameAr,
    required this.role,
    required this.shortDescription,
    required this.shortDescriptionAr,
    required this.whyIExist,
    required this.whyIExistAr,
    required this.triggers,
    required this.triggersAr,
    required this.coreBelief,
    required this.coreBeliefAr,
    required this.intention,
    required this.intentionAr,
    required this.fear,
    required this.fearAr,
    required this.whatINeed,
    required this.whatINeedAr,
  });

  factory InnerCharacterProfile.fromJson(Map<String, dynamic> json) {
    return InnerCharacterProfile(
      id: json['id'],
      displayName: json['displayName'],
      displayNameAr: json['displayNameAr'] ?? '',
      role: json['role'] ?? '',
      shortDescription: json['shortDescription'] ?? '',
      shortDescriptionAr: json['shortDescriptionAr'] ?? '',
      whyIExist: json['whyIExist'] ?? '',
      whyIExistAr: json['whyIExistAr'] ?? '',
      triggers: _readStringList(json['triggers']),
      triggersAr: _readStringList(json['triggersAr']),
      coreBelief: json['coreBelief'] ?? '',
      coreBeliefAr: json['coreBeliefAr'] ?? '',
      intention: json['intention'] ?? '',
      intentionAr: json['intentionAr'] ?? '',
      fear: json['fear'] ?? '',
      fearAr: json['fearAr'] ?? '',
      whatINeed: _readStringList(json['whatINeed']),
      whatINeedAr: _readStringList(json['whatINeedAr']),
    );
  }

  Map<String, dynamic> toPromptMap({bool useArabic = false}) {
    return {
      'id': id,
      'displayName': useArabic ? displayNameAr : displayName,
      'role': role,
      'shortDescription': useArabic ? shortDescriptionAr : shortDescription,
      'whyIExist': useArabic ? whyIExistAr : whyIExist,
      'triggers': useArabic ? triggersAr : triggers,
      'coreBelief': useArabic ? coreBeliefAr : coreBelief,
      'intention': useArabic ? intentionAr : intention,
      'fear': useArabic ? fearAr : fear,
      'whatINeed': useArabic ? whatINeedAr : whatINeed,
    };
  }

  static List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}
