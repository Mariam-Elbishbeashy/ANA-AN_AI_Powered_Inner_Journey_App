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

  String? get currentUserId => _auth.currentUser?.uid;

  List<Milestone> _milestones = [];
  bool _isLoading = false;
  DateTime _lastAppOpen = DateTime.now();
  bool _initialized = false;
  bool _mounted = true;

  List<Milestone> get milestones => _milestones;
  bool get isLoading => _isLoading;
  DateTime get lastAppOpen => _lastAppOpen;
  bool get isInitialized => _initialized;

  @override
  void dispose() {
    _mounted = false;
    super.dispose();
  }

  void _safeNotifyListeners() {
    if (_mounted) {
      notifyListeners();
    }
  }

  // ============= FIREBASE METHODS =============

  Future<void> initializeUserMilestones() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Check if user already has milestones
      final existingSnapshot = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .limit(1)
          .get();

      if (existingSnapshot.docs.isEmpty) {
        print('📝 Creating default milestones for user: $userId');

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        // Create default milestones
        final List<Map<String, dynamic>> defaultMilestones = [
          // First time achievement
          {
            'id': 'first_day_$userId',
            'userId': userId,
            'title': 'First Day Journey',
            'description': 'Start your self-awareness journey',
            'targetCount': 1,
            'currentCount': 1,
            'isAchieved': true,
            'category': 'achievement',
            'achievedAt': Timestamp.now(),
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          // Daily streak milestone - This tracks the actual streak
          {
            'id': 'daily_streak_$userId',
            'userId': userId,
            'title': 'Daily Check-in Streak',
            'description': 'Complete daily check-ins',
            'targetCount': 7, // This is for the 7-day milestone
            'currentCount': 1,
            'isAchieved': false,
            'category': 'daily',
            'streakDays': 1, // ACTUAL CURRENT STREAK
            'lastCompletedDate': Timestamp.now(),
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'taskIds': ['morning_reflection', 'character_checkin', 'evening_journal'],
            'completedTasks': {
              'morning_reflection': false,
              'character_checkin': false,
              'evening_journal': false,
              'lastResetDate': today.toIso8601String(),
            },
          },
          // Healing-based achievements
          {
            'id': 'first_healing_$userId',
            'userId': userId,
            'title': 'First Healing',
            'description': 'Heal your first inner character',
            'targetCount': 1,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'healing',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'inner_peace_$userId',
            'userId': userId,
            'title': 'Inner Peace',
            'description': 'Heal 3 inner characters',
            'targetCount': 3,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'healing',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'master_healer_$userId',
            'userId': userId,
            'title': 'Master Healer',
            'description': 'Heal all 5 inner characters',
            'targetCount': 5,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'healing',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'inner_peace_$userId',
            'userId': userId,
            'title': 'Inner Peace',
            'description': 'Heal 8 inner characters',
            'targetCount': 8,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'healing',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'inner_peace_$userId',
            'userId': userId,
            'title': 'Inner Peace',
            'description': 'Heal 10 inner characters',
            'targetCount': 10,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'healing',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'discover_3_characters_$userId',
            'userId': userId,
            'title': 'Self-Explorer',
            'description': 'Discover 3 inner characters',
            'targetCount': 3,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'character_discovery',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'discover_5_characters_$userId',
            'userId': userId,
            'title': 'Self-Knower',
            'description': 'Discover all 5 inner characters',
            'targetCount': 5,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'character_discovery',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'discover_8_characters_$userId',
            'userId': userId,
            'title': 'Deep Explorer',
            'description': 'Discover 8 inner characters',
            'targetCount': 8,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'character_discovery',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'discover_10_characters_$userId',
            'userId': userId,
            'title': 'Master of Self',
            'description': 'Discover 10 inner characters',
            'targetCount': 10,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'character_discovery',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'discover_15_characters_$userId',
            'userId': userId,
            'title': 'Master of Self',
            'description': 'Discover 15 inner characters',
            'targetCount': 15,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'character_discovery',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          // Streak achievements - These only check against daily streak
          {
            'id': 'streak_3_days_$userId',
            'userId': userId,
            'title': '3-Day Streak',
            'description': 'Maintain a 3-day streak',
            'targetCount': 3, // Target streak days
            'currentCount': 0, // Will be updated from daily streak
            'isAchieved': false,
            'category': 'streak',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'streak_7_days_$userId',
            'userId': userId,
            'title': 'Weekly Warrior',
            'description': 'Maintain a 7-day streak',
            'targetCount': 7,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'streak',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'streak_14_days_$userId',
            'userId': userId,
            'title': 'Fortnight Focus',
            'description': 'Maintain a 14-day streak',
            'targetCount': 14,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'streak',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'streak_30_days_$userId',
            'userId': userId,
            'title': 'Monthly Master',
            'description': 'Maintain a 30-day streak',
            'targetCount': 30,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'streak',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'streak_60_days_$userId',
            'userId': userId,
            'title': 'Consistency Champion',
            'description': 'Maintain a 60-day streak',
            'targetCount': 60,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'streak',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
          {
            'id': 'streak_90_days_$userId',
            'userId': userId,
            'title': 'Quarterly Legend',
            'description': 'Maintain a 90-day streak',
            'targetCount': 90,
            'currentCount': 0,
            'isAchieved': false,
            'category': 'streak',
            'createdAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
            'streakDays': 0,
          },
        ];

        final createBatch = _firestore.batch();
        for (final milestone in defaultMilestones) {
          final milestoneId = milestone['id'] as String;
          final docRef = userMilestonesCollection.doc(milestoneId);
          createBatch.set(docRef, milestone);
        }
        await createBatch.commit();

        print('✅ Created ${defaultMilestones.length} default milestones for user: $userId');
      } else {
        print('📊 User already has milestones, skipping creation');
      }
    } catch (e) {
      print('❌ Error initializing milestones: $e');
    }
  }

  Future<List<Milestone>> getUserMilestones() async {
    final userId = currentUserId;
    if (userId == null) return [];

    try {
      final querySnapshot = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt')
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final convertedData = Map<String, dynamic>.from(data);

        // Convert Timestamp to String
        dynamic convertTimestamp(dynamic value) {
          if (value is Timestamp) {
            return value.toDate().toIso8601String();
          }
          return value;
        }

        // Convert all timestamp fields
        ['achievedAt', 'createdAt', 'updatedAt', 'lastCompletedDate'].forEach((field) {
          if (convertedData.containsKey(field)) {
            convertedData[field] = convertTimestamp(convertedData[field]);
          }
        });

        // Handle completedTasks
        if (convertedData.containsKey('completedTasks')) {
          final completedTasks = convertedData['completedTasks'] as Map<String, dynamic>?;
          if (completedTasks != null) {
            final newCompletedTasks = Map<String, dynamic>.from(completedTasks);
            for (final key in newCompletedTasks.keys) {
              final value = newCompletedTasks[key];
              if (value is Timestamp) {
                newCompletedTasks[key] = value.toDate().toIso8601String();
              }
            }
            convertedData['completedTasks'] = newCompletedTasks;
          }
        }

        return Milestone.fromMap(convertedData, doc.id);
      }).toList();
    } catch (e) {
      print('Error getting milestones: $e');
      return [];
    }
  }

  Future<void> updateMilestone(String milestoneId, Map<String, dynamic> updates) async {
    try {
      final finalUpdates = Map<String, dynamic>.from(updates);

      // Convert string dates to Timestamp if needed
      if (finalUpdates.containsKey('lastCompletedDate') &&
          finalUpdates['lastCompletedDate'] is String) {
        finalUpdates['lastCompletedDate'] = Timestamp.fromDate(
            DateTime.parse(finalUpdates['lastCompletedDate'] as String)
        );
      }

      if (finalUpdates.containsKey('achievedAt') &&
          finalUpdates['achievedAt'] is String) {
        finalUpdates['achievedAt'] = Timestamp.fromDate(
            DateTime.parse(finalUpdates['achievedAt'] as String)
        );
      }

      finalUpdates['updatedAt'] = Timestamp.now();

      await userMilestonesCollection.doc(milestoneId).update(finalUpdates);
    } catch (e) {
      print('Error updating milestone: $e');
      throw e;
    }
  }

  Future<void> resetDailyTasksIfNewDay() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final querySnapshot = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'daily')
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final completedTasks = data['completedTasks'] as Map<String, dynamic>? ?? {};
        final lastResetDateStr = completedTasks['lastResetDate'];

        DateTime? lastResetDate;
        if (lastResetDateStr != null) {
          try {
            lastResetDate = DateTime.parse(lastResetDateStr);
          } catch (e) {
            print('Error parsing last reset date: $e');
          }
        }

        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        if (lastResetDate == null || !_isSameDay(lastResetDate, today)) {
          final updatedTasks = Map<String, dynamic>.from(completedTasks);
          updatedTasks['morning_reflection'] = false;
          updatedTasks['character_checkin'] = false;
          updatedTasks['evening_journal'] = false;
          updatedTasks['lastResetDate'] = today.toIso8601String();

          await userMilestonesCollection.doc(doc.id).update({
            'completedTasks': updatedTasks,
            'updatedAt': Timestamp.now(),
          });
        }
      }
    } catch (e) {
      print('Error resetting daily tasks: $e');
    }
  }

  Future<void> updateHealingMilestones() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Get healing progress from Firestore
      final userCharactersCollection = _firestore.collection('user_characters');
      final allCharactersQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .get();

      final healedCharactersQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .where('isHealed', isEqualTo: true)
          .get();

      final healedCount = healedCharactersQuery.docs.length;

      // Get all healing-based milestones
      final querySnapshot = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'healing')
          .get();

      final batch = _firestore.batch();

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final targetCount = data['targetCount'] as int;
        final currentCount = data['currentCount'] as int;
        final isAchieved = data['isAchieved'] as bool? ?? false;

        if (!isAchieved || currentCount != healedCount) {
          final newlyAchieved = healedCount >= targetCount;

          batch.update(doc.reference, {
            'currentCount': healedCount,
            'isAchieved': newlyAchieved,
            'achievedAt': newlyAchieved ? Timestamp.now() : null,
            'updatedAt': Timestamp.now(),
          });
        }
      }

      await batch.commit();
    } catch (e) {
      print('Error updating healing milestones: $e');
    }
  }

  // ============= PROVIDER METHODS =============
  Future<void> initialize() async {
    if (_initialized) return;

    _isLoading = true;
    _safeNotifyListeners();

    try {
      await _loadMilestones();

      if (_milestones.isEmpty) {
        await initializeUserMilestones();
        await _loadMilestones();
      }

      await resetDailyTasksIfNewDay();
      await _trackDailyAppOpen();
      await generateNewDailyActivities();
      await updateCharacterDiscoveryMilestones();
      await updateHealingMilestones();
      await _loadMilestones();

      _initialized = true;
    } catch (e) {
      print('Error initializing MilestoneProvider: $e');
    } finally {
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  Future<void> _loadMilestones() async {
    try {
      _milestones = await getUserMilestones();
      print('📊 Loaded ${_milestones.length} milestones');
    } catch (e) {
      print('Error loading milestones: $e');
      _milestones = [];
    }
  }

  // Check if two dates are on the same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Track daily app open
  Future<void> _trackDailyAppOpen() async {
    final userId = currentUserId;
    if (userId == null) return;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    print('📱 Tracking daily app open - Today: $today');

    try {
      // Get daily milestone
      final dailyQuery = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'daily')
          .limit(1)
          .get();

      if (dailyQuery.docs.isEmpty) {
        print('❌ No daily milestone found');
        return;
      }

      final dailyDoc = dailyQuery.docs.first;
      final dailyData = dailyDoc.data() as Map<String, dynamic>;
      final lastCompletedDate = dailyData['lastCompletedDate'] as Timestamp?;
      final currentStreak = dailyData['streakDays'] as int? ?? 0;
      final currentCount = dailyData['currentCount'] as int? ?? 0;

      final updates = <String, dynamic>{};

      if (lastCompletedDate == null) {
        // First time tracking
        print('🎯 First time tracking daily milestone');
        updates['streakDays'] = 1;
        updates['currentCount'] = 1;
        updates['lastCompletedDate'] = Timestamp.now();
      } else {
        final lastDay = DateTime(
          lastCompletedDate.toDate().year,
          lastCompletedDate.toDate().month,
          lastCompletedDate.toDate().day,
        );

        // Check if we already completed today
        if (_isSameDay(lastDay, today)) {
          print('📅 Already completed today, no update needed');
          return;
        }

        // Calculate days difference
        final daysSinceLastCompletion = today.difference(lastDay).inDays;
        print('📱 Days since last completion: $daysSinceLastCompletion');

        // Update last completed date
        updates['lastCompletedDate'] = Timestamp.now();

        if (daysSinceLastCompletion == 1) {
          // Consecutive day - increment streak
          print('🔥 Consecutive day! Incrementing streak');
          updates['streakDays'] = currentStreak + 1;
        } else if (daysSinceLastCompletion > 1) {
          // Missed one or more days - reset streak to 1
          print('🔄 Missed ${daysSinceLastCompletion - 1} days, resetting streak');
          updates['streakDays'] = 1;
        }

        // Always increment total count
        updates['currentCount'] = currentCount + 1;
      }

      // Check if daily milestone is achieved (7-day target)
      if (!(dailyData['isAchieved'] as bool? ?? false) &&
          ((updates['streakDays'] as int? ?? currentStreak) >= (dailyData['targetCount'] as int? ?? 7))) {
        updates['isAchieved'] = true;
        updates['achievedAt'] = Timestamp.now();
        print('🏆 Daily milestone achieved!');
      }

      updates['updatedAt'] = Timestamp.now();

      // Update daily milestone
      await userMilestonesCollection.doc(dailyDoc.id).update(updates);
      print('✅ Updated daily milestone with streak: ${updates['streakDays']}');

      // Update provider's last app open timestamp
      _lastAppOpen = now;

      // Update streak achievements based on new streak
      await _updateStreakAchievements();

      // Reload milestones to get updated data
      await _loadMilestones();

      print('📱 Successfully tracked app open at: ${now.toLocal()}');

    } catch (e) {
      print('❌ Error tracking daily app open: $e');
    }
  }

  // Update streak achievements based on current streak from daily milestone
  Future<void> _updateStreakAchievements() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Get current daily streak
      final dailyQuery = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'daily')
          .limit(1)
          .get();

      if (dailyQuery.docs.isEmpty) return;

      final dailyDoc = dailyQuery.docs.first;
      final dailyData = dailyDoc.data() as Map<String, dynamic>;
      final currentStreak = dailyData['streakDays'] as int? ?? 0;

      print('🔥 Current streak for achievements: $currentStreak');

      // Get all streak achievements
      final querySnapshot = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'streak')
          .get();

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in querySnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final targetCount = data['targetCount'] as int;
        final currentCount = data['currentCount'] as int;
        final isAchieved = data['isAchieved'] as bool? ?? false;

        // Update current count to match current streak
        if (currentCount != currentStreak) {
          batch.update(doc.reference, {
            'currentCount': currentStreak,
            'updatedAt': Timestamp.now(),
          });
          hasUpdates = true;
          print('📈 Updated ${data['title']} currentCount to $currentStreak');
        }

        // Check if achievement should be unlocked
        if (!isAchieved && currentStreak >= targetCount) {
          batch.update(doc.reference, {
            'isAchieved': true,
            'achievedAt': Timestamp.now(),
            'updatedAt': Timestamp.now(),
          });
          hasUpdates = true;
          print('🏆 Unlocked ${data['title']} with streak $currentStreak >= $targetCount');
        }
      }

      if (hasUpdates) {
        await batch.commit();
        print('✅ Updated streak achievements');
      }
    } catch (e) {
      print('Error updating streak achievements: $e');
    }
  }

  // Update milestone progress
  Future<void> updateMilestoneProgress(String milestoneId, {int increment = 1}) async {
    try {
      final milestone = _milestones.firstWhere((m) => m.id == milestoneId);

      // For daily milestones, we need to check if already completed today
      if (milestone.category == 'daily') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastDate = milestone.lastCompletedDate;

        if (lastDate != null && _isSameDay(lastDate, today)) {
          print('📅 Daily milestone already completed today, skipping');
          return;
        }
      }

      final newCount = milestone.currentCount + increment;
      final isAchieved = newCount >= milestone.targetCount;

      final updates = <String, dynamic>{
        'currentCount': newCount,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      if (isAchieved && !milestone.isAchieved) {
        updates['isAchieved'] = true;
        updates['achievedAt'] = DateTime.now().toIso8601String();
      }

      // For daily milestones, update streak logic
      if (milestone.category == 'daily') {
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final lastDate = milestone.lastCompletedDate;

        if (lastDate != null) {
          final lastDay = DateTime(lastDate.year, lastDate.month, lastDate.day);

          if (_isSameDay(lastDay, today)) {
            print('📅 Daily milestone already completed today, skipping');
            return;
          }

          // Calculate days difference
          final daysDifference = today.difference(lastDay).inDays;
          print('📅 Days since last completion: $daysDifference');

          if (daysDifference == 1) {
            // Consecutive day
            updates['streakDays'] = milestone.streakDays + 1;
            print('🔥 Consecutive day streak');
          } else if (daysDifference > 1) {
            // Missed days - reset streak
            updates['streakDays'] = 1;
            print('🔄 Missed ${daysDifference - 1} days, resetting streak');
          }
        } else {
          // First time
          updates['streakDays'] = 1;
        }

        updates['lastCompletedDate'] = now.toIso8601String();
      }

      // Update in Firestore
      await updateMilestone(milestoneId, updates);

      // Update streak achievements after updating daily milestone
      if (milestone.category == 'daily') {
        await _updateStreakAchievements();
      }

      // Refresh the list
      await _loadMilestones();

      // Notify listeners
      _safeNotifyListeners();

      print('✅ Updated milestone: ${milestone.title}, count: $newCount/${milestone.targetCount}');
    } catch (e) {
      print('Error updating milestone: $e');
    }
  }

  // Get streak statistics
  Map<String, dynamic> getStreakStats() {
    final dailyMilestones = _milestones.where((m) => m.category == 'daily').toList();
    final dailyMilestone = dailyMilestones.isNotEmpty
        ? dailyMilestones.first
        : Milestone(
      id: '',
      userId: '',
      title: '',
      description: '',
      targetCount: 0,
      currentCount: 0,
      isAchieved: false,
      category: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      streakDays: 0,
    );

    final totalAchieved = _milestones.where((m) => m.isAchieved).length;
    final totalMilestones = _milestones.length;
    final percentage = totalMilestones > 0
        ? (totalAchieved / totalMilestones * 100).round()
        : 0;

    final today = DateTime.now();
    final lastOpenDay = DateTime(_lastAppOpen.year, _lastAppOpen.month, _lastAppOpen.day);
    final achievedToday = _isSameDay(lastOpenDay, today);

    return {
      'currentStreak': dailyMilestone.streakDays,
      'totalAchieved': totalAchieved,
      'totalMilestones': totalMilestones,
      'completionPercentage': percentage,
      'achievedToday': achievedToday,
      'dailyProgress': dailyMilestone.currentCount,
      'dailyTarget': dailyMilestone.targetCount,
    };
  }

  // Get achievements by category
  List<Milestone> getAchievements() {
    return _milestones.where((m) => m.category == 'achievement').toList();
  }

  List<Milestone> getDailyMilestones() {
    return _milestones.where((m) => m.category == 'daily').toList();
  }

  List<Milestone> getStreakAchievements() {
    return _milestones.where((m) => m.category == 'streak').toList();
  }

  List<Milestone> getHealingMilestones() {
    return _milestones.where((m) => m.category == 'healing').toList();
  }

  Future<void> completeDailyTask(String taskId, {bool completed = true}) async {
    try {
      final dailyMilestones = getDailyMilestones();
      if (dailyMilestones.isEmpty) {
        throw Exception('No daily milestone found');
      }

      final dailyMilestone = dailyMilestones.first;

      // Get current tasks
      final currentTasks = Map<String, dynamic>.from(dailyMilestone.completedTasks ?? {});

      // Initialize default tasks if empty
      if (currentTasks.isEmpty) {
        currentTasks['morning_reflection'] = false;
        currentTasks['character_checkin'] = false;
        currentTasks['evening_journal'] = false;
        currentTasks['lastResetDate'] = DateTime.now().toIso8601String();
      }

      // Only update if the value is different
      if (currentTasks[taskId] != completed) {
        currentTasks[taskId] = completed;

        final updates = <String, dynamic>{
          'completedTasks': currentTasks,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await updateMilestone(dailyMilestone.id, updates);
        await _loadMilestones();
        _safeNotifyListeners();

        print('✅ Task $taskId set to: $completed');
      }
    } catch (e) {
      print('Error updating task: $e');
      rethrow;
    }
  }

  // Get today's check-in status
  Map<String, bool> getTodayCheckins() {
    try {
      final dailyMilestones = getDailyMilestones();
      if (dailyMilestones.isEmpty) {
        return {
          'morning_reflection': false,
          'character_checkin': false,
          'evening_journal': false,
        };
      }

      final dailyMilestone = dailyMilestones.first;
      final tasks = dailyMilestone.completedTasks ?? {
        'morning_reflection': false,
        'character_checkin': false,
        'evening_journal': false,
      };

      // Convert dynamic values to bool and return a Map<String, bool>
      return {
        'morning_reflection': tasks['morning_reflection'] is bool ? tasks['morning_reflection'] as bool : false,
        'character_checkin': tasks['character_checkin'] is bool ? tasks['character_checkin'] as bool : false,
        'evening_journal': tasks['evening_journal'] is bool ? tasks['evening_journal'] as bool : false,
      };
    } catch (e) {
      return {
        'morning_reflection': false,
        'character_checkin': false,
        'evening_journal': false,
      };
    }
  }

  // Method to manually update milestone (for UI testing)
  Future<void> manuallyUpdateMilestone(String milestoneId, int newCount) async {
    try {
      final milestone = _milestones.firstWhere((m) => m.id == milestoneId);
      final updates = <String, dynamic>{
        'currentCount': newCount,
        'updatedAt': DateTime.now().toIso8601String(),
      };

      // Check if it becomes achieved
      if (newCount >= milestone.targetCount && !milestone.isAchieved) {
        updates['isAchieved'] = true;
        updates['achievedAt'] = DateTime.now().toIso8601String();
      }

      // For daily milestones, update streak if needed
      if (milestone.category == 'daily' && newCount > milestone.currentCount) {
        final now = DateTime.now();
        updates['lastCompletedDate'] = now.toIso8601String();

        // Simple streak logic for manual update
        if (milestone.streakDays > 0) {
          updates['streakDays'] = milestone.streakDays + 1;
        } else {
          updates['streakDays'] = 1;
        }
      }

      await updateMilestone(milestoneId, updates);
      await _loadMilestones();
      _safeNotifyListeners();

      print('🔄 Manually updated milestone ${milestone.title} to $newCount');
    } catch (e) {
      print('Error manually updating milestone: $e');
    }
  }

  // Method to refresh healing milestones
  Future<void> refreshHealingMilestones() async {
    try {
      await updateHealingMilestones();
      await _loadMilestones();
      _safeNotifyListeners();
      print('🔄 Refreshed healing milestones');
    } catch (e) {
      print('Error refreshing healing milestones: $e');
    }
  }

  // Refresh all milestones
  Future<void> refreshMilestones() async {
    try {
      _isLoading = true;
      _safeNotifyListeners();

      await _loadMilestones();
      await _trackDailyAppOpen(); // Also track app open on refresh

      _isLoading = false;
      _safeNotifyListeners();
    } catch (e) {
      print('Error refreshing milestones: $e');
      _isLoading = false;
      _safeNotifyListeners();
    }
  }

  // Reset provider state
  void reset() {
    _milestones = [];
    _isLoading = false;
    _lastAppOpen = DateTime.now();
    _initialized = false;
    _mounted = true;
    _safeNotifyListeners();
  }

  // Update milestones when character count changes (discovered or healed)
  Future<void> updateCharacterDiscoveryMilestones() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final userCharactersCollection = _firestore.collection('user_characters');

      // Get ALL characters (both healed and unhealed)
      final allCharactersQuery = await userCharactersCollection
          .where('userId', isEqualTo: userId)
          .get();

      final totalCharacters = allCharactersQuery.docs.length;

      print('📊 Total characters discovered: $totalCharacters');

      // Update character discovery achievements
      final achievementsQuery = await userMilestonesCollection
          .where('userId', isEqualTo: userId)
          .where('category', isEqualTo: 'character_discovery')
          .get();

      final batch = _firestore.batch();
      bool hasUpdates = false;

      for (final doc in achievementsQuery.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final targetCount = data['targetCount'] as int;
        final currentCount = data['currentCount'] as int;
        final isAchieved = data['isAchieved'] as bool? ?? false;

        // Only update if needed
        if (currentCount != totalCharacters ||
            (!isAchieved && totalCharacters >= targetCount)) {

          final newlyAchieved = totalCharacters >= targetCount;

          batch.update(doc.reference, {
            'currentCount': totalCharacters,
            'isAchieved': newlyAchieved,
            'achievedAt': newlyAchieved ? Timestamp.now() : null,
            'updatedAt': Timestamp.now(),
          });

          hasUpdates = true;
          print('📈 Updated ${data['title']} to $totalCharacters/$targetCount, achieved: $newlyAchieved');
        }
      }

      if (hasUpdates) {
        await batch.commit();
        print('✅ Updated character discovery milestones');
      }

      // Also update healing milestones separately
      await updateHealingMilestones();

    } catch (e) {
      print('Error updating character discovery milestones: $e');
    }
  }

// Add this method to be called when a new character is discovered
  Future<void> onCharacterDiscovered() async {
    await updateCharacterDiscoveryMilestones();
    await _loadMilestones();
    _safeNotifyListeners();
  }

  // Generate new daily activities
  Future<void> generateNewDailyActivities() async {
    final userId = currentUserId;
    if (userId == null) return;

    try {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Get daily milestone
      final dailyMilestones = _milestones.where((m) => m.category == 'daily').toList();
      if (dailyMilestones.isEmpty) return;

      final dailyMilestone = dailyMilestones.first;
      final activitiesDate = dailyMilestone.activitiesDate;

      // Check if we need new activities
      if (activitiesDate == null || !_isSameDay(activitiesDate, todayDate)) {
        print('🎯 Generating new daily activities for today');

        // Get 3 random activities
        final repository = DailyActivityRepository();
        final newActivities = repository.getTodaysActivities();

        // Convert to map for Firestore
        final activitiesMap = <String, dynamic>{};
        final completedMap = <String, bool>{};

        for (final activity in newActivities) {
          activitiesMap[activity.id] = activity.toMap();
          completedMap[activity.id] = false;
        }

        // Update milestone
        await updateMilestone(dailyMilestone.id, {
          'todaysActivities': activitiesMap,
          'completedActivities': completedMap,
          'activitiesDate': todayDate.toIso8601String(),
          'updatedAt': todayDate.toIso8601String(),
        });

        print('✅ Generated ${newActivities.length} new activities for today');

        // Reload milestones
        await _loadMilestones();
      } else {
        print('📅 Activities already assigned for today');
      }
    } catch (e) {
      print('❌ Error generating daily activities: $e');
    }
  }

// Update activity completion
  Future<void> completeDailyActivity(String activityId, {bool completed = true}) async {
    try {
      final dailyMilestones = getDailyMilestones();
      if (dailyMilestones.isEmpty) {
        throw Exception('No daily milestone found');
      }

      final dailyMilestone = dailyMilestones.first;

      // Get current activities
      final currentCompleted = Map<String, dynamic>.from(dailyMilestone.completedActivities ?? {});

      // Only update if the value is different
      if (currentCompleted[activityId] != completed) {
        currentCompleted[activityId] = completed;

        final updates = <String, dynamic>{
          'completedActivities': currentCompleted,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await updateMilestone(dailyMilestone.id, updates);
        await _loadMilestones();
        _safeNotifyListeners();

        print('✅ Activity $activityId set to: $completed');
      }
    } catch (e) {
      print('Error updating activity: $e');
      rethrow;
    }
  }

// Get today's activities with completion status
  Map<String, dynamic> getTodaysActivities() {
    try {
      final dailyMilestones = getDailyMilestones();
      if (dailyMilestones.isEmpty) {
        return {
          'activities': [],
          'completed': {},
          'date': null,
          'hasActivities': false,
        };
      }

      final dailyMilestone = dailyMilestones.first;
      final activities = dailyMilestone.todaysActivities ?? {};
      final completed = dailyMilestone.completedActivities ?? {};

      // Check if activities are for today
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);
      final activitiesDate = dailyMilestone.activitiesDate;
      final isToday = activitiesDate != null && _isSameDay(activitiesDate, todayDate);

      return {
        'activities': activities.values.toList(),
        'completed': completed,
        'date': activitiesDate,
        'hasActivities': activities.isNotEmpty,
        'isToday': isToday,
      };
    } catch (e) {
      return {
        'activities': [],
        'completed': {},
        'date': null,
        'hasActivities': false,
        'isToday': false,
      };
    }
  }

  List<Milestone> getActiveAchievements() {
    return _milestones
        .where((m) => m.category == 'achievement' && !m.isAchieved)
        .toList();
  }

// Get completed achievements
  List<Milestone> getCompletedAchievements() {
    return _milestones
        .where((m) => m.isAchieved)
        .toList();
  }

// Get limited streak achievements (first two)
  List<Milestone> getLimitedStreakAchievements() {
    final streakAchievements = _milestones
        .where((m) => m.category == 'streak')
        .toList();

    // Sort by target count (ascending)
    streakAchievements.sort((a, b) => a.targetCount.compareTo(b.targetCount));

    // Return only first two
    return streakAchievements.take(2).toList();
  }

// Get all streak achievements
  List<Milestone> getAllStreakAchievements() {
    final streakAchievements = _milestones
        .where((m) => m.category == 'streak')
        .toList();

    // Sort by target count (ascending)
    streakAchievements.sort((a, b) => a.targetCount.compareTo(b.targetCount));

    return streakAchievements;
  }

  // Get character discovery milestones
  List<Milestone> getCharacterDiscoveryMilestones() {
    return _milestones.where((m) => m.category == 'character_discovery').toList();
  }

  // Get current streak from daily milestone
  int getCurrentStreak() {
    final dailyMilestones = getDailyMilestones();
    if (dailyMilestones.isEmpty) return 0;
    return dailyMilestones.first.streakDays;
  }

  // Get streak progress for streak achievements
  Map<String, dynamic> getStreakProgress(Milestone streakAchievement) {
    final currentStreak = getCurrentStreak();
    final progress = currentStreak / streakAchievement.targetCount;
    final shouldBeAchieved = currentStreak >= streakAchievement.targetCount;

    return {
      'currentStreak': currentStreak,
      'targetStreak': streakAchievement.targetCount,
      'progress': progress > 1.0 ? 1.0 : progress,
      'shouldBeAchieved': shouldBeAchieved,
    };
  }
}