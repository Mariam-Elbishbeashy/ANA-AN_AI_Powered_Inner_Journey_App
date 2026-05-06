// lib/features/progress/presentation/providers/daily_activity_provider.dart

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/progress/domain/entities/daily_activity.dart';
import 'package:ana_ifs_app/core/services/daily_task_notification_service.dart';

class DailyActivityProvider with ChangeNotifier {
  final DailyActivityRepository _repository = DailyActivityRepository();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<DailyActivity> _todaysActivities = [];
  Map<String, bool> _completedActivities = {};
  DateTime? _activitiesAssignedDate;
  bool _isLoading = false;

  List<DailyActivity> get todaysActivities => _todaysActivities;
  Map<String, bool> get completedActivities => _completedActivities;
  bool get hasActivities => _todaysActivities.isNotEmpty;
  bool get isLoading => _isLoading;

  double get completionPercentage {
    if (_todaysActivities.isEmpty) return 0;
    final completedCount =
        _completedActivities.values.where((completed) => completed).length;
    return completedCount / _todaysActivities.length;
  }

  Future<void> initializeDailyActivities({DateTime? forDate}) async {
    final user = _auth.currentUser;

    if (user == null) {
      _initializeLocalOnly(forDate: forDate);
      return;
    }

    final today = forDate ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final dateId = _formatDateId(todayDate);

    if (_activitiesAssignedDate != null &&
        _isSameDay(_activitiesAssignedDate!, todayDate) &&
        _todaysActivities.isNotEmpty) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailyTasks')
          .doc(dateId);

      final docSnapshot = await docRef.get();

      if (docSnapshot.exists && docSnapshot.data() != null) {
        final data = docSnapshot.data()!;

        final activitiesData =
        List<Map<String, dynamic>>.from(data['activities'] ?? []);

        _todaysActivities = activitiesData
            .map((activityMap) => DailyActivity.fromMap(activityMap))
            .toList();

        _completedActivities =
        Map<String, bool>.from(data['completedActivities'] ?? {});

        for (final activity in _todaysActivities) {
          _completedActivities.putIfAbsent(activity.id, () => false);
        }

        _activitiesAssignedDate = todayDate;
      } else {
        _todaysActivities = _repository.getTodaysActivities();

        _completedActivities = {};
        for (final activity in _todaysActivities) {
          _completedActivities[activity.id] = false;
        }

        _activitiesAssignedDate = todayDate;

        await docRef.set({
          'date': dateId,
          'activities':
          _todaysActivities.map((activity) => activity.toMap()).toList(),
          'completedActivities': _completedActivities,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        await _createDailyTasksInAppNotification(
          userId: user.uid,
          dateId: dateId,
        );

        await DailyTaskNotificationService.showDailyTasksRenewedNotification();
      }
    } catch (e) {
      debugPrint('DailyActivityProvider error: $e');
      _initializeLocalOnly(forDate: forDate);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _createDailyTasksInAppNotification({
    required String userId,
    required String dateId,
  }) async {
    final notificationId = 'daily_tasks_renewed_$dateId';

    final notificationRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('appNotifications')
        .doc(notificationId);

    final existing = await notificationRef.get();
    if (existing.exists) return;

    await notificationRef.set({
      'id': notificationId,
      'type': 'daily_tasks_renewed',
      'titleEn': 'Daily tasks renewed',
      'titleAr': 'تم تجديد المهام اليومية',
      'bodyEn': 'Your new daily activities are ready.',
      'bodyAr': 'مهامك اليومية الجديدة جاهزة الآن.',
      'isOpened': false,
      'date': dateId,
      'createdAt': FieldValue.serverTimestamp(),
      'openedAt': null,
    });
  }

  void _initializeLocalOnly({DateTime? forDate}) {
    final today = forDate ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    final shouldRenew = _activitiesAssignedDate == null ||
        !_isSameDay(_activitiesAssignedDate!, todayDate);

    if (shouldRenew) {
      _todaysActivities = _repository.getTodaysActivities();

      _completedActivities = {};
      for (final activity in _todaysActivities) {
        _completedActivities[activity.id] = false;
      }

      _activitiesAssignedDate = todayDate;

      DailyTaskNotificationService.showDailyTasksRenewedNotification();
      notifyListeners();
    }
  }

  Future<void> toggleActivityCompletion(String activityId) async {
    if (!_completedActivities.containsKey(activityId)) return;

    _completedActivities[activityId] = !_completedActivities[activityId]!;

    notifyListeners();

    final user = _auth.currentUser;
    if (user == null || _activitiesAssignedDate == null) return;

    final dateId = _formatDateId(_activitiesAssignedDate!);

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('dailyTasks')
          .doc(dateId)
          .update({
        'completedActivities': _completedActivities,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error saving daily task completion: $e');
    }
  }

  List<DailyActivity> getActivitiesByCategory(String category) {
    return _todaysActivities
        .where((activity) => activity.category == category)
        .toList();
  }

  List<DailyActivity> getMorningActivities() {
    return getActivitiesByCategory('morning');
  }

  List<DailyActivity> getAfternoonActivities() {
    return getActivitiesByCategory('afternoon');
  }

  List<DailyActivity> getEveningActivities() {
    return getActivitiesByCategory('evening');
  }

  bool get areAllActivitiesCompleted {
    if (_todaysActivities.isEmpty) return false;
    return _completedActivities.values.every((completed) => completed);
  }

  Map<String, dynamic> getCompletionStats() {
    final total = _todaysActivities.length;
    final completed =
        _completedActivities.values.where((completed) => completed).length;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
      'percentage': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  String _formatDateId(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  void reset() {
    _todaysActivities = [];
    _completedActivities = {};
    _activitiesAssignedDate = null;
    notifyListeners();
  }
}