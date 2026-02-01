import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import 'package:ana_ifs_app/features/progress/domain/entities/daily_activity.dart';

import '../../domain/entities/milestone.dart';

class ProgressScreen extends StatefulWidget {
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
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MilestoneProvider(),
      child: _ProgressScreenContent(
        name: widget.name,
        onLogout: widget.onLogout,
        onRetakeQuestionnaire: widget.onRetakeQuestionnaire,
        onSwitchLanguage: widget.onSwitchLanguage,
      ),
    );
  }
}

class _ProgressScreenContent extends StatefulWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const _ProgressScreenContent({
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  State<_ProgressScreenContent> createState() => __ProgressScreenContentState();
}

class __ProgressScreenContentState extends State<_ProgressScreenContent> {
  bool _showAllStreakAchievements = false;
  bool _showAchievementHistory = false;
  bool _showAllCharacterDiscovery = false;
  bool _showAllHealingProgress = false;

  @override
  void initState() {
    super.initState();
    // Initialize provider when screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final provider = Provider.of<MilestoneProvider>(context, listen: false);
        if (!provider.isInitialized) {
          await provider.initialize();
        }
      } catch (e) {
        print('Error initializing provider: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        // Show loading state
        if (milestoneProvider.isLoading && milestoneProvider.milestones.isEmpty) {
          return _buildLoadingState();
        }

        final stats = milestoneProvider.getStreakStats();
        final activeAchievements = milestoneProvider.getActiveAchievements();
        final completedAchievements = milestoneProvider.getCompletedAchievements();
        final allHealingMilestones = milestoneProvider.getHealingMilestones();
        final dailyMilestones = milestoneProvider.getDailyMilestones();
        final allCharacterDiscoveryMilestones = milestoneProvider.getCharacterDiscoveryMilestones();

        // Get limited or all sections based on state
        final healingMilestones = _showAllHealingProgress
            ? allHealingMilestones
            : (allHealingMilestones.length > 2
            ? allHealingMilestones.sublist(0, 2)
            : allHealingMilestones);

        final characterDiscoveryMilestones = _showAllCharacterDiscovery
            ? allCharacterDiscoveryMilestones
            : (allCharacterDiscoveryMilestones.length > 2
            ? allCharacterDiscoveryMilestones.sublist(0, 2)
            : allCharacterDiscoveryMilestones);

        // Get limited or all streak achievements based on state
        final streakAchievements = _showAllStreakAchievements
            ? milestoneProvider.getAllStreakAchievements()
            : milestoneProvider.getLimitedStreakAchievements();

        return _buildContent(
            stats,
            activeAchievements,
            completedAchievements,
            healingMilestones,
            allHealingMilestones,
            dailyMilestones,
            characterDiscoveryMilestones,
            allCharacterDiscoveryMilestones,
            streakAchievements,
            milestoneProvider
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        TopHelloBar(
          name: widget.name,
          onLogout: widget.onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SettingsBottomSheet(
                onRetakeQuestionnaire: widget.onRetakeQuestionnaire,
                onSwitchLanguage: widget.onSwitchLanguage,
              ),
            );
          },
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Color(0xFF8E7CFF)),
                SizedBox(height: 20),
                Text(
                  'Loading your progress...',
                  style: TextStyle(color: Color(0xFF4B3A66)),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent(
      Map<String, dynamic> stats,
      List<Milestone> activeAchievements,
      List<Milestone> completedAchievements,
      List<Milestone> healingMilestones,
      List<Milestone> allHealingMilestones,
      List<Milestone> dailyMilestones,
      List<Milestone> characterDiscoveryMilestones,
      List<Milestone> allCharacterDiscoveryMilestones,
      List<Milestone> streakAchievements,
      MilestoneProvider milestoneProvider,
      ) {
    return Column(
      children: [
        TopHelloBar(
          name: widget.name,
          onLogout: widget.onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SettingsBottomSheet(
                onRetakeQuestionnaire: widget.onRetakeQuestionnaire,
                onSwitchLanguage: widget.onSwitchLanguage,
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
              20 + MediaQuery.of(context).padding.bottom + 80, // Extra padding for bottom navbar
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // Progress overview with streak
                _buildProgressOverview(stats, context),
                const SizedBox(height: 30),

                // Daily streak section
                if (dailyMilestones.isNotEmpty)
                  _buildDailyStreakSection(dailyMilestones.first, context),

                const SizedBox(height: 30),

                // Today's Wellness Activities
                _buildTodaysActivities(context, milestoneProvider),

                const SizedBox(height: 30),

                // Character Discovery Achievements
                if (allCharacterDiscoveryMilestones.isNotEmpty)
                  _buildCharacterDiscoverySection(
                    characterDiscoveryMilestones,
                    allCharacterDiscoveryMilestones,
                    context,
                  ),

                const SizedBox(height: 30),

                // Streak Achievements
                if (streakAchievements.isNotEmpty)
                  _buildStreakAchievementsSection(streakAchievements, milestoneProvider),

                const SizedBox(height: 30),

                // Healing Progress
                if (allHealingMilestones.isNotEmpty)
                  _buildHealingSection(
                    healingMilestones,
                    allHealingMilestones,
                    context,
                  ),

                const SizedBox(height: 10),

                // Active Achievements
                if (activeAchievements.isNotEmpty)
                  _buildActiveAchievementsSection(activeAchievements, context),

                // Separation line before Achievement History
                Container(
                  height: 1,
                  color: Color(0xFFE5DEFF),
                  margin: EdgeInsets.symmetric(vertical: 10),
                ),

                const SizedBox(height: 10),

                // Achievement History (Completed Achievements)
                if (completedAchievements.isNotEmpty)
                  _buildAchievementHistorySection(completedAchievements, context),

                const SizedBox(height: 40), // Extra spacing at the bottom
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterDiscoverySection(
      List<Milestone> milestones,
      List<Milestone> allMilestones,
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Character Discovery', 'اكتشاف الشخصيات'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'Discover your inner characters', 'اكتشف شخصياتك الداخلية'),
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF7A6A5A).withOpacity(0.8),
                  ),
                ),
              ],
            ),
            // Show "See More" button only if there are more than 2 milestones
            if (allMilestones.length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllCharacterDiscovery = !_showAllCharacterDiscovery;
                  });
                },
                child: Text(
                  _showAllCharacterDiscovery
                      ? tr(context, 'See Less', 'عرض أقل')
                      : tr(context, 'See More', 'عرض المزيد'),
                  style: TextStyle(
                    color: Color(0xFF8E7CFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 15),

        ...milestones.map((achievement) => _AchievementCard(
          milestone: achievement,
        )).toList(),
      ],
    );
  }

  Widget _buildHealingSection(
      List<Milestone> milestones,
      List<Milestone> allMilestones,
      BuildContext context,
      ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Healing Progress', 'تقدم الشفاء'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'Track your healing journey milestones', 'تتبع معالم رحلة الشفاء الخاصة بك'),
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF7A6A5A).withOpacity(0.8),
                  ),
                ),
              ],
            ),
            // Show "See More" button only if there are more than 2 milestones
            if (allMilestones.length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllHealingProgress = !_showAllHealingProgress;
                  });
                },
                child: Text(
                  _showAllHealingProgress
                      ? tr(context, 'See Less', 'عرض أقل')
                      : tr(context, 'See More', 'عرض المزيد'),
                  style: TextStyle(
                    color: Color(0xFF8E7CFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 15),

        ...milestones.map((achievement) => _AchievementCard(
          milestone: achievement,
        )).toList(),
      ],
    );
  }

  Widget _buildProgressOverview(Map<String, dynamic> stats, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        const SizedBox(height: 20),

        // Progress stats cards
        Row(
          children: [
            Expanded(
              child: _StatCard(
                title: tr(context, 'Current Streak', 'السلسلة الحالية'),
                value: '${stats['currentStreak']}',
                unit: tr(context, 'days', 'يوم'),
                icon: Icons.local_fire_department_rounded,
                color: Color(0xFFFF6B6B),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: tr(context, 'Achievements', 'الإنجازات'),
                value: '${stats['totalAchieved']}',
                unit: '/${stats['totalMilestones']}',
                icon: Icons.emoji_events_rounded,
                color: Color(0xFF8E7CFF),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDailyStreakSection(Milestone milestone, BuildContext context) {
    final progress = milestone.currentCount / milestone.targetCount;

    return Container(
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
                Icons.local_fire_department_rounded,
                color: Color(0xFFFF6B6B),
                size: 24,
              ),
              const SizedBox(width: 10),
              Text(
                tr(context, 'Daily Streak', 'السلسلة اليومية'),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
              const Spacer(),
              Text(
                '${milestone.streakDays} ${tr(context, 'days', 'يوم')}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFFF6B6B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Progress bar for 7-day milestone
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  Text(
                    '${milestone.currentCount}/${milestone.targetCount}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF4B3A66),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: const Color(0xFFE5DEFF),
                valueColor: AlwaysStoppedAnimation<Color>(
                  progress >= 1 ? Color(0xFF4CAF50) : Color(0xFF8E7CFF),
                ),
                minHeight: 10,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 8),
              Text(
                milestone.description,
                style: TextStyle(
                  fontSize: 14,
                  color: const Color(0xFF7A6A5A).withOpacity(0.8),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Daily check-in prompt
          if (!milestone.isAchieved && milestone.currentCount < milestone.targetCount)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8E7CFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8E7CFF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF8E7CFF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'Check in today!', 'سجل دخولك اليوم!'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        Text(
                          tr(
                            context,
                            'Open the app tomorrow to continue your streak',
                            'افتح التطبيق غدًا لمواصلة سلسلتك',
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: const Color(0xFF7A6A5A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTodaysActivities(BuildContext context, MilestoneProvider milestoneProvider) {
    final activitiesData = milestoneProvider.getTodaysActivities();
    final activities = activitiesData['activities'] as List<DailyActivity>;
    final completed = activitiesData['completed'] as Map<String, bool>;
    final hasActivities = activitiesData['hasActivities'] as bool;
    final isToday = activitiesData['isToday'] as bool;

    if (!hasActivities || !isToday) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5DEFF)),
        ),
        child: Column(
          children: [
            Icon(
              Icons.psychology_rounded,
              color: Color(0xFF8E7CFF),
              size: 40,
            ),
            const SizedBox(height: 10),
            Text(
              tr(context, 'Loading today\'s activities...', 'جارٍ تحميل أنشطة اليوم...'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF4B3A66),
              ),
            ),
          ],
        ),
      );
    }

    // Group by category
    final morningActivities = activities.where((a) => a.category == 'morning').toList();
    final afternoonActivities = activities.where((a) => a.category == 'afternoon').toList();
    final eveningActivities = activities.where((a) => a.category == 'evening').toList();

    final completedCount = completed.values.where((c) => c).length;
    final totalCount = activities.length;

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.psychology_rounded,
                    color: Color(0xFF8E7CFF),
                    size: 24,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    tr(context, 'Today\'s Wellness Activities', 'أنشطة العافية اليومية'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: completedCount == totalCount
                      ? Color(0xFF4CAF50).withOpacity(0.1)
                      : Color(0xFF8E7CFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$completedCount/$totalCount',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: completedCount == totalCount
                        ? Color(0xFF4CAF50)
                        : Color(0xFF8E7CFF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr(context,
                'Small steps for a calmer day. Try to complete all three!',
                'خطوات صغيرة ليوم أكثر هدوءًا. حاول إكمال جميع الأنشطة الثلاثة!'
            ),
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF7A6A5A).withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 20),

          // Morning Activities
          if (morningActivities.isNotEmpty)
            _buildActivityCategorySection(
              context: context,
              title: tr(context, 'Morning Calm', 'هدوء الصباح'),
              icon: Icons.wb_sunny_rounded,
              iconColor: Color(0xFFFFB74D),
              activities: morningActivities,
              completed: completed,
              milestoneProvider: milestoneProvider,
            ),

          const SizedBox(height: 20),

          // Afternoon Activities
          if (afternoonActivities.isNotEmpty)
            _buildActivityCategorySection(
              context: context,
              title: tr(context, 'Midday Reset', 'استراحة الظهيرة'),
              icon: Icons.light_mode_rounded,
              iconColor: Color(0xFF4CAF50),
              activities: afternoonActivities,
              completed: completed,
              milestoneProvider: milestoneProvider,
            ),

          const SizedBox(height: 20),

          // Evening Activities
          if (eveningActivities.isNotEmpty)
            _buildActivityCategorySection(
              context: context,
              title: tr(context, 'Evening Wind Down', 'استرخاء المساء'),
              icon: Icons.nightlight_rounded,
              iconColor: Color(0xFF7B1FA2),
              activities: eveningActivities,
              completed: completed,
              milestoneProvider: milestoneProvider,
            ),

          const SizedBox(height: 10),

          // Completion encouragement
          if (completedCount < totalCount)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF8E7CFF).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8E7CFF).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.emoji_objects_rounded,
                    color: Color(0xFF8E7CFF),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(context,
                          'Complete all activities to boost your wellbeing!',
                          'أكمل جميع الأنشطة لتعزيز عافيتك!'
                      ),
                      style: TextStyle(
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF4CAF50).withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.celebration_rounded,
                    color: Color(0xFF4CAF50),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tr(context,
                          'Amazing! You completed all wellness activities today!',
                          'مذهل! لقد أكملت جميع أنشطة العافية اليوم!'
                      ),
                      style: TextStyle(
                        color: Color(0xFF2A1E3B),
                        fontWeight: FontWeight.w600,
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

  Widget _buildActivityCategorySection({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color iconColor,
    required List<DailyActivity> activities,
    required Map<String, bool> completed,
    required MilestoneProvider milestoneProvider,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...activities.map((activity) => _DailyActivityItem(
          activity: activity,
          completed: completed[activity.id] ?? false,
          onTap: () async {
            try {
              final isCurrentlyCompleted = completed[activity.id] ?? false;
              await milestoneProvider.completeDailyActivity(
                activity.id,
                completed: !isCurrentlyCompleted,
              );
            } catch (e) {
              print('Error toggling activity: $e');
            }
          },
          context: context,
        )).toList(),
      ],
    );
  }

  Widget _buildStreakAchievementsSection(List<Milestone> streakAchievements, MilestoneProvider milestoneProvider) {
    if (streakAchievements.isEmpty) return const SizedBox();

    final currentStreak = milestoneProvider.getCurrentStreak();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'Streak Achievements', 'إنجازات السلسلة'),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(context, 'Maintaining your daily streak', 'افتح الإنجازات بالمحافظة على سلسلتك اليومية'),
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF7A6A5A).withOpacity(0.8),
                  ),
                ),
              ],
            ),
            // Show "See More" button only if there are more achievements to show
            if (milestoneProvider.getAllStreakAchievements().length > 2)
              TextButton(
                onPressed: () {
                  setState(() {
                    _showAllStreakAchievements = !_showAllStreakAchievements;
                  });
                },
                child: Text(
                  _showAllStreakAchievements
                      ? tr(context, 'See Less', 'عرض أقل')
                      : tr(context, 'See More', 'عرض المزيد'),
                  style: TextStyle(
                    color: Color(0xFF8E7CFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 15),

        ...streakAchievements.map((achievement) {
          final streakProgress = milestoneProvider.getStreakProgress(achievement);
          final displayCurrentCount = streakProgress['currentStreak'] as int;
          final shouldBeAchieved = streakProgress['shouldBeAchieved'] as bool;

          return _StreakAchievementCard(
            milestone: achievement,
            currentStreak: displayCurrentCount,
            shouldBeAchieved: shouldBeAchieved,
          );
        }).toList(),
      ],
    );
  }

  Widget _buildActiveAchievementsSection(List<Milestone> achievements, BuildContext context) {
    if (achievements.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          tr(context, 'Active Milestones', 'المعالم النشطة'),
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A1E3B),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          tr(context, 'Work in progress achievements', 'الإنجازات قيد التقدم'),
          style: TextStyle(
            fontSize: 14,
            color: const Color(0xFF7A6A5A).withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 15),

        ...achievements.map((achievement) => _AchievementCard(
          milestone: achievement,
        )).toList(),
      ],
    );
  }

  Widget _buildAchievementHistorySection(List<Milestone> completedAchievements, BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () {
            setState(() {
              _showAchievementHistory = !_showAchievementHistory;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Color(0xFF4CAF50).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.history_rounded,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(context, 'Achievement History', 'سجل الإنجازات'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        Text(
                          '${completedAchievements.length} ${tr(context, 'achievements unlocked', 'إنجاز تم فتحه')}',
                          style: TextStyle(
                            fontSize: 14,
                            color: const Color(0xFF7A6A5A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Icon(
                  _showAchievementHistory
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded,
                  color: Color(0xFF8E7CFF),
                  size: 28,
                ),
              ],
            ),
          ),
        ),

        if (_showAchievementHistory) ...[
          const SizedBox(height: 15),

          // Completed achievements grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 0.8,
            ),
            itemCount: completedAchievements.length,
            itemBuilder: (context, index) {
              final achievement = completedAchievements[index];
              return _CompletedAchievementCard(
                milestone: achievement,
                onTap: () {
                  _showAchievementDetails(achievement, context);
                },
              );
            },
          ),

          const SizedBox(height: 10),

          // View all button
          Center(
            child: TextButton(
              onPressed: () {
                _showAllAchievementsDialog(completedAchievements, context);
              },
              child: Text(
                tr(context, 'View All Achievements', 'عرض جميع الإنجازات'),
                style: TextStyle(
                  color: Color(0xFF8E7CFF),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  void _showAchievementDetails(Milestone milestone, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(milestone.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(milestone.description),
            const SizedBox(height: 16),
            Text(
              'Category: ${milestone.category}',
              style: TextStyle(
                color: Color(0xFF4B3A66),
              ),
            ),
            if (milestone.achievedAt != null) ...[
              const SizedBox(height: 8),
              Text(
                'Achieved on: ${milestone.achievedAt!.toString().split(' ')[0]}',
                style: TextStyle(
                  color: Color(0xFF4CAF50),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  void _showAllAchievementsDialog(List<Milestone> achievements, BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'All Achievements', 'جميع الإنجازات')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: achievements.length,
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              return ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Color(0xFF4CAF50).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _getAchievementIcon(achievement),
                    color: Color(0xFF4CAF50),
                    size: 20,
                  ),
                ),
                title: Text(achievement.title),
                subtitle: Text(achievement.description),
                trailing: Text(
                  achievement.achievedAt?.toString().split(' ')[0] ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showAchievementDetails(achievement, context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  IconData _getAchievementIcon(Milestone milestone) {
    switch (milestone.category) {
      case 'healing':
        return Icons.healing_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.people_rounded;
      case 'daily':
        return Icons.check_circle_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}

class _StreakAchievementCard extends StatelessWidget {
  final Milestone milestone;
  final int currentStreak;
  final bool shouldBeAchieved;

  const _StreakAchievementCard({
    required this.milestone,
    required this.currentStreak,
    required this.shouldBeAchieved,
  });

  @override
  Widget build(BuildContext context) {
    final isActuallyAchieved = milestone.isAchieved;
    final progress = currentStreak / milestone.targetCount;
    final progressPercentage = progress > 1.0 ? 1.0 : progress;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(milestone.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.description),
                SizedBox(height: 16),
                Text(
                  'Current Streak: $currentStreak days',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B3A66),
                  ),
                ),
                Text(
                  'Target: ${milestone.targetCount} days',
                  style: TextStyle(
                    color: Color(0xFF4B3A66),
                  ),
                ),
                if (isActuallyAchieved && milestone.achievedAt != null)
                  Text(
                    'Achieved on: ${milestone.achievedAt!.toString().split(' ')[0]}',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'Close', 'إغلاق')),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActuallyAchieved
                ? Color(0xFF4CAF50).withOpacity(0.3)
                : const Color(0xFFE5DEFF),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: isActuallyAchieved
                    ? Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFFFF6B6B).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_fire_department_rounded,
                color: isActuallyAchieved ? Color(0xFF4CAF50) : Color(0xFFFF6B6B),
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isActuallyAchieved
                          ? Color(0xFF2A1E3B)
                          : Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    milestone.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF7A6A5A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!isActuallyAchieved)
                    LinearProgressIndicator(
                      value: progressPercentage,
                      backgroundColor: const Color(0xFFE5DEFF),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF6B6B),
                      ),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  if (!isActuallyAchieved)
                    const SizedBox(height: 4),
                  if (!isActuallyAchieved)
                    Text(
                      '$currentStreak/${milestone.targetCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A6A5A),
                      ),
                    ),
                  if (isActuallyAchieved && milestone.achievedAt != null)
                    Text(
                      '${tr(context, 'Achieved on', 'تم الإنجاز في')} ${milestone.achievedAt!.toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isActuallyAchieved
                  ? Icons.check_circle_rounded
                  : (shouldBeAchieved ? Icons.warning_amber_rounded : Icons.circle_outlined),
              color: isActuallyAchieved
                  ? Color(0xFF4CAF50)
                  : (shouldBeAchieved ? Color(0xFFFF9800) : Color(0xFF9C90B3)),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletedAchievementCard extends StatelessWidget {
  final Milestone milestone;
  final VoidCallback onTap;

  const _CompletedAchievementCard({
    required this.milestone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Color(0xFFE5DEFF)),
          boxShadow: [
            BoxShadow(
              color: Color(0xFF4CAF50).withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Color(0xFF4CAF50).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getAchievementIcon(milestone),
                color: Color(0xFF4CAF50),
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                milestone.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              milestone.achievedAt?.toString().split(' ')[0] ?? '',
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(Milestone milestone) {
    switch (milestone.category) {
      case 'healing':
        return Icons.healing_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.people_rounded;
      case 'daily':
        return Icons.check_circle_rounded;
      default:
        return Icons.emoji_events_rounded;
    }
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String unit;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.unit,
    required this.icon,
    required this.color,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF7A6A5A),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: TextStyle(
                  fontSize: 14,
                  color: color.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final Milestone milestone;

  const _AchievementCard({
    required this.milestone,
  });

  @override
  Widget build(BuildContext context) {
    final progress = milestone.currentCount / milestone.targetCount;

    return GestureDetector(
      onTap: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(milestone.title),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestone.description),
                SizedBox(height: 16),
                Text(
                  'Progress: ${milestone.currentCount}/${milestone.targetCount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF4B3A66),
                  ),
                ),
                if (milestone.streakDays > 0)
                  Text(
                    'Current streak: ${milestone.streakDays} days',
                    style: TextStyle(
                      color: Color(0xFF4B3A66),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tr(context, 'Close', 'إغلاق')),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: milestone.isAchieved
                ? Color(0xFF4CAF50).withOpacity(0.3)
                : const Color(0xFFE5DEFF),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: milestone.isAchieved
                    ? Color(0xFF4CAF50).withOpacity(0.1)
                    : _getCategoryColor(milestone.category).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _getAchievementIcon(milestone),
                color: milestone.isAchieved
                    ? Color(0xFF4CAF50)
                    : _getCategoryColor(milestone.category),
                size: 24,
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: milestone.isAchieved
                          ? Color(0xFF2A1E3B)
                          : Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    milestone.description,
                    style: TextStyle(
                      fontSize: 12,
                      color: const Color(0xFF7A6A5A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (!milestone.isAchieved)
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFFE5DEFF),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        _getCategoryColor(milestone.category),
                      ),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  if (!milestone.isAchieved)
                    const SizedBox(height: 4),
                  if (!milestone.isAchieved)
                    Text(
                      '${milestone.currentCount}/${milestone.targetCount}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A6A5A),
                      ),
                    ),
                  if (milestone.isAchieved && milestone.achievedAt != null)
                    Text(
                      '${tr(context, 'Achieved on', 'تم الإنجاز في')} ${milestone.achievedAt!.toString().split(' ')[0]}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4CAF50),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              milestone.isAchieved
                  ? Icons.check_circle_rounded
                  : Icons.circle_outlined,
              color: milestone.isAchieved
                  ? Color(0xFF4CAF50)
                  : Color(0xFF9C90B3),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getAchievementIcon(Milestone milestone) {
    if (milestone.isAchieved) {
      return Icons.emoji_events_rounded;
    }

    switch (milestone.category) {
      case 'healing':
        return Icons.healing_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.people_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'healing':
        return Color(0xFFFF6B6B);
      case 'streak':
        return Color(0xFFFF6B6B);
      case 'character_discovery':
        return Color(0xFF2196F3);
      case 'daily':
        return Color(0xFF8E7CFF);
      default:
        return Color(0xFF8E7CFF);
    }
  }
}

class _DailyActivityItem extends StatelessWidget {
  final DailyActivity activity;
  final bool completed;
  final VoidCallback onTap;
  final BuildContext context;

  const _DailyActivityItem({
    required this.activity,
    required this.completed,
    required this.onTap,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final title = isArabic ? activity.titleAr : activity.titleEn;
    final description = isArabic ? activity.descriptionAr : activity.descriptionEn;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: completed
                ? Color(0xFF4CAF50).withOpacity(0.3)
                : const Color(0xFFE5DEFF),
            width: completed ? 2 : 1,
          ),
          boxShadow: completed ? [
            BoxShadow(
              color: Color(0xFF4CAF50).withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, 2),
            )
          ] : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Checkbox container
            GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: 24,
                height: 24,
                margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(
                  color: completed ? Color(0xFF4CAF50) : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: completed ? Color(0xFF4CAF50) : Color(0xFF9C90B3),
                    width: 2,
                  ),
                ),
                child: completed
                    ? Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 16,
                )
                    : null,
              ),
            ),

            const SizedBox(width: 15),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: completed
                                ? Color(0xFF2A1E3B)
                                : Color(0xFF2A1E3B),
                            decoration: completed
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getCategoryColor(activity.category)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${activity.estimatedMinutes} min',
                          style: TextStyle(
                            fontSize: 12,
                            color: _getCategoryColor(activity.category),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 14,
                      color: completed
                          ? const Color(0xFF7A6A5A).withOpacity(0.7)
                          : const Color(0xFF7A6A5A),
                      height: 1.4,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Tags
                  if (activity.tags.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: activity.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: completed
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFF5F3FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            _getTagLabel(tag, context),
                            style: TextStyle(
                              fontSize: 11,
                              color: completed
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF7A6A5A),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'morning':
        return Color(0xFFFFB74D);
      case 'afternoon':
        return Color(0xFF4CAF50);
      case 'evening':
        return Color(0xFF7B1FA2);
      default:
        return Color(0xFF8E7CFF);
    }
  }

  String _getTagLabel(String tag, BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    final Map<String, Map<String, String>> tagTranslations = {
      'mindfulness': {
        'en': 'Mindfulness',
        'ar': 'وعي',
      },
      'gratitude': {
        'en': 'Gratitude',
        'ar': 'امتنان',
      },
      'breathing': {
        'en': 'Breathing',
        'ar': 'تنفس',
      },
      'stress_relief': {
        'en': 'Stress Relief',
        'ar': 'تخفيف التوتر',
      },
      'physical_health': {
        'en': 'Physical Health',
        'ar': 'صحة بدنية',
      },
      'digital_detox': {
        'en': 'Digital Detox',
        'ar': 'صيام رقمي',
      },
      'nature': {
        'en': 'Nature',
        'ar': 'طبيعة',
      },
      'journaling': {
        'en': 'Journaling',
        'ar': 'يوميات',
      },
      'positive_thinking': {
        'en': 'Positive Thinking',
        'ar': 'تفكير إيجابي',
      },
      'self_care': {
        'en': 'Self-Care',
        'ar': 'عناية ذاتية',
      },
      'sensory_awareness': {
        'en': 'Sensory Awareness',
        'ar': 'وعي حسي',
      },
      'energy': {
        'en': 'Energy',
        'ar': 'طاقة',
      },
      'flexibility': {
        'en': 'Flexibility',
        'ar': 'مرونة',
      },
      'self_esteem': {
        'en': 'Self-Esteem',
        'ar': 'ثقة بالنفس',
      },
      'reflection': {
        'en': 'Reflection',
        'ar': 'تأمل',
      },
      'nutrition': {
        'en': 'Nutrition',
        'ar': 'تغذية',
      },
      'body_awareness': {
        'en': 'Body Awareness',
        'ar': 'وعي جسدي',
      },
      'aromatherapy': {
        'en': 'Aromatherapy',
        'ar': 'علاج عطري',
      },
      'hydration': {
        'en': 'Hydration',
        'ar': 'ترطيب',
      },
      'exercise': {
        'en': 'Exercise',
        'ar': 'تمرين',
      },
      'ergonomics': {
        'en': 'Ergonomics',
        'ar': 'بيئة عمل',
      },
      'eye_rest': {
        'en': 'Eye Rest',
        'ar': 'راحة عينين',
      },
      'mindful_eating': {
        'en': 'Mindful Eating',
        'ar': 'أكل واعٍ',
      },
      'posture': {
        'en': 'Posture',
        'ar': 'وضعية جسم',
      },
      'kindness': {
        'en': 'Kindness',
        'ar': 'لطافة',
      },
      'compassion': {
        'en': 'Compassion',
        'ar': 'تعاطف',
      },
      'music': {
        'en': 'Music',
        'ar': 'موسيقى',
      },
      'relaxation': {
        'en': 'Relaxation',
        'ar': 'استرخاء',
      },
      'social': {
        'en': 'Social',
        'ar': 'اجتماعي',
      },
      'communication': {
        'en': 'Communication',
        'ar': 'تواصل',
      },
      'productivity': {
        'en': 'Productivity',
        'ar': 'إنتاجية',
      },
      'organization': {
        'en': 'Organization',
        'ar': 'تنظيم',
      },
      'eye_health': {
        'en': 'Eye Health',
        'ar': 'صحة عيون',
      },
      'energy_boost': {
        'en': 'Energy Boost',
        'ar': 'نشاط',
      },
      'meditation': {
        'en': 'Meditation',
        'ar': 'تأمل',
      },
      'sleep_hygiene': {
        'en': 'Sleep Hygiene',
        'ar': 'نظافة نوم',
      },
      'learning': {
        'en': 'Learning',
        'ar': 'تعلم',
      },
      'environment': {
        'en': 'Environment',
        'ar': 'بيئة',
      },
      'hygiene': {
        'en': 'Hygiene',
        'ar': 'نظافة',
      },
      'emotional_release': {
        'en': 'Emotional Release',
        'ar': 'تحرير عاطفي',
      },
      'self_compassion': {
        'en': 'Self-Compassion',
        'ar': 'تعاطف ذاتي',
      },
    };

    return tagTranslations[tag]?[isArabic ? 'ar' : 'en'] ?? tag;
  }
}