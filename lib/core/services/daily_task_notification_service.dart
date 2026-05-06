// lib/core/services/daily_task_notification_service.dart

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DailyTaskNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
  FlutterLocalNotificationsPlugin();

  static const String _enabledKey = 'daily_tasks_notifications_enabled';
  static const String _soundKey = 'daily_tasks_sound_enabled';
  static const String _vibrationKey = 'daily_tasks_vibration_enabled';

  static Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings iosSettings =
    DarwinInitializationSettings();

    const InitializationSettings initializationSettings =
    InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(
      settings: initializationSettings,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<bool> get enabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey) ?? true;
  }

  static Future<bool> get soundEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_soundKey) ?? true;
  }

  static Future<bool> get vibrationEnabled async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_vibrationKey) ?? true;
  }

  static Future<void> saveSettings({
    required bool enabled,
    required bool sound,
    required bool vibration,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey, enabled);
    await prefs.setBool(_soundKey, sound);
    await prefs.setBool(_vibrationKey, vibration);
  }

  static Future<void> showDailyTasksRenewedNotification() async {
    final isEnabled = await enabled;
    if (!isEnabled) return;

    final sound = await soundEnabled;
    final vibration = await vibrationEnabled;

    final AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'daily_tasks_channel',
      'Daily Tasks',
      channelDescription: 'Notification when daily tasks are renewed',
      importance: Importance.high,
      priority: Priority.high,
      playSound: sound,
      enableVibration: vibration,
    );

    final DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: sound,
    );

    final NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(
      id: 1001,
      title: 'Daily tasks renewed',
      body: 'Your new daily activities are ready.',
      notificationDetails: notificationDetails,
    );
  }
}
