// lib/features/profile/presentation/screens/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const String _enabledKey = 'daily_tasks_notifications_enabled';
  static const String _soundKey = 'daily_tasks_sound_enabled';
  static const String _vibrationKey = 'daily_tasks_vibration_enabled';

  bool _dailyTasksEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotificationSettings();
  }

  Future<void> _loadNotificationSettings() async {
    final prefs = await SharedPreferences.getInstance();

    if (!mounted) return;

    setState(() {
      _dailyTasksEnabled = prefs.getBool(_enabledKey) ?? true;
      _soundEnabled = prefs.getBool(_soundKey) ?? true;
      _vibrationEnabled = prefs.getBool(_vibrationKey) ?? true;
      _isLoading = false;
    });
  }

  Future<void> _saveNotificationSettings() async {
    final isArabicValue = isArabic(context);

    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_enabledKey, _dailyTasksEnabled);
    await prefs.setBool(_soundKey, _soundEnabled);
    await prefs.setBool(_vibrationKey, _vibrationEnabled);

    if (!mounted) return;

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
                  Container(
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
                    child: Column(
                      children: [
                        _NotificationSwitch(
                          title: isArabicValue
                              ? 'تجديد المهام اليومية'
                              : 'Daily Tasks Renewal',
                          subtitle: isArabicValue
                              ? 'إشعار فقط عندما يتم تجديد كل المهام اليومية'
                              : 'Notify me only when all daily tasks are renewed',
                          value: _dailyTasksEnabled,
                          onChanged: (value) {
                            setState(() {
                              _dailyTasksEnabled = value;
                            });
                          },
                        ),
                        const Divider(height: 24),
                        _NotificationSwitch(
                          title: isArabicValue ? 'الصوت' : 'Sound',
                          subtitle: isArabicValue
                              ? 'تشغيل صوت عند وصول الإشعار'
                              : 'Play sound when the notification arrives',
                          value: _soundEnabled,
                          enabled: _dailyTasksEnabled,
                          onChanged: _dailyTasksEnabled
                              ? (value) {
                            setState(() {
                              _soundEnabled = value;
                            });
                          }
                              : null,
                        ),
                        const Divider(height: 24),
                        _NotificationSwitch(
                          title: isArabicValue ? 'الاهتزاز' : 'Vibration',
                          subtitle: isArabicValue
                              ? 'تفعيل الاهتزاز عند وصول الإشعار'
                              : 'Enable vibration when the notification arrives',
                          value: _vibrationEnabled,
                          enabled: _dailyTasksEnabled,
                          onChanged: _dailyTasksEnabled
                              ? (value) {
                            setState(() {
                              _vibrationEnabled = value;
                            });
                          }
                              : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFF8E7CFF).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF8E7CFF)
                            .withValues(alpha: 0.18),
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
                            isArabicValue
                                ? 'لن يتم إرسال أي إشعارات أخرى. سيظهر الإشعار فقط عندما يتم تجديد المهام اليومية بالكامل.'
                                : 'No other notifications will be sent. You will only be notified when the full daily tasks are renewed.',
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
                onPressed: _isLoading ? null : _saveNotificationSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E7CFF),
                  disabledBackgroundColor: const Color(0xFFD0C6E8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
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