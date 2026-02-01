import 'package:cloud_firestore/cloud_firestore.dart';

class UserInitializationService {
  UserInitializationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  String? _deriveFirstName({String? displayName, String? email}) {
    final display = displayName?.trim();
    if (display != null && display.isNotEmpty) {
      final parts = display.split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) {
        return parts.first;
      }
    }

    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail != null &&
        normalizedEmail.contains('@') &&
        !normalizedEmail.startsWith('@')) {
      final beforeAt = normalizedEmail.split('@').first;
      if (beforeAt.isNotEmpty) return beforeAt;
    }
    return null;
  }

  Future<void> ensureUserInitialized(
      String uid, {
        String? preferredLanguage,
        String? email,
        String? displayName,
        String? photoUrl,
      }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final snapshot = await userRef.get();
    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final updates = <String, dynamic>{};

    bool hasKey(String key) => data.containsKey(key);

    if (!hasKey('createdAt')) {
      updates['createdAt'] = FieldValue.serverTimestamp();
    }
    if (!hasKey('updatedAt')) {
      updates['updatedAt'] = FieldValue.serverTimestamp();
    }
    if (!hasKey('lastActiveAt')) {
      updates['lastActiveAt'] = FieldValue.serverTimestamp();
    }
    if (!hasKey('lastAgentRunAt')) {
      updates['lastAgentRunAt'] = null;
    }
    if (preferredLanguage != null && !hasKey('preferredLanguage')) {
      updates['preferredLanguage'] = preferredLanguage;
    }
    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail != null &&
        (!hasKey('email') ||
            (data['email']?.toString().toLowerCase() != normalizedEmail))) {
      updates['email'] = normalizedEmail;
    }
    if (displayName != null &&
        (!hasKey('displayName') ||
            (data['displayName']?.toString() != displayName))) {
      updates['displayName'] = displayName;
    }
    if (photoUrl != null &&
        (!hasKey('photoUrl') || (data['photoUrl']?.toString() != photoUrl))) {
      updates['photoUrl'] = photoUrl;
    }
    if (!hasKey('firstName') || (data['firstName']?.toString().trim() == '')) {
      final firstName = _deriveFirstName(
        displayName: displayName,
        email: email,
      );
      if (firstName != null) {
        updates['firstName'] = firstName;
      }
    }
    if (!hasKey('lastName')) {
      updates['lastName'] = null;
    }
    if (!hasKey('birthdate')) {
      updates['birthdate'] = null;
    }
    if (!hasKey('isAdmin')) {
      updates['isAdmin'] = false;
    }

    final settings = data['settings'];
    final settingsMap = settings is Map ? settings : null;
    if (settingsMap == null || !settingsMap.containsKey('theme')) {
      updates['settings.theme'] = 'system';
    }
    if (settingsMap == null ||
        !settingsMap.containsKey('notificationsEnabled')) {
      updates['settings.notificationsEnabled'] = true;
    }
    if (settingsMap == null || !settingsMap.containsKey('voiceEnabled')) {
      updates['settings.voiceEnabled'] = true;
    }

    final progressSummary = data['progressSummary'];
    final progressMap = progressSummary is Map ? progressSummary : null;
    if (progressMap == null || !progressMap.containsKey('currentStage')) {
      updates['progressSummary.currentStage'] = 'exploring';
    }
    if (progressMap == null || !progressMap.containsKey('streakDays')) {
      updates['progressSummary.streakDays'] = 0;
    }
    if (progressMap == null || !progressMap.containsKey('lastSessionAt')) {
      updates['progressSummary.lastSessionAt'] = null;
    }

    if (updates.isEmpty) return;

    await userRef.set(updates, SetOptions(merge: true));
  }
}