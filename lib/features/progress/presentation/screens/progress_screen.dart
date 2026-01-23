import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';

class ProgressScreen extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const ProgressScreen({
    super.key,
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopHelloBar(
          name: name,
          onLogout: onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SettingsBottomSheet(
                onRetakeQuestionnaire: onRetakeQuestionnaire,
                onSwitchLanguage: onSwitchLanguage,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + 92 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Progress overview
                Text(
                  tr(context, 'Your Journey Progress', 'تقدم رحلتك'),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr(
                    context,
                    'Track your growth and insights over time',
                    'تتبع نموك ورؤاك عبر الوقت',
                  ),
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF4B3A66).withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 30),

                // Weekly activity
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            color: Color(0xFF8E7CFF),
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            tr(context, 'Weekly Activity', 'النشاط الأسبوعي'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ActivityItem(
                        day: 'Mon',
                        value: 0.8,
                        label: tr(context, 'High self-awareness', 'وعي ذاتي مرتفع'),
                      ),
                      _ActivityItem(
                        day: 'Tue',
                        value: 0.6,
                        label: tr(context, 'Moderate activity', 'نشاط معتدل'),
                      ),
                      _ActivityItem(
                        day: 'Wed',
                        value: 0.9,
                        label: tr(context, 'Deep reflection', 'تأمل عميق'),
                      ),
                      _ActivityItem(
                        day: 'Thu',
                        value: 0.4,
                        label: tr(context, 'Quiet day', 'يوم هادئ'),
                      ),
                      _ActivityItem(
                        day: 'Fri',
                        value: 0.7,
                        label: tr(context, 'Good progress', 'تقدم جيد'),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Character insights
                Text(
                  tr(context, 'Character Insights', 'رؤى الشخصيات'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 15),
                _CharacterInsightCard(
                  characterName: tr(context, 'Inner Critic', 'الناقد الداخلي'),
                  trend: tr(context, 'Decreasing', 'يتناقص'),
                  trendColor: Colors.green,
                  insight: tr(
                    context,
                    'You\'re becoming more compassionate with yourself',
                    'أنت تصبح أكثر تعاطفًا مع نفسك',
                  ),
                ),
                const SizedBox(height: 15),
                _CharacterInsightCard(
                  characterName: tr(context, 'People Pleaser', 'إرضاء الآخرين'),
                  trend: tr(context, 'Stable', 'مستقر'),
                  trendColor: Colors.orange,
                  insight: tr(
                    context,
                    'Boundary-setting practice is showing results',
                    'ممارسة وضع الحدود تُظهر نتائج',
                  ),
                ),
                const SizedBox(height: 15),
                _CharacterInsightCard(
                  characterName: tr(context, 'Wounded Child', 'الطفل الجريح'),
                  trend: tr(context, 'Healing', 'يتعافى'),
                  trendColor: Colors.blue,
                  insight: tr(
                    context,
                    'Increased moments of self-compassion noted',
                    'زيادة لحظات التعاطف مع الذات',
                  ),
                ),

                const SizedBox(height: 40),

                // Milestones
                Text(
                  tr(context, 'Milestones', 'الإنجازات'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 15),
                _MilestoneItem(
                  title: tr(context, 'First Week Complete', 'إكمال الأسبوع الأول'),
                  date: tr(context, 'Completed 7 days ago', 'تم قبل 7 أيام'),
                  achieved: true,
                ),
                _MilestoneItem(
                  title: tr(context, '10 Self-Checkins', '10 تسجيلات ذاتية'),
                  date: tr(context, '3 more to go', 'تبقّى 3'),
                  achieved: false,
                ),
                _MilestoneItem(
                  title: tr(context, 'Recognized 3 Patterns', 'تم التعرف على 3 أنماط'),
                  date: tr(context, 'Completed today', 'تم اليوم'),
                  achieved: true,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String day;
  final double value;
  final String label;

  const _ActivityItem({
    required this.day,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: const Color(0xFFE5DEFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF8E7CFF),
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: const Color(0xFF7A6A5A), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterInsightCard extends StatelessWidget {
  final String characterName;
  final String trend;
  final Color trendColor;
  final String insight;

  const _CharacterInsightCard({
    required this.characterName,
    required this.trend,
    required this.trendColor,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8E7CFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF8E7CFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  characterName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: trendColor),
            ),
            child: Text(
              trend,
              style: TextStyle(
                color: trendColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String title;
  final String date;
  final bool achieved;

  const _MilestoneItem({
    required this.title,
    required this.date,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: achieved
                  ? const Color(0xFF8E7CFF).withOpacity(0.1)
                  : const Color(0xFFF0ECF7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              achieved ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: achieved
                  ? const Color(0xFF8E7CFF)
                  : const Color(0xFF9C90B3),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: achieved
                        ? const Color(0xFF2A1E3B)
                        : const Color(0xFF7A6A5A),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    color: achieved
                        ? const Color(0xFF6A5CFF)
                        : const Color(0xFF9C90B3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
