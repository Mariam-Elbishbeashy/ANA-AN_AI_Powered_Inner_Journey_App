// lib/features/progress/domain/entities/milestone.dart

import 'package:ana_ifs_app/features/progress/domain/entities/daily_activity.dart';

class Milestone {
  final String id;
  final String userId;
  final String title;
  final String description;
  final int targetCount;
  final int currentCount;
  final bool isAchieved;
  final String category;
  final DateTime? achievedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int streakDays;
  final DateTime? lastCompletedDate;
  final List<String>? taskIds;
  final Map<String, dynamic>? completedTasks;

  // Add daily activities tracking
  final Map<String, DailyActivity>? todaysActivities;
  final Map<String, bool>? completedActivities;
  final DateTime? activitiesDate; // Date when activities were assigned

  Milestone({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.targetCount,
    required this.currentCount,
    required this.isAchieved,
    required this.category,
    this.achievedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.streakDays,
    this.lastCompletedDate,
    this.taskIds,
    this.completedTasks,
    this.todaysActivities,
    this.completedActivities,
    this.activitiesDate,
  });

  factory Milestone.fromMap(Map<String, dynamic> map, String docId) {
    // Parse dates
    DateTime? parseDate(String? dateString) {
      if (dateString == null) return null;
      try {
        return DateTime.parse(dateString);
      } catch (e) {
        return null;
      }
    }

    // Parse activities
    Map<String, DailyActivity>? parseActivities(Map<String, dynamic>? activitiesMap) {
      if (activitiesMap == null) return null;
      final result = <String, DailyActivity>{};
      activitiesMap.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          result[key] = DailyActivity.fromMap(value);
        }
      });
      return result;
    }

    // Parse completed activities
    Map<String, bool>? parseCompletedActivities(Map<String, dynamic>? map) {
      if (map == null) return null;
      final result = <String, bool>{};
      map.forEach((key, value) {
        result[key] = value is bool ? value : false;
      });
      return result;
    }

    return Milestone(
      id: docId,
      userId: map['userId'],
      title: map['title'],
      description: map['description'],
      targetCount: map['targetCount'] ?? 0,
      currentCount: map['currentCount'] ?? 0,
      isAchieved: map['isAchieved'] ?? false,
      category: map['category'] ?? '',
      achievedAt: parseDate(map['achievedAt']),
      createdAt: parseDate(map['createdAt']) ?? DateTime.now(),
      updatedAt: parseDate(map['updatedAt']) ?? DateTime.now(),
      streakDays: map['streakDays'] ?? 0,
      lastCompletedDate: parseDate(map['lastCompletedDate']),
      taskIds: map['taskIds'] != null ? List<String>.from(map['taskIds']) : null,
      completedTasks: map['completedTasks'] != null
          ? Map<String, dynamic>.from(map['completedTasks'])
          : null,
      todaysActivities: parseActivities(map['todaysActivities']),
      completedActivities: parseCompletedActivities(map['completedActivities']),
      activitiesDate: parseDate(map['activitiesDate']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'id': id,
      'userId': userId,
      'title': title,
      'description': description,
      'targetCount': targetCount,
      'currentCount': currentCount,
      'isAchieved': isAchieved,
      'category': category,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'streakDays': streakDays,
    };

    if (achievedAt != null) {
      map['achievedAt'] = achievedAt!.toIso8601String();
    }

    if (lastCompletedDate != null) {
      map['lastCompletedDate'] = lastCompletedDate!.toIso8601String();
    }

    if (taskIds != null) {
      map['taskIds'] = taskIds;
    }

    if (completedTasks != null) {
      map['completedTasks'] = completedTasks;
    }

    if (todaysActivities != null) {
      map['todaysActivities'] = todaysActivities!.map((key, value) =>
          MapEntry(key, value.toMap()));
    }

    if (completedActivities != null) {
      map['completedActivities'] = completedActivities;
    }

    if (activitiesDate != null) {
      map['activitiesDate'] = activitiesDate!.toIso8601String();
    }

    return map;
  }

  Milestone copyWith({
    String? id,
    String? userId,
    String? title,
    String? description,
    int? targetCount,
    int? currentCount,
    bool? isAchieved,
    String? category,
    DateTime? achievedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? streakDays,
    DateTime? lastCompletedDate,
    List<String>? taskIds,
    Map<String, dynamic>? completedTasks,
    Map<String, DailyActivity>? todaysActivities,
    Map<String, bool>? completedActivities,
    DateTime? activitiesDate,
  }) {
    return Milestone(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      title: title ?? this.title,
      description: description ?? this.description,
      targetCount: targetCount ?? this.targetCount,
      currentCount: currentCount ?? this.currentCount,
      isAchieved: isAchieved ?? this.isAchieved,
      category: category ?? this.category,
      achievedAt: achievedAt ?? this.achievedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      streakDays: streakDays ?? this.streakDays,
      lastCompletedDate: lastCompletedDate ?? this.lastCompletedDate,
      taskIds: taskIds ?? this.taskIds,
      completedTasks: completedTasks ?? this.completedTasks,
      todaysActivities: todaysActivities ?? this.todaysActivities,
      completedActivities: completedActivities ?? this.completedActivities,
      activitiesDate: activitiesDate ?? this.activitiesDate,
    );
  }
}