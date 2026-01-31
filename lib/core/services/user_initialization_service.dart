import 'package:cloud_firestore/cloud_firestore.dart';

class UserInitializationService {
  UserInitializationService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> ensureUserInitialized(
    String uid, {
    String? preferredLanguage,
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
