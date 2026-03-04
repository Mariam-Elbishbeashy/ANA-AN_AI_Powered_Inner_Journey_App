// lib/features/progress/presentation/screens/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
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
              20 + MediaQuery.of(context).padding.bottom + 80,
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

                const SizedBox(height: 40),
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