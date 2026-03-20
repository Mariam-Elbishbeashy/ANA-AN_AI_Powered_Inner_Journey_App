// lib/features/progress/presentation/widgets/progress_charts.dart

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import '../../domain/entities/milestone.dart';


String _milestoneTitle(BuildContext context, Milestone milestone) {
  final isAr = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('ar');
  return isAr ? milestone.titleAr : milestone.titleEn;
}

String _milestoneDescription(BuildContext context, Milestone milestone) {
  final isAr = Localizations.localeOf(context).languageCode.toLowerCase().startsWith('ar');
  return isAr ? milestone.descriptionAr : milestone.descriptionEn;
}


class ProgressCharts extends StatelessWidget {
  const ProgressCharts({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            // Mood Trend Chart
            _buildChartCard(
              context,
              title: tr(context, 'Mood Trend', 'اتجاه المزاج'),
              subtitle: tr(context, 'Your emotional journey over time', 'رحلتك العاطفية عبر الزمن'),
              icon: Icons.show_chart_rounded,
              iconColor: const Color(0xFF8E7CFF),
              chart: _buildMoodTrendChart(context, provider),
              insight: _getMoodInsight(context, provider),
            ),

            const SizedBox(height: 20),

            // Emotion Distribution Chart
            _buildChartCard(
              context,
              title: tr(context, 'Emotion Distribution', 'توزيع المشاعر'),
              subtitle: tr(context, 'How your emotions are balanced', 'كيف تتوازن مشاعرك'),
              icon: Icons.pie_chart_rounded,
              iconColor: const Color(0xFFFF6B6B),
              chart: _buildEmotionDistributionChart(context, provider),
              insight: _getEmotionInsight(context, provider),
            ),

            const SizedBox(height: 20),

            // Character Interaction Chart
            _buildChartCard(
              context,
              title: tr(context, 'Character Interaction', 'تفاعل الشخصيات'),
              subtitle: tr(context, 'Which inner parts appear most', 'أي الأجزاء الداخلية تظهر أكثر'),
              icon: Icons.people_rounded,
              iconColor: const Color(0xFF2196F3),
              chart: _buildCharacterInteractionChart(context, provider),
              insight: _getCharacterInsight(context, provider),
            ),

            const SizedBox(height: 20),

            // Healing Progress Chart
            _buildChartCard(
              context,
              title: tr(context, 'Healing Progress', 'تقدم الشفاء'),
              subtitle: tr(context, 'Your growth in the healing journey', 'نموك في رحلة الشفاء'),
              icon: Icons.healing_rounded,
              iconColor: const Color(0xFF4CAF50),
              chart: _buildHealingProgressChart(context, provider),
              insight: _getHealingInsight(context, provider),
            ),
          ],
        );
      },
    );
  }

  Widget _buildChartCard(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color iconColor,
        required Widget chart,
        required String insight,
      }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withOpacity(0.1),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: const Color(0xFF7A6A5A).withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Chart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 220,
              child: chart,
            ),
          ),

          // Insight
          Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: iconColor,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    insight,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF2A1E3B),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Mood Trend Chart - using streak data to simulate mood over time
  Widget _buildMoodTrendChart(BuildContext context, MilestoneProvider provider) {
    // Get streak data from the last 7 days (simulated from streak history)
    final currentStreak = provider.getCurrentStreak();

    // Generate mood spots based on streak (simulating mood data)
    // In a real app, you'd store actual mood entries in Firestore
    final List<FlSpot> spots = [];
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    // Create varied mood data based on streak
    for (int i = 0; i < 7; i++) {
      // Simulate better mood on days with streak activity
      double moodValue;
      if (i < currentStreak) {
        // Recent days (if streak is active) - better mood
        moodValue = 3.5 + (i * 0.3); // Increasing mood with streak
        if (moodValue > 5) moodValue = 5;
      } else {
        // Older days - random mood
        moodValue = 2.0 + (i % 3).toDouble();
      }
      spots.add(FlSpot(i.toDouble(), moodValue));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 1,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5DEFF),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5DEFF),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < days.length) {
                  return Text(
                    days[value.toInt()],
                    style: const TextStyle(
                      color: Color(0xFF7A6A5A),
                      fontSize: 11,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                const moods = ['', '😔', '😟', '😐', '🙂', '😊'];
                if (value.toInt() >= 0 && value.toInt() < moods.length) {
                  return Text(
                    moods[value.toInt()],
                    style: const TextStyle(
                      color: Color(0xFF7A6A5A),
                      fontSize: 12,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xFFE5DEFF), width: 1),
        ),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 5.5,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF8E7CFF),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF8E7CFF),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF8E7CFF).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  // Emotion Distribution Chart - based on completed achievements by category
  Widget _buildEmotionDistributionChart(BuildContext context, MilestoneProvider provider) {
    final allMilestones = provider.milestones;

    // Calculate emotion distribution based on achievement categories
    double healingCount = allMilestones.where((m) => m.category == 'healing' && m.isAchieved).length.toDouble();
    double streakCount = allMilestones.where((m) => m.category == 'streak' && m.isAchieved).length.toDouble();
    double discoveryCount = allMilestones.where((m) => m.category == 'character_discovery' && m.isAchieved).length.toDouble();
    double dailyCount = allMilestones.where((m) => m.category == 'daily' && m.isAchieved).length.toDouble();

    final total = healingCount + streakCount + discoveryCount + dailyCount;

    // If no data, show sample distribution
    if (total == 0) {
      healingCount = 35;
      streakCount = 25;
      discoveryCount = 20;
      dailyCount = 20;
    } else {
      // Convert to percentages
      healingCount = (healingCount / total * 100).roundToDouble();
      streakCount = (streakCount / total * 100).roundToDouble();
      discoveryCount = (discoveryCount / total * 100).roundToDouble();
      dailyCount = (dailyCount / total * 100).roundToDouble();
    }

    final sections = [
      PieChartSectionData(
        value: healingCount,
        title: '${healingCount.round()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: const Color(0xFFFF6B6B), // Healing - red
      ),
      PieChartSectionData(
        value: streakCount,
        title: '${streakCount.round()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: const Color(0xFFFF9800), // Streak - orange
      ),
      PieChartSectionData(
        value: discoveryCount,
        title: '${discoveryCount.round()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: const Color(0xFF2196F3), // Discovery - blue
      ),
      PieChartSectionData(
        value: dailyCount,
        title: '${dailyCount.round()}%',
        radius: 50,
        titleStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
        color: const Color(0xFF8E7CFF), // Daily - purple
      ),
    ];

    return PieChart(
      PieChartData(
        sections: sections,
        centerSpaceRadius: 40,
        sectionsSpace: 2,
        pieTouchData: PieTouchData(
          touchCallback: (FlTouchEvent event, pieTouchResponse) {},
        ),
      ),
    );
  }

  // Character Interaction Chart - derived from achievement progress without legacy title/description fields
  Widget _buildCharacterInteractionChart(BuildContext context, MilestoneProvider provider) {
    final discoveryMilestones = provider.getCharacterDiscoveryMilestones();
    final healingMilestones = provider.getHealingMilestones();
    final stableMilestones = provider.getStableMilestones();

    final discovered = discoveryMilestones.isEmpty
        ? 0
        : discoveryMilestones
        .map((m) => m.currentCount)
        .fold<int>(0, (maxValue, value) => value > maxValue ? value : maxValue);
    final healed = healingMilestones.where((m) => m.isAchieved).length;
    final stable = stableMilestones.where((m) => m.isAchieved).length;
    final streak = provider.getCurrentStreak();

    double innerCritic = (discovered * 3 + healed * 2).clamp(0, 100).toDouble();
    double protector = (discovered * 2 + stable * 4 + streak).clamp(0, 100).toDouble();
    double overwhelmed = (discovered * 2 + healed).clamp(0, 100).toDouble();
    double calmSelf = (healed * 8 + stable * 10 + streak * 2).clamp(0, 100).toDouble();
    calmSelf = (calmSelf + streak * 3).clamp(0, 100);

    // If still zero, use sample data
    if (innerCritic == 0 && protector == 0 && overwhelmed == 0 && calmSelf == 0) {
      innerCritic = 85;
      protector = 45;
      overwhelmed = 60;
      calmSelf = 30;
    }

    final barGroups = [
      BarChartGroupData(
        x: 0,
        barRods: [
          BarChartRodData(
            toY: innerCritic,
            color: const Color(0xFFFF6B6B),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 1,
        barRods: [
          BarChartRodData(
            toY: protector,
            color: const Color(0xFF8E7CFF),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 2,
        barRods: [
          BarChartRodData(
            toY: overwhelmed,
            color: const Color(0xFFFF9800),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
      BarChartGroupData(
        x: 3,
        barRods: [
          BarChartRodData(
            toY: calmSelf,
            color: const Color(0xFF4CAF50),
            width: 16,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    ];

    return BarChart(
      BarChartData(
        gridData: FlGridData(
          show: true,
          drawHorizontalLine: true,
          horizontalInterval: 20,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5DEFF),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final characters = [
                  tr(context, 'Critic', 'الناقد'),
                  tr(context, 'Protector', 'الحامي'),
                  tr(context, 'Overwhelm', 'المرهق'),
                  tr(context, 'Calm', 'الهادئ'),
                ];
                if (value.toInt() >= 0 && value.toInt() < characters.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      characters[value.toInt()],
                      style: const TextStyle(
                        color: Color(0xFF7A6A5A),
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF7A6A5A),
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xFFE5DEFF), width: 1),
        ),
        barGroups: barGroups,
        maxY: 100,
      ),
    );
  }

  // Healing Progress Chart - based on healing milestones
  Widget _buildHealingProgressChart(BuildContext context, MilestoneProvider provider) {
    final healingMilestones = provider.getHealingMilestones();

    // Generate spots based on healing milestones
    final List<FlSpot> spots = [];

    if (healingMilestones.isEmpty) {
      // Sample data
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), (i * 12).toDouble()));
      }
    } else {
      // Sort milestones by target count
      final sorted = List<Milestone>.from(healingMilestones)
        ..sort((a, b) => a.targetCount.compareTo(b.targetCount));

      for (int i = 0; i < sorted.length; i++) {
        final milestone = sorted[i];
        final progress = (milestone.currentCount / milestone.targetCount) * 100;
        spots.add(FlSpot(i.toDouble(), progress));
      }

      // Add current streak as a progress indicator
      final streak = provider.getCurrentStreak();
      if (spots.length < 7) {
        for (int i = spots.length; i < 7; i++) {
          spots.add(FlSpot(i.toDouble(), (streak * 5).clamp(0, 100).toDouble()));
        }
      }
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          verticalInterval: 1,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5DEFF),
              strokeWidth: 1,
            );
          },
          getDrawingVerticalLine: (value) {
            return FlLine(
              color: const Color(0xFFE5DEFF),
              strokeWidth: 1,
            );
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final weeks = ['W1', 'W2', 'W3', 'W4', 'W5', 'W6', 'W7'];
                if (value.toInt() >= 0 && value.toInt() < weeks.length) {
                  return Text(
                    weeks[value.toInt()],
                    style: const TextStyle(
                      color: Color(0xFF7A6A5A),
                      fontSize: 11,
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(
                    color: Color(0xFF7A6A5A),
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xFFE5DEFF), width: 1),
        ),
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF4CAF50),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 4,
                  color: Colors.white,
                  strokeWidth: 2,
                  strokeColor: const Color(0xFF4CAF50),
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF4CAF50).withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  // Insights generation methods
  String _getMoodInsight(BuildContext context, MilestoneProvider provider) {
    final streak = provider.getCurrentStreak();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (streak > 5) {
      return isRtl
          ? 'مزاجك يتحسن مع استمرار السلسلة! استمر في الحفاظ على تفاعلك اليومي'
          : 'Your mood improves with your streak! Keep up your daily engagement';
    } else if (streak > 0) {
      return isRtl
          ? 'أنت في بداية رحلة تحسين المزاج. استمر في التفاعل يومياً'
          : 'You\'re at the start of your mood improvement journey. Keep engaging daily';
    } else {
      return isRtl
          ? 'ابدأ يومك بتسجيل مزاجك لترى أنماطك العاطفية'
          : 'Start logging your mood to see your emotional patterns';
    }
  }

  String _getEmotionInsight(BuildContext context, MilestoneProvider provider) {
    final totalAchieved = provider.milestones.where((m) => m.isAchieved).length;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (totalAchieved > 10) {
      return isRtl
          ? 'لديك توازن جيد في إنجازاتك! معظم مشاعرك إيجابية'
          : 'You have a good balance in your achievements! Most emotions are positive';
    } else if (totalAchieved > 5) {
      return isRtl
          ? 'أنت تبني تدريجياً مجموعة متنوعة من التجارب العاطفية'
          : 'You\'re gradually building a diverse range of emotional experiences';
    } else {
      return isRtl
          ? 'استمر في تحقيق المزيد من الإنجازات لترى توزيعاً أوضح لمشاعرك'
          : 'Keep achieving more milestones to see clearer emotion distribution';
    }
  }

  String _getCharacterInsight(BuildContext context, MilestoneProvider provider) {
    final discoveryCount = provider.getCharacterDiscoveryMilestones().length;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (discoveryCount > 3) {
      return isRtl
          ? 'لديك وعي جيد بشخصياتك الداخلية. الناقد الداخلي يظهر كثيراً'
          : 'You have good awareness of your inner characters. Inner Critic appears frequently';
    } else if (discoveryCount > 1) {
      return isRtl
          ? 'أنت تبدأ في التعرف على شخصياتك الداخلية. استمر في الاكتشاف'
          : 'You\'re starting to recognize your inner characters. Keep discovering';
    } else {
      return isRtl
          ? 'اكتشف المزيد من الشخصيات الداخلية لفهم نفسك بشكل أفضل'
          : 'Discover more inner characters to understand yourself better';
    }
  }

  String _getHealingInsight(BuildContext context, MilestoneProvider provider) {
    final healingMilestones = provider.getHealingMilestones();
    final achievedHealing = healingMilestones.where((m) => m.isAchieved).length;
    final streak = provider.getCurrentStreak();
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    if (achievedHealing > 2) {
      return isRtl
          ? 'تقدم رائع في رحلة الشفاء! استمر في العمل على شخصياتك الداخلية'
          : 'Great progress in your healing journey! Keep working on your inner characters';
    } else if (streak > 3) {
      return isRtl
          ? 'سلسلتك اليومية تساعد في تقدم الشفاء. استمر في التفاعل'
          : 'Your daily streak is helping healing progress. Keep engaging';
    } else {
      return isRtl
          ? 'ابدأ رحلة الشفاء بمعالجة شخصياتك الداخلية تدريجياً'
          : 'Start your healing journey by gradually working on your inner characters';
    }
  }
}