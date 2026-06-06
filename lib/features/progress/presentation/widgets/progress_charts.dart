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
      title: tr(context, 'Session Intensity', 'شدة الجلسات'),
      subtitle: tr(
        context,
        'Track how each session starts and ends over time',
        'تابع شدة كل جلسة من أولها لآخرها مع الوقت',
      ),
      action: _buildIntensityHelpButton(context),
      child: _buildIntensityOverviewCard(context),
    );
  }

  Widget _buildIntensityHelpButton(BuildContext context) {
    final isAr = isArabic(context);
    final tooltipMessage = tr(
      context,
      'What does this chart show?',
      'الشارت ده بيعرض إيه؟',
    );
    final title = tr(context, 'Session Intensity', 'شدة الجلسات');
    final paragraphs = [
      tr(
        context,
        'This chart shows only active characters. Stable or inactive characters stay hidden here, even if they still have old intensity data.',
        'الشارت ده بيعرض الشخصيات النشطة بس. الشخصيات المستقرة أو غير النشطة مش هتظهر هنا حتى لو عندها بيانات شدة قديمة.',
      ),
      tr(
        context,
        'Intensity means how strongly the character is showing up in the session. A higher percentage means the feeling, voice, or behavior is stronger.',
        'الشدة معناها الشخصية ظاهرة قد إيه في الجلسة. كل ما النسبة تعلى، يبقى الإحساس أو الصوت أو التصرف أقوى.',
      ),
      tr(
        context,
        'Chat intensity comes from the written conversation. Voice intensity comes from voice tone and emotional signals. Video intensity combines the session signals with face and voice cues when available.',
        'شدة الدردشة بتيجي من الكلام المكتوب. شدة الصوت بتيجي من نبرة الصوت والإشارات العاطفية. شدة الفيديو بتجمع إشارات الجلسة مع تعبيرات الوش والصوت لما يكونوا متاحين.',
      ),
      tr(
        context,
        'In Day view, tap a start or end dot to see the session type and exact intensity. In Week view, tap a day bar to see the latest sessions.',
        'في عرض اليوم، دوس على نقطة البداية أو النهاية عشان تشوف نوع الجلسة وقيمة الشدة. وفي عرض الأسبوع، دوس على عمود اليوم عشان تشوف آخر الجلسات.',
      ),
    ];

    return _buildChartHelpButton(
      context,
      isAr: isAr,
      tooltipMessage: tooltipMessage,
      title: title,
      icon: Icons.help_outline_rounded,
      paragraphs: paragraphs,
    );
  }

  Widget _buildEmotionHelpButton(BuildContext context) {
    final isAr = isArabic(context);
    final tooltipMessage = tr(
      context,
      'What does this chart show?',
      'الشارت ده بيعرض إيه؟',
    );
    final title = tr(context, 'Video Call Emotions', 'مشاعر مكالمات الفيديو');
    final paragraphs = [
      tr(
        context,
        'This chart shows the emotion detected at the start and end of each video session for active characters only.',
        'الشارت ده بيعرض المشاعر اللي اتعرفت في بداية ونهاية كل جلسة فيديو للشخصيات النشطة بس.',
      ),
      tr(
        context,
        'Each point is an emotion state like happy, sad, angry, fear, surprise, or neutral. The line helps you see how the emotion moved during the session.',
        'كل نقطة بتمثل حالة شعورية زي سعيد، حزين، غاضب، خوف، مفاجأة، أو محايد. والخط بيساعدك تشوف الإحساس اتحرك إزاي خلال الجلسة.',
      ),
      tr(
        context,
        'Tap a point to see the session, stage, character, and exact emotion label.',
        'دوس على أي نقطة عشان تشوف الجلسة، المرحلة، الشخصية، واسم الشعور بالظبط.',
      ),
    ];

    return _buildChartHelpButton(
      context,
      isAr: isAr,
      tooltipMessage: tooltipMessage,
      title: title,
      icon: Icons.help_outline_rounded,
      paragraphs: paragraphs,
    );
  }

  Widget _buildToneHelpButton(BuildContext context) {
    final isAr = isArabic(context);
    final tooltipMessage = tr(
      context,
      'What does this chart show?',
      'الشارت ده بيعرض إيه؟',
    );
    final title = tr(context, 'Call Tone', 'نبرة المكالمات');
    final paragraphs = [
      tr(
        context,
        'This chart shows how the tone changes from the start to the end of voice and video sessions for active characters only.',
        'الشارت ده بيعرض النبرة بتتغير إزاي من بداية لنهاية جلسات الصوت والفيديو للشخصيات النشطة بس.',
      ),
      tr(
        context,
        'Tone describes the sound/emotional quality of the session, such as calm, anxious, angry, sad, happy, or neutral.',
        'النبرة بتوصف جودة الصوت أو الإحساس في الجلسة، زي هادئ، قلق، غاضب، حزين، سعيد، أو محايد.',
      ),
      tr(
        context,
        'Tap a point to see whether it is the start or end of the session and the exact tone label.',
        'دوس على أي نقطة عشان تشوف هل هي بداية ولا نهاية الجلسة واسم النبرة بالظبط.',
      ),
    ];

    return _buildChartHelpButton(
      context,
      isAr: isAr,
      tooltipMessage: tooltipMessage,
      title: title,
      icon: Icons.help_outline_rounded,
      paragraphs: paragraphs,
    );
  }

  Widget _buildChartHelpButton(
      BuildContext context, {
        required bool isAr,
        required String tooltipMessage,
        required String title,
        required IconData icon,
        required List<String> paragraphs,
      }) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(start: 6),
      child: Tooltip(
        message: tooltipMessage,
        child: InkWell(
          onTap: () => _showChartHelpDialog(
            context,
            isAr: isAr,
            title: title,
            icon: icon,
            paragraphs: paragraphs,
          ),
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F5FF),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE7E1FF)),
            ),
            child: Icon(
              icon,
              size: 17,
              color: const Color(0xFF8E7CFF),
            ),
          ),
        ),
      ),
    );
  }

  void _showChartHelpDialog(
      BuildContext context, {
        required bool isAr,
        required String title,
        required IconData icon,
        required List<String> paragraphs,
      }) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      builder: (dialogContext) {
        return Directionality(
          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
          child: Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
            backgroundColor: Colors.transparent,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 340),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFFE9E4FF)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2A1E3B).withValues(alpha: 0.14),
                    blurRadius: 22,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: const BoxDecoration(
                          color: Color(0xFFF2EFFF),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          icon,
                          size: 20,
                          color: const Color(0xFF8E7CFF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          title,
                          textAlign: isAr ? TextAlign.right : TextAlign.left,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () => Navigator.of(dialogContext).pop(),
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 19,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (int i = 0; i < paragraphs.length; i++) ...[
                    if (i > 0) const SizedBox(height: 10),
                    Text(
                      paragraphs[i],
                      textAlign: isAr ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6D6486),
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
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
        'تابع إزاي مشاعر الجلسات بتتنقل من إحساس لإحساس تاني',
      ),
      action: _buildEmotionHelpButton(context),
      child: _buildVideoFlowOverviewCard(
        context,
        type: _VideoFlowCardType.emotion,
      ),
    );
  }

  Widget _buildVideoToneSection(BuildContext context) {
    return _ChartSectionShell(
      title: tr(context, 'Call Tone', 'نبرة المكالمات'),
      subtitle: tr(
        context,
        'Track the tone flow across your sessions',
        'تابع تغيّر النبرة خلال جلساتك',
      ),
      action: _buildToneHelpButton(context),
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

        final rawPoints = snapshot.data ?? [];
        final points = type == _VideoFlowCardType.emotion
            ? rawPoints.where((point) => point.sessionType == 'video').toList()
            : rawPoints
            .where((point) => point.sessionType == 'voice' || point.sessionType == 'video')
            .toList();

        if (points.isEmpty) {
          return _buildEmptyVideoFlowCard(context, type: type);
        }

        if (type == _VideoFlowCardType.emotion) {
          return _VideoFlowHabitLandCard(
            allPoints: points,
            type: type,
          );
        }

        return _ToneFlowHabitLandCard(
          allPoints: points,
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
    final isAr = isArabic(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment:
                isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment:
                    isAr ? MainAxisAlignment.end : MainAxisAlignment.start,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          title,
                          textAlign: isAr ? TextAlign.right : TextAlign.left,
                          textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2D2344),
                          ),
                        ),
                      ),
                      if (action != null) action!,
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    subtitle,
                    textAlign: isAr ? TextAlign.right : TextAlign.left,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8F87B3),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
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
  String? _selectedCharacterId;
  int _pageOffset = 0;
  bool _isWeekView = true;
  final GlobalKey _intensityDayChartKey = GlobalKey();
  OverlayEntry? _intensityDayPopupEntry;

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
  void dispose() {
    _hideIntensityDayPopup();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _IntensityHabitLandCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final characterIds = _groupByCharacter(widget.allSessions).keys.toList();
    final previousSelectedId = _selectedCharacterId;
    _syncSelectedCharacter(characterIds);

    if (previousSelectedId != _selectedCharacterId) {
      _hideIntensityDayPopup();
      _pageOffset = 0;
    }
  }

  void _syncSelectedCharacter(List<String> characterIds) {
    if (characterIds.isEmpty) {
      _selectedCharacterId = null;
      _selectedCharacterIndex = 0;
      return;
    }

    if (_selectedCharacterId == null ||
        !characterIds.contains(_selectedCharacterId)) {
      _selectedCharacterId = characterIds.first;
      _selectedCharacterIndex = 0;
      return;
    }

    _selectedCharacterIndex = characterIds.indexOf(_selectedCharacterId!);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCharacter(widget.allSessions);
    final characterIds = grouped.keys.toList();

    if (characterIds.isEmpty) {
      return const SizedBox.shrink();
    }

    _syncSelectedCharacter(characterIds);

    final selectedId = _selectedCharacterId!;
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
          _hideIntensityDayPopup();
          setState(() {
            _isWeekView = false;
            _pageOffset = 0;
          });
        }),
        tab(tr(context, 'Week', 'الأسبوع'), _isWeekView, () {
          _hideIntensityDayPopup();
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
        reverse: isArabic(context) &&
            Directionality.of(context) != TextDirection.rtl,
        itemCount: characterIds.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final id = characterIds[index];
          final name = grouped[id]!.first.characterName;
          final selected = index == _selectedCharacterIndex;

          return GestureDetector(
            onTap: () {
              _hideIntensityDayPopup();
              setState(() {
                _selectedCharacterIndex = index;
                _selectedCharacterId = id;
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
                    color: const Color(0xFF8E7CFF).withValues(alpha: 0.20),
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
            _hideIntensityDayPopup();
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
            _hideIntensityDayPopup();
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
              const SizedBox(height: 7),
              _buildIntensitySessionLegend(context),
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

  Widget _buildIntensitySessionLegend(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildIntensityLegendItem(
            color: _chatLineColor,
            label: tr(context, 'Chat session', 'جلسة دردشة'),
          ),
          _buildIntensityLegendItem(
            color: _voiceLineColor,
            label: tr(context, 'Voice session', 'جلسة صوتية'),
          ),
          _buildIntensityLegendItem(
            color: _videoLineColor,
            label: tr(context, 'Video session', 'جلسة فيديو'),
          ),
        ],
      ),
    );
  }

  Widget _buildIntensityLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8D84A6),
          ),
        ),
      ],
    );
  }

  Color _sessionTypeColor(String sessionType) {
    if (sessionType == 'chat') {
      return _chatLineColor;
    }

    if (sessionType == 'voice') {
      return _voiceLineColor;
    }

    return _videoLineColor;
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
              color: Color(0xFF4B2D73),
            ),
          ),
        ],
      ),
    );
  }

  _WeeklyIntensityPopupPayload _buildWeeklyIntensityPopupPayload(
      BuildContext context,
      WeeklyDayIntensitySummary summary,
      ) {
    final sortedSessions = List<CharacterSessionIntensity>.from(summary.sessions)
      ..sort((a, b) => a.date.compareTo(b.date));

    final latestSessions = sortedSessions.length <= 3
        ? sortedSessions
        : sortedSessions.sublist(sortedSessions.length - 3);

    final rows = <_WeeklyIntensityPopupRowData>[];
    for (int index = 0; index < latestSessions.length; index++) {
      final originalIndex = sortedSessions.length - latestSessions.length + index + 1;
      final session = latestSessions[index];
      rows.add(
        _WeeklyIntensityPopupRowData(
          session: session,
          title: '${_sessionLabel(context, originalIndex)} • ${_sessionTypeShortLabel(context, session.sessionType)}',
          subtitle:
          '${tr(context, 'Start', 'البداية')} ${_localizedNumber(context, session.startPercent.round())}%  →  ${tr(context, 'End', 'النهاية')} ${_localizedNumber(context, session.endPercent.round())}%',
          averageLabel: '${_localizedNumber(context, session.averagePercent.round())}%',
        ),
      );
    }

    return _WeeklyIntensityPopupPayload(
      title: _formatMonthDay(context, summary.date),
      subtitle:
      '${tr(context, 'Latest 3 sessions', 'آخر ٣ جلسات')} • ${tr(context, 'Avg', 'المتوسط')} ${_localizedNumber(context, summary.averagePercent.round())}%',
      rows: rows,
    );
  }

  void _showWeeklyIntensitySessionsPopup(
      BuildContext context,
      _WeeklyIntensityPopupPayload payload,
      ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.20),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 34, vertical: 24),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 340),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE9E4FF)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2A1E3B).withValues(alpha: 0.14),
                  blurRadius: 22,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            payload.title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            payload.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(dialogContext).pop(),
                      borderRadius: BorderRadius.circular(999),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 19,
                          color: Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: payload.rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    return _buildWeeklyIntensitySessionPopupRow(payload.rows[index]);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyIntensitySessionPopupRow(
      _WeeklyIntensityPopupRowData row,
      ) {
    final color = _sessionTypeColor(row.session.sessionType);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFAFF),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFEDE8FF)),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  row.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  row.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              row.averageLabel,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _sessionTypeShortLabel(BuildContext context, String sessionType) {
    if (sessionType == 'chat') return tr(context, 'Chat', 'دردشة');
    if (sessionType == 'voice') return tr(context, 'Voice', 'صوت');
    return tr(context, 'Video', 'فيديو');
  }

  String _sessionTypeLabel(BuildContext context, String sessionType) {
    if (sessionType == 'chat') return tr(context, 'Chat session', 'جلسة دردشة');
    if (sessionType == 'voice') return tr(context, 'Voice session', 'جلسة صوتية');
    return tr(context, 'Video session', 'جلسة فيديو');
  }

  Widget _buildWeeklyCompletionBarChart(
      BuildContext context,
      _CharacterPeriodData periodData,
      ) {
    final popupPayloadsByDay = <int, _WeeklyIntensityPopupPayload>{};
    periodData.dayItems.forEach((dayIndex, summary) {
      if (summary.sessions.isNotEmpty) {
        popupPayloadsByDay[dayIndex] = _buildWeeklyIntensityPopupPayload(
          context,
          summary,
        );
      }
    });

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        minY: 0,
        groupsSpace: 12,
        borderData: FlBorderData(show: false),
        barTouchData: BarTouchData(
          enabled: true,
          handleBuiltInTouches: false,
          touchCallback: (event, response) {
            if (event is! FlTapUpEvent) return;

            final groupIndex = response?.spot?.touchedBarGroupIndex;
            if (groupIndex == null || groupIndex < 0 || groupIndex > 6) return;

            final payload = popupPayloadsByDay[groupIndex];
            if (payload == null) return;

            _showWeeklyIntensitySessionsPopup(context, payload);
          },
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

          Color barColor;
          if (hasData && item != null && item.sessions.isNotEmpty) {
            final latestSession = List<CharacterSessionIntensity>.from(item.sessions)
              ..sort((a, b) => a.date.compareTo(b.date));
            barColor = _sessionTypeColor(latestSession.last.sessionType);
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

    final startPointLabel = tr(context, 'Start', 'البداية');
    final endPointLabel = tr(context, 'End', 'النهاية');
    final intensityMetricLabel = tr(context, 'Intensity', 'الشدة');
    final sessionLabels = List.generate(
      sessions.length,
          (index) => _sessionLabel(context, index + 1),
    );
    final sessionTypeLabels = List.generate(
      sessions.length,
          (index) => _sessionTypeShortLabel(context, sessions[index].sessionType),
    );
    final sessionDateLabels = List.generate(
      sessions.length,
          (index) => _formatMonthDay(context, sessions[index].date),
    );
    final startIntensityLabels = List.generate(
      sessions.length,
          (index) => _localizedNumber(context, sessions[index].startPercent.round()),
    );
    final endIntensityLabels = List.generate(
      sessions.length,
          (index) => _localizedNumber(context, sessions[index].endPercent.round()),
    );
    final tooltipTextBySpot = <String, String>{};

    const leftReservedSize = 42.0;
    const bottomReservedSize = 40.0;
    const edgePointPadding = 0.65;
    final maxX = (sessions.length * 2 - 1).toDouble();
    final chartMinX = -edgePointPadding;
    final chartMaxX = maxX + edgePointPadding;
    final needsHorizontalScroll = sessions.length > 6;

    LineChart buildChart({
      required double width,
      required bool showLeftTitles,
    }) {
      return LineChart(
        LineChartData(
          minY: 0,
          maxY: 100,
          minX: chartMinX,
          maxX: chartMaxX,
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
                reservedSize: showLeftTitles ? leftReservedSize : 0,
                showTitles: showLeftTitles,
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
                reservedSize: bottomReservedSize,
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  // Only draw labels on exact session-start x positions.
                  // This prevents duplicated labels like S1 caused by the
                  // fractional minX padding used to give edge points space.
                  final roundedValue = value.roundToDouble();
                  if ((value - roundedValue).abs() > 0.001) {
                    return const SizedBox.shrink();
                  }

                  final index = roundedValue.toInt();
                  if (index.isOdd) return const SizedBox.shrink();
                  final sessionIndex = index ~/ 2;
                  if (sessionIndex < 0 || sessionIndex >= sessions.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SizedBox(
                      width: 44,
                      child: Center(
                        child: Text(
                          sessionLabels[sessionIndex],
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF9B93AF),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchSpotThreshold: 24,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;

              final touchedSpots = response?.lineBarSpots;
              if (touchedSpots == null || touchedSpots.isEmpty) {
                _hideIntensityDayPopup();
                return;
              }

              final spot = touchedSpots.first;
              final key = '${spot.barIndex}_${spot.spotIndex}';
              final text = tooltipTextBySpot[key];
              if (text == null || text.trim().isEmpty) {
                _hideIntensityDayPopup();
                return;
              }

              final chartHeight = (_intensityDayChartKey.currentContext?.findRenderObject() as RenderBox?)
                  ?.size
                  .height ??
                  240.0;

              // Match the emotion/tone popups by anchoring the popup to the
              // actual chart point center, not to the user's finger position.
              final popupAnchor = _intensityDaySpotLocalPosition(
                spot,
                Size(width, chartHeight),
                minX: chartMinX,
                maxX: chartMaxX,
                minY: 0,
                maxY: 100,
                leftReservedSize: showLeftTitles ? leftReservedSize : 0,
                bottomReservedSize: bottomReservedSize,
              );

              _showIntensityDayPointPopup(context, text, popupAnchor);
            },
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                final pointColor = barData.color ?? _videoLineColor;
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: pointColor.withValues(alpha: 0.25),
                    strokeWidth: 1.5,
                    dashArray: const [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 2.6,
                        strokeColor: pointColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (_) => const [],
            ),
          ),
          lineBarsData: List.generate(sessions.length, (i) {
            final s = sessions[i];
            final x0 = (i * 2).toDouble();
            final x1 = x0 + 1;

            tooltipTextBySpot['${i}_0'] =
            '${sessionLabels[i]} • ${sessionTypeLabels[i]}\n'
                '${sessionDateLabels[i]} • $startPointLabel $intensityMetricLabel: ${startIntensityLabels[i]}%';
            tooltipTextBySpot['${i}_1'] =
            '${sessionLabels[i]} • ${sessionTypeLabels[i]}\n'
                '${sessionDateLabels[i]} • $endPointLabel $intensityMetricLabel: ${endIntensityLabels[i]}%';

            Color lineColor;
            Color startDotFill;
            Color startDotStroke;
            Color endDotFill;

            if (s.sessionType == 'chat') {
              lineColor = _chatLineColor;
              startDotFill = _chatStartDotFill;
              startDotStroke = _chatStartDotStroke;
              endDotFill = _chatEndDotFill;
            } else if (s.sessionType == 'voice') {
              lineColor = _voiceLineColor;
              startDotFill = _voiceStartDotFill;
              startDotStroke = _voiceStartDotStroke;
              endDotFill = _voiceEndDotFill;
            } else {
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
                    lineColor.withValues(alpha: 0.20),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!needsHorizontalScroll) {
          return SizedBox(
            key: _intensityDayChartKey,
            child: buildChart(
              width: constraints.maxWidth,
              showLeftTitles: true,
            ),
          );
        }

        final availableChartWidth = math.max(
          1.0,
          constraints.maxWidth - leftReservedSize,
        );
        final scrollChartWidth = math.max(
          availableChartWidth,
          sessions.length * 72.0 + 44.0,
        );

        return Row(
          children: [
            _buildFixedIntensityPercentAxis(),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  key: _intensityDayChartKey,
                  width: scrollChartWidth,
                  child: buildChart(
                    width: scrollChartWidth,
                    showLeftTitles: false,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFixedIntensityPercentAxis() {
    const bottomReservedSize = 40.0;
    const labels = [100, 75, 50, 25];

    return SizedBox(
      width: 42,
      height: 240,
      child: Padding(
        padding: const EdgeInsets.only(bottom: bottomReservedSize),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: labels.map((value) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(
                '$value%',
                textAlign: TextAlign.right,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Offset _intensityDaySpotLocalPosition(
      LineBarSpot spot,
      Size chartSize, {
        required double minX,
        required double maxX,
        required double minY,
        required double maxY,
        required double leftReservedSize,
        required double bottomReservedSize,
      }) {
    final plotLeft = leftReservedSize;
    final plotRight = chartSize.width;
    final plotTop = 0.0;
    final plotBottom = chartSize.height - bottomReservedSize;

    final plotWidth = math.max(1.0, plotRight - plotLeft);
    final plotHeight = math.max(1.0, plotBottom - plotTop);
    final xRange = math.max(0.0001, maxX - minX);
    final yRange = math.max(0.0001, maxY - minY);

    final dx = plotLeft + ((spot.x - minX) / xRange).clamp(0.0, 1.0) * plotWidth;
    final dy = plotBottom - ((spot.y - minY) / yRange).clamp(0.0, 1.0) * plotHeight;

    return Offset(dx, dy);
  }

  void _hideIntensityDayPopup() {
    _intensityDayPopupEntry?.remove();
    _intensityDayPopupEntry = null;
  }

  void _showIntensityDayPointPopup(
      BuildContext context,
      String text,
      Offset localPosition,
      ) {
    _hideIntensityDayPopup();

    final overlay = Overlay.of(context);
    final chartBox = _intensityDayChartKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;

    if (chartBox == null || overlayBox == null) return;

    final globalPoint = chartBox.localToGlobal(localPosition);
    final overlayPoint = overlayBox.globalToLocal(globalPoint);

    const popupWidth = 158.0;
    const horizontalPadding = 8.0;
    const verticalGap = 10.0;
    const arrowSize = 10.0;

    final estimatedHeight = text.contains('\n') ? 50.0 : 40.0;
    final left = (overlayPoint.dx - popupWidth / 2).clamp(
      horizontalPadding,
      overlayBox.size.width - popupWidth - horizontalPadding,
    );
    final top = (overlayPoint.dy - estimatedHeight - verticalGap).clamp(
      horizontalPadding,
      overlayBox.size.height - estimatedHeight - horizontalPadding,
    );

    final arrowLeft = (overlayPoint.dx - left - arrowSize / 2).clamp(
      8.0,
      popupWidth - arrowSize - 8.0,
    );

    _intensityDayPopupEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _intensityDayPopupEntry?.remove();
                    _intensityDayPopupEntry = null;
                  },
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: popupWidth,
                  child: _SmallFlowPointPopup(
                    text: text,
                    arrowLeft: arrowLeft,
                    onClose: () {
                      _intensityDayPopupEntry?.remove();
                      _intensityDayPopupEntry = null;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(_intensityDayPopupEntry!);
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

class _WeeklyIntensityPopupPayload {
  final String title;
  final String subtitle;
  final List<_WeeklyIntensityPopupRowData> rows;

  const _WeeklyIntensityPopupPayload({
    required this.title,
    required this.subtitle,
    required this.rows,
  });
}

class _WeeklyIntensityPopupRowData {
  final CharacterSessionIntensity session;
  final String title;
  final String subtitle;
  final String averageLabel;

  const _WeeklyIntensityPopupRowData({
    required this.session,
    required this.title,
    required this.subtitle,
    required this.averageLabel,
  });
}

class _IntensityTooltipTrianglePainter extends CustomPainter {
  final Color color;

  const _IntensityTooltipTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _IntensityTooltipTrianglePainter oldDelegate) {
    return oldDelegate.color != color;
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
  final GlobalKey _flowChartKey = GlobalKey();
  OverlayEntry? _flowPointPopupEntry;
  int _selectedCharacterIndex = 0;
  String? _selectedCharacterId;
  int _pageOffset = 0;
  bool _isWeekView = true;

  static const Color _purple = Color(0xFF8E7CFF);
  static const Color _purpleDark = Color(0xFF6F5BFF);
  static const Color _voiceBlue = Color(0xFF2F80ED);

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
  void dispose() {
    _flowPointPopupEntry?.remove();
    _flowPointPopupEntry = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _VideoFlowHabitLandCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final characterIds = _groupByCharacter(widget.allPoints).keys.toList();
    final previousSelectedId = _selectedCharacterId;
    _syncSelectedCharacter(characterIds);

    if (previousSelectedId != _selectedCharacterId) {
      _flowPointPopupEntry?.remove();
      _flowPointPopupEntry = null;
      _pageOffset = 0;
    }
  }

  void _syncSelectedCharacter(List<String> characterIds) {
    if (characterIds.isEmpty) {
      _selectedCharacterId = null;
      _selectedCharacterIndex = 0;
      return;
    }

    if (_selectedCharacterId == null ||
        !characterIds.contains(_selectedCharacterId)) {
      _selectedCharacterId = characterIds.first;
      _selectedCharacterIndex = 0;
      return;
    }

    _selectedCharacterIndex = characterIds.indexOf(_selectedCharacterId!);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCharacter(widget.allPoints);
    final characterIds = grouped.keys.toList();
    if (characterIds.isEmpty) return const SizedBox.shrink();

    _syncSelectedCharacter(characterIds);

    final selectedId = _selectedCharacterId!;
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatBlock(
                  context,
                  widget.type == _VideoFlowCardType.emotion
                      ? tr(context, 'Latest emotion', 'آخر شعور')
                      : tr(context, 'Latest tone', 'آخر نبرة'),
                  latestLabel,
                  footer: widget.type == _VideoFlowCardType.tone
                      ? _buildToneSessionLegend(context)
                      : null,
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
              child: _buildScrollableFlowChart(context, periodData),
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
        reverse: isArabic(context) &&
            Directionality.of(context) != TextDirection.rtl,
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
                _selectedCharacterId = id;
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

  Widget _buildStatBlock(
      BuildContext context,
      String label,
      String value, {
        bool alignEnd = false,
        Widget? footer,
      }) {
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
        if (footer != null) ...[
          const SizedBox(height: 6),
          footer,
        ],
      ],
    );
  }


  Widget _buildToneSessionLegend(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildToneLegendItem(
            color: _voiceBlue,
            label: tr(context, 'Voice session', 'جلسة صوتية'),
          ),
          _buildToneLegendItem(
            color: _purple,
            label: tr(context, 'Video session', 'جلسة فيديو'),
          ),
        ],
      ),
    );
  }


  Widget _buildToneLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8D84A6),
          ),
        ),
      ],
    );
  }

  Color _sessionColor(VideoSessionFlowPoint point) {
    if (widget.type == _VideoFlowCardType.tone && point.sessionType == 'voice') {
      return _voiceBlue;
    }
    return _purple;
  }

  Widget _buildScrollableFlowChart(BuildContext context, _FlowPeriodData periodData) {
    final sessionIds = <String>{};
    for (final point in periodData.points) {
      sessionIds.add(point.sessionId);
    }

    // Emotion Week: when there are more than 8 sessions, keep the
    // emotions axis fixed and let only the session points/date labels swipe.
    // Week spacing is compact, while Day view keeps its wider spacing.
    final needsScrollableEmotionWeek =
        _isWeekView && widget.type == _VideoFlowCardType.emotion && sessionIds.length > 8;
    final needsScrollableDay = !_isWeekView && sessionIds.length > 6;

    if (!needsScrollableEmotionWeek && !needsScrollableDay) {
      return _buildFlowChart(context, periodData);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const axisWidth = 52.0;
        final availableChartWidth = math.max(
          1.0,
          constraints.maxWidth - axisWidth,
        );
        final pointSpacing = needsScrollableEmotionWeek ? 42.0 : 72.0;
        final extraEdgeSpace = needsScrollableEmotionWeek ? 34.0 : 44.0;
        final chartWidth = math.max(
          availableChartWidth,
          sessionIds.length * pointSpacing + extraEdgeSpace,
        );

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFixedFlowAxis(context),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: SizedBox(
                  width: chartWidth,
                  child: _buildFlowChart(
                    context,
                    periodData,
                    showLeftTitles: false,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  Widget _buildFixedFlowAxis(BuildContext context) {
    return SizedBox(
      width: 52,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 44, right: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _axisItems.reversed.map((item) {
            return Text(
              item.label(context),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8D84A6),
                height: 1.0,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildFlowChart(
      BuildContext context,
      _FlowPeriodData periodData, {
        bool showLeftTitles = true,
      }) {
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
    const double xStartOffset = 0.0;

    final List<LineChartBarData> lineBarsData = [];
    final Map<String, String> tooltipTextBySpot = {};
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
        tooltipTextBySpot['0_$i'] = _flowPointTooltipText(
          context,
          point,
          i + 1,
        );

        final bool isFirstPointForDay =
            i == 0 || !_isSameDay(periodData.points[i - 1].date, point.date);

        if (isFirstPointForDay) {
          dayStartXValues.add(x);
        }

        // Show each date only once per day to avoid duplicated labels
        // when multiple sessions/points happen on the same date.
        labels.add(isFirstPointForDay ? _formatMonthDay(context, point.date) : '');
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
                strokeColor: _sessionColor(periodData.points[index]),
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
        final label = _sessionLabel(context, i + 1);
        labels.add(label);
        labels.add('');

        final barIndex = lineBarsData.length;
        tooltipTextBySpot['${barIndex}_0'] = _flowPointTooltipText(
          context,
          startPoint,
          i + 1,
        );
        tooltipTextBySpot['${barIndex}_1'] = _flowPointTooltipText(
          context,
          endPoint,
          i + 1,
        );

        lineBarsData.add(
          LineChartBarData(
            spots: [
              FlSpot(startX, _indexFor(startPoint).toDouble()),
              FlSpot(endX, _indexFor(endPoint).toDouble()),
            ],
            isCurved: false,
            color: _sessionColor(startPoint),
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                final sessionColor = _sessionColor(startPoint);
                return FlDotCirclePainter(
                  radius: 5,
                  color: sessionColor,
                  strokeWidth: 2,
                  strokeColor: sessionColor,
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
    // Add edge breathing room in Day view too, so the first session
    // start point and the last session end point are not pressed against
    // the chart borders. Bottom labels are still rendered only for exact
    // integer x-values, so this does not create duplicate S1 labels.
    const dayEdgePointPadding = 0.65;
    const weekEdgePointPadding = 0.65;
    final chartMinX = _isWeekView ? -weekEdgePointPadding : -dayEdgePointPadding;
    final chartMaxX = _isWeekView ? maxX + weekEdgePointPadding : maxX + dayEdgePointPadding;
    const chartMinY = -0.35;
    final chartMaxY = maxY + 0.15;

    return KeyedSubtree(
      key: _flowChartKey,
      child: LineChart(
        LineChartData(
          minX: chartMinX,
          maxX: chartMaxX,
          minY: chartMinY,
          maxY: chartMaxY,
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
                showTitles: showLeftTitles,
                interval: 1,
                reservedSize: showLeftTitles ? 52 : 0,
                getTitlesWidget: (value, meta) {
                  if (!showLeftTitles) return const SizedBox.shrink();
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
                  // Avoid duplicated date labels caused by fractional title ticks.
                  final roundedValue = value.roundToDouble();
                  if ((value - roundedValue).abs() > 0.001) {
                    return const SizedBox.shrink();
                  }

                  final index = roundedValue.toInt();
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
            enabled: true,
            handleBuiltInTouches: false,
            touchSpotThreshold: 9,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;

              final spots = response?.lineBarSpots;
              if (spots == null || spots.isEmpty) return;

              final touchedSpot = spots.first;
              final key = '${touchedSpot.barIndex}_${touchedSpot.spotIndex}';
              final text = tooltipTextBySpot[key];
              if (text == null || text.trim().isEmpty) return;

              final tapPosition = event.localPosition;
              if (tapPosition == null) return;

              // Anchor the popup to the real chart point center in both
              // Week and Day views, not to the user's finger position. This keeps
              // the triangle tip exactly on the clicked point.
              final chartBox = _flowChartKey.currentContext?.findRenderObject() as RenderBox?;
              final popupPosition = chartBox != null
                  ? _flowSpotLocalPosition(
                touchedSpot,
                chartBox.size,
                minX: chartMinX,
                maxX: chartMaxX,
                minY: chartMinY,
                maxY: chartMaxY,
                leftReservedSize: showLeftTitles ? 52 : 0,
                bottomReservedSize: 44,
              )
                  : tapPosition;

              _showFlowPointPopup(context, text, popupPosition);
            },
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: _purple.withValues(alpha: 0.20),
                    strokeWidth: 1.4,
                    dashArray: const [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final pointColor = barData.color ?? _purple;
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 2.4,
                        strokeColor: pointColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (_) => const [],
            ),
          ),
          lineBarsData: lineBarsData,
        ),
      ),
    );
  }

  Offset _flowSpotLocalPosition(
      LineBarSpot spot,
      Size chartSize, {
        required double minX,
        required double maxX,
        required double minY,
        required double maxY,
        required double leftReservedSize,
        required double bottomReservedSize,
      }) {
    final plotLeft = leftReservedSize;
    final plotRight = chartSize.width;
    final plotTop = 0.0;
    final plotBottom = chartSize.height - bottomReservedSize;

    final plotWidth = math.max(1.0, plotRight - plotLeft);
    final plotHeight = math.max(1.0, plotBottom - plotTop);
    final xRange = math.max(0.0001, maxX - minX);
    final yRange = math.max(0.0001, maxY - minY);

    final dx = plotLeft + ((spot.x - minX) / xRange).clamp(0.0, 1.0) * plotWidth;
    final dy = plotBottom - ((spot.y - minY) / yRange).clamp(0.0, 1.0) * plotHeight;

    return Offset(dx, dy);
  }

  void _showFlowPointPopup(
      BuildContext context,
      String text,
      Offset localPosition,
      ) {
    _flowPointPopupEntry?.remove();
    _flowPointPopupEntry = null;

    final overlay = Overlay.of(context);
    final chartBox = _flowChartKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;

    if (chartBox == null || overlayBox == null) return;

    final globalPoint = chartBox.localToGlobal(localPosition);
    final overlayPoint = overlayBox.globalToLocal(globalPoint);

    const popupWidth = 158.0;
    const horizontalPadding = 8.0;
    const verticalGap = 10.0;
    const arrowSize = 10.0;

    final estimatedHeight = text.contains('\n') ? 50.0 : 40.0;
    final left = (overlayPoint.dx - popupWidth / 2).clamp(
      horizontalPadding,
      overlayBox.size.width - popupWidth - horizontalPadding,
    );
    final top = (overlayPoint.dy - estimatedHeight - verticalGap).clamp(
      horizontalPadding,
      overlayBox.size.height - estimatedHeight - horizontalPadding,
    );

    // Keep the triangle tip aligned exactly with the tapped chart point,
    // even when the popup is clamped near the screen edges.
    final arrowLeft = (overlayPoint.dx - left - arrowSize / 2).clamp(
      8.0,
      popupWidth - arrowSize - 8.0,
    );

    _flowPointPopupEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _flowPointPopupEntry?.remove();
                    _flowPointPopupEntry = null;
                  },
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: popupWidth,
                  child: _SmallFlowPointPopup(
                    text: text,
                    arrowLeft: arrowLeft,
                    onClose: () {
                      _flowPointPopupEntry?.remove();
                      _flowPointPopupEntry = null;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(_flowPointPopupEntry!);
  }

  String _flowPointTooltipText(
      BuildContext context,
      VideoSessionFlowPoint point,
      int sessionNumber,
      ) {
    final isAr = isArabic(context);
    final sessionType = _flowSessionTypeLabel(context, point.sessionType);
    final valueLabel = widget.type == _VideoFlowCardType.emotion
        ? point.emotionLabel(isAr)
        : point.toneLabel(isAr);
    final metricLabel = widget.type == _VideoFlowCardType.emotion
        ? tr(context, 'Emotion', 'الشعور')
        : tr(context, 'Tone', 'النبرة');
    final stageLabel = point.isSessionStart
        ? tr(context, 'Start', 'البداية')
        : tr(context, 'End', 'النهاية');

    return '${_sessionLabel(context, sessionNumber)} • $sessionType\n${_formatMonthDay(context, point.date)} • $stageLabel $metricLabel: $valueLabel';
  }

  String _flowSessionTypeLabel(BuildContext context, String sessionType) {
    if (sessionType == 'voice') return tr(context, 'Voice session', 'جلسة صوتية');
    if (sessionType == 'video') return tr(context, 'Video session', 'جلسة فيديو');
    return tr(context, 'Chat session', 'جلسة دردشة');
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
      final key = point.characterId.trim().toLowerCase().isNotEmpty
          ? point.characterId.trim().toLowerCase()
          : point.characterName.trim().toLowerCase();
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(point);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final lastA = a.value.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
        final lastB = b.value.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
        return lastB.compareTo(lastA);
      });

    return {for (final entry in entries) entry.key: entry.value};
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


class _SmallFlowPointPopup extends StatelessWidget {
  final String text;
  final double arrowLeft;
  final VoidCallback onClose;

  const _SmallFlowPointPopup({
    required this.text,
    required this.arrowLeft,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 158,
          padding: const EdgeInsets.fromLTRB(9, 7, 7, 7),
          decoration: BoxDecoration(
            color: const Color(0xFF4B2D73),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A1E3B).withValues(alpha: 0.20),
                blurRadius: 12,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8.8,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                  ),
                ),
              ),
              const SizedBox(width: 5),
              InkWell(
                onTap: onClose,
                borderRadius: BorderRadius.circular(999),
                child: Padding(
                  padding: const EdgeInsets.all(1.5),
                  child: Icon(
                    Icons.close_rounded,
                    size: 13,
                    color: Colors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: arrowLeft,
          bottom: -5,
          child: Transform.rotate(
            angle: math.pi / 4,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Color(0xFF4B2D73),
              ),
            ),
          ),
        ),
      ],
    );
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

class _ToneFlowHabitLandCard extends StatefulWidget {
  final List<VideoSessionFlowPoint> allPoints;

  const _ToneFlowHabitLandCard({
    required this.allPoints,
  });

  @override
  State<_ToneFlowHabitLandCard> createState() => _ToneFlowHabitLandCardState();
}

class _ToneFlowHabitLandCardState extends State<_ToneFlowHabitLandCard> {
  final GlobalKey _toneChartKey = GlobalKey();
  OverlayEntry? _tonePointPopupEntry;
  int _selectedCharacterIndex = 0;
  String? _selectedCharacterId;
  int _pageOffset = 0;
  bool _isWeekView = true;

  @override
  void dispose() {
    _tonePointPopupEntry?.remove();
    _tonePointPopupEntry = null;
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ToneFlowHabitLandCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    final characterIds = _groupByCharacter(widget.allPoints).keys.toList();
    final previousSelectedId = _selectedCharacterId;
    _syncSelectedCharacter(characterIds);

    if (previousSelectedId != _selectedCharacterId) {
      _tonePointPopupEntry?.remove();
      _tonePointPopupEntry = null;
      _pageOffset = 0;
    }
  }

  void _syncSelectedCharacter(List<String> characterIds) {
    if (characterIds.isEmpty) {
      _selectedCharacterId = null;
      _selectedCharacterIndex = 0;
      return;
    }

    if (_selectedCharacterId == null ||
        !characterIds.contains(_selectedCharacterId)) {
      _selectedCharacterId = characterIds.first;
      _selectedCharacterIndex = 0;
      return;
    }

    _selectedCharacterIndex = characterIds.indexOf(_selectedCharacterId!);
  }

  static const Color _purple = Color(0xFF8E7CFF);
  static const Color _voiceBlue = Color(0xFF2F80ED);

  static const List<_FlowAxisItem> _toneAxis = [
    _FlowAxisItem('happy', 'Happy', 'سعيد'),
    _FlowAxisItem('neutral', 'Neutral', 'محايد'),
    _FlowAxisItem('surprise', 'Surprise', 'مفاجأة'),
    _FlowAxisItem('fear', 'Fear', 'خوف'),
    _FlowAxisItem('sad', 'Sad', 'حزين'),
    _FlowAxisItem('angry', 'Angry', 'غاضب'),
  ];

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByCharacter(widget.allPoints);
    final characterIds = grouped.keys.toList();
    if (characterIds.isEmpty) return const SizedBox.shrink();

    _syncSelectedCharacter(characterIds);

    final selectedId = _selectedCharacterId!;
    final points = List<VideoSessionFlowPoint>.from(grouped[selectedId] ?? const [])
      ..sort((a, b) => a.date.compareTo(b.date));
    final periodData = _isWeekView ? _buildWeekData(points) : _buildDayData(points);
    final latestLabel = periodData.points.isEmpty
        ? '—'
        : periodData.points.last.toneLabel(isArabic(context));

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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatBlock(
                  context,
                  tr(context, 'Latest tone', 'آخر نبرة'),
                  latestLabel,
                  footer: _buildToneSessionLegend(context),
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
          const SizedBox(height: 10),
          SizedBox(
            height: 250,
            child: Padding(
              padding: const EdgeInsets.only(left: 0, right: 4, top: 2, bottom: 2),
              child: _buildScrollableToneChart(context, periodData),
            ),
          ),
        ],
      ),
    );
  }

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
        reverse: isArabic(context) &&
            Directionality.of(context) != TextDirection.rtl,
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
                _selectedCharacterId = id;
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

  Widget _buildHeader(BuildContext context, _ToneFlowPeriodData periodData) {
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
                  letterSpacing: -0.2,
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

  Widget _buildStatBlock(
      BuildContext context,
      String label,
      String value, {
        bool alignEnd = false,
        Widget? footer,
      }) {
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
        if (footer != null) ...[
          const SizedBox(height: 5),
          footer,
        ],
      ],
    );
  }

  Widget _buildToneSessionLegend(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Wrap(
        spacing: 8,
        runSpacing: 5,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _buildToneLegendItem(
            color: _voiceBlue,
            label: tr(context, 'Voice session', 'جلسة صوتية'),
          ),
          _buildToneLegendItem(
            color: _purple,
            label: tr(context, 'Video session', 'جلسة فيديو'),
          ),
        ],
      ),
    );
  }

  Widget _buildToneLegendItem({
    required Color color,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w700,
            color: Color(0xFF8D84A6),
          ),
        ),
      ],
    );
  }

  Widget _buildScrollableToneChart(BuildContext context, _ToneFlowPeriodData periodData) {
    final daySessionCount = _isWeekView ? 0 : _sessionEntriesForDay(periodData.points).length;

    if (!_isWeekView && daySessionCount <= 6) {
      return _buildToneChart(context, periodData);
    }

    final sessionCount = _isWeekView
        ? periodData.points.length.clamp(1, 20)
        : math.max(1, daySessionCount);
    final availableWidth = math.max(MediaQuery.of(context).size.width - 88, 180.0);
    final chartWidth = _isWeekView
        ? math.max(availableWidth - 48, 78.0 + (sessionCount * 38.0))
        : math.max(availableWidth - 48, sessionCount * 72.0 + 44.0);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildFixedToneAxis(context),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: SizedBox(
              width: chartWidth,
              child: _buildToneChart(
                context,
                periodData,
                showLeftTitles: false,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFixedToneAxis(BuildContext context) {
    return SizedBox(
      width: 48,
      child: Padding(
        padding: EdgeInsets.only(top: 8, bottom: _isWeekView ? 40 : 44, right: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: _toneAxis.reversed.map((item) {
            return Text(
              item.label(context),
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.visible,
              style: const TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8D84A6),
                height: 1.0,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildToneChart(
      BuildContext context,
      _ToneFlowPeriodData periodData, {
        bool showLeftTitles = true,
      }) {
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
    final List<LineChartBarData> lineBarsData = [];
    final Map<String, String> tooltipTextBySpot = {};
    int visualPointCount = 0;

    if (_isWeekView) {
      final sessions = List<VideoSessionFlowPoint>.from(periodData.points)
        ..sort((a, b) {
          final dateCompare = a.date.compareTo(b.date);
          if (dateCompare != 0) return dateCompare;
          return a.sessionId.compareTo(b.sessionId);
        });

      final visibleSessions = sessions.length > 20
          ? sessions.sublist(sessions.length - 20)
          : sessions;

      for (int i = 0; i < visibleSessions.length; i++) {
        final point = visibleSessions[i];
        final sessionColor = _colorForSessionType(point.sessionType);
        final x = i.toDouble();

        final isFirstPointForDay =
            i == 0 || !_isSameDay(visibleSessions[i - 1].date, point.date);

        // Week view uses real day/date labels like the emotion chart,
        // for example Apr 24, instead of S1, S2, etc.
        // If there is more than one session on the same day, only the first
        // one gets the date label to avoid duplicate labels.
        labels.add(isFirstPointForDay ? _formatMonthDay(context, point.date) : '');
        if (isFirstPointForDay) {
          dayStartXValues.add(x);
        }

        final barIndex = lineBarsData.length;
        tooltipTextBySpot['${barIndex}_0'] = _tonePointTooltipText(
          context,
          point,
          i + 1,
        );

        lineBarsData.add(
          LineChartBarData(
            spots: [FlSpot(x, _toneIndexFor(point).toDouble())],
            isCurved: false,
            color: sessionColor,
            barWidth: 0,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return _toneDotPainterForSessionType(point.sessionType, sessionColor);
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }

      visualPointCount = visibleSessions.length;
    } else {
      final sessionEntries = _sessionEntriesForDay(periodData.points);

      for (int i = 0; i < sessionEntries.length; i++) {
        final sessionPoints = List<VideoSessionFlowPoint>.from(sessionEntries[i].value)
          ..sort((a, b) => a.date.compareTo(b.date));

        final startPoint = _startPointForSession(sessionPoints);
        final endPoint = _endPointForSession(sessionPoints);
        final startX = (i * 2).toDouble();
        final endX = startX + 1;
        final sessionColor = _colorForSessionType(startPoint.sessionType);

        dayStartXValues.add(startX);
        labels.add(_sessionLabel(context, i + 1));
        labels.add('');

        final barIndex = lineBarsData.length;
        tooltipTextBySpot['${barIndex}_0'] = _tonePointTooltipText(
          context,
          startPoint,
          i + 1,
        );
        tooltipTextBySpot['${barIndex}_1'] = _tonePointTooltipText(
          context,
          endPoint,
          i + 1,
        );

        lineBarsData.add(
          LineChartBarData(
            spots: [
              FlSpot(startX, _toneIndexFor(startPoint).toDouble()),
              FlSpot(endX, _toneIndexFor(endPoint).toDouble()),
            ],
            isCurved: false,
            color: sessionColor,
            barWidth: 2.6,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) {
                return _toneDotPainterForSessionType(startPoint.sessionType, sessionColor);
              },
            ),
            belowBarData: BarAreaData(show: false),
          ),
        );
      }

      visualPointCount = sessionEntries.length * 2;
    }

    final maxX = math.max(0, visualPointCount - 1).toDouble();
    final maxY = (_toneAxis.length - 1).toDouble();

    // Add the same edge spacing used by the intensity day chart in Day view.
    // Since bottom labels are drawn only on exact integer ticks, this extra
    // fractional padding does not duplicate S1 or the last session label.
    const dayEdgePointPadding = 0.65;
    final chartMinX = _isWeekView ? -0.35 : -dayEdgePointPadding;
    final chartMaxX = _isWeekView ? maxX + 0.35 : maxX + dayEdgePointPadding;
    const chartMinY = -0.35;
    final chartMaxY = maxY + 0.15;

    return KeyedSubtree(
      key: _toneChartKey,
      child: LineChart(
        LineChartData(
          minX: chartMinX,
          maxX: chartMaxX,
          minY: chartMinY,
          maxY: chartMaxY,
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
                showTitles: showLeftTitles,
                interval: 1,
                reservedSize: showLeftTitles ? 48 : 0,
                getTitlesWidget: (value, meta) {
                  if (!showLeftTitles) return const SizedBox.shrink();

                  final roundedValue = value.roundToDouble();

                  if ((value - roundedValue).abs() > 0.001) {
                    return const SizedBox.shrink();
                  }

                  final index = roundedValue.toInt();
                  if (index < 0 || index >= _toneAxis.length) {
                    return const SizedBox.shrink();
                  }

                  return Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Text(
                        _toneAxis[index].label(context),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        style: const TextStyle(
                          fontSize: 8,
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
                reservedSize: _isWeekView ? 40 : 44,
                showTitles: true,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (_isWeekView) {
                    final roundedValue = value.roundToDouble();

                    // Hide boundary ticks produced by fl_chart at minX/maxX
                    // (for example -0.35 and maxX + 0.35), so only the
                    // real middle session labels are shown.
                    if ((value - roundedValue).abs() > 0.001) {
                      return const SizedBox.shrink();
                    }

                    final index = roundedValue.toInt();
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
                          fontSize: 8,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8D84A6),
                        ),
                      ),
                    );
                  }

                  // Only draw labels on exact session-start x positions.
                  final roundedValue = value.roundToDouble();
                  if ((value - roundedValue).abs() > 0.001) {
                    return const SizedBox.shrink();
                  }

                  final index = roundedValue.toInt();
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
            enabled: true,
            handleBuiltInTouches: false,
            touchSpotThreshold: 9,
            touchCallback: (event, response) {
              if (event is! FlTapUpEvent) return;

              final spots = response?.lineBarSpots;
              if (spots == null || spots.isEmpty) return;

              final touchedSpot = spots.first;
              final key = '${touchedSpot.barIndex}_${touchedSpot.spotIndex}';
              final text = tooltipTextBySpot[key];
              if (text == null || text.trim().isEmpty) return;

              final tapPosition = event.localPosition;
              if (tapPosition == null) return;

              // In day view, use the actual chart spot coordinates instead of
              // the finger tap location, so the popup triangle points exactly
              // to the selected dot. Week view keeps the existing behavior.
              final popupAnchor = _isWeekView
                  ? tapPosition
                  : _toneSpotToLocalOffset(
                context,
                touchedSpot,
                showLeftTitles: showLeftTitles,
                minX: chartMinX,
                maxX: chartMaxX,
                minY: chartMinY,
                maxY: chartMaxY,
              );

              _showTonePointPopup(context, text, popupAnchor);
            },
            getTouchedSpotIndicator: (barData, spotIndexes) {
              return spotIndexes.map((index) {
                return TouchedSpotIndicatorData(
                  FlLine(
                    color: (barData.color ?? _purple).withValues(alpha: 0.20),
                    strokeWidth: 1.4,
                    dashArray: const [4, 4],
                  ),
                  FlDotData(
                    show: true,
                    getDotPainter: (spot, percent, barData, index) {
                      final pointColor = barData.color ?? _purple;
                      return FlDotCirclePainter(
                        radius: 6,
                        color: Colors.white,
                        strokeWidth: 2.4,
                        strokeColor: pointColor,
                      );
                    },
                  ),
                );
              }).toList();
            },
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (_) => const [],
            ),
          ),
          lineBarsData: lineBarsData,
        ),
      ),
    );
  }

  Offset _toneSpotToLocalOffset(
      BuildContext context,
      LineBarSpot spot, {
        required bool showLeftTitles,
        required double minX,
        required double maxX,
        required double minY,
        required double maxY,
      }) {
    final chartBox = _toneChartKey.currentContext?.findRenderObject() as RenderBox?;
    final chartSize = chartBox?.size;

    if (chartSize == null || chartSize.width <= 0 || chartSize.height <= 0) {
      return Offset.zero;
    }

    final leftReserved = showLeftTitles ? 48.0 : 0.0;
    final bottomReserved = _isWeekView ? 40.0 : 44.0;
    const topReserved = 0.0;
    const rightReserved = 0.0;

    final plotWidth = math.max(
      1.0,
      chartSize.width - leftReserved - rightReserved,
    );
    final plotHeight = math.max(
      1.0,
      chartSize.height - topReserved - bottomReserved,
    );

    final xRange = math.max(0.0001, maxX - minX);
    final yRange = math.max(0.0001, maxY - minY);

    final dx = leftReserved + ((spot.x - minX) / xRange) * plotWidth;
    final dy = topReserved + ((maxY - spot.y) / yRange) * plotHeight;

    return Offset(
      dx.clamp(0.0, chartSize.width),
      dy.clamp(0.0, chartSize.height),
    );
  }

  void _showTonePointPopup(
      BuildContext context,
      String text,
      Offset localPosition,
      ) {
    _tonePointPopupEntry?.remove();
    _tonePointPopupEntry = null;

    final overlay = Overlay.of(context);
    final chartBox = _toneChartKey.currentContext?.findRenderObject() as RenderBox?;
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;

    if (chartBox == null || overlayBox == null) return;

    final globalPoint = chartBox.localToGlobal(localPosition);
    final overlayPoint = overlayBox.globalToLocal(globalPoint);

    const popupWidth = 158.0;
    const horizontalPadding = 8.0;
    const verticalGap = 10.0;
    const arrowSize = 10.0;

    final estimatedHeight = text.contains('\n') ? 50.0 : 40.0;
    final left = (overlayPoint.dx - popupWidth / 2).clamp(
      horizontalPadding,
      overlayBox.size.width - popupWidth - horizontalPadding,
    );
    final top = (overlayPoint.dy - estimatedHeight - verticalGap).clamp(
      horizontalPadding,
      overlayBox.size.height - estimatedHeight - horizontalPadding,
    );

    // Keep the triangle tip aligned exactly with the tapped chart point,
    // even when the popup is clamped near the screen edges.
    final arrowLeft = (overlayPoint.dx - left - arrowSize / 2).clamp(
      8.0,
      popupWidth - arrowSize - 8.0,
    );

    _tonePointPopupEntry = OverlayEntry(
      builder: (overlayContext) {
        return Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: Stack(
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    _tonePointPopupEntry?.remove();
                    _tonePointPopupEntry = null;
                  },
                  child: const SizedBox.expand(),
                ),
                Positioned(
                  left: left,
                  top: top,
                  width: popupWidth,
                  child: _SmallFlowPointPopup(
                    text: text,
                    arrowLeft: arrowLeft,
                    onClose: () {
                      _tonePointPopupEntry?.remove();
                      _tonePointPopupEntry = null;
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    overlay.insert(_tonePointPopupEntry!);
  }

  String _tonePointTooltipText(
      BuildContext context,
      VideoSessionFlowPoint point,
      int sessionNumber,
      ) {
    final sessionType = point.sessionType == 'voice'
        ? tr(context, 'Voice session', 'جلسة صوتية')
        : tr(context, 'Video session', 'جلسة فيديو');
    final stageLabel = point.isSessionStart
        ? tr(context, 'Start', 'البداية')
        : tr(context, 'End', 'النهاية');
    final toneLabel = point.toneLabel(isArabic(context));

    return '${_sessionLabel(context, sessionNumber)} • $sessionType\n${_formatMonthDay(context, point.date)} • $stageLabel ${tr(context, 'Tone', 'النبرة')}: $toneLabel';
  }

  FlDotPainter _toneDotPainterForSessionType(String sessionType, Color color) {
    if (sessionType == 'voice') {
      return FlDotCirclePainter(
        radius: 5.8,
        color: color,
        strokeWidth: 2,
        strokeColor: Colors.white,
      );
    }

    return FlDotSquarePainter(
      size: 10.5,
      color: color,
      strokeWidth: 2,
      strokeColor: Colors.white,
    );
  }

  Color _colorForSessionType(String sessionType) {
    return sessionType == 'voice' ? _voiceBlue : _purple;
  }

  int _toneIndexFor(VideoSessionFlowPoint point) {
    final index = _toneAxis.indexWhere((item) => item.key == point.toneKey);
    final neutralIndex = _toneAxis.indexWhere((item) => item.key == 'neutral');
    return index >= 0 ? index : neutralIndex.clamp(0, _toneAxis.length - 1);
  }

  Map<String, List<VideoSessionFlowPoint>> _groupByCharacter(List<VideoSessionFlowPoint> points) {
    final Map<String, List<VideoSessionFlowPoint>> grouped = {};

    for (final point in points) {
      final key = point.characterId.trim().toLowerCase().isNotEmpty
          ? point.characterId.trim().toLowerCase()
          : point.characterName.trim().toLowerCase();
      grouped.putIfAbsent(key, () => []);
      grouped[key]!.add(point);
    }

    final entries = grouped.entries.toList()
      ..sort((a, b) {
        final lastA = a.value.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
        final lastB = b.value.map((e) => e.date).reduce((x, y) => x.isAfter(y) ? x : y);
        return lastB.compareTo(lastA);
      });

    return {for (final entry in entries) entry.key: entry.value};
  }

  List<MapEntry<String, List<VideoSessionFlowPoint>>> _sessionEntriesForDay(
      List<VideoSessionFlowPoint> points,
      ) {
    final Map<String, List<VideoSessionFlowPoint>> pointsBySession = {};
    for (final point in points) {
      pointsBySession.putIfAbsent(point.sessionId, () => []);
      pointsBySession[point.sessionId]!.add(point);
    }

    return pointsBySession.entries.toList()
      ..sort((a, b) {
        final aDate = _startPointForSession(a.value).date;
        final bDate = _startPointForSession(b.value).date;
        final timeCompare = aDate.compareTo(bDate);
        if (timeCompare != 0) return timeCompare;
        return a.key.compareTo(b.key);
      });
  }

  VideoSessionFlowPoint _startPointForSession(List<VideoSessionFlowPoint> sessionPoints) {
    final sorted = List<VideoSessionFlowPoint>.from(sessionPoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted.firstWhere(
          (point) => point.isSessionStart,
      orElse: () => sorted.first,
    );
  }

  VideoSessionFlowPoint _endPointForSession(List<VideoSessionFlowPoint> sessionPoints) {
    final sorted = List<VideoSessionFlowPoint>.from(sessionPoints)
      ..sort((a, b) => a.date.compareTo(b.date));
    return sorted.firstWhere(
          (point) => !point.isSessionStart,
      orElse: () => sorted.last,
    );
  }

  _ToneFlowPeriodData _buildWeekData(List<VideoSessionFlowPoint> points) {
    final now = DateTime.now();
    final startOfThisWeek = _startOfWeek(now);
    final start = startOfThisWeek.subtract(Duration(days: 7 * _pageOffset));
    final end = start.add(const Duration(days: 6));

    final inWeek = points.where((point) {
      final d = DateTime(point.date.year, point.date.month, point.date.day);
      return !d.isBefore(start) && !d.isAfter(end);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final Map<String, List<VideoSessionFlowPoint>> bySession = {};
    for (final point in inWeek) {
      bySession.putIfAbsent(point.sessionId, () => []);
      bySession[point.sessionId]!.add(point);
    }

    final latestSessionPoints = bySession.entries.map((entry) {
      final sorted = List<VideoSessionFlowPoint>.from(entry.value)
        ..sort((a, b) => a.date.compareTo(b.date));
      return sorted.firstWhere(
            (point) => !point.isSessionStart,
        orElse: () => sorted.last,
      );
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final limitedPoints = latestSessionPoints.length > 20
        ? latestSessionPoints.sublist(latestSessionPoints.length - 20)
        : latestSessionPoints;
    final oldest = points.isEmpty ? null : points.first.date;
    final canGoBack = oldest != null && _startOfWeek(oldest).isBefore(start);

    return _ToneFlowPeriodData(
      title: _formatDateRange(context, start, end),
      subtitle: _localizedNumber(context, start.year),
      points: limitedPoints,
      canGoBack: canGoBack,
      sessionCount: latestSessionPoints.length,
    );
  }

  _ToneFlowPeriodData _buildDayData(List<VideoSessionFlowPoint> points) {
    final Map<DateTime, List<VideoSessionFlowPoint>> dayGroups = {};
    for (final point in points) {
      final dayKey = DateTime(point.date.year, point.date.month, point.date.day);
      dayGroups.putIfAbsent(dayKey, () => []);
      dayGroups[dayKey]!.add(point);
    }

    final days = dayGroups.keys.toList()..sort((a, b) => b.compareTo(a));
    if (days.isEmpty) {
      final now = DateTime.now();
      return _ToneFlowPeriodData(
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
      ..sort((a, b) => a.date.compareTo(b.date));
    final sessionCount = _sessionEntriesForDay(selectedDayPoints).length;

    return _ToneFlowPeriodData(
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

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
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

class _ToneFlowPeriodData {
  final String title;
  final String subtitle;
  final List<VideoSessionFlowPoint> points;
  final bool canGoBack;
  final int sessionCount;

  const _ToneFlowPeriodData({
    required this.title,
    required this.subtitle,
    required this.points,
    required this.canGoBack,
    required this.sessionCount,
  });
}
