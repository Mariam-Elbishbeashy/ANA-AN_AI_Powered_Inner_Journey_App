// lib/features/profile/presentation/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/core/services/daily_task_notification_service.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/daily_activity_provider.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  DailyTaskReminderSettings _settings = DailyTaskReminderSettings.defaults();
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final loadedSettings = await DailyTaskNotificationService.loadSettings();

    if (!mounted) return;

    setState(() {
      _settings = loadedSettings;
      _isLoading = false;
    });
  }

  Future<void> _saveNotificationSettings({bool showSnackBar = true}) async {
    final isArabicValue = Localizations.localeOf(context).languageCode == 'ar';

    setState(() {
      _isSaving = true;
    });

    await DailyTaskNotificationService.saveFullSettings(_settings);

    if (_settings.taskRemindersEnabled) {
      try {
        await Provider.of<DailyActivityProvider>(context, listen: false)
            .rescheduleTaskRemindersFromSettings();
      } catch (_) {
        // This screen can still save settings even if the provider is not above it.
      }
    } else {
      await DailyTaskNotificationService.cancelTaskReminderNotifications();
    }

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    if (showSnackBar) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isArabicValue
                ? 'تم حفظ إعدادات الإشعارات'
                : 'Notification settings saved',
          ),
          backgroundColor: const Color(0xFF8E7CFF),
        ),
      );
    }
  }

  Future<void> _applySettingsImmediately(
      DailyTaskReminderSettings newSettings,
      ) async {
    if (!mounted) return;

    setState(() {
      _settings = newSettings;
    });

    await _saveNotificationSettings(showSnackBar: false);
  }

  Future<void> _pickTime({required String period}) async {
    final current = _timeOfDayForPeriod(period);

    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8E7CFF),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF2A1E3B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (period == 'morning') {
        _settings = _settings.copyWith(
          morningHour: picked.hour,
          morningMinute: picked.minute,
          taskRemindersEnabled: true,
          morningEnabled: true,
        );
      } else if (period == 'afternoon') {
        _settings = _settings.copyWith(
          afternoonHour: picked.hour,
          afternoonMinute: picked.minute,
          taskRemindersEnabled: true,
          afternoonEnabled: true,
        );
      } else {
        _settings = _settings.copyWith(
          eveningHour: picked.hour,
          eveningMinute: picked.minute,
          taskRemindersEnabled: true,
          eveningEnabled: true,
        );
      }
    });

    // Apply immediately after choosing the time so the user does not need
    // to press Save before the OS notification is rescheduled.
    await _saveNotificationSettings(showSnackBar: false);
  }

  TimeOfDay _timeOfDayForPeriod(String period) {
    if (period == 'morning') {
      return TimeOfDay(
        hour: _settings.morningHour,
        minute: _settings.morningMinute,
      );
    }
    if (period == 'afternoon') {
      return TimeOfDay(
        hour: _settings.afternoonHour,
        minute: _settings.afternoonMinute,
      );
    }
    return TimeOfDay(
      hour: _settings.eveningHour,
      minute: _settings.eveningMinute,
    );
  }

  String _formatTime(BuildContext context, int hour, int minute) {
    return TimeOfDay(hour: hour, minute: minute).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_back_ios_rounded,
                      color: Color(0xFF2A1E3B),
                      size: 20,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabicValue ? 'الإشعارات' : 'Notifications',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF8E7CFF),
              ),
            )
                : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabicValue
                        ? 'إشعارات المهام اليومية'
                        : 'Daily Tasks Notifications',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsCard(
                    children: [
                      _NotificationSwitch(
                        title: isArabicValue
                            ? 'تجديد المهام اليومية'
                            : 'Daily Tasks Renewal',
                        subtitle: isArabicValue
                            ? 'إشعار فقط عندما يتم تجديد كل المهام اليومية'
                            : 'Notify me only when all daily tasks are renewed',
                        value: _settings.renewalEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(renewalEnabled: value),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _NotificationSwitch(
                        title: isArabicValue ? 'الصوت' : 'Sound',
                        subtitle: isArabicValue
                            ? 'تشغيل صوت عند وصول الإشعار'
                            : 'Play sound when the notification arrives',
                        value: _settings.soundEnabled,
                        enabled: _settings.renewalEnabled ||
                            _settings.taskRemindersEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(soundEnabled: value),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _NotificationSwitch(
                        title: isArabicValue ? 'الاهتزاز' : 'Vibration',
                        subtitle: isArabicValue
                            ? 'تفعيل الاهتزاز عند وصول الإشعار'
                            : 'Enable vibration when the notification arrives',
                        value: _settings.vibrationEnabled,
                        enabled: _settings.renewalEnabled ||
                            _settings.taskRemindersEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(vibrationEnabled: value),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text(
                    isArabicValue
                        ? 'تذكير وقت المهام'
                        : 'Task Time Reminders',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SettingsCard(
                    children: [
                      _NotificationSwitch(
                        title: isArabicValue
                            ? 'تذكير لكل مهمة'
                            : 'Reminder for each task',
                        subtitle: isArabicValue
                            ? 'إرسال تذكير لكل مهمة حسب وقتها: صباحاً، بعد الظهر، أو مساءً'
                            : 'Send a reminder for every task according to its time: morning, afternoon, or evening',
                        value: _settings.taskRemindersEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(taskRemindersEnabled: value),
                          );
                        },
                      ),
                      const Divider(height: 24),
                      _PeriodReminderRow(
                        title: isArabicValue ? 'مهام الصباح' : 'Morning tasks',
                        subtitle: isArabicValue
                            ? 'تذكير لكل مهمة صباحية'
                            : 'Reminder for each morning task',
                        timeText: _formatTime(
                          context,
                          _settings.morningHour,
                          _settings.morningMinute,
                        ),
                        value: _settings.morningEnabled,
                        enabled: _settings.taskRemindersEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(morningEnabled: value),
                          );
                        },
                        onPickTime: () => _pickTime(period: 'morning'),
                      ),
                      const Divider(height: 24),
                      _PeriodReminderRow(
                        title: isArabicValue
                            ? 'مهام بعد الظهر'
                            : 'Afternoon tasks',
                        subtitle: isArabicValue
                            ? 'تذكير لكل مهمة بعد الظهر'
                            : 'Reminder for each afternoon task',
                        timeText: _formatTime(
                          context,
                          _settings.afternoonHour,
                          _settings.afternoonMinute,
                        ),
                        value: _settings.afternoonEnabled,
                        enabled: _settings.taskRemindersEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(afternoonEnabled: value),
                          );
                        },
                        onPickTime: () => _pickTime(period: 'afternoon'),
                      ),
                      const Divider(height: 24),
                      _PeriodReminderRow(
                        title: isArabicValue ? 'مهام المساء' : 'Evening tasks',
                        subtitle: isArabicValue
                            ? 'تذكير لكل مهمة مسائية'
                            : 'Reminder for each evening task',
                        timeText: _formatTime(
                          context,
                          _settings.eveningHour,
                          _settings.eveningMinute,
                        ),
                        value: _settings.eveningEnabled,
                        enabled: _settings.taskRemindersEnabled,
                        onChanged: (value) {
                          _applySettingsImmediately(
                            _settings.copyWith(eveningEnabled: value),
                          );
                        },
                        onPickTime: () => _pickTime(period: 'evening'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _InfoBox(
                    text: isArabicValue
                        ? 'سيتم إرسال إشعار التجديد عند إنشاء مهام جديدة. تذكيرات المهام يتم جدولتها للمهام الموجودة اليوم فقط حسب تصنيف كل مهمة.'
                        : 'Renewal notifications are sent when new daily tasks are created. Task reminders are scheduled for today’s tasks only according to each task category.',
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading || _isSaving
                    ? null
                    : () => _saveNotificationSettings(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E7CFF),
                  disabledBackgroundColor: const Color(0xFFD0C6E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isSaving
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
                    : Text(
                  isArabicValue ? 'حفظ التغييرات' : 'Save Changes',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

class _InfoBox extends StatelessWidget {
  final String text;

  const _InfoBox({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF8E7CFF).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF8E7CFF).withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_rounded,
            color: Color(0xFF8E7CFF),
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool>? onChanged;

  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    this.enabled = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textColor =
    enabled ? const Color(0xFF2A1E3B) : const Color(0xFF9C90B3);
    final subtitleColor =
    enabled ? const Color(0xFF7A6A5A) : const Color(0xFFB8ADC8);

    return Row(
      children: [
        Expanded(
          child: Opacity(
            opacity: enabled ? 1 : 0.55,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        Switch(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: const Color(0xFF8E7CFF),
        ),
      ],
    );
  }
}

class _PeriodReminderRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final String timeText;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final VoidCallback onPickTime;

  const _PeriodReminderRow({
    required this.title,
    required this.subtitle,
    required this.timeText,
    required this.value,
    required this.enabled,
    required this.onChanged,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final active = enabled && value;
    final textColor =
    enabled ? const Color(0xFF2A1E3B) : const Color(0xFF9C90B3);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A6A5A),
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: enabled ? onChanged : null,
                activeColor: const Color(0xFF8E7CFF),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: InkWell(
              onTap: active ? onPickTime : null,
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                decoration: BoxDecoration(
                  color: active
                      ? const Color(0xFF8E7CFF).withValues(alpha: 0.12)
                      : const Color(0xFFEFEAF8),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: active
                        ? const Color(0xFF8E7CFF).withValues(alpha: 0.26)
                        : const Color(0xFFE5DEFF),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.access_time_rounded,
                      size: 18,
                      color: active
                          ? const Color(0xFF6A5CFF)
                          : const Color(0xFF9C90B3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      timeText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: active
                            ? const Color(0xFF6A5CFF)
                            : const Color(0xFF9C90B3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
