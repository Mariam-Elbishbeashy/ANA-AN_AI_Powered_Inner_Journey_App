// lib/features/progress/presentation/providers/progress_charts_provider.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

class CharacterSessionIntensity {
  final String sessionId;
  final String characterId;
  final String characterName;
  final double startIntensity;
  final double endIntensity;
  final DateTime date;

  const CharacterSessionIntensity({
    required this.sessionId,
    required this.characterId,
    required this.characterName,
    required this.startIntensity,
    required this.endIntensity,
    required this.date,
  });

  double get startPercent => (startIntensity * 100).clamp(0, 100).toDouble();
  double get endPercent => (endIntensity * 100).clamp(0, 100).toDouble();
  double get averagePercent => ((startPercent + endPercent) / 2).clamp(0, 100).toDouble();
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
        required bool isArabic, // ✅ Keep as bool parameter
      }) {
    final controller = StreamController<List<CharacterSessionIntensity>>.broadcast();

    // Get all sessions
    final sessionsQuery = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('sessions')
        .orderBy('updatedAt', descending: true);

    // Get ALL user_characters (not just active - we'll filter in the mapping)
    final charactersQuery = FirebaseFirestore.instance
        .collection('user_characters')
        .where('userId', isEqualTo: uid);

    // Build a map of characterName -> UserCharacter data
    Map<String, Map<String, dynamic>> charactersByName = {};
    Map<String, Map<String, dynamic>> charactersByDocId = {};

    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs = [];

    void emit() {
      if (controller.isClosed) return;

      final extracted = extractCharacterSessions(
        sessionDocs,
        charactersByName: charactersByName,
        charactersByDocId: charactersByDocId,
        isArabic: isArabic, // ✅ Pass the boolean
      );

      controller.add(extracted);
    }

    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> charactersSub;
    late final StreamSubscription<QuerySnapshot<Map<String, dynamic>>> sessionsSub;

    // Listen to characters collection
    charactersSub = charactersQuery.snapshots().listen(
          (snapshot) {
        charactersByName.clear();
        charactersByDocId.clear();

        for (var doc in snapshot.docs) {
          final data = doc.data();
          final docId = doc.id;

          // Store by document ID
          charactersByDocId[docId] = data;

          // Store by characterName (lowercase for case-insensitive matching)
          final characterName = (data['characterName'] ?? '').toString().trim().toLowerCase();
          if (characterName.isNotEmpty) {
            charactersByName[characterName] = data;
          }

          // Also store by common variations (for "Inner Critic" -> "inner_critic")
          final normalizedName = characterName.replaceAll(' ', '_');
          if (normalizedName != characterName) {
            charactersByName[normalizedName] = data;
          }
        }

        emit();
      },
      onError: controller.addError,
    );

    // Listen to sessions collection
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

  List<CharacterSessionIntensity> extractCharacterSessions(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs, {
        required Map<String, Map<String, dynamic>> charactersByName,
        required Map<String, Map<String, dynamic>> charactersByDocId,
        required bool isArabic, // ✅ Keep as bool parameter
      }) {
    final List<CharacterSessionIntensity> sessions = [];

    for (final doc in sessionDocs) {
      final data = doc.data();

      // Check if session has intensity data
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

      // Get the character ID from the session
      final sessionCharacterId = (data['characterId'] ?? '').toString().trim().toLowerCase();
      if (sessionCharacterId.isEmpty) {
        continue;
      }

      // Find the matching user_character
      Map<String, dynamic>? characterData;

      // Try 1: Match by characterName field
      characterData = charactersByName[sessionCharacterId];

      // Try 2: Match by characterName with underscore (inner_critic -> inner_critic)
      if (characterData == null) {
        characterData = charactersByName[sessionCharacterId.replaceAll(' ', '_')];
      }

      // Try 3: Match by characterName with space (inner_critic -> inner critic)
      if (characterData == null) {
        characterData = charactersByName[sessionCharacterId.replaceAll('_', ' ')];
      }

      // Try 4: Match by document ID
      if (characterData == null) {
        characterData = charactersByDocId[sessionCharacterId];
      }

      // Try 5: Find any character where characterName contains the session ID
      if (characterData == null) {
        for (var entry in charactersByName.entries) {
          if (entry.key.contains(sessionCharacterId) || sessionCharacterId.contains(entry.key)) {
            characterData = entry.value;
            break;
          }
        }
      }

      // Skip if no matching character found
      if (characterData == null) {
        continue;
      }

      // Check if character is ACTIVE (currentState == 'active')
      final currentState = (characterData['currentState'] ?? 'active').toString().toLowerCase();
      if (currentState != 'active') {
        continue; // Skip inactive or stable characters
      }

      // Get the display name based on language
      final displayNameEn = (characterData['displayNameEn'] ?? characterData['displayName'] ?? '').toString().trim();
      final displayNameAr = (characterData['displayNameAr'] ?? characterData['displayName'] ?? '').toString().trim();

      String displayName;
      if (isArabic) { // ✅ Use the boolean parameter
        displayName = displayNameAr.isNotEmpty ? displayNameAr : displayNameEn;
      } else {
        displayName = displayNameEn.isNotEmpty ? displayNameEn : displayNameAr;
      }

      // Fallback to characterName if display name is empty
      if (displayName.isEmpty) {
        displayName = (characterData['characterName'] ?? '').toString();
      }

      final DateTime date = _extractSessionDate(data);

      sessions.add(
        CharacterSessionIntensity(
          sessionId: doc.id,
          characterId: sessionCharacterId,
          characterName: displayName,
          startIntensity: startIntensity.clamp(0.0, 1.0),
          endIntensity: endIntensity.clamp(0.0, 1.0),
          date: date,
        ),
      );
    }

    // Sort sessions by date (oldest first for chart display)
    sessions.sort((a, b) => a.date.compareTo(b.date));

    return sessions;
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  DateTime _extractSessionDate(Map<String, dynamic> data) {
    final intensityMap = (data['intensity'] as Map<String, dynamic>?) ?? {};

    final dynamic dateCandidate = intensityMap['updatedAt'] ??
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

    return DateTime.now();
  }
}