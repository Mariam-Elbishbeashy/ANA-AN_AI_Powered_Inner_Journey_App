// lib/core/services/daily_task_notification_service.dart

import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class DailyTaskReminderSettings {
  final bool renewalEnabled;
  final bool taskRemindersEnabled;
  final bool morningEnabled;
  final bool afternoonEnabled;
  final bool eveningEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final int morningHour;
  final int morningMinute;
  final int afternoonHour;
  final int afternoonMinute;
  final int eveningHour;
  final int eveningMinute;

  const DailyTaskReminderSettings({
    required this.renewalEnabled,
    required this.taskRemindersEnabled,
    required this.morningEnabled,
    required this.afternoonEnabled,
    required this.eveningEnabled,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.morningHour,
    required this.morningMinute,
    required this.afternoonHour,
    required this.afternoonMinute,
    required this.eveningHour,
    required this.eveningMinute,
  });

  factory DailyTaskReminderSettings.defaults() {
    return const DailyTaskReminderSettings(
      renewalEnabled: true,
      taskRemindersEnabled: true,
      morningEnabled: true,
      afternoonEnabled: true,
      eveningEnabled: true,
      soundEnabled: true,
      vibrationEnabled: true,
      morningHour: 8,
      morningMinute: 0,
      afternoonHour: 14,
      afternoonMinute: 0,
      eveningHour: 20,
      eveningMinute: 0,
    );
  }

  DailyTaskReminderSettings copyWith({
    bool? renewalEnabled,
    bool? taskRemindersEnabled,
    bool? morningEnabled,
    bool? afternoonEnabled,
    bool? eveningEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    int? morningHour,
    int? morningMinute,
    int? afternoonHour,
    int? afternoonMinute,
    int? eveningHour,
    int? eveningMinute,
  }) {
    return DailyTaskReminderSettings(
      renewalEnabled: renewalEnabled ?? this.renewalEnabled,
      taskRemindersEnabled:
      taskRemindersEnabled ?? this.taskRemindersEnabled,
      morningEnabled: morningEnabled ?? this.morningEnabled,
      afternoonEnabled: afternoonEnabled ?? this.afternoonEnabled,
      eveningEnabled: eveningEnabled ?? this.eveningEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      morningHour: morningHour ?? this.morningHour,
      morningMinute: morningMinute ?? this.morningMinute,
      afternoonHour: afternoonHour ?? this.afternoonHour,
      afternoonMinute: afternoonMinute ?? this.afternoonMinute,
      eveningHour: eveningHour ?? this.eveningHour,
      eveningMinute: eveningMinute ?? this.eveningMinute,
    );
  }
}

class DailyTaskNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _renewalEnabledKey = 'daily_tasks_notifications_enabled';
  static const String _taskRemindersEnabledKey =
      'daily_tasks_task_reminders_enabled';
  static const String _morningEnabledKey = 'daily_tasks_morning_enabled';
  static const String _afternoonEnabledKey = 'daily_tasks_afternoon_enabled';
  static const String _eveningEnabledKey = 'daily_tasks_evening_enabled';
  static const String _soundKey = 'daily_tasks_sound_enabled';
  static const String _vibrationKey = 'daily_tasks_vibration_enabled';
  static const String _morningHourKey = 'daily_tasks_morning_hour';
  static const String _morningMinuteKey = 'daily_tasks_morning_minute';
  static const String _afternoonHourKey = 'daily_tasks_afternoon_hour';
  static const String _afternoonMinuteKey = 'daily_tasks_afternoon_minute';
  static const String _eveningHourKey = 'daily_tasks_evening_hour';
  static const String _eveningMinuteKey = 'daily_tasks_evening_minute';

  static const int renewalNotificationId = 1001;
  static const int taskReminderBaseId = 3000;
  static const int automaticTaskReminderBaseId = 4000;
  static const int maxScheduledTaskReminders = 100;

  static Future<void> init() async {
    tz.initializeTimeZones();
    await _configureLocalTimezone();

    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings: initializationSettings);

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();

    await androidPlugin?.requestNotificationsPermission();

    try {
      await androidPlugin?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('Exact alarm permission request skipped: $e');
    }

    await _plugin
        .resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Keep the daily renewal reminder registered with the OS.
    // It fires only when the calendar day changes, even if the app is closed.
    await scheduleDailyTasksRenewalNotification();

    // Keep the next one-time reminders registered with the OS.
    // They appear even when the app is fully closed, but they are not repeated.
    await scheduleAutomaticDailyTaskReminders();
  }

  static Future<void> _configureLocalTimezone() async {
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }
  }

  static Future<DailyTaskReminderSettings> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final defaults = DailyTaskReminderSettings.defaults();

    return DailyTaskReminderSettings(
      renewalEnabled:
      prefs.getBool(_renewalEnabledKey) ?? defaults.renewalEnabled,
      taskRemindersEnabled:
      prefs.getBool(_taskRemindersEnabledKey) ??
          defaults.taskRemindersEnabled,
      morningEnabled:
      prefs.getBool(_morningEnabledKey) ?? defaults.morningEnabled,
      afternoonEnabled:
      prefs.getBool(_afternoonEnabledKey) ?? defaults.afternoonEnabled,
      eveningEnabled:
      prefs.getBool(_eveningEnabledKey) ?? defaults.eveningEnabled,
      soundEnabled: prefs.getBool(_soundKey) ?? defaults.soundEnabled,
      vibrationEnabled:
      prefs.getBool(_vibrationKey) ?? defaults.vibrationEnabled,
      morningHour: prefs.getInt(_morningHourKey) ?? defaults.morningHour,
      morningMinute:
      prefs.getInt(_morningMinuteKey) ?? defaults.morningMinute,
      afternoonHour:
      prefs.getInt(_afternoonHourKey) ?? defaults.afternoonHour,
      afternoonMinute:
      prefs.getInt(_afternoonMinuteKey) ?? defaults.afternoonMinute,
      eveningHour: prefs.getInt(_eveningHourKey) ?? defaults.eveningHour,
      eveningMinute:
      prefs.getInt(_eveningMinuteKey) ?? defaults.eveningMinute,
    );
  }

  static Future<bool> get enabled async {
    final settings = await loadSettings();
    return settings.renewalEnabled;
  }

  static Future<void> saveSettings({
    required bool enabled,
    required bool sound,
    required bool vibration,
    bool? taskRemindersEnabled,
    bool? morningEnabled,
    bool? afternoonEnabled,
    bool? eveningEnabled,
    int? morningHour,
    int? morningMinute,
    int? afternoonHour,
    int? afternoonMinute,
    int? eveningHour,
    int? eveningMinute,
  }) async {
    final current = await loadSettings();

    await saveFullSettings(
      current.copyWith(
        renewalEnabled: enabled,
        soundEnabled: sound,
        vibrationEnabled: vibration,
        taskRemindersEnabled:
        taskRemindersEnabled ?? current.taskRemindersEnabled,
        morningEnabled: morningEnabled ?? current.morningEnabled,
        afternoonEnabled: afternoonEnabled ?? current.afternoonEnabled,
        eveningEnabled: eveningEnabled ?? current.eveningEnabled,
        morningHour: morningHour ?? current.morningHour,
        morningMinute: morningMinute ?? current.morningMinute,
        afternoonHour: afternoonHour ?? current.afternoonHour,
        afternoonMinute: afternoonMinute ?? current.afternoonMinute,
        eveningHour: eveningHour ?? current.eveningHour,
        eveningMinute: eveningMinute ?? current.eveningMinute,
      ),
    );
  }

  static Future<void> saveFullSettings(
      DailyTaskReminderSettings settings,
      ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_renewalEnabledKey, settings.renewalEnabled);
    await prefs.setBool(_taskRemindersEnabledKey, settings.taskRemindersEnabled);
    await prefs.setBool(_morningEnabledKey, settings.morningEnabled);
    await prefs.setBool(_afternoonEnabledKey, settings.afternoonEnabled);
    await prefs.setBool(_eveningEnabledKey, settings.eveningEnabled);
    await prefs.setBool(_soundKey, settings.soundEnabled);
    await prefs.setBool(_vibrationKey, settings.vibrationEnabled);
    await prefs.setInt(_morningHourKey, settings.morningHour);
    await prefs.setInt(_morningMinuteKey, settings.morningMinute);
    await prefs.setInt(_afternoonHourKey, settings.afternoonHour);
    await prefs.setInt(_afternoonMinuteKey, settings.afternoonMinute);
    await prefs.setInt(_eveningHourKey, settings.eveningHour);
    await prefs.setInt(_eveningMinuteKey, settings.eveningMinute);

    if (settings.renewalEnabled) {
      await scheduleDailyTasksRenewalNotification(settingsOverride: settings);
    } else {
      await cancelDailyTasksRenewalNotification();
    }

    if (settings.taskRemindersEnabled) {
      await scheduleAutomaticDailyTaskReminders(settingsOverride: settings);
    } else {
      await cancelTaskReminderNotifications();
      await cancelAutomaticDailyTaskReminders();
    }
  }

  static Future<void> showDailyTasksRenewedNotification() async {
    // This method can be called when tasks are created or when the app opens.
    // It must not show anything immediately; it only makes sure the next
    // day-change notification is scheduled with the OS.
    await scheduleDailyTasksRenewalNotification();
  }

  static Future<void> scheduleDailyTasksRenewalNotification({
    DailyTaskReminderSettings? settingsOverride,
  }) async {
    final settings = settingsOverride ?? await loadSettings();

    await cancelDailyTasksRenewalNotification();

    if (!settings.renewalEnabled) return;

    final scheduledTime = _nextDayChangeTime();

    await _safeZonedSchedule(
      id: renewalNotificationId,
      title: 'Daily tasks renewed',
      body: 'Your new daily activities are ready.',
      scheduledDate: scheduledTime,
      notificationDetails: _notificationDetails(
        channelId: 'daily_tasks_renewal_channel',
        channelName: 'Daily Tasks Renewal',
        channelDescription:
        'Notification when daily tasks are renewed at day change',
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
      ),
      payload: 'daily_tasks_renewed|day_change',
      matchDateTimeComponents: DateTimeComponents.time,
    );

    await _upsertScheduledInAppRenewal(scheduledTime: scheduledTime);
  }

  static Future<void> cancelDailyTasksRenewalNotification() async {
    await _plugin.cancel(id: renewalNotificationId);
  }


  static Future<void> scheduleAutomaticDailyTaskReminders({
    DailyTaskReminderSettings? settingsOverride,
  }) async {
    final settings = settingsOverride ?? await loadSettings();

    await cancelAutomaticDailyTaskReminders();

    if (!settings.taskRemindersEnabled) return;

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

    for (int index = 0; index < periods.length; index++) {
      final period = periods[index];
      if (!period.enabled) continue;

      final scheduledTime = _nextInstanceOfTime(
        hour: period.hour,
        minute: period.minute,
      );

      final details = _notificationDetails(
        channelId: 'automatic_daily_task_reminders_channel',
        channelName: 'Automatic Daily Task Reminders',
        channelDescription:
        'One-time task reminders that fire even when the app is closed',
        sound: settings.soundEnabled,
        vibration: settings.vibrationEnabled,
      );

      // Outside-app notification:
      // ONE TIME ONLY for the next selected time.
      // No DateTimeComponents.time here, because that would repeat daily.
      await _safeZonedSchedule(
        id: automaticTaskReminderBaseId + index,
        title: titleForPeriod(period.key),
        body: bodyForPeriod(period.key),
        scheduledDate: scheduledTime,
        notificationDetails: details,
        payload: 'automatic_daily_task_reminder|${period.key}|once',
      );

      // Inside-app notification:
      // Save it in Firestore immediately with scheduledAt.
      // The notification sheet shows it only when scheduledAt <= now.
      await _upsertScheduledInAppReminder(
        period: period.key,
        scheduledTime: scheduledTime,
      );
    }
  }

  static Future<void> _safeZonedSchedule({
    required int id,
    required String title,
    required String body,
    required tz.TZDateTime scheduledDate,
    required NotificationDetails notificationDetails,
    required String payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    try {
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    } on PlatformException catch (e) {
      if (e.code != 'exact_alarms_not_permitted') rethrow;

      debugPrint(
        'Exact alarms are not permitted. Scheduling notification $id using inexact mode.',
      );

      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: notificationDetails,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: matchDateTimeComponents,
        payload: payload,
      );
    }
  }

  static Future<void> cancelAutomaticDailyTaskReminders() async {
    // 4000-4002 = current one-time reminders.
    // 4010-4012 = old daily repeating reminders from previous versions.
    for (final id in <int>[
      automaticTaskReminderBaseId,
      automaticTaskReminderBaseId + 1,
      automaticTaskReminderBaseId + 2,
      automaticTaskReminderBaseId + 10,
      automaticTaskReminderBaseId + 11,
      automaticTaskReminderBaseId + 12,
    ]) {
      await _plugin.cancel(id: id);
    }
  }

  static tz.TZDateTime _nextDayChangeTime() {
    final now = tz.TZDateTime.now(tz.local);
    final tomorrow = now.add(const Duration(days: 1));

    return tz.TZDateTime(
      tz.local,
      tomorrow.year,
      tomorrow.month,
      tomorrow.day,
    );
  }

  static Future<void> _upsertScheduledInAppRenewal({
    required tz.TZDateTime scheduledTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateId = _formatDateIdFromDateTime(scheduledTime);
    final notificationId = 'daily_tasks_renewed_$dateId';

    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appNotifications')
        .doc(notificationId);

    await notificationRef.set({
      'id': notificationId,
      'type': 'daily_tasks_renewed',
      'titleEn': 'Daily tasks renewed',
      'titleAr': 'تم تجديد المهام اليومية',
      'bodyEn': 'Your new daily activities are ready.',
      'bodyAr': 'أنشطتك اليومية الجديدة جاهزة.',
      'isOpened': false,
      'date': dateId,
      'scheduledAt': Timestamp.fromDate(DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
      )),
      'createdAt': FieldValue.serverTimestamp(),
      'openedAt': null,
    }, SetOptions(merge: true));
  }

  static tz.TZDateTime _nextInstanceOfTime({
    required int hour,
    required int minute,
  }) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduledDate = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (!scheduledDate.isAfter(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }

    return scheduledDate;
  }

  static Future<void> _upsertScheduledInAppReminder({
    required String period,
    required tz.TZDateTime scheduledTime,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dateId = _formatDateIdFromDateTime(scheduledTime);
    final notificationId = 'daily_task_reminder_${dateId}_$period';

    final notificationRef = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('appNotifications')
        .doc(notificationId);

    await notificationRef.set({
      'id': notificationId,
      'type': 'daily_task_reminder',
      'period': period,
      'titleEn': titleForPeriod(period),
      'titleAr': arabicTitleForPeriod(period),
      'bodyEn': bodyForPeriod(period),
      'bodyAr': arabicBodyForPeriod(period),
      'isOpened': false,
      'date': dateId,
      'scheduledAt': Timestamp.fromDate(DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day,
        scheduledTime.hour,
        scheduledTime.minute,
      )),
      'createdAt': FieldValue.serverTimestamp(),
      'openedAt': null,
    }, SetOptions(merge: true));
  }

  static String _formatDateIdFromDateTime(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static Future<void> scheduleTodayTaskReminders({
    required List<dynamic> activities,
    DateTime? forDate,
  }) async {
    final settings = await loadSettings();
    await cancelTaskReminderNotifications();

    if (!settings.taskRemindersEnabled || activities.isEmpty) return;

    final date = forDate ?? DateTime.now();
    final today = DateTime.now();
    final scheduleDate = DateTime(date.year, date.month, date.day);
    final todayDate = DateTime(today.year, today.month, today.day);

    // Only schedule reminders for today's renewed tasks.
    if (scheduleDate != todayDate) return;

    final Map<String, List<dynamic>> activitiesByPeriod = {
      'morning': [],
      'afternoon': [],
      'evening': [],
    };

    for (final activity in activities) {
      final category = _readString(activity, 'category').toLowerCase().trim();
      final period = periodSettingsForCategory(category, settings);
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

    for (int index = 0; index < periods.length; index++) {
      final period = periods[index];
      final periodActivities = activitiesByPeriod[period.key] ?? [];

      if (!period.enabled || periodActivities.isEmpty) continue;

      final scheduledDate = dateAt(
        scheduleDate,
        hour: period.hour,
        minute: period.minute,
      );

      final now = tz.TZDateTime.now(tz.local);
      if (!scheduledDate.isAfter(now)) continue;

      final firstTitle = _activityTitle(periodActivities.first);
      final extraCount = periodActivities.length - 1;
      final body = extraCount <= 0
          ? firstTitle
          : '$firstTitle and $extraCount more task${extraCount == 1 ? '' : 's'}';

      await _safeZonedSchedule(
        id: taskReminderBaseId + index,
        title: titleForPeriod(period.key),
        body: body,
        scheduledDate: scheduledDate,
        notificationDetails: _notificationDetails(
          channelId: 'daily_task_reminders_channel',
          channelName: 'Daily Task Reminders',
          channelDescription: 'Reminders for each daily task time period',
          sound: settings.soundEnabled,
          vibration: settings.vibrationEnabled,
        ),
        payload: 'daily_task_reminder|${period.key}',
      );
    }
  }

  static Future<void> cancelTaskReminderNotifications() async {
    for (int id = taskReminderBaseId;
    id < taskReminderBaseId + maxScheduledTaskReminders;
    id++) {
      await _plugin.cancel(id: id);
    }
  }

  static NotificationDetails _notificationDetails({
    required String channelId,
    required String channelName,
    required String channelDescription,
    required bool sound,
    required bool vibration,
  }) {
    // Android notification channel settings are permanent after the channel is created.
    // If the same channel id is reused, changing Sound/Vibration in the app may appear
    // to do nothing. So every sound/vibration combination gets its own channel id.
    final effectiveChannelId = _channelIdForSettings(
      baseChannelId: channelId,
      sound: sound,
      vibration: vibration,
    );

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      effectiveChannelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
      vibrationPattern: vibration ? null : Int64List.fromList(<int>[0]),
      category: AndroidNotificationCategory.reminder,
      visibility: NotificationVisibility.public,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: sound,
      presentBadge: true,
    );

    return NotificationDetails(android: androidDetails, iOS: iosDetails);
  }

  static String _channelIdForSettings({
    required String baseChannelId,
    required bool sound,
    required bool vibration,
  }) {
    final soundPart = sound ? 'sound' : 'silent';
    final vibrationPart = vibration ? 'vibration' : 'no_vibration';
    return '${baseChannelId}_${soundPart}_$vibrationPart';
  }

  static tz.TZDateTime dateAt(
      DateTime date, {
        required int hour,
        required int minute,
      }) {
    return tz.TZDateTime(
      tz.local,
      date.year,
      date.month,
      date.day,
      hour,
      minute,
    );
  }

  static PeriodSettings? periodSettingsForCategory(
      String category,
      DailyTaskReminderSettings settings,
      ) {
    if (category == 'morning') {
      return PeriodSettings(
        key: 'morning',
        enabled: settings.morningEnabled,
        hour: settings.morningHour,
        minute: settings.morningMinute,
      );
    }

    if (category == 'afternoon') {
      return PeriodSettings(
        key: 'afternoon',
        enabled: settings.afternoonEnabled,
        hour: settings.afternoonHour,
        minute: settings.afternoonMinute,
      );
    }

    if (category == 'evening') {
      return PeriodSettings(
        key: 'evening',
        enabled: settings.eveningEnabled,
        hour: settings.eveningHour,
        minute: settings.eveningMinute,
      );
    }

    return null;
  }

  static String titleForPeriod(String period) {
    if (period == 'morning') return 'Morning task reminder';
    if (period == 'afternoon') return 'Afternoon task reminder';
    return 'Evening task reminder';
  }

  static String bodyForPeriod(String period) {
    if (period == 'morning') {
      return 'Your morning daily tasks are waiting for you.';
    }
    if (period == 'afternoon') {
      return 'Your afternoon daily tasks are waiting for you.';
    }
    return 'Your evening daily tasks are waiting for you.';
  }

  static String arabicTitleForPeriod(String period) {
    if (period == 'morning') return 'تذكير مهام الصباح';
    if (period == 'afternoon') return 'تذكير مهام بعد الظهر';
    return 'تذكير مهام المساء';
  }

  static String arabicBodyForPeriod(String period) {
    if (period == 'morning') {
      return 'مهامك الصباحية بانتظارك.';
    }
    if (period == 'afternoon') {
      return 'مهام بعد الظهر بانتظارك.';
    }
    return 'مهامك المسائية بانتظارك.';
  }

  static String _activityTitle(dynamic activity) {
    final titleEn = _readString(activity, 'titleEn').trim();
    if (titleEn.isNotEmpty) return titleEn;

    final title = _readString(activity, 'title').trim();
    if (title.isNotEmpty) return title;

    return 'Daily task reminder';
  }

  static String _readString(dynamic activity, String key) {
    try {
      final value = activity.toMap()[key];
      if (value == null) return '';
      return value.toString();
    } catch (_) {
      return '';
    }
  }
}

class PeriodSettings {
  final String key;
  final bool enabled;
  final int hour;
  final int minute;

  const PeriodSettings({
    required this.key,
    required this.enabled,
    required this.hour,
    required this.minute,
  });
}
