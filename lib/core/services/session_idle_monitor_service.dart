import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:ana_ifs_app/features/chat/data/datasources/chat_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:workmanager/workmanager.dart';

const String _workReminderTaskName = 'session_reminder_task';
const String _workWarningTaskName = 'session_warning_task';
const String _workAutoEndTaskName = 'session_auto_end_task';
const String _workReminderUniquePrefix = 'session_reminder_';
const String _workWarningUniquePrefix = 'session_warning_';
const String _workAutoEndUniquePrefix = 'session_auto_end_';

@pragma('vm:entry-point')
void sessionIdleCallbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    DartPluginRegistrant.ensureInitialized();
    debugPrint('[session-idle][bg] task=$task input=$inputData');
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    if (task == _workReminderTaskName ||
        task.startsWith(_workReminderUniquePrefix)) {
      await SessionIdleMonitorService.showBackgroundReminder(isWarning: false);
      return Future.value(true);
    }
    if (task == _workWarningTaskName ||
        task.startsWith(_workWarningUniquePrefix)) {
      await SessionIdleMonitorService.showBackgroundReminder(isWarning: true);
      return Future.value(true);
    }
    if (task == _workAutoEndTaskName ||
        task.startsWith(_workAutoEndUniquePrefix)) {
      return SessionIdleMonitorService.autoEndIfOverdue();
    }
    return Future.value(true);
  });
}

class SessionIdleMonitorService with WidgetsBindingObserver {
  SessionIdleMonitorService._();
  static final SessionIdleMonitorService instance =
      SessionIdleMonitorService._();

  // Production timings.
  static const Duration reminderDelay = Duration(minutes: 20);
  static const Duration warningDelay = Duration(minutes: 35);
  static const Duration autoEndDelay = Duration(minutes: 45);

  static const String _prefsKey = 'active_session_idle_monitor_v1';
  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final ChatRemoteDataSource _chatRemoteDataSource = ChatRemoteDataSource();
  final ChatAiRemoteDataSource _chatAiRemoteDataSource =
      ChatAiRemoteDataSource();

  SessionIdleState? _activeState;
  bool _initialized = false;
  Timer? _inAppAutoEndTimer;

  bool get _isAndroidPlatform =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    debugPrint('[session-idle] initialize()');

    tz.initializeTimeZones();

    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const iosSettings = DarwinInitializationSettings();
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    await _notifications.initialize(settings: settings);
    await _requestNotificationPermissions();

    await Workmanager().initialize(sessionIdleCallbackDispatcher);
    debugPrint('[session-idle] workmanager initialized');

    WidgetsBinding.instance.addObserver(this);
    await _restoreState();
    await _handleOverdueOnForeground();
  }

  Future<void> beginMonitoring({
    required String uid,
    required String sessionId,
    required String threadId,
    required String characterId,
  }) async {
    final state = SessionIdleState(
      uid: uid,
      sessionId: sessionId,
      threadId: threadId,
      characterId: characterId,
    );
    _activeState = state;
    _cancelInAppAutoEndTimer();
    debugPrint(
      '[session-idle] beginMonitoring session=${state.sessionId} thread=${state.threadId} char=${state.characterId}',
    );
    await _persistState();
    await _cancelPendingForSession(state);
  }

  Future<void> stopMonitoring({required String sessionId}) async {
    final state = _activeState;
    if (state != null && state.sessionId == sessionId) {
      debugPrint('[session-idle] stopMonitoring active session=$sessionId');
      await _cancelPendingForSession(state);
      await _clearBackendAutoEndSchedule(state);
      _cancelInAppAutoEndTimer();
      _activeState = null;
      await _clearState();
      return;
    }

    // Handle cases where service was rehydrated later.
    final restored = await _loadState();
    if (restored != null && restored.sessionId == sessionId) {
      debugPrint('[session-idle] stopMonitoring restored session=$sessionId');
      await _cancelPendingForSession(restored);
      await _clearBackendAutoEndSchedule(restored);
      _cancelInAppAutoEndTimer();
      _activeState = null;
      await _clearState();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final current = _activeState;
    if (current == null) return;
    debugPrint('[session-idle] lifecycle=$state session=${current.sessionId}');

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _scheduleBackgroundFlow(current);
      return;
    }

    if (state == AppLifecycleState.resumed) {
      _onResumed();
    }
  }

  Future<void> _onResumed() async {
    final state = _activeState;
    if (state == null) return;

    await _cancelPendingForSession(state);
    await _clearBackendAutoEndSchedule(state);
    _cancelInAppAutoEndTimer();

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (state.autoEndAtMs != null && nowMs >= state.autoEndAtMs!) {
      debugPrint('[session-idle] resumed overdue -> autoEnd attempt');
      await _autoEndSession(state);
      _activeState = null;
      await _clearState();
      return;
    }

    _activeState = state.copyWith(
      backgroundedAtMs: null,
      reminderAtMs: null,
      warningAtMs: null,
      autoEndAtMs: null,
    );
    await _persistState();
  }

  Future<void> _scheduleBackgroundFlow(SessionIdleState state) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final updated = state.copyWith(
      backgroundedAtMs: nowMs,
      reminderAtMs: now.add(reminderDelay).millisecondsSinceEpoch,
      warningAtMs: now.add(warningDelay).millisecondsSinceEpoch,
      autoEndAtMs: now.add(autoEndDelay).millisecondsSinceEpoch,
    );
    _activeState = updated;
    debugPrint(
      '[session-idle] schedule background flow reminderAt=${updated.reminderAtMs} warningAt=${updated.warningAtMs} autoEndAt=${updated.autoEndAtMs}',
    );
    await _persistState();
    await _persistBackendAutoEndSchedule(updated);

    // Always re-arm notifications/tasks on each background event.
    // Existing entries are replaced via stable IDs/unique names.
    await _cancelPendingForSession(updated);
    await _scheduleReminderNotifications(updated);
    // Workmanager reminder tasks can duplicate local notifications on iOS.
    if (_isAndroidPlatform) {
      await _scheduleReminderWorkTasks(updated);
    }
    await _scheduleAutoEndTask(updated);
    _scheduleInAppAutoEndFallback(updated);
  }

  Future<void> _scheduleReminderNotifications(SessionIdleState state) async {
    final reminderAt = state.reminderAtMs;
    final warningAt = state.warningAtMs;
    if (reminderAt == null || warningAt == null) return;
    debugPrint(
      '[session-idle] schedule local notifications for ${state.sessionId}',
    );

    final androidDetails = AndroidNotificationDetails(
      'session_idle_reminders',
      'Session reminders',
      channelDescription: 'Reminds users about active chat sessions.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final reminderDate = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      reminderAt,
    );
    final warningDate = tz.TZDateTime.fromMillisecondsSinceEpoch(
      tz.local,
      warningAt,
    );

    await _notifications.zonedSchedule(
      id: _notificationId(state, offset: 1),
      title: 'Session still active',
      body: 'You left a session open. Come back to continue or end it.',
      scheduledDate: reminderDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: state.sessionId,
    );

    await _notifications.zonedSchedule(
      id: _notificationId(state, offset: 2),
      title: 'Session will auto-end soon',
      body: 'If you stay away, this session will be ended automatically.',
      scheduledDate: warningDate,
      notificationDetails: details,
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: state.sessionId,
    );
  }

  Future<void> _scheduleAutoEndTask(SessionIdleState state) async {
    final autoEndAt = state.autoEndAtMs;
    if (autoEndAt == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var delay = Duration(milliseconds: autoEndAt - nowMs);
    if (delay.isNegative) delay = Duration.zero;
    debugPrint('[session-idle] schedule autoEnd task delay=$delay');

    await Workmanager().registerOneOffTask(
      _workUniqueName(state.sessionId),
      _workAutoEndTaskName,
      initialDelay: delay,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: {'sessionId': state.sessionId},
    );
  }

  Future<void> _scheduleReminderWorkTasks(SessionIdleState state) async {
    final reminderAt = state.reminderAtMs;
    final warningAt = state.warningAtMs;
    if (reminderAt == null || warningAt == null) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var reminderDelayValue = Duration(milliseconds: reminderAt - nowMs);
    var warningDelayValue = Duration(milliseconds: warningAt - nowMs);
    if (reminderDelayValue.isNegative) reminderDelayValue = Duration.zero;
    if (warningDelayValue.isNegative) warningDelayValue = Duration.zero;
    debugPrint(
      '[session-idle] schedule reminder tasks reminderDelay=$reminderDelayValue warningDelay=$warningDelayValue',
    );

    await Workmanager().registerOneOffTask(
      _workReminderUniqueName(state.sessionId),
      _workReminderTaskName,
      initialDelay: reminderDelayValue,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: {'sessionId': state.sessionId},
    );

    await Workmanager().registerOneOffTask(
      _workWarningUniqueName(state.sessionId),
      _workWarningTaskName,
      initialDelay: warningDelayValue,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      inputData: {'sessionId': state.sessionId},
    );
  }

  Future<void> _restoreState() async {
    _activeState = await _loadState();
  }

  Future<void> _handleOverdueOnForeground() async {
    final state = _activeState;
    if (state == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (state.autoEndAtMs != null && nowMs >= state.autoEndAtMs!) {
      try {
        await _autoEndSession(state);
        _activeState = null;
        await _clearState();
      } catch (e) {
        debugPrint('[session-idle] _handleOverdueOnForeground failed: $e');
      }
    }
  }

  Future<void> _autoEndSession(SessionIdleState state) async {
    debugPrint(
      '[session-idle] _autoEndSession start session=${state.sessionId}',
    );
    try {
      await _chatAiRemoteDataSource.endAnalyzeSession(
        uid: state.uid,
        sessionId: state.sessionId,
        threadId: state.threadId,
        characterId: state.characterId,
      );
    } catch (_) {
      // We still proceed with ending the session in Firestore.
    }

    try {
      await _chatRemoteDataSource.endChatSession(
        uid: state.uid,
        sessionId: state.sessionId,
        threadId: state.threadId,
      );
      await _clearBackendAutoEndSchedule(state);
      debugPrint('[session-idle] _autoEndSession firestore end success');
    } catch (e) {
      debugPrint('[session-idle] _autoEndSession firestore end failed: $e');
      rethrow;
    }
  }

  void _scheduleInAppAutoEndFallback(SessionIdleState state) {
    final autoEndAt = state.autoEndAtMs;
    if (autoEndAt == null) return;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    var delay = Duration(milliseconds: autoEndAt - nowMs);
    if (delay.isNegative) delay = Duration.zero;
    _cancelInAppAutoEndTimer();
    debugPrint('[session-idle] schedule in-app autoEnd fallback delay=$delay');
    _inAppAutoEndTimer = Timer(delay, () async {
      final current = _activeState;
      if (current == null || current.sessionId != state.sessionId) return;
      final dueAt = current.autoEndAtMs;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (dueAt == null || now < dueAt) return;
      debugPrint('[session-idle] in-app fallback autoEnd firing');
      try {
        await _autoEndSession(current);
        _activeState = null;
        await _clearState();
      } catch (e) {
        debugPrint('[session-idle] in-app fallback autoEnd failed: $e');
      }
    });
  }

  void _cancelInAppAutoEndTimer() {
    _inAppAutoEndTimer?.cancel();
    _inAppAutoEndTimer = null;
  }

  Future<void> _cancelPendingForSession(SessionIdleState state) async {
    await _notifications.cancel(id: _notificationId(state, offset: 1));
    await _notifications.cancel(id: _notificationId(state, offset: 2));
    await Workmanager().cancelByUniqueName(
      _workReminderUniqueName(state.sessionId),
    );
    await Workmanager().cancelByUniqueName(
      _workWarningUniqueName(state.sessionId),
    );
    await Workmanager().cancelByUniqueName(_workUniqueName(state.sessionId));
  }

  Future<void> _persistBackendAutoEndSchedule(SessionIdleState state) async {
    final autoEndAtMs = state.autoEndAtMs;
    if (autoEndAtMs == null) return;
    try {
      await _chatRemoteDataSource.setSessionAutoEndAt(
        uid: state.uid,
        sessionId: state.sessionId,
        autoEndAt: DateTime.fromMillisecondsSinceEpoch(autoEndAtMs),
      );
      debugPrint('[session-idle] backend autoEndAt armed');
    } catch (e) {
      debugPrint('[session-idle] backend autoEndAt arm failed: $e');
    }
  }

  Future<void> _clearBackendAutoEndSchedule(SessionIdleState state) async {
    try {
      await _chatRemoteDataSource.clearSessionAutoEndAt(
        uid: state.uid,
        sessionId: state.sessionId,
      );
      debugPrint('[session-idle] backend autoEndAt cleared');
    } catch (e) {
      debugPrint('[session-idle] backend autoEndAt clear failed: $e');
    }
  }

  Future<void> _persistState() async {
    final current = _activeState;
    if (current == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, jsonEncode(current.toJson()));
  }

  Future<void> _clearState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  static Future<SessionIdleState?> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      return SessionIdleState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  int _notificationId(SessionIdleState state, {required int offset}) {
    return state.sessionId.hashCode ^ (offset * 100003);
  }

  static String _workUniqueName(String sessionId) =>
      '$_workAutoEndUniquePrefix$sessionId';
  String _workReminderUniqueName(String sessionId) =>
      '$_workReminderUniquePrefix$sessionId';
  String _workWarningUniqueName(String sessionId) =>
      '$_workWarningUniquePrefix$sessionId';

  Future<void> _requestNotificationPermissions() async {
    final androidImpl = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidImpl?.requestNotificationsPermission();

    final iosImpl = _notifications
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);

    final macImpl = _notifications
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >();
    await macImpl?.requestPermissions(alert: true, badge: true, sound: true);
  }

  static Future<bool> autoEndIfOverdue() async {
    final state = await _loadState();
    if (state == null) return true;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (state.autoEndAtMs == null) return true;
    if (nowMs < state.autoEndAtMs!) {
      // Worker fired a bit early; re-arm it instead of silently exiting.
      final remainingMs = state.autoEndAtMs! - nowMs;
      final delay = Duration(
        milliseconds: remainingMs < 5000 ? 5000 : remainingMs,
      );
      debugPrint(
        '[session-idle][bg] autoEnd fired early, re-scheduling in $delay',
      );
      await _scheduleAutoEndRetry(state, delay: delay);
      return true;
    }
    debugPrint('[session-idle][bg] overdue autoEnd session=${state.sessionId}');

    final chatRemote = ChatRemoteDataSource();
    final aiRemote = ChatAiRemoteDataSource();

    try {
      await aiRemote.endAnalyzeSession(
        uid: state.uid,
        sessionId: state.sessionId,
        threadId: state.threadId,
        characterId: state.characterId,
      );
    } catch (_) {}

    try {
      await chatRemote.endChatSession(
        uid: state.uid,
        sessionId: state.sessionId,
        threadId: state.threadId,
      );
    } catch (_) {
      debugPrint('[session-idle][bg] firestore end failed');
      // Keep trying in background without requiring app resume.
      await _scheduleAutoEndRetry(state, delay: const Duration(seconds: 20));
      return false;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    return true;
  }

  static Future<void> _scheduleAutoEndRetry(
    SessionIdleState state, {
    required Duration delay,
  }) async {
    try {
      await Workmanager().registerOneOffTask(
        _workUniqueName(state.sessionId),
        _workAutoEndTaskName,
        initialDelay: delay,
        existingWorkPolicy: ExistingWorkPolicy.replace,
        inputData: {'sessionId': state.sessionId},
      );
      debugPrint('[session-idle][bg] autoEnd retry scheduled in $delay');
    } catch (e) {
      debugPrint('[session-idle][bg] autoEnd retry scheduling failed: $e');
    }
  }

  static Future<void> showBackgroundReminder({required bool isWarning}) async {
    final state = await _loadState();
    if (state == null) return;
    debugPrint(
      '[session-idle][bg] show reminder isWarning=$isWarning session=${state.sessionId}',
    );

    final plugin = FlutterLocalNotificationsPlugin();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await plugin.initialize(settings: settings);

    const androidDetails = AndroidNotificationDetails(
      'session_idle_reminders',
      'Session reminders',
      channelDescription: 'Reminds users about active chat sessions.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await plugin.show(
      id: state.sessionId.hashCode ^ (isWarning ? 2 : 1),
      title: isWarning ? 'Session will auto-end soon' : 'Session still active',
      body: isWarning
          ? 'If you stay away, this session will be ended automatically.'
          : 'You left a session open. Come back to continue or end it.',
      notificationDetails: details,
      payload: state.sessionId,
    );
    debugPrint('[session-idle][bg] reminder notification dispatched');
  }
}

class SessionIdleState {
  const SessionIdleState({
    required this.uid,
    required this.sessionId,
    required this.threadId,
    required this.characterId,
    this.backgroundedAtMs,
    this.reminderAtMs,
    this.warningAtMs,
    this.autoEndAtMs,
  });

  final String uid;
  final String sessionId;
  final String threadId;
  final String characterId;
  final int? backgroundedAtMs;
  final int? reminderAtMs;
  final int? warningAtMs;
  final int? autoEndAtMs;

  SessionIdleState copyWith({
    int? backgroundedAtMs,
    int? reminderAtMs,
    int? warningAtMs,
    int? autoEndAtMs,
  }) {
    return SessionIdleState(
      uid: uid,
      sessionId: sessionId,
      threadId: threadId,
      characterId: characterId,
      backgroundedAtMs: backgroundedAtMs,
      reminderAtMs: reminderAtMs,
      warningAtMs: warningAtMs,
      autoEndAtMs: autoEndAtMs,
    );
  }

  Map<String, dynamic> toJson() => {
    'uid': uid,
    'sessionId': sessionId,
    'threadId': threadId,
    'characterId': characterId,
    'backgroundedAtMs': backgroundedAtMs,
    'reminderAtMs': reminderAtMs,
    'warningAtMs': warningAtMs,
    'autoEndAtMs': autoEndAtMs,
  };

  factory SessionIdleState.fromJson(Map<String, dynamic> json) {
    return SessionIdleState(
      uid: json['uid']?.toString() ?? '',
      sessionId: json['sessionId']?.toString() ?? '',
      threadId: json['threadId']?.toString() ?? '',
      characterId: json['characterId']?.toString() ?? '',
      backgroundedAtMs: (json['backgroundedAtMs'] as num?)?.toInt(),
      reminderAtMs: (json['reminderAtMs'] as num?)?.toInt(),
      warningAtMs: (json['warningAtMs'] as num?)?.toInt(),
      autoEndAtMs: (json['autoEndAtMs'] as num?)?.toInt(),
    );
  }
}
