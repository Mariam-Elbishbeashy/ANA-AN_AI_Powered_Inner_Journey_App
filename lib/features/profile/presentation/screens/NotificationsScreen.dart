// notifications_screen.dart
import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _dailyReminders = true;
  bool _characterInsights = true;
  bool _weeklyProgress = true;
  bool _motivationalTips = false;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Column(
        children: [
          // App Bar
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
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF2A1E3B), size: 20),
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

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Notification Types Section
                  Text(
                    isArabicValue ? 'أنواع الإشعارات' : 'Notification Types',
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
                          title: isArabicValue ? 'التذكيرات اليومية' : 'Daily Reminders',
                          subtitle: isArabicValue
                              ? 'تذكير يومي بمراجعة شخصياتك'
                              : 'Daily reminder to check your characters',
                          value: _dailyReminders,
                          onChanged: (value) => setState(() => _dailyReminders = value),
                        ),
                        const Divider(height: 24),
                        _NotificationSwitch(
                          title: isArabicValue ? 'رؤى الشخصيات' : 'Character Insights',
                          subtitle: isArabicValue
                              ? 'تحليلات وتوصيات حول شخصياتك'
                              : 'Analytics and recommendations about your characters',
                          value: _characterInsights,
                          onChanged: (value) => setState(() => _characterInsights = value),
                        ),
                        const Divider(height: 24),
                        _NotificationSwitch(
                          title: isArabicValue ? 'التقدم الأسبوعي' : 'Weekly Progress',
                          subtitle: isArabicValue
                              ? 'ملخص أسبوعي لتقدمك'
                              : 'Weekly summary of your progress',
                          value: _weeklyProgress,
                          onChanged: (value) => setState(() => _weeklyProgress = value),
                        ),
                        const Divider(height: 24),
                        _NotificationSwitch(
                          title: isArabicValue ? 'نصائح تحفيزية' : 'Motivational Tips',
                          subtitle: isArabicValue
                              ? 'نصائح عشوائية للتحفيز'
                              : 'Random motivational tips and quotes',
                          value: _motivationalTips,
                          onChanged: (value) => setState(() => _motivationalTips = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Notification Settings Section
                  Text(
                    isArabicValue ? 'إعدادات الإشعارات' : 'Notification Settings',
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
                          title: isArabicValue ? 'الصوت' : 'Sound',
                          subtitle: isArabicValue
                              ? 'تشغيل صوت للإشعارات'
                              : 'Play sound for notifications',
                          value: _soundEnabled,
                          onChanged: (value) => setState(() => _soundEnabled = value),
                        ),
                        const Divider(height: 24),
                        _NotificationSwitch(
                          title: isArabicValue ? 'الاهتزاز' : 'Vibration',
                          subtitle: isArabicValue
                              ? 'تفعيل الاهتزاز للإشعارات'
                              : 'Enable vibration for notifications',
                          value: _vibrationEnabled,
                          onChanged: (value) => setState(() => _vibrationEnabled = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Notification Schedule
                  Text(
                    isArabicValue ? 'جدول الإشعارات' : 'Notification Schedule',
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
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.access_time_rounded,
                                color: Color(0xFF8E7CFF), size: 20),
                          ),
                          title: Text(
                            isArabicValue ? 'الوقت اليومي' : 'Daily Time',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          subtitle: const Text(
                            '9:00 AM',
                            style: TextStyle(fontSize: 13, color: Color(0xFF7A6A5A)),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: Color(0xFFD0C6E8)),
                          onTap: () {
                            _selectTime(context);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40), // Extra padding at bottom
                ],
              ),
            ),
          ),

          // Save Button (Fixed at bottom)
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
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isArabicValue
                          ? 'تم حفظ التفضيلات'
                          : 'Preferences saved'),
                      backgroundColor: const Color(0xFF8E7CFF),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E7CFF),
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

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8E7CFF),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      // Handle time selection
    }
  }
}

class _NotificationSwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _NotificationSwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
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
          onChanged: onChanged,
          activeColor: const Color(0xFF8E7CFF),
        ),
      ],
    );
  }
}