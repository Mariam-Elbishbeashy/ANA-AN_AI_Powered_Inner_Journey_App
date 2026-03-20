import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:ana_ifs_app/features/progress/domain/entities/milestone.dart';

import '../../domain/entities/daily_activity.dart';

class MilestoneProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  CollectionReference get userMilestonesCollection =>
      _firestore.collection('user_milestones');

  CollectionReference get userCharactersCollection =>
      _firestore.collection('user_characters');

  String? get currentUserId => _auth.currentUser?.uid;

  static const List<int> _discoveryTargets = [1, 3, 5, 8, 10, 15, 18];
  static const List<int> _stableTargets = [1, 2, 3, 5, 8, 12, 18];
  static const List<int> _streakTargets = [3, 7, 14, 30, 60, 90];

  List<Milestone> _milestones = [];
  bool _isLoading = false;
  DateTime _lastAppOpen = DateTime.now();
  bool _initialized = false;
  bool _mounted = true;

  StreamSubscription<QuerySnapshot>? _milestonesSubscription;
  StreamSubscription<QuerySnapshot>? _charactersSubscription;
  bool _isSyncingCharacterMilestones = false;
  bool _pendingCharacterResync = false;

  List<Milestone> get milestones => _milestones;
  bool get isLoading => _isLoading;
  DateTime get lastAppOpen => _lastAppOpen;
  bool get isInitialized => _initialized;

  @override
  void dispose() {
    _mounted = false;
    _milestonesSubscription?.cancel();
    _charactersSubscription?.cancel();
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (_mounted) {
      notifyListeners();
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    try {
      return DateTime.parse(value.toString());
    } catch (_) {
      return null;
    }
  }

  Map<String, dynamic> _normalizeMilestoneData(Map<String, dynamic> data) {
    final normalized = Map<String, dynamic>.from(data);

    for (final field in [
      'achievedAt',
      'createdAt',
      'updatedAt',
      'lastCompletedDate',
      'activitiesDate',
    ]) {
      if (normalized.containsKey(field) && normalized[field] is Timestamp) {
        normalized[field] =
            (normalized[field] as Timestamp).toDate().toIso8601String();
      }
    }

    if (normalized['completedTasks'] is Map<String, dynamic>) {
      final tasks = Map<String, dynamic>.from(normalized['completedTasks']);
      tasks.forEach((key, value) {
        if (value is Timestamp) {
          tasks[key] = value.toDate().toIso8601String();
        }
      });
      normalized['completedTasks'] = tasks;
    }

    return normalized;
  }

  Map<String, dynamic> _buildMilestoneDefinition({
    required String id,
    required String userId,
    required String titleEn,
    required String titleAr,
    required String descriptionEn,
    required String descriptionAr,
    required int targetCount,
    required String category,
    int currentCount = 0,
    bool isAchieved = false,
    int streakDays = 0,
    DateTime? achievedAt,
    DateTime? lastCompletedDate,
    List<String>? taskIds,
    Map<String, dynamic>? completedTasks,
    Map<String, dynamic>? todaysActivities,
    Map<String, bool>? completedActivities,
    DateTime? activitiesDate,
  }) {
    final now = Timestamp.now();
    final data = <String, dynamic>{
      'id': id,
      'userId': userId,
      'titleEn': titleEn,
      'titleAr': titleAr,
      'descriptionEn': descriptionEn,
      'descriptionAr': descriptionAr,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'isAchieved': isAchieved,
      'category': category,
      'createdAt': now,
      'updatedAt': now,
      'streakDays': streakDays,
    };

    if (achievedAt != null) {
      data['achievedAt'] = Timestamp.fromDate(achievedAt);
    }
    if (lastCompletedDate != null) {
      data['lastCompletedDate'] = Timestamp.fromDate(lastCompletedDate);
    }
    if (taskIds != null) {
      data['taskIds'] = taskIds;
    }
    if (completedTasks != null) {
      data['completedTasks'] = completedTasks;
    }
    if (todaysActivities != null) {
      data['todaysActivities'] = todaysActivities;
    }
    if (completedActivities != null) {
      data['completedActivities'] = completedActivities;
    }
    if (activitiesDate != null) {
      data['activitiesDate'] = Timestamp.fromDate(activitiesDate);
    }

    return data;
  }

  List<Map<String, dynamic>> _defaultMilestonesForUser(String userId) {
    return [
      for (final entry in _discoveryTargets)
        _buildMilestoneDefinition(
          id: 'discover_${entry}_characters_$userId',
          userId: userId,
          titleEn: {
            1: 'First Discovery',
            3: 'Self Explorer',
            5: 'Self Knower',
            8: 'Deep Explorer',
            10: 'Inner Mapper',
            15: 'Master of Self',
            18: 'Complete Inner Atlas',
          }[entry]!,
          titleAr: {
            1: 'أول اكتشاف',
            3: 'مستكشفة الذات',
            5: 'عارفة الذات',
            8: 'مستكشفة عميقة',
            10: 'راسمة الخريطة الداخلية',
            15: 'سيدة الذات',
            18: 'الأطلس الداخلي الكامل',
          }[entry]!,
          descriptionEn: entry == 1
              ? 'Discover your first inner character.'
              : 'Discover $entry inner characters.',
          descriptionAr: entry == 1
              ? 'اكتشفي أول شخصية داخلية.'
              : 'اكتشفي $entry شخصيات داخلية.',
          targetCount: entry,
          category: 'character_discovery',
        ),
      for (final entry in _stableTargets)
        _buildMilestoneDefinition(
          id: 'stable_${entry}_$userId',
          userId: userId,
          titleEn: {
            1: 'Steady Heart',
            2: 'Grounded Pair',
            3: 'Steady Circle',
            5: 'Inner Shelter',
            8: 'Peaceful System',
            12: 'Balanced Landscape',
            18: 'Stable Universe',
          }[entry]!,
          titleAr: {
            1: 'قلب ثابت',
            2: 'ثنائي متزن',
            3: 'دائرة مستقرة',
            5: 'ملاذ داخلي',
            8: 'منظومة هادئة',
            12: 'مشهد متوازن',
            18: 'عالم مستقر',
          }[entry]!,
          descriptionEn: entry == 1
              ? 'Unlock your first stable character.'
              : 'Reach $entry stable characters.',
          descriptionAr: entry == 1
              ? 'افتحي أول شخصية مستقرة لك.'
              : 'صلي إلى $entry شخصيات مستقرة.',
          targetCount: entry,
          category: 'stable',
        ),
      for (final entry in _streakTargets)
        _buildMilestoneDefinition(
          id: 'streak_${entry}_days_$userId',
          userId: userId,
          titleEn: {
            3: '3-Day Streak',
            7: 'Weekly Warrior',
            14: 'Fortnight Focus',
            30: 'Monthly Master',
            60: 'Consistency Champion',
            90: 'Quarterly Legend',
          }[entry]!,
          titleAr: {
            3: 'سلسلة 3 أيام',
            7: 'محاربة الأسبوع',
            14: 'تركيز لأسبوعين',
            30: 'إتقان شهري',
            60: 'بطلة الاستمرارية',
            90: 'أسطورة الربع السنوي',
          }[entry]!,
          descriptionEn: 'Maintain a $entry-day streak.',
          descriptionAr:
          'حافظي على سلسلة لمدة $entry ${entry == 3 || entry == 7 ? 'أيام' : 'يوماً'}.',
          targetCount: entry,
          category: 'streak',
        ),
    ];
  }

  Future<void> _removeUnsupportedMilestones(String userId) async {
    final expectedIds = _defaultMilestonesForUser(userId)
        .map((item) => item['id'] as String)
        .toSet();

    final snapshot = await userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .get();

    final batch = _firestore.batch();
    var hasDeletes = false;

    for (final doc in snapshot.docs) {
      if (!expectedIds.contains(doc.id)) {
        batch.delete(doc.reference);
        hasDeletes = true;
      }
    }

    if (hasDeletes) {
      await batch.commit();
    }
  }

  Future<void> _ensureDefaultMilestonesExist(String userId) async {
    final existingSnapshot = await userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .get();

    final existingById = {
      for (final doc in existingSnapshot.docs)
        doc.id: doc.data() as Map<String, dynamic>,
    };

    final batch = _firestore.batch();
    var hasWrites = false;

    for (final milestone in _defaultMilestonesForUser(userId)) {
      final milestoneId = milestone['id'] as String;
      final ref = userMilestonesCollection.doc(milestoneId);
      final existing = existingById[milestoneId];

      if (existing == null) {
        batch.set(ref, milestone, SetOptions(merge: true));
        hasWrites = true;
        continue;
      }

      final updates = <String, dynamic>{
        'titleEn': milestone['titleEn'],
        'titleAr': milestone['titleAr'],
        'descriptionEn': milestone['descriptionEn'],
        'descriptionAr': milestone['descriptionAr'],
        'targetCount': milestone['targetCount'],
        'category': milestone['category'],
        'updatedAt': Timestamp.now(),
        'title': FieldValue.delete(),
        'description': FieldValue.delete(),
      };

      batch.update(ref, updates);
      hasWrites = true;
    }

    if (hasWrites) {
      await batch.commit();
    }

    await _removeUnsupportedMilestones(userId);
  }

  Future<void> initializeUserMilestones() async {
    final userId = currentUserId;
    if (userId == null) return;
    await _ensureDefaultMilestonesExist(userId);
  }

  Future<List<Milestone>> getUserMilestones() async {
    final userId = currentUserId;
    if (userId == null) return [];

    final querySnapshot = await userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .get();

    return querySnapshot.docs
        .map(
          (doc) => Milestone.fromMap(
        _normalizeMilestoneData(doc.data() as Map<String, dynamic>),
        doc.id,
      ),
    )
        .toList();
  }

  Future<void> updateMilestone(String milestoneId, Map<String, dynamic> updates) async {
    final finalUpdates = Map<String, dynamic>.from(updates);

    void convertField(String field) {
      final value = finalUpdates[field];
      if (value is String) {
        final parsed = DateTime.tryParse(value);
        if (parsed != null) {
          finalUpdates[field] = Timestamp.fromDate(parsed);
        }
      } else if (value is DateTime) {
        finalUpdates[field] = Timestamp.fromDate(value);
      }
    }

    for (final field in ['lastCompletedDate', 'achievedAt', 'activitiesDate']) {
      convertField(field);
    }

    finalUpdates['updatedAt'] = Timestamp.now();
    finalUpdates.remove('title');
    finalUpdates.remove('description');

    await userMilestonesCollection.doc(milestoneId).update(finalUpdates);
  }

  Future<void> _loadMilestones() async {
    _milestones = await getUserMilestones();
    _safeNotifyListeners();
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  Future<void> _startMilestonesListener() async {
    final userId = currentUserId;
    if (userId == null) return;

    await _milestonesSubscription?.cancel();
    _milestonesSubscription = userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt')
        .snapshots()
        .listen((snapshot) {
      _milestones = snapshot.docs
          .map(
            (doc) => Milestone.fromMap(
          _normalizeMilestoneData(doc.data() as Map<String, dynamic>),
          doc.id,
        ),
      )
          .toList();
      _isLoading = false;
      _safeNotifyListeners();
    });
  }

  Future<void> _syncCharacterBasedMilestonesFromSnapshot(QuerySnapshot snapshot) async {
    final totalCharacters = snapshot.docs.length;
    final stableCharacters = snapshot.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      return (data['currentState'] ?? '').toString() == 'stable';
    }).length;

    await _applyCharacterProgressCounts(
      totalCharacterCount: totalCharacters,
      stableCharacterCount: stableCharacters,
    );
  }

  Future<void> _scheduleCharacterMilestoneSync(QuerySnapshot snapshot) async {
    if (_isSyncingCharacterMilestones) {
      _pendingCharacterResync = true;
      return;
    }

    _isSyncingCharacterMilestones = true;
    try {
      await _syncCharacterBasedMilestonesFromSnapshot(snapshot);
    } finally {
      _isSyncingCharacterMilestones = false;
    }

    if (_pendingCharacterResync) {
      _pendingCharacterResync = false;
      final userId = currentUserId;
      if (userId != null) {
        final refreshed = await userCharactersCollection
            .where('userId', isEqualTo: userId)
            .get();
        await _scheduleCharacterMilestoneSync(refreshed);
      }
    }
  }

  Future<void> _startCharactersListener() async {
    final userId = currentUserId;
    if (userId == null) return;

    await _charactersSubscription?.cancel();
    _charactersSubscription = userCharactersCollection
        .where('userId', isEqualTo: userId)
        .snapshots()
        .listen((snapshot) async {
      await _scheduleCharacterMilestoneSync(snapshot);
    });
  }

  Future<void> _applyCharacterProgressCounts({
    required int totalCharacterCount,
    required int stableCharacterCount,
  }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final snapshot = await userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .where('category', whereIn: ['character_discovery', 'stable'])
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final category = (data['category'] ?? '').toString();
      final targetCount = data['targetCount'] as int? ?? 0;
      final currentCount = data['currentCount'] as int? ?? 0;
      final isAchieved = data['isAchieved'] as bool? ?? false;
      final achievedAt = data['achievedAt'];

      final nextCount = category == 'character_discovery'
          ? totalCharacterCount
          : stableCharacterCount;
      final nextAchieved = nextCount >= targetCount;

      if (currentCount != nextCount ||
          isAchieved != nextAchieved ||
          (nextAchieved && achievedAt == null)) {
        batch.update(doc.reference, {
          'currentCount': nextCount,
          'isAchieved': nextAchieved,
          'achievedAt': nextAchieved ? (achievedAt ?? Timestamp.now()) : null,
          'updatedAt': Timestamp.now(),
          'title': FieldValue.delete(),
          'description': FieldValue.delete(),
        });
        hasWrites = true;
      }
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> updateCharacterDiscoveryMilestones() async {
    final userId = currentUserId;
    if (userId == null) return;
    final snapshot =
    await userCharactersCollection.where('userId', isEqualTo: userId).get();
    await _syncCharacterBasedMilestonesFromSnapshot(snapshot);
  }

  Future<void> updateHealingMilestones() async {
    // No-op kept only for compatibility with older callers.
    await updateCharacterDiscoveryMilestones();
  }

  Future<void> resetDailyTasksIfNewDay() async {
    // No-op kept only for compatibility.
  }

  Future<void> generateNewDailyActivities() async {
    // No-op kept only for compatibility.
  }

  Future<void> _trackDailyAppOpen() async {
    final userId = currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    _lastAppOpen = now;

    final streakMilestones = await userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: 'streak')
        .get();

    if (streakMilestones.docs.isEmpty) return;

    final sampleData = streakMilestones.docs.first.data() as Map<String, dynamic>;
    final lastCompletedDate = _parseDate(sampleData['lastCompletedDate']);
    final currentStreak = sampleData['streakDays'] as int? ?? 0;

    if (lastCompletedDate != null && _isSameDay(lastCompletedDate, today)) {
      await _updateStreakAchievements(currentStreak, updateLastCompletedDate: false);
      return;
    }

    final yesterday = today.subtract(const Duration(days: 1));
    final nextStreak = lastCompletedDate != null && _isSameDay(lastCompletedDate, yesterday)
        ? currentStreak + 1
        : 1;

    await _updateStreakAchievements(nextStreak, updateLastCompletedDate: true);
  }

  Future<void> _updateStreakAchievements(
      int currentStreak, {
        bool updateLastCompletedDate = true,
      }) async {
    final userId = currentUserId;
    if (userId == null) return;

    final snapshot = await userMilestonesCollection
        .where('userId', isEqualTo: userId)
        .where('category', isEqualTo: 'streak')
        .get();

    final batch = _firestore.batch();
    var hasWrites = false;

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final targetCount = data['targetCount'] as int? ?? 0;
      final currentCount = data['currentCount'] as int? ?? 0;
      final isAchieved = data['isAchieved'] as bool? ?? false;
      final achievedAt = data['achievedAt'];
      final nextAchieved = currentStreak >= targetCount;

      final nextUpdate = <String, dynamic>{
        'currentCount': currentStreak,
        'streakDays': currentStreak,
        'isAchieved': nextAchieved,
        'achievedAt': nextAchieved ? (achievedAt ?? Timestamp.now()) : null,
        'updatedAt': Timestamp.now(),
        'title': FieldValue.delete(),
        'description': FieldValue.delete(),
      };

      if (updateLastCompletedDate) {
        nextUpdate['lastCompletedDate'] = Timestamp.fromDate(DateTime.now());
      }

      if (currentCount != currentStreak ||
          isAchieved != nextAchieved ||
          (nextAchieved && achievedAt == null) ||
          updateLastCompletedDate) {
        batch.update(doc.reference, nextUpdate);
        hasWrites = true;
      }
    }

    if (hasWrites) {
      await batch.commit();
    }
  }

  Future<void> initialize() async {
    if (_initialized) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      await initializeUserMilestones();
      await _loadMilestones();
      await _trackDailyAppOpen();
      await updateCharacterDiscoveryMilestones();
      await _startMilestonesListener();
      await _startCharactersListener();
      _initialized = true;
    } catch (e) {
      debugPrint('Error initializing MilestoneProvider: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> refresh() async {
    _isLoading = true;
    _safeNotifyListeners();
    try {
      await initializeUserMilestones();
      await _loadMilestones();
      await _trackDailyAppOpen();
      await updateCharacterDiscoveryMilestones();
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  void reset() {
    _milestones = [];
    _isLoading = false;
    _lastAppOpen = DateTime.now();
    _initialized = false;
    _safeNotifyListeners();
  }

  Future<void> updateMilestoneProgress(String milestoneId, int increment) async {
    final milestone = _milestones.cast<Milestone?>().firstWhere(
          (item) => item?.id == milestoneId,
      orElse: () => null,
    );
    if (milestone == null) return;

    final newCount = milestone.currentCount + increment;
    await updateMilestone(milestoneId, {
      'currentCount': newCount,
      'isAchieved': newCount >= milestone.targetCount,
      'achievedAt': newCount >= milestone.targetCount && milestone.achievedAt == null
          ? DateTime.now()
          : milestone.achievedAt,
    });
  }

  Map<String, dynamic> getStreakStats() {
    final currentStreak = getCurrentStreak();
    final totalAchieved = _milestones.where((m) => m.isAchieved).length;
    final totalMilestones = _milestones.length;
    final percentage = totalMilestones > 0
        ? (totalAchieved / totalMilestones * 100).round()
        : 0;

    final today = DateTime.now();
    final lastOpenDay = DateTime(_lastAppOpen.year, _lastAppOpen.month, _lastAppOpen.day);
    final achievedToday = _isSameDay(lastOpenDay, today);

    return {
      'currentStreak': currentStreak,
      'totalAchieved': totalAchieved,
      'totalMilestones': totalMilestones,
      'completionPercentage': percentage,
      'achievedToday': achievedToday,
      'dailyProgress': currentStreak,
      'dailyTarget': _streakTargets.isNotEmpty ? _streakTargets.first : 0,
    };
  }

  List<Milestone> getAchievements() => const [];

  List<Milestone> getDailyMilestones() => const [];

  List<Milestone> getHealingMilestones() => const [];

  List<Milestone> getStableMilestones() => _milestones
      .where((m) => m.category == 'stable')
      .toList()
    ..sort((a, b) => a.targetCount.compareTo(b.targetCount));

  List<Milestone> getCharacterDiscoveryMilestones() => _milestones
      .where((m) => m.category == 'character_discovery')
      .toList()
    ..sort((a, b) => a.targetCount.compareTo(b.targetCount));

  List<Milestone> getAllStreakAchievements() => _milestones
      .where((m) => m.category == 'streak')
      .toList()
    ..sort((a, b) => a.targetCount.compareTo(b.targetCount));

  List<Milestone> getLimitedStreakAchievements() {
    final all = getAllStreakAchievements();
    return all.length > 2 ? all.sublist(0, 2) : all;
  }

  List<Milestone> getActiveAchievements() => const [];

  List<Milestone> getCompletedAchievements() => _milestones
      .where((m) =>
  m.isAchieved &&
      (m.category == 'character_discovery' ||
          m.category == 'stable' ||
          m.category == 'streak'))
      .toList();

  int getCurrentStreak() {
    final streaks = getAllStreakAchievements();
    if (streaks.isEmpty) return 0;
    return streaks.map((m) => m.streakDays).fold<int>(0, (a, b) => a > b ? a : b);
  }

  Map<String, dynamic> getStreakProgress(Milestone milestone) {
    final currentStreak = getCurrentStreak();
    return {
      'currentStreak': currentStreak,
      'shouldBeAchieved': currentStreak >= milestone.targetCount,
    };
  }

  Future<void> completeDailyActivity(String activityId) async {}

  List<DailyActivity> getTodayActivities() => const [];
}
