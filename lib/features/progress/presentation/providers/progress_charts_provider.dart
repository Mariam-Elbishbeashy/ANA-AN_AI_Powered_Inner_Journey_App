// lib/features/progress/presentation/providers/progress_charts_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class CharacterSessionIntensity {
  final String sessionId;
  final String characterId;
  final String characterName;
  final String sessionType;
  final double startIntensity;
  final double endIntensity;
  final DateTime date;

  const CharacterSessionIntensity({
    required this.sessionId,
    required this.characterId,
    required this.characterName,
    required this.sessionType,
    required this.startIntensity,
    required this.endIntensity,
    required this.date,
  });

  double get startPercent => (startIntensity * 100).clamp(0, 100).toDouble();
  double get endPercent => (endIntensity * 100).clamp(0, 100).toDouble();
  double get averagePercent => ((startPercent + endPercent) / 2).clamp(0, 100).toDouble();
}

class VideoSessionFlowPoint {
  final String sessionId;
  final String characterId;
  final String characterName;
  final DateTime date;
  final String emotionKey;
  final String emotionLabelEn;
  final String emotionLabelAr;
  final String toneKey;
  final String toneLabelEn;
  final String toneLabelAr;

  const VideoSessionFlowPoint({
    required this.sessionId,
    required this.characterId,
    required this.characterName,
    required this.date,
    required this.emotionKey,
    required this.emotionLabelEn,
    required this.emotionLabelAr,
    required this.toneKey,
    required this.toneLabelEn,
    required this.toneLabelAr,
  });

  String emotionLabel(bool isArabic) => isArabic ? emotionLabelAr : emotionLabelEn;

  String toneLabel(bool isArabic) => isArabic ? toneLabelAr : toneLabelEn;
}

class _FlowChoice {
  final String key;
  final String labelEn;
  final String labelAr;

  const _FlowChoice({
    required this.key,
    required this.labelEn,
    required this.labelAr,
  });
}

class WeeklyDayIntensitySummary {
  final DateTime date;
  final double startPercent;
  final double endPercent;
  final double averagePercent;
  final int sessionCount;
  final List<CharacterSessionIntensity> sessions;

  const WeeklyDayIntensitySummary({
    required this.date,
    required this.startPercent,
    required this.endPercent,
    required this.averagePercent,
    required this.sessionCount,
    required this.sessions,
  });
}

class ProgressChartsProvider {
  const ProgressChartsProvider();

  Stream<List<CharacterSessionIntensity>> streamCharacterSessions(
      String uid, {
        required bool isArabic,
      }) {
    final controller = StreamController<List<CharacterSessionIntensity>>.broadcast();

    final sessionsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .orderBy('updatedAt', descending: true);

    final charactersQuery = FirebaseFirestore.instance
        .collection('user_characters')
        .where('userId', isEqualTo: uid);

    Map<String, Map<String, dynamic>> charactersByName = {};
    Map<String, Map<String, dynamic>> charactersByDocId = {};
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs = [];

    void emit() {
      if (controller.isClosed) return;

      final extracted = extractCharacterSessions(
        sessionDocs,
        charactersByName: charactersByName,
        charactersByDocId: charactersByDocId,
        isArabic: isArabic,
      );

      controller.add(extracted);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> charactersSub;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> sessionsSub;

    charactersSub = charactersQuery.snapshots().listen(
          (snapshot) {
        charactersByName.clear();
        charactersByDocId.clear();

        for (final doc in snapshot.docs) {
          final data = {
            ...doc.data(),
            '__docId': doc.id,
          };

          final docId = doc.id;
          charactersByDocId[docId] = data;

          final characterName =
          (data['characterName'] ?? '').toString().trim().toLowerCase();
          if (characterName.isNotEmpty) {
            charactersByName[characterName] = data;
          }

          final normalizedName = characterName.replaceAll(' ', '_');
          if (normalizedName != characterName) {
            charactersByName[normalizedName] = data;
          }
        }

        emit();
      },
      onError: controller.addError,
    );

    sessionsSub = sessionsQuery.snapshots().listen(
          (snapshot) {
        sessionDocs = snapshot.docs;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await charactersSub.cancel();
      await sessionsSub.cancel();
    };

    return controller.stream;
  }

  Stream<List<VideoSessionFlowPoint>> streamVideoSessionFlow(
      String uid, {
        required bool isArabic,
      }) {
    final controller = StreamController<List<VideoSessionFlowPoint>>.broadcast();

    final sessionsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .orderBy('updatedAt', descending: true);

    final charactersQuery = FirebaseFirestore.instance
        .collection('user_characters')
        .where('userId', isEqualTo: uid);

    Map<String, Map<String, dynamic>> charactersByName = {};
    Map<String, Map<String, dynamic>> charactersByDocId = {};
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs = [];

    void emit() {
      if (controller.isClosed) return;

      final extracted = extractVideoSessionFlow(
        sessionDocs,
        charactersByName: charactersByName,
        charactersByDocId: charactersByDocId,
        isArabic: isArabic,
      );

      controller.add(extracted);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> charactersSub;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> sessionsSub;

    charactersSub = charactersQuery.snapshots().listen(
          (snapshot) {
        charactersByName.clear();
        charactersByDocId.clear();

        for (final doc in snapshot.docs) {
          final data = {
            ...doc.data(),
            '__docId': doc.id,
          };

          final docId = doc.id;
          charactersByDocId[docId] = data;

          final characterName =
          (data['characterName'] ?? '').toString().trim().toLowerCase();
          if (characterName.isNotEmpty) {
            charactersByName[characterName] = data;
          }

          final normalizedName = characterName.replaceAll(' ', '_');
          if (normalizedName != characterName) {
            charactersByName[normalizedName] = data;
          }
        }

        emit();
      },
      onError: controller.addError,
    );

    sessionsSub = sessionsQuery.snapshots().listen(
          (snapshot) {
        sessionDocs = snapshot.docs;
        emit();
      },
      onError: controller.addError,
    );

    controller.onCancel = () async {
      await charactersSub.cancel();
      await sessionsSub.cancel();
    };

    return controller.stream;
  }

  List<VideoSessionFlowPoint> extractVideoSessionFlow(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs, {
        required Map<String, Map<String, dynamic>> charactersByName,
        required Map<String, Map<String, dynamic>> charactersByDocId,
        required bool isArabic,
      }) {
    final List<VideoSessionFlowPoint> points = [];

    for (final doc in sessionDocs) {
      final data = doc.data();

      final sessionCharacterId =
      (data['characterId'] ?? '').toString().trim().toLowerCase();
      if (sessionCharacterId.isEmpty) {
        continue;
      }

      final characterData = _resolveCharacterData(
        sessionCharacterId,
        charactersByName: charactersByName,
        charactersByDocId: charactersByDocId,
      );
      if (characterData == null) {
        continue;
      }

      final currentState =
      (characterData['currentState'] ?? 'active').toString().toLowerCase();
      if (currentState != 'active') {
        continue;
      }

      final displayName = _resolveDisplayName(characterData, isArabic: isArabic);
      final canonicalCharacterId = _resolveCanonicalCharacterId(
        characterData,
        fallbackSessionCharacterId: sessionCharacterId,
      );

      final faceEmotionMap = (data['faceEmotion'] as Map<String, dynamic>?) ?? {};
      final voiceToneMap = (data['voiceTone'] as Map<String, dynamic>?) ?? {};

      final startEmotionRaw = faceEmotionMap['startEmotion'];
      final endEmotionRaw = faceEmotionMap['endEmotion'];
      final startToneRaw = voiceToneMap['startEmotion'];
      final endToneRaw = voiceToneMap['endEmotion'];

      final hasAnyFlowData = startEmotionRaw != null ||
          endEmotionRaw != null ||
          startToneRaw != null ||
          endToneRaw != null;

      if (!hasAnyFlowData) {
        continue;
      }

      final startEmotion = _mapSessionValueToFlowChoice(startEmotionRaw);
      final endEmotion = _mapSessionValueToFlowChoice(endEmotionRaw);
      final startTone = _mapSessionValueToFlowChoice(startToneRaw);
      final endTone = _mapSessionValueToFlowChoice(endToneRaw);

      final sessionDate = _extractSessionDate(data);

      final startDate = _extractGenericDate(
        faceEmotionMap['updatedAt'] ?? voiceToneMap['updatedAt'],
      ) ??
          sessionDate;

      final endDate = _extractGenericDate(
        voiceToneMap['updatedAt'] ??
            faceEmotionMap['updatedAt'] ??
            data['updatedAt'],
      ) ??
          startDate.add(const Duration(milliseconds: 1));

      points.add(
        VideoSessionFlowPoint(
          sessionId: doc.id,
          characterId: canonicalCharacterId,
          characterName: displayName,
          date: startDate,
          emotionKey: startEmotion.key,
          emotionLabelEn: startEmotion.labelEn,
          emotionLabelAr: startEmotion.labelAr,
          toneKey: startTone.key,
          toneLabelEn: startTone.labelEn,
          toneLabelAr: startTone.labelAr,
        ),
      );

      points.add(
        VideoSessionFlowPoint(
          sessionId: doc.id,
          characterId: canonicalCharacterId,
          characterName: displayName,
          date: endDate.isAfter(startDate)
              ? endDate
              : startDate.add(const Duration(milliseconds: 1)),
          emotionKey: endEmotion.key,
          emotionLabelEn: endEmotion.labelEn,
          emotionLabelAr: endEmotion.labelAr,
          toneKey: endTone.key,
          toneLabelEn: endTone.labelEn,
          toneLabelAr: endTone.labelAr,
        ),
      );
    }

    points.sort((a, b) {
      final dateCompare = a.date.compareTo(b.date);
      if (dateCompare != 0) return dateCompare;

      final sessionCompare = a.sessionId.compareTo(b.sessionId);
      if (sessionCompare != 0) return sessionCompare;

      return a.characterName.compareTo(b.characterName);
    });

    return points;
  }

  List<CharacterSessionIntensity> extractCharacterSessions(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs, {
        required Map<String, Map<String, dynamic>> charactersByName,
        required Map<String, Map<String, dynamic>> charactersByDocId,
        required bool isArabic,
      }) {
    final List<CharacterSessionIntensity> sessions = [];

    for (final doc in sessionDocs) {
      final data = doc.data();

      final intensityMap = (data['intensity'] as Map<String, dynamic>?) ?? {};
      final dynamic startRaw = intensityMap['start'];
      final dynamic endRaw = intensityMap['latest'];

      if (startRaw == null || endRaw == null) {
        continue;
      }

      final double? startIntensity = _toDouble(startRaw);
      final double? endIntensity = _toDouble(endRaw);

      if (startIntensity == null || endIntensity == null) {
        continue;
      }

      final sessionCharacterId =
      (data['characterId'] ?? '').toString().trim().toLowerCase();
      if (sessionCharacterId.isEmpty) {
        continue;
      }

      final characterData = _resolveCharacterData(
        sessionCharacterId,
        charactersByName: charactersByName,
        charactersByDocId: charactersByDocId,
      );

      if (characterData == null) {
        continue;
      }

      final displayName = _resolveDisplayName(characterData, isArabic: isArabic);
      final canonicalCharacterId = _resolveCanonicalCharacterId(
        characterData,
        fallbackSessionCharacterId: sessionCharacterId,
      );

      // Get session type - supports 'chat', 'video', and 'voice'
      final sessionTypeRaw = (data['type'] ?? 'chat').toString().trim().toLowerCase();
      String normalizedSessionType;

      if (sessionTypeRaw == 'video') {
        normalizedSessionType = 'video';
      } else if (sessionTypeRaw == 'voice') {
        normalizedSessionType = 'voice';
      } else {
        normalizedSessionType = 'chat';
      }

      final date = _extractSessionDate(data);

      sessions.add(
        CharacterSessionIntensity(
          sessionId: doc.id,
          characterId: canonicalCharacterId,
          characterName: displayName,
          sessionType: normalizedSessionType,
          startIntensity: startIntensity.clamp(0.0, 1.0),
          endIntensity: endIntensity.clamp(0.0, 1.0),
          date: date,
        ),
      );
    }

    sessions.sort((a, b) => a.date.compareTo(b.date));
    return sessions;
  }

  Map<String, dynamic>? _resolveCharacterData(
      String sessionCharacterId, {
        required Map<String, Map<String, dynamic>> charactersByName,
        required Map<String, Map<String, dynamic>> charactersByDocId,
      }) {
    Map<String, dynamic>? characterData;

    characterData = charactersByName[sessionCharacterId];
    characterData ??= charactersByName[sessionCharacterId.replaceAll(' ', '_')];
    characterData ??= charactersByName[sessionCharacterId.replaceAll('_', ' ')];
    characterData ??= charactersByDocId[sessionCharacterId];

    if (characterData == null) {
      for (final entry in charactersByName.entries) {
        if (entry.key.contains(sessionCharacterId) ||
            sessionCharacterId.contains(entry.key)) {
          characterData = entry.value;
          break;
        }
      }
    }

    return characterData;
  }

  String _resolveCanonicalCharacterId(
      Map<String, dynamic> characterData, {
        required String fallbackSessionCharacterId,
      }) {
    final candidates = [
      characterData['__docId'],
      characterData['characterId'],
      characterData['id'],
      characterData['characterName'],
      fallbackSessionCharacterId,
    ];

    for (final value in candidates) {
      final normalized = value.toString().trim().toLowerCase();
      if (normalized.isNotEmpty) {
        return normalized;
      }
    }

    return fallbackSessionCharacterId;
  }

  String _resolveDisplayName(
      Map<String, dynamic> characterData, {
        required bool isArabic,
      }) {
    final displayNameEn =
    (characterData['displayNameEn'] ?? characterData['displayName'] ?? '')
        .toString()
        .trim();
    final displayNameAr =
    (characterData['displayNameAr'] ?? characterData['displayName'] ?? '')
        .toString()
        .trim();

    var displayName = isArabic
        ? (displayNameAr.isNotEmpty ? displayNameAr : displayNameEn)
        : (displayNameEn.isNotEmpty ? displayNameEn : displayNameAr);

    if (displayName.isEmpty) {
      displayName = (characterData['characterName'] ?? '').toString().trim();
    }

    return displayName;
  }

  _FlowChoice _mapSessionValueToFlowChoice(dynamic rawValue) {
    final value = (rawValue ?? '').toString().trim().toLowerCase();

    switch (value) {
      case 'happy':
      case 'joy':
      case 'joyful':
      case 'glad':
      case 'pleased':
        return const _FlowChoice(
          key: 'happy',
          labelEn: 'Happy',
          labelAr: 'سعيد',
        );

      case 'neutral':
      case 'calm':
      case 'steady':
      case 'balanced':
      case 'ok':
      case 'okay':
        return const _FlowChoice(
          key: 'neutral',
          labelEn: 'Neutral',
          labelAr: 'محايد',
        );

      case 'surprise':
      case 'surprised':
      case 'shock':
      case 'shocked':
        return const _FlowChoice(
          key: 'surprise',
          labelEn: 'Surprise',
          labelAr: 'مفاجأة',
        );

      case 'fear':
      case 'fearful':
      case 'afraid':
      case 'scared':
      case 'anxious':
      case 'anxiety':
      case 'worry':
      case 'worried':
      case 'tense':
      case 'stress':
      case 'stressed':
        return const _FlowChoice(
          key: 'fear',
          labelEn: 'Fear',
          labelAr: 'خوف',
        );

      case 'sad':
      case 'sadness':
      case 'down':
      case 'hurt':
      case 'lonely':
      case 'grief':
      case 'disappointed':
      case 'disgust':
      case 'disgusted':
        return const _FlowChoice(
          key: 'sad',
          labelEn: 'Sad',
          labelAr: 'حزين',
        );

      case 'angry':
      case 'anger':
      case 'mad':
      case 'frustrated':
      case 'frustration':
      case 'irritated':
      case 'rage':
        return const _FlowChoice(
          key: 'angry',
          labelEn: 'Angry',
          labelAr: 'غاضب',
        );

      default:
        return const _FlowChoice(
          key: 'neutral',
          labelEn: 'Neutral',
          labelAr: 'محايد',
        );
    }
  }

  DateTime? _extractGenericDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime _extractSessionDate(Map<String, dynamic> data) {
    final intensityMap = (data['intensity'] as Map<String, dynamic>?) ?? {};
    final faceEmotionMap = (data['faceEmotion'] as Map<String, dynamic>?) ?? {};
    final voiceToneMap = (data['voiceTone'] as Map<String, dynamic>?) ?? {};

    final dynamic dateCandidate = faceEmotionMap['updatedAt'] ??
        voiceToneMap['updatedAt'] ??
        intensityMap['updatedAt'] ??
        data['updatedAt'] ??
        data['createdAt'] ??
        data['startedAt'] ??
        data['timestamp'];

    if (dateCandidate is Timestamp) {
      return dateCandidate.toDate();
    }

    if (dateCandidate is DateTime) {
      return dateCandidate;
    }

    if (dateCandidate is String) {
      final parsed = DateTime.tryParse(dateCandidate);
      if (parsed != null) return parsed;
    }

    return DateTime.now();
  }
}