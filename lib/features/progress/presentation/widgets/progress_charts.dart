// lib/features/progress/presentation/widgets/progress_charts.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/progress_charts_provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';

import '../../domain/entities/milestone.dart';

String _milestoneTitle(BuildContext context, Milestone milestone) {
  final isAr = isArabic(context);
  return isAr ? milestone.titleAr : milestone.titleEn;
}

String _milestoneDescription(BuildContext context, Milestone milestone) {
  final isAr = isArabic(context);
  return isAr ? milestone.descriptionAr : milestone.descriptionEn;
}

class ProgressCharts extends StatelessWidget {
  const ProgressCharts({super.key});

  static const ProgressChartsProvider _chartsProvider = ProgressChartsProvider();

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, provider, child) {
        return Column(
          children: [
            _buildIntensitySection(context),
            const SizedBox(height: 20),
            _buildVideoEmotionSection(context),
            const SizedBox(height: 20),
            _buildVideoToneSection(context),
          ],
        );
      },
    );
  }

  Widget _buildIntensitySection(BuildContext context) {
    return _ChartSectionShell(
      title: tr(context, 'Session Intensity', 'شدة جلسات '),
      subtitle: tr(
        context,
        'Track how each session starts and ends over time',
        'تابعي كيف تبدأ وتنتهي شدة كل جلسة مع الوقت',
      ),
      child: _buildIntensityOverviewCard(context),
    );
  }

  Widget _buildIntensityOverviewCard(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isArabicLanguage = isArabic(context);

    if (uid == null) {
      return _buildEmptyIntensityCard(context);
    }

    return StreamBuilder<List<CharacterSessionIntensity>>(
      stream: _chartsProvider.streamCharacterSessions(
        uid,
        isArabic: isArabicLanguage,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildIntensityLoadingCard(context);
        }

        final allSessions = snapshot.data ?? [];

        if (allSessions.isEmpty) {
          return _buildEmptyIntensityCard(context);
        }

        return _IntensityHabitLandCard(allSessions: allSessions);
      },
    );
  }



  Widget _buildVideoEmotionSection(BuildContext context) {
    return _ChartSectionShell(
      title: tr(context, 'Video Call Emotions', 'مشاعر مكالمات الفيديو'),
      subtitle: tr(
        context,
        'Track how session emotions move from one feeling to another',
        'تابعي كيف تنتقل مشاعر الجلسات من شعور إلى آخر',
      ),
      child: _buildVideoFlowOverviewCard(
        context,
        type: _VideoFlowCardType.emotion,
      ),
    );
  }

  Widget _buildVideoToneSection(BuildContext context) {
    return _ChartSectionShell(
      title: tr(context, 'Call Tone', 'نبرة مكالمات'),
      subtitle: tr(
        context,
        'Track the tone flow across your sessions',
        'تابعي تغيّر النبرة عبر جلسات',
      ),
      child: _buildVideoFlowOverviewCard(
        context,
        type: _VideoFlowCardType.tone,
      ),
    );
  }

  Widget _buildVideoFlowOverviewCard(
      BuildContext context, {
        required _VideoFlowCardType type,
      }) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final isArabicLanguage = isArabic(context);

    if (uid == null) {
      return _buildEmptyVideoFlowCard(context, type: type);
    }

    return StreamBuilder<List<VideoSessionFlowPoint>>(
      stream: _chartsProvider.streamVideoSessionFlow(
        uid,
        isArabic: isArabicLanguage,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildIntensityLoadingCard(context);
        }

        final points = snapshot.data ?? [];
        if (points.isEmpty) {
          return _buildEmptyVideoFlowCard(context, type: type);
        }

        return _VideoFlowHabitLandCard(
          allPoints: points,
          type: type,
        );
      },
    );
  }

  Widget _buildEmptyVideoFlowCard(
      BuildContext context, {
        required _VideoFlowCardType type,
      }) {
    final title = type == _VideoFlowCardType.emotion
        ? tr(context, 'No emotion flow yet', 'لا يوجد تدفق للمشاعر بعد')
        : tr(context, 'No tone flow yet', 'لا يوجد تدفق للنبرة بعد');

    final subtitle = type == _VideoFlowCardType.emotion
        ? tr(
      context,
      'Complete a video session to show emotion words like happy, sad, angry, and more.',
      'أكملي جلسة فيديو لعرض كلمات المشاعر مثل سعيد وحزين وغاضب وغيرها.',
    )
        : tr(
      context,
      'Complete a video session to show tone words like calm, supportive, anxious, and more.',
      'أكملي جلسة فيديو لعرض كلمات النبرة مثل هادئ وداعم وقلق وغيرها.',
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE7E1FF)),
      ),
      child: Column(
        children: [
          Icon(
            type == _VideoFlowCardType.emotion
                ? Icons.mood_rounded
                : Icons.record_voice_over_rounded,
            size: 36,
            color: const Color(0xFF8E7CFF),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A1E3B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8D84A6),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 24),
          Container(
            height: 150,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Center(
              child: Icon(
                Icons.show_chart_rounded,
                size: 40,
                color: Color(0xFFC4B5F5),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildIntensityLoadingCard(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.14),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF8E7CFF),
        ),
      ),
    );
  }

  Widget _buildEmptyIntensityCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(color: const Color(0xFFE7E1FF)),
      ),
      child: Column(
        children: [
          Container(
            width: 130,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2FF),
              borderRadius: BorderRadius.circular(22),
            ),
            alignment: Alignment.center,
            child: Container(
              width: 62,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E7CFF).withValues(alpha: 0.10),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            tr(context, 'No sessions yet', 'لا توجد جلسات بعد'),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2A1E3B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Start chatting with a character to see session start and end intensity here.',
              'ابدأ الدردشة مع إحدى الشخصيات لرؤية شدة البداية والنهاية هنا.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8D84A6),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 28),
          SizedBox(
            height: 150,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                    (index) => Container(
                  width: 16,
                  height: 40.0 + (index % 3) * 22,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFF8E7CFF).withValues(alpha: 0.85),
                        const Color(0xFFC6BCFF).withValues(alpha: 0.95),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
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
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.1),
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
                          color: const Color(0xFF7A6A5A).withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SizedBox(
              height: 220,
              child: chart,
            ),
          ),
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
                    color: iconColor.withValues(alpha: 0.1),
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

  Widget _buildEmotionDistributionChart(BuildContext context, MilestoneProvider provider) {
    final allMilestones = provider.milestones;

    double healingCount =
    allMilestones.where((m) => m.category == 'healing' && m.isAchieved).length.toDouble();
    double streakCount =
    allMilestones.where((m) => m.category == 'streak' && m.isAchieved).length.toDouble();
    double discoveryCount = allMilestones
        .where((m) => m.category == 'character_discovery' && m.isAchieved)
        .length
        .toDouble();
    double dailyCount =
    allMilestones.where((m) => m.category == 'daily' && m.isAchieved).length.toDouble();

    final total = healingCount + streakCount + discoveryCount + dailyCount;

    if (total == 0) {
      healingCount = 35;
      streakCount = 25;
      discoveryCount = 20;
      dailyCount = 20;
    } else {
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
        color: const Color(0xFFFF6B6B),
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
        color: const Color(0xFFFF9800),
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
        color: const Color(0xFF2196F3),
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
        color: const Color(0xFF8E7CFF),
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
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              reservedSize: 38,
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

  Widget _buildHealingProgressChart(BuildContext context, MilestoneProvider provider) {
    final healingMilestones = provider.getHealingMilestones();
    final List<FlSpot> spots = [];
    final List<String> labels = [];

    if (healingMilestones.isEmpty) {
      for (int i = 0; i < 7; i++) {
        spots.add(FlSpot(i.toDouble(), (i * 12).toDouble()));
        labels.add('W${i + 1}');
      }
    } else {
      final sorted = List<Milestone>.from(healingMilestones)
        ..sort((a, b) => a.targetCount.compareTo(b.targetCount));

      for (int i = 0; i < sorted.length; i++) {
        final milestone = sorted[i];
        final progress = milestone.targetCount == 0
            ? 0.0
            : ((milestone.currentCount / milestone.targetCount) * 100).clamp(0, 100).toDouble();

        spots.add(FlSpot(i.toDouble(), progress));
        labels.add(_milestoneTitle(context, milestone));
      }

      final streak = provider.getCurrentStreak();
      if (spots.length < 7) {
        for (int i = spots.length; i < 7; i++) {
          spots.add(FlSpot(i.toDouble(), (streak * 5).clamp(0, 100).toDouble()));
          labels.add('W${i + 1}');
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
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              reservedSize: 38,
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
        lineTouchData: LineTouchData(
          enabled: true,
          handleBuiltInTouches: true,
          touchSpotThreshold: 24,
          getTouchedSpotIndicator: (barData, spotIndexes) {
            return spotIndexes.map((index) {
              return TouchedSpotIndicatorData(
                FlLine(
                  color: const Color(0xFF4CAF50).withValues(alpha: 0.25),
                  strokeWidth: 2,
                  dashArray: [4, 4],
                ),
                FlDotData(
                  show: true,
                  getDotPainter: (spot, percent, barData, index) {
                    return FlDotCirclePainter(
                      radius: 6,
                      color: Colors.white,
                      strokeWidth: 3,
                      strokeColor: const Color(0xFF4CAF50),
                    );
                  },
                ),
              );
            }).toList();
          },
          touchTooltipData: LineTouchTooltipData(
            tooltipRoundedRadius: 14,
            tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            tooltipBgColor: const Color(0xFF4CAF50),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            showOnTopOfTheChartBoxArea: true,
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                final index = spot.x.toInt();
                final label = (index >= 0 && index < labels.length) ? labels[index] : 'Point';

                return LineTooltipItem(
                  '$label\n${spot.y.toStringAsFixed(1)}%',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                    height: 1.35,
                  ),
                );
              }).toList();
            },
          ),
        ),
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
              color: const Color(0xFF4CAF50).withValues(alpha: 0.1),
            ),
          ),
        ],
      ),
    );
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

class _ChartSectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _ChartSectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2344),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8F87B3),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null) action!,
          ],
        ),
        const SizedBox(height: 16),
        child,
      ],
    );
  }
}

class _IntensityHabitLandCard extends StatefulWidget {
  final List<CharacterSessionIntensity> allSessions;

  const _IntensityHabitLandCard({
    required this.allSessions,
  });

  @override
  State<_IntensityHabitLandCard> createState() => _IntensityHabitLandCardState();
}

class _IntensityHabitLandCardState extends State<_IntensityHabitLandCard> {
  int _selectedCharacterIndex = 0;
  int _pageOffset = 0;
  bool _isWeekView = true;

  static const Color _tabIndicatorPurple = Color(0xFF8E7CFF);
  static const Color _chatLineColor = Color(0xFFE57A91);
  static const Color _voiceLineColor = Color(0xFF5489DE);
  static const Color _videoLineColor = Color(0xFF8E7CFF);
  static const Color _daySelectedPurple = Color(0xFF6F5BFF);
  static const Color _chatStartDotFill = Color(0xFFFFF0F2);
  static const Color _chatStartDotStroke = Color(0xFFE8B0BE);
  static const Color _chatEndDotFill = Color(0xFFE88B9E);
  static const Color _voiceStartDotFill = Color(0xFFEDF3FF);
  static const Color _voiceStartDotStroke = Color(0xFF8CB0E0);
  static const Color _voiceEndDotFill = Color(0xFF3D7ACC);
  static const Color _videoStartDotFill = Color(0xFFE8E0FF);
  static const Color _videoStartDotStroke = Color(0xFFC4B5F5);
  static const Color _videoEndDotFill = Color(0xFF8E7CFF);

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCharacter(widget.allSessions);
    final characterIds = grouped.keys.toList();

    if (characterIds.isEmpty) {
      return const SizedBox.shrink();
    }

    if (_selectedCharacterIndex >= characterIds.length) {
      _selectedCharacterIndex = 0;
    }

    final selectedId = characterIds[_selectedCharacterIndex];
    final selectedSessions = grouped[selectedId]!..sort((a, b) => a.date.compareTo(b.date));

    final periodData = _isWeekView
        ? _buildWeekData(selectedSessions, _pageOffset)
        : _buildDayData(selectedSessions, _pageOffset);

    final visibleSessions = periodData.sessions;

    final sessionCount = visibleSessions.isEmpty ? 0 : visibleSessions.length;

    final avgIntensity = visibleSessions.isEmpty
        ? 0.0
        : visibleSessions.map((e) => e.averagePercent).reduce((a, b) => a + b) / visibleSessions.length;


    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9E4FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTopSegment(),
          const SizedBox(height: 18),
          _buildCharacterSelector(characterIds, grouped),
          const SizedBox(height: 16),
          _buildPeriodHeader(periodData),
          const SizedBox(height: 14),
          _buildTopStats(context, avgIntensity, sessionCount, visibleSessions),
          const SizedBox(height: 18),
          SizedBox(
            height: 240,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 6, top: 8, bottom: 2),
              child: _isWeekView
                  ? _buildWeeklyCompletionBarChart(context, periodData)
                  : _buildDailySessionStartEndLineChart(context, periodData),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSegment() {
    const activeColor = Color(0xFF2A1E3B);
    const inactiveColor = Color(0xFF9CA3AF);

    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: selected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: selected ? _tabIndicatorPurple : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(tr(context, 'Day', 'اليوم'), !_isWeekView, () {
          setState(() {
            _isWeekView = false;
            _pageOffset = 0;
          });
        }),
        tab(tr(context, 'Week', 'الأسبوع'), _isWeekView, () {
          setState(() {
            _isWeekView = true;
            _pageOffset = 0;
          });
        }),
      ],
    );
  }

  Widget _buildCharacterSelector(
      List<String> characterIds,
      Map<String, List<CharacterSessionIntensity>> grouped,
      ) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: characterIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = characterIds[index];
          final name = grouped[id]!.first.characterName;
          final selected = index == _selectedCharacterIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCharacterIndex = index;
                _pageOffset = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: selected
                    ? const LinearGradient(
                  colors: [
                    Color(0xFF8E7CFF),
                    Color(0xFFA797FF),
                  ],
                )
                    : null,
                color: selected ? null : const Color(0xFFF7F5FF),
                border: Border.all(
                  color: selected ? Colors.transparent : const Color(0xFFE7E1FF),
                ),
                boxShadow: selected
                    ? [
                  BoxShadow(
                    color: const Color(0xFF8E7CFF).withValues(alpha: 0.22),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ]
                    : null,
              ),
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF6D6486),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPeriodHeader(_CharacterPeriodData data) {
    final canGoBack = data.canGoBack;
    final canGoForward = _pageOffset > 0;

    return Row(
      children: [
        _PeriodNavArrow(
          icon: Icons.chevron_left_rounded,
          enabled: canGoBack,
          onTap: !canGoBack
              ? null
              : () {
            setState(() {
              _pageOffset += 1;
            });
          },
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        _PeriodNavArrow(
          icon: Icons.chevron_right_rounded,
          enabled: canGoForward,
          onTap: !canGoForward
              ? null
              : () {
            setState(() {
              _pageOffset -= 1;
            });
          },
        ),
      ],
    );
  }

  Widget _buildTopStats(
      BuildContext context,
      double avgIntensity,
      int sessionCount,
      List<CharacterSessionIntensity> visibleSessions,
      ) {
    final intensityLabel = _intensityLabel(context, visibleSessions);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                intensityLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                sessionCount == 0 ? '—' : '${avgIntensity.round()}%',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ],
          ),
        ),        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                tr(context, 'Sessions', 'جلسات'),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$sessionCount',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _intensityLabel(
      BuildContext context,
      List<CharacterSessionIntensity> visibleSessions,
      ) {
    if (visibleSessions.isEmpty) {
      return tr(context, 'Intensity', 'الشدة');
    }

    final hasChat = visibleSessions.any((session) => session.sessionType == 'chat');
    final hasVideo = visibleSessions.any((session) => session.sessionType == 'video');
    final hasVoice = visibleSessions.any((session) => session.sessionType == 'voice');

    if (hasChat && !hasVideo && !hasVoice) {
      return tr(context, 'Chat Intensity', 'شدة الدردشة');
    }

    if (hasVideo && !hasChat && !hasVoice) {
      return tr(context, 'Video Intensity', 'شدة الفيديو');
    }

    if (hasVoice && !hasChat && !hasVideo) {
      return tr(context, 'Voice Intensity', 'شدة المكالمات الصوتية');
    }

    if (hasChat && hasVoice && !hasVideo) {
      return tr(context, 'Chat & Voice Intensity', 'شدة الدردشة والصوت');
    }

    if (hasChat && hasVideo && !hasVoice) {
      return tr(context, 'Chat & Video Intensity', 'شدة الدردشة والفيديو');
    }

    if (hasVideo && hasVoice && !hasChat) {
      return tr(context, 'Video & Voice Intensity', 'شدة الفيديو والصوت');
    }

    return tr(context, 'Chat, Video & Voice Intensity', 'شدة الدردشة والفيديو والصوت');
  }

  Widget _buildSelectedSummaryPill({
    Key? key,
    required WeeklyDayIntensitySummary summary,
  }) {
    return Container(
      key: key,
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F3FA),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatMonthDay(context, summary.date),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFFA39BB8),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${summary.startPercent.round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA39BB8),
            ),
          ),
          const SizedBox(width: 8),
          const Text(
            '→',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFFA39BB8),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '${summary.endPercent.round()}%',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF6F5BFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCompletionBarChart(
      BuildContext context,
      _CharacterPeriodData periodData,
      ) {
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        minY: 0,
        groupsSpace: 12,
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: false,
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return FlLine(
                color: Colors.transparent,
                strokeWidth: 0,
              );
            }

            if (value == 25 || value == 50 || value == 75 || value == 100) {
              return FlLine(
                color: const Color(0xFFE3DEF7),
                strokeWidth: 1.1,
                dashArray: const [4, 4],
              );
            }

            return FlLine(
              color: Colors.transparent,
              strokeWidth: 0,
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 48,
              showTitles: true,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();

                return Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      '${value.toInt()}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();

                if (index < 0 || index > 6) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _weekdayShortLabel(context, index),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        // Find this section and REPLACE the color assignment:
        barGroups: List.generate(7, (dayIndex) {
          final item = periodData.dayItems[dayIndex];
          final overallY = item?.averagePercent ?? 0;
          final hasData = item != null && overallY > 0;

          // REPLACE this entire color logic block:
          Color barColor;
          String? tooltipLabel;
          if (hasData && item != null) {
            final hasChat = item.sessions.any((s) => s.sessionType == 'chat');
            final hasVideo = item.sessions.any((s) => s.sessionType == 'video');
            final hasVoice = item.sessions.any((s) => s.sessionType == 'voice');

            if (hasChat && !hasVideo && !hasVoice) {
              barColor = _chatLineColor;   // Chat only - Pink
              tooltipLabel = 'Chat';
            } else if (hasVoice && !hasChat && !hasVideo) {
              barColor = _voiceLineColor;  // Voice only - Blue
              tooltipLabel = 'Voice';
            } else if (hasVideo && !hasChat && !hasVoice) {
              barColor = _videoLineColor;  // Video only - Purple
              tooltipLabel = 'Video';
            } else if (hasChat && hasVoice && !hasVideo) {
              barColor = _chatLineColor;   // Chat + Voice mix - Pink
              tooltipLabel = 'Chat + Voice';
            } else {
              barColor = _videoLineColor;  // Any mix including video - Purple
              tooltipLabel = 'Mixed';
            }
          } else {
            barColor = _videoLineColor;
          }

          return BarChartGroupData(
            x: dayIndex,
            barsSpace: 0,
            barRods: [
              BarChartRodData(
                fromY: 0,
                toY: hasData ? overallY : 0,
                width: 14,
                borderRadius: BorderRadius.circular(12),
                color: hasData ? barColor : Colors.transparent,
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: 100,
                  color: const Color(0xFFF4F1FF),
                ),
              ),
            ],
          );
        }),
      ),
      swapAnimationDuration: const Duration(milliseconds: 250),
    );
  }

  Widget _buildDailySessionStartEndLineChart(
      BuildContext context,
      _CharacterPeriodData periodData,
      ) {
    final sessions = periodData.sessions;

    if (sessions.isEmpty) {
      return Center(
        child: Text(
          tr(context, 'No sessions this day', 'لا جلسات في هذا اليوم'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    final maxX = (sessions.length * 2 - 1).toDouble();

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: maxX,
        clipData: FlClipData.all(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 25,
          getDrawingHorizontalLine: (value) {
            if (value == 0) {
              return FlLine(color: Colors.transparent, strokeWidth: 0);
            }
            final isMid = value == 75;
            return FlLine(
              color: const Color(0xFFE8E0F5),
              strokeWidth: isMid ? 1.4 : 1,
              dashArray: const [4, 4],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 42,
              showTitles: true,
              interval: 25,
              getTitlesWidget: (value, meta) {
                if (value == 0) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    '${value.toInt()}%',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 36,
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index.isOdd) return const SizedBox.shrink();
                final sessionIndex = index ~/ 2;
                if (sessionIndex >= sessions.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    _sessionLabel(context, sessionIndex + 1),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF9B93AF),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: false,
        ),
        // Find the lineBarsData generation section and REPLACE:
        lineBarsData: List.generate(sessions.length, (i) {
          final s = sessions[i];
          final x0 = (i * 2).toDouble();
          final x1 = x0 + 1;

          // REPLACE this entire color assignment block:
          Color lineColor;
          Color startDotFill;
          Color startDotStroke;
          Color endDotFill;

          if (s.sessionType == 'chat') {
            // Chat - Pink
            lineColor = _chatLineColor;
            startDotFill = _chatStartDotFill;
            startDotStroke = _chatStartDotStroke;
            endDotFill = _chatEndDotFill;
          } else if (s.sessionType == 'voice') {
            // Voice - Blue
            lineColor = _voiceLineColor;
            startDotFill = _voiceStartDotFill;
            startDotStroke = _voiceStartDotStroke;
            endDotFill = _voiceEndDotFill;
          } else {
            // Video - Purple (original)
            lineColor = _videoLineColor;
            startDotFill = _videoStartDotFill;
            startDotStroke = _videoStartDotStroke;
            endDotFill = _videoEndDotFill;
          }

          return LineChartBarData(
            spots: [
              FlSpot(x0, s.startPercent),
              FlSpot(x1, s.endPercent),
            ],
            isCurved: false,
            barWidth: 2.5,
            color: lineColor,
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, barData) => true,
              getDotPainter: (spot, percent, barData, index) {
                final isStart = index == 0;
                return FlDotCirclePainter(
                  radius: isStart ? 4.5 : 5.5,
                  color: isStart ? startDotFill : endDotFill,
                  strokeWidth: 2,
                  strokeColor: isStart ? startDotStroke : Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  lineColor.withValues(alpha: 0.22),
                  lineColor.withValues(alpha: 0.04),
                ],
              ),
            ),
          );
        }),
      ),
      duration: Duration.zero,
    );
  }

  Map<String, List<CharacterSessionIntensity>> _groupByCharacter(
      List<CharacterSessionIntensity> sessions,
      ) {
    final Map<String, List<CharacterSessionIntensity>> grouped = {};

    for (final session in sessions) {
      grouped.putIfAbsent(session.characterId, () => []);
      grouped[session.characterId]!.add(session);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final lastA = a.value.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
        final lastB = b.value.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
        return lastB.compareTo(lastA);
      });

    return {for (final entry in entries) entry.key: entry.value};
  }

  _CharacterPeriodData _buildWeekData(
      List<CharacterSessionIntensity> sessions,
      int pageOffset,
      ) {
    final now = DateTime.now();
    final startOfThisWeek = _startOfWeek(now);
    final start = startOfThisWeek.subtract(Duration(days: 7 * pageOffset));
    final end = start.add(const Duration(days: 6));

    final periodSessions = sessions.where((session) {
      final d = DateTime(session.date.year, session.date.month, session.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<int, WeeklyDayIntensitySummary> dayItems = {};

    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      final dayDate = start.add(Duration(days: dayIndex));
      final daySessions = periodSessions.where((session) {
        final d = DateTime(session.date.year, session.date.month, session.date.day);
        return d.year == dayDate.year && d.month == dayDate.month && d.day == dayDate.day;
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      if (daySessions.isEmpty) continue;

      final firstSession = daySessions.first;
      final lastSession = daySessions.last;

      final averagePercent =
          daySessions.map((e) => e.averagePercent).reduce((a, b) => a + b) / daySessions.length;

      dayItems[dayIndex] = WeeklyDayIntensitySummary(
        date: dayDate,
        startPercent: firstSession.startPercent,
        endPercent: lastSession.endPercent,
        averagePercent: averagePercent,
        sessionCount: daySessions.length,
        sessions: daySessions,
      );
    }

    WeeklyDayIntensitySummary? highlightSession;
    int? highlightIndex;

    if (dayItems.isNotEmpty) {
      final bestEntry = dayItems.entries.reduce(
            (a, b) => a.value.averagePercent >= b.value.averagePercent ? a : b,
      );
      highlightIndex = bestEntry.key;
      highlightSession = bestEntry.value;
    }

    final oldestSession = sessions.isEmpty ? null : sessions.first.date;
    final canGoBack = oldestSession != null && _startOfWeek(oldestSession).isBefore(start);

    return _CharacterPeriodData(
      title: _formatDateRange(context, start, end),
      subtitle: _localizedNumber(context, start.year),
      sessions: periodSessions,
      dayItems: dayItems,
      highlightSession: highlightSession,
      highlightIndex: highlightIndex,
      canGoBack: canGoBack,
    );
  }

  _CharacterPeriodData _buildDayData(
      List<CharacterSessionIntensity> sessions,
      int pageOffset,
      ) {
    final uniqueDays = sessions
        .map((session) => DateTime(session.date.year, session.date.month, session.date.day))
        .toSet()
        .toList()
      ..sort((a, b) => b.compareTo(a));

    if (uniqueDays.isEmpty) {
      final now = DateTime.now();
      return _CharacterPeriodData(
        title: _formatMonthDay(context, now),
        subtitle: _localizedNumber(context, now.year),
        sessions: const [],
        dayItems: const {},
        highlightSession: null,
        highlightIndex: null,
        canGoBack: false,
      );
    }

    final safeOffset = pageOffset.clamp(0, uniqueDays.length - 1);
    final day = uniqueDays[safeOffset];

    final periodSessions = sessions.where((session) {
      final d = DateTime(session.date.year, session.date.month, session.date.day);
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    WeeklyDayIntensitySummary? highlightSession;
    if (periodSessions.isNotEmpty) {
      final firstSession = periodSessions.first;
      final lastSession = periodSessions.last;
      final averagePercent =
          periodSessions.map((e) => e.averagePercent).reduce((a, b) => a + b) /
              periodSessions.length;

      highlightSession = WeeklyDayIntensitySummary(
        date: day,
        startPercent: firstSession.startPercent,
        endPercent: lastSession.endPercent,
        averagePercent: averagePercent,
        sessionCount: periodSessions.length,
        sessions: periodSessions,
      );
    }

    final canGoBack = safeOffset < uniqueDays.length - 1;

    return _CharacterPeriodData(
      title: _formatMonthDay(context, day),
      subtitle: _localizedNumber(context, day.year),
      sessions: periodSessions,
      dayItems: const {},
      highlightSession: highlightSession,
      highlightIndex: null,
      canGoBack: canGoBack,
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final weekday = normalized.weekday;
    return normalized.subtract(Duration(days: weekday - 1));
  }

  static String _formatDateRange(BuildContext context, DateTime start, DateTime end) {
    return '${_formatMonthDay(context, start)} - ${_formatMonthDay(context, end)}';
  }

  static String _formatMonthDay(BuildContext context, DateTime date) {
    final month = _monthName(context, date.month);
    final day = _localizedNumber(context, date.day);

    if (isArabic(context)) {
      return '$day $month';
    }

    return '$month $day';
  }

  static String _sessionLabel(BuildContext context, int number) {
    return '${tr(context, 'S', 'ج')}${_localizedNumber(context, number)}';
  }

  static String _weekdayShortLabel(BuildContext context, int index) {
    const en = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    const ar = ['ن', 'ث', 'ر', 'خ', 'ج', 'س', 'ح'];
    return isArabic(context) ? ar[index] : en[index];
  }

  static String _monthName(BuildContext context, int month) {
    const en = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    const ar = [
      'يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو',
      'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'
    ];

    return isArabic(context) ? ar[month - 1] : en[month - 1];
  }

  static String _localizedNumber(BuildContext context, int value) {
    final text = value.toString();
    if (!isArabic(context)) return text;

    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    var result = text;
    for (int i = 0; i < western.length; i++) {
      result = result.replaceAll(western[i], arabic[i]);
    }
    return result;
  }
}

class _CharacterPeriodData {
  final String title;
  final String subtitle;
  final List<CharacterSessionIntensity> sessions;
  final Map<int, WeeklyDayIntensitySummary> dayItems;
  final WeeklyDayIntensitySummary? highlightSession;
  final int? highlightIndex;
  final bool canGoBack;

  const _CharacterPeriodData({
    required this.title,
    required this.subtitle,
    required this.sessions,
    required this.dayItems,
    required this.highlightSession,
    required this.highlightIndex,
    required this.canGoBack,
  });
}

class _PeriodNavArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final VoidCallback? onTap;

  const _PeriodNavArrow({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 26,
            color: enabled ? const Color(0xFF6B7280) : const Color(0xFFE5E7EB),
          ),
        ),
      ),
    );
  }
}

enum _VideoFlowCardType { emotion, tone }

class _VideoFlowHabitLandCard extends StatefulWidget {
  final List<VideoSessionFlowPoint> allPoints;
  final _VideoFlowCardType type;

  const _VideoFlowHabitLandCard({
    required this.allPoints,
    required this.type,
  });

  @override
  State<_VideoFlowHabitLandCard> createState() => _VideoFlowHabitLandCardState();
}

class _VideoFlowHabitLandCardState extends State<_VideoFlowHabitLandCard> {
  int _selectedCharacterIndex = 0;
  int _pageOffset = 0;
  bool _isWeekView = true;

  static const Color _purple = Color(0xFF8E7CFF);
  static const Color _purpleDark = Color(0xFF6F5BFF);

  static const List<_FlowAxisItem> _emotionAxis = [
    _FlowAxisItem('happy', 'Happy', 'سعيد'),
    _FlowAxisItem('neutral', 'Neutral', 'محايد'),
    _FlowAxisItem('surprise', 'Surprise', 'مفاجأة'),
    _FlowAxisItem('fear', 'Fear', 'خوف'),
    _FlowAxisItem('sad', 'Sad', 'حزين'),
    _FlowAxisItem('angry', 'Angry', 'غاضب'),
  ];

  static const List<_FlowAxisItem> _toneAxis = _emotionAxis;

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCharacter(widget.allPoints);
    final characterIds = grouped.keys.toList();
    if (characterIds.isEmpty) return const SizedBox.shrink();

    if (_selectedCharacterIndex >= characterIds.length) {
      _selectedCharacterIndex = 0;
    }

    final selectedId = characterIds[_selectedCharacterIndex];
    final points = grouped[selectedId]!..sort((a, b) => a.date.compareTo(b.date));
    final periodData = _isWeekView ? _buildWeekData(points) : _buildDayData(points);
    final latestLabel = periodData.points.isEmpty
        ? '—'
        : widget.type == _VideoFlowCardType.emotion ? periodData.points.last.emotionLabel(isArabic(context)) : periodData.points.last.toneLabel(isArabic(context));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE9E4FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.14),
            blurRadius: 26,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildTopSegment(context),
          const SizedBox(height: 18),
          _buildCharacterSelector(context, characterIds, grouped),
          const SizedBox(height: 16),
          _buildHeader(context, periodData),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _buildStatBlock(
                  context,
                  widget.type == _VideoFlowCardType.emotion
                      ? tr(context, 'Latest emotion', 'آخر شعور')
                      : tr(context, 'Latest tone', 'آخر نبرة'),
                  latestLabel,
                ),
              ),
              Expanded(
                child: _buildStatBlock(
                  context,
                  tr(context, 'Sessions', 'الجلسات'),
                  _localizedNumber(context, periodData.sessionCount),
                  alignEnd: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 260,
            child: Padding(
              padding: const EdgeInsets.only(left: 8, right: 6, top: 8, bottom: 2),
              child: _buildFlowChart(context, periodData),
            ),
          ),
        ],
      ),
    );
  }


  List<_FlowAxisItem> get _axisItems =>
      widget.type == _VideoFlowCardType.emotion ? _emotionAxis : _toneAxis;

  Widget _buildTopSegment(BuildContext context) {
    const activeColor = Color(0xFF2A1E3B);
    const inactiveColor = Color(0xFF9CA3AF);

    Widget tab(String label, bool selected, VoidCallback onTap) {
      return Expanded(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? activeColor : inactiveColor,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  height: 3,
                  width: selected ? 28 : 0,
                  decoration: BoxDecoration(
                    color: selected ? _purple : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        tab(tr(context, 'Day', 'اليوم'), !_isWeekView, () {
          setState(() {
            _isWeekView = false;
            _pageOffset = 0;
          });
        }),
        tab(tr(context, 'Week', 'الأسبوع'), _isWeekView, () {
          setState(() {
            _isWeekView = true;
            _pageOffset = 0;
          });
        }),
      ],
    );
  }

  Widget _buildCharacterSelector(
      BuildContext context,
      List<String> characterIds,
      Map<String, List<VideoSessionFlowPoint>> grouped,
      ) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: characterIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = characterIds[index];
          final name = grouped[id]!.first.characterName;
          final selected = index == _selectedCharacterIndex;

          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedCharacterIndex = index;
                _pageOffset = 0;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: selected
                    ? const LinearGradient(
                  colors: [Color(0xFF8E7CFF), Color(0xFFA797FF)],
                )
                    : null,
                color: selected ? null : const Color(0xFFF7F5FF),
                border: Border.all(
                  color: selected ? Colors.transparent : const Color(0xFFE7E1FF),
                ),
              ),
              child: Center(
                child: Text(
                  name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : const Color(0xFF6D6486),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, _FlowPeriodData periodData) {
    final canGoBack = periodData.canGoBack;
    final canGoForward = _pageOffset > 0;

    return Row(
      children: [
        _PeriodNavArrow(
          icon: Icons.chevron_left_rounded,
          enabled: canGoBack,
          onTap: canGoBack
              ? () {
            setState(() {
              _pageOffset += 1;
            });
          }
              : null,
        ),
        Expanded(
          child: Column(
            children: [
              Text(
                periodData.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                periodData.subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
        _PeriodNavArrow(
          icon: Icons.chevron_right_rounded,
          enabled: canGoForward,
          onTap: canGoForward
              ? () {
            setState(() {
              _pageOffset -= 1;
            });
          }
              : null,
        ),
      ],
    );
  }

  Widget _buildStatBlock(BuildContext context, String label, String value, {bool alignEnd = false}) {
    return Column(
      crossAxisAlignment: alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF2A1E3B),
          ),
          textAlign: alignEnd ? TextAlign.end : TextAlign.start,
        ),
      ],
    );
  }

  Widget _buildFlowChart(BuildContext context, _FlowPeriodData periodData) {
    if (periodData.points.isEmpty) {
      return Center(
        child: Text(
          tr(context, 'No sessions in this period', 'لا توجد جلسات في هذه الفترة'),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
          ),
        ),
      );
    }

    final labels = <String>[];
    final dayStartXValues = <double>[];
    const double xStartOffset = 0.1;

    final bool showAllDates = periodData.points.length <= 7;
    final List<LineChartBarData> lineBarsData = [];
    int visualPointCount = 0;

    if (_isWeekView) {
      final spots = <FlSpot>[];

      for (int i = 0; i < periodData.points.length; i++) {
        final point = periodData.points[i];
        final x = i.toDouble() + xStartOffset;

        spots.add(
          FlSpot(
            x,
            _indexFor(point).toDouble(),
          ),
        );

        final bool isFirstPointForDay =
            i == 0 || !_isSameDay(periodData.points[i - 1].date, point.date);

        if (isFirstPointForDay) {
          dayStartXValues.add(x);
        }

        if (showAllDates) {
          labels.add(_formatMonthDay(context, point.date));
        } else {
          labels.add(isFirstPointForDay ? _formatMonthDay(context, point.date) : '');
        }
      }

      visualPointCount = spots.length;

      lineBarsData.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: _purple,
          barWidth: 2.6,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) {
              return FlDotCirclePainter(
                radius: 4,
                color: Colors.white,
                strokeWidth: 2,
                strokeColor: _purple,
              );
            },
          ),
        ),
      );
    } else {
      final Map<String, List<VideoSessionFlowPoint>> pointsBySession = {};
      for (final point in periodData.points) {
        pointsBySession.putIfAbsent(point.sessionId, () => []);
        pointsBySession[point.sessionId]!.add(point);
      }

      final sessionEntries = pointsBySession.entries.toList()
        ..sort((a, b) {
          final aDate = a.value.first.date;
          final bDate = b.value.first.date;
          final timeCompare = aDate.compareTo(bDate);
          if (timeCompare != 0) return timeCompare;
          return a.key.compareTo(b.key);
        });

      for (int i = 0; i < sessionEntries.length; i++) {
        final sessionPoints = List<VideoSessionFlowPoint>.from(sessionEntries[i].value)
          ..sort((a, b) => a.date.compareTo(b.date));

        final startPoint = sessionPoints.first;
        final endPoint = sessionPoints.last;
        final startX = (i * 2).toDouble();
        final endX = startX + 1;

        dayStartXValues.add(startX);
        labels.add(_sessionLabel(context, i + 1));
        labels.add('');

        lineBarsData.add(
          LineChartBarData(
            spots: [
              FlSpot(startX, _indexFor(startPoint).toDouble()),
              FlSpot(endX, _indexFor(endPoint).toDouble()),
            ],
            isCurved: false,
            color: _purple,
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final isStart = index == 0;
                return FlDotCirclePainter(
                  radius: isStart ? 4.5 : 5,
                  color: isStart ? Colors.white : _purpleDark,
                  strokeWidth: 2,
                  strokeColor: _purple,
                );
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }

      visualPointCount = sessionEntries.length * 2;
    }

    final maxX = math.max(0, visualPointCount - 1).toDouble();
    final maxY = (_axisItems.length - 1).toDouble();

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: maxX,
        minY: -0.35,
        maxY: maxY + 0.15,
        clipData: FlClipData.none(),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          verticalInterval: 1,
          horizontalInterval: 1,
          checkToShowVerticalLine: (value) {
            return dayStartXValues.any((x) => (x - value).abs() < 0.2);
          },
          getDrawingVerticalLine: (value) => FlLine(
            color: const Color(0xFFD9CFFF),
            strokeWidth: 1.2,
            dashArray: const [4, 4],
          ),
          getDrawingHorizontalLine: (value) => FlLine(
            color: const Color(0xFFE8E0F5),
            strokeWidth: 1,
            dashArray: const [4, 4],
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 52,
              getTitlesWidget: (value, meta) {
                final roundedValue = value.roundToDouble();

                if ((value - roundedValue).abs() > 0.001) {
                  return const SizedBox.shrink();
                }

                final index = roundedValue.toInt();
                if (index < 0 || index >= _axisItems.length) {
                  return const SizedBox.shrink();
                }

                return Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _axisItems[index].label(context),
                      textAlign: TextAlign.right,
                      maxLines: 1,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8D84A6),
                        height: 1.0,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              reservedSize: 44,
              showTitles: true,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.toInt();
                if (index < 0 || index >= labels.length) {
                  return const SizedBox.shrink();
                }

                final label = labels[index];
                if (label.isEmpty) {
                  return const SizedBox.shrink();
                }

                return Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF8D84A6),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          enabled: false,
          handleBuiltInTouches: false,
        ),
        lineBarsData: lineBarsData,
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _indexFor(VideoSessionFlowPoint point) {
    final key = widget.type == _VideoFlowCardType.emotion ? point.emotionKey : point.toneKey;
    final index = _axisItems.indexWhere((item) => item.key == key);
    return index >= 0 ? index : _axisItems.indexWhere((item) => item.key == 'neutral').clamp(0, _axisItems.length - 1);
  }

  Map<String, List<VideoSessionFlowPoint>> _groupByCharacter(List<VideoSessionFlowPoint> points) {
    final Map<String, List<VideoSessionFlowPoint>> grouped = {};
    for (final point in points) {
      final key = point.characterName.trim().toLowerCase();
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(point);
    }
    return {for (final entry in grouped.entries) entry.key: entry.value};
  }

  _FlowPeriodData _buildWeekData(List<VideoSessionFlowPoint> points) {
    final now = DateTime.now();
    final startOfThisWeek = _startOfWeek(now);
    final start = startOfThisWeek.subtract(Duration(days: 7 * _pageOffset));
    final end = start.add(const Duration(days: 6));

    final inWeek = points.where((point) {
      final d = DateTime(point.date.year, point.date.month, point.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()..sort((a, b) => a.date.compareTo(b.date));

    final Map<String, VideoSessionFlowPoint> latestPerSession = {};
    for (final point in inWeek) {
      latestPerSession[point.sessionId] = point;
    }
    final periodPoints = latestPerSession.values.toList()..sort((a, b) => a.date.compareTo(b.date));

    final oldest = points.isEmpty ? null : points.first.date;
    final canGoBack = oldest != null && _startOfWeek(oldest).isBefore(start);

    return _FlowPeriodData(
      title: _formatDateRange(context, start, end),
      subtitle: _localizedNumber(context, start.year),
      points: periodPoints,
      canGoBack: canGoBack,
      sessionCount: latestPerSession.length,
    );
  }

  _FlowPeriodData _buildDayData(List<VideoSessionFlowPoint> points) {
    final Map<DateTime, List<VideoSessionFlowPoint>> dayGroups = {};
    final Map<DateTime, Set<String>> sessionIdsByDay = {};

    for (final point in points) {
      final dayKey = DateTime(point.date.year, point.date.month, point.date.day);
      dayGroups.putIfAbsent(dayKey, () => []);
      dayGroups[dayKey]!.add(point);

      sessionIdsByDay.putIfAbsent(dayKey, () => <String>{});
      sessionIdsByDay[dayKey]!.add(point.sessionId);
    }

    final days = dayGroups.keys.toList()
      ..sort((a, b) => b.compareTo(a));

    if (days.isEmpty) {
      final now = DateTime.now();
      return _FlowPeriodData(
        title: _formatMonthDay(context, now),
        subtitle: _localizedNumber(context, now.year),
        points: const [],
        canGoBack: false,
        sessionCount: 0,
      );
    }

    final safeOffset = _pageOffset.clamp(0, days.length - 1);
    final selectedDay = days[safeOffset];
    final selectedDayPoints = List<VideoSessionFlowPoint>.from(dayGroups[selectedDay] ?? const [])
      ..sort((a, b) {
        final timeCompare = a.date.compareTo(b.date);
        if (timeCompare != 0) return timeCompare;
        final sessionCompare = a.sessionId.compareTo(b.sessionId);
        if (sessionCompare != 0) return sessionCompare;
        return a.characterName.compareTo(b.characterName);
      });

    final sessionCount = sessionIdsByDay[selectedDay]?.length ?? 0;

    return _FlowPeriodData(
      title: _formatMonthDay(context, selectedDay),
      subtitle: tr(
        context,
        'Session start and end in this day',
        'بداية ونهاية كل جلسة في هذا اليوم',
      ),
      points: selectedDayPoints,
      canGoBack: safeOffset < days.length - 1,
      sessionCount: sessionCount,
    );
  }

  static DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return normalized.subtract(Duration(days: normalized.weekday - 1));
  }

  static String _formatDateRange(BuildContext context, DateTime start, DateTime end) {
    return '${_formatMonthDay(context, start)} - ${_formatMonthDay(context, end)}';
  }

  static String _formatMonthDay(BuildContext context, DateTime date) {
    final month = _monthName(context, date.month);
    final day = _localizedNumber(context, date.day);
    return isArabic(context) ? '$day $month' : '$month $day';
  }

  static String _sessionLabel(BuildContext context, int number) {
    return '${tr(context, 'S', 'ج')}${_localizedNumber(context, number)}';
  }


  static String _formatTimeLabel(BuildContext context, DateTime date) {
    final hour24 = date.hour;
    final minuteText = date.minute.toString().padLeft(2, '0');
    if (isArabic(context)) {
      final period = hour24 >= 12 ? 'م' : 'ص';
      final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
      return '${_localizedNumber(context, hour12)}:${_localizedNumber(context, date.minute)} $period';
    }
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '$hour12:$minuteText $period';
  }

  static String _monthName(BuildContext context, int month) {
    const en = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const ar = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
    return isArabic(context) ? ar[month - 1] : en[month - 1];
  }

  static String _localizedNumber(BuildContext context, int value) {
    final text = value.toString();
    if (!isArabic(context)) return text;
    const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
    var result = text;
    for (int i = 0; i < western.length; i++) {
      result = result.replaceAll(western[i], arabic[i]);
    }
    return result;
  }
}

class _FlowAxisItem {
  final String key;
  final String en;
  final String ar;

  const _FlowAxisItem(this.key, this.en, this.ar);

  String label(BuildContext context) => isArabic(context) ? ar : en;
}

class _FlowPeriodData {
  final String title;
  final String subtitle;
  final List<VideoSessionFlowPoint> points;
  final bool canGoBack;
  final int sessionCount;

  const _FlowPeriodData({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.canGoBack,
    required this.sessionCount,
  });
}