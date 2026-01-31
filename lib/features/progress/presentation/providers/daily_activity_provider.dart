// lib/features/progress/presentation/providers/daily_activity_provider.dart

import 'package:flutter/foundation.dart';
import 'package:ana_ifs_app/features/progress/domain/entities/daily_activity.dart';

class DailyActivityProvider with ChangeNotifier {
  final DailyActivityRepository _repository = DailyActivityRepository();

  List<DailyActivity> _todaysActivities = [];
  Map<String, bool> _completedActivities = {};
  DateTime? _activitiesAssignedDate;

  List<DailyActivity> get todaysActivities => _todaysActivities;
  Map<String, bool> get completedActivities => _completedActivities;
  bool get hasActivities => _todaysActivities.isNotEmpty;
  double get completionPercentage {
    if (_todaysActivities.isEmpty) return 0;
    final completedCount = _completedActivities.values.where((completed) => completed).length;
    return completedCount / _todaysActivities.length;
  }

  // Initialize today's activities
  void initializeDailyActivities({DateTime? forDate}) {
    final today = forDate ?? DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);

    // Check if we need new activities
    if (_activitiesAssignedDate == null ||
        !_isSameDay(_activitiesAssignedDate!, todayDate)) {

      // Get new random activities
      _todaysActivities = _repository.getTodaysActivities();

      // Reset completion status
      _completedActivities = {};
      for (final activity in _todaysActivities) {
        _completedActivities[activity.id] = false;
      }

      _activitiesAssignedDate = todayDate;
      notifyListeners();
    }
  }

  // Toggle activity completion
  void toggleActivityCompletion(String activityId) {
    if (_completedActivities.containsKey(activityId)) {
      _completedActivities[activityId] = !_completedActivities[activityId]!;
      notifyListeners();
    }
  }

  // Get activity by category
  List<DailyActivity> getActivitiesByCategory(String category) {
    return _todaysActivities.where((activity) => activity.category == category).toList();
  }

  // Get morning activities
  List<DailyActivity> getMorningActivities() {
    return getActivitiesByCategory('morning');
  }

  // Get afternoon activities
  List<DailyActivity> getAfternoonActivities() {
    return getActivitiesByCategory('afternoon');
  }

  // Get evening activities
  List<DailyActivity> getEveningActivities() {
    return getActivitiesByCategory('evening');
  }

  // Check if all activities completed
  bool get areAllActivitiesCompleted {
    if (_todaysActivities.isEmpty) return false;
    return _completedActivities.values.every((completed) => completed);
  }

  // Get completion stats
  Map<String, dynamic> getCompletionStats() {
    final total = _todaysActivities.length;
    final completed = _completedActivities.values.where((completed) => completed).length;
    final pending = total - completed;

    return {
      'total': total,
      'completed': completed,
      'pending': pending,
      'percentage': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  // Helper method to check if same day
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }

  // Reset for testing
  void reset() {
    _todaysActivities = [];
    _completedActivities = {};
    _activitiesAssignedDate = null;
    notifyListeners();
  }
}