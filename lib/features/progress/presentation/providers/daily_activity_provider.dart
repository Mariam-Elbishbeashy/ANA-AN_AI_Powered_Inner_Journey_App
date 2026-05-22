// lib/features/progress/presentation/providers/daily_activity_provider.dart

import 'dart:async';

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

  final List<Timer> _inAppReminderTimers = [];

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
      await _scheduleAllTaskRemindersForToday(todayDate);
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

        await _createDailyTasksRenewedInAppNotification(
          userId: user.uid,
          dateId: dateId,
        );

        await DailyTaskNotificationService.showDailyTasksRenewedNotification();
      }

      await _scheduleAllTaskRemindersForToday(todayDate);
    } catch (e) {
      debugPrint('DailyActivityProvider error: $e');
      _initializeLocalOnly(forDate: forDate);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _scheduleAllTaskRemindersForToday(DateTime todayDate) async {
    await _scheduleOutsideAppTaskReminders(todayDate);
    await _scheduleInsideAppTaskReminders(todayDate);
  }

  Future<void> _scheduleOutsideAppTaskReminders(DateTime todayDate) async {
    // Outside-app reminders are intentionally NOT scheduled from the provider.
    // They are scheduled one time only when the user saves notification settings.
    //
    // Why:
    // - Provider runs whenever the app opens/loads today's tasks.
    // - If we schedule OS notifications here, the outside notification can be
    //   re-created again after it already fired.
    // - The user's requested behavior is one outside notification per selected
    //   reminder time, not repeated/re-created by opening the app.
  }

  Future<void> _scheduleInsideAppTaskReminders(DateTime todayDate) async {
    _cancelInAppReminderTimers();

    final user = _auth.currentUser;
    if (user == null || _todaysActivities.isEmpty) return;

    final settings = await DailyTaskNotificationService.loadSettings();
    if (!settings.taskRemindersEnabled) return;

    final Map<String, List<DailyActivity>> activitiesByPeriod = {
      'morning': [],
      'afternoon': [],
      'evening': [],
    };

    for (final activity in _todaysActivities) {
      final period = DailyTaskNotificationService.periodSettingsForCategory(
        activity.category.toLowerCase().trim(),
        settings,
      );

      if (period == null || !period.enabled) continue;
      activitiesByPeriod[period.key]?.add(activity);
    }

    final periods = <PeriodSettings>[
      PeriodSettings(
        key: 'morning',
        enabled: settings.morningEnabled,
        hour: settings.morningHour,
        minute: settings.morningMinute,
      ),
      PeriodSettings(
        key: 'afternoon',
        enabled: settings.afternoonEnabled,
        hour: settings.afternoonHour,
        minute: settings.afternoonMinute,
      ),
      PeriodSettings(
        key: 'evening',
        enabled: settings.eveningEnabled,
        hour: settings.eveningHour,
        minute: settings.eveningMinute,
      ),
    ];

    for (final period in periods) {
      final periodActivities = activitiesByPeriod[period.key] ?? [];
      if (!period.enabled || periodActivities.isEmpty) continue;

      final scheduledTime = DailyTaskNotificationService.dateAt(
        todayDate,
        hour: period.hour,
        minute: period.minute,
      );

      final scheduledDateTime = DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
      );

      final now = DateTime.now();
      if (!scheduledDateTime.isAfter(now)) continue;

      final delay = scheduledDateTime.difference(now);

      _inAppReminderTimers.add(
        Timer(delay, () async {
          await _createTaskReminderInAppNotification(
            userId: user.uid,
            dateId: _formatDateId(todayDate),
            period: period.key,
            activities: periodActivities,
            scheduledAt: scheduledDateTime,
          );
        }),
      );
    }
  }

  Future<void> _createDailyTasksRenewedInAppNotification({
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

  Future<void> _createTaskReminderInAppNotification({
    required String userId,
    required String dateId,
    required String period,
    required List<DailyActivity> activities,
    required DateTime scheduledAt,
  }) async {
    final notificationId = 'daily_task_reminder_${dateId}_$period';

    final notificationRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('appNotifications')
        .doc(notificationId);

    final existing = await notificationRef.get();
    if (existing.exists) return;

    final titleEn = DailyTaskNotificationService.titleForPeriod(period);
    final titleAr = _arabicTitleForPeriod(period);

    final firstTask = activities.first.titleEn.trim();
    final extraCount = activities.length - 1;

    final bodyEn = extraCount <= 0
        ? firstTask
        : '$firstTask and $extraCount more task${extraCount == 1 ? '' : 's'}';

    final bodyAr = bodyEn;

    await notificationRef.set({
      'id': notificationId,
      'type': 'daily_task_reminder',
      'period': period,
      'activityIds': activities.map((activity) => activity.id).toList(),
      'titleEn': titleEn,
      'titleAr': titleAr,
      'bodyEn': bodyEn,
      'bodyAr': bodyAr,
      'isOpened': false,
      'date': dateId,
      'scheduledAt': Timestamp.fromDate(scheduledAt),
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
      _scheduleOutsideAppTaskReminders(todayDate);
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

  Future<void> rescheduleTaskRemindersFromSettings() async {
    if (_activitiesAssignedDate == null) return;

    await _scheduleAllTaskRemindersForToday(_activitiesAssignedDate!);
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

  String _arabicTitleForPeriod(String period) {
    if (period == 'morning') return 'تذكير مهمة الصباح';
    if (period == 'afternoon') return 'تذكير مهمة بعد الظهر';
    return 'تذكير مهمة المساء';
  }

  void _cancelInAppReminderTimers() {
    for (final timer in _inAppReminderTimers) {
      timer.cancel();
    }
    _inAppReminderTimers.clear();
  }

  void reset() {
    _cancelInAppReminderTimers();
    _todaysActivities = [];
    _completedActivities = {};
    _activitiesAssignedDate = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelInAppReminderTimers();
    super.dispose();
  }
}
