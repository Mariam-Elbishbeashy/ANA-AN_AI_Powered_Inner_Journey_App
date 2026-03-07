// lib/features/progress/presentation/screens/progress_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_charts.dart';
import '../../domain/entities/milestone.dart';
import '../widgets/progress_background.dart';

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

  // New toggle state
  bool _showChartsView = true; // true = charts, false = achievements

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
    return ProgressBackground(  // Wrap with background
      isLoading: true,
      child: Column(
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
      ),
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
    // Weekly mood tracking data structure - this would come from database later
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final today = DateTime.now().weekday; // Monday = 1, Sunday = 7
    final todayIndex = today - 1; // Convert to 0-based index

    final moodOptions = {
      'Happy': Icons.sentiment_satisfied_rounded,
      'Sad': Icons.sentiment_dissatisfied_rounded,
      'Tired': Icons.battery_alert_rounded,
      'Energetic': Icons.bolt_rounded,
      'Calm': Icons.spa_rounded,
      'Anxious': Icons.psychology_rounded,
    };

    // Sample mood data - in real app, this would come from database
    final List<Map<String, dynamic>> weeklyMoods = [
      {'day': 'Mon', 'mood': 'Happy', 'note': 'Feeling good'},
      {'day': 'Tue', 'mood': 'Tired', 'note': 'Didn\'t sleep well'},
      {'day': 'Wed', 'mood': 'Calm', 'note': 'Peaceful day'},
      {'day': 'Thu', 'mood': 'Anxious', 'note': 'Busy day'},
      {'day': 'Fri', 'mood': 'Sad', 'note': 'Missing someone'},
      {'day': 'Sat', 'mood': 'Energetic', 'note': 'Workout day'},
      {'day': 'Sun', 'mood': 'Happy', 'note': 'Relaxing'},
    ];

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
          child: ProgressBackground(
            isLoading: milestoneProvider.isLoading && milestoneProvider.milestones.isEmpty,
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

                  // Weekly Mood Tracking Section
                  _buildWeeklyMoodSection(weekDays, todayIndex, weeklyMoods, moodOptions, context),

                  const SizedBox(height: 30),

                  // View Toggle (Charts / Achievements)
                  _buildViewToggle(context),

                  const SizedBox(height: 30),

                  // Conditional content based on toggle
                  if (_showChartsView)
                    _buildChartsView()
                  else
                    _buildAchievementsView(
                      allCharacterDiscoveryMilestones,
                      characterDiscoveryMilestones,
                      streakAchievements,
                      milestoneProvider,
                      allHealingMilestones,
                      healingMilestones,
                      activeAchievements,
                      completedAchievements,
                      context,
                    ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildViewToggle(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showChartsView = true;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _showChartsView ? const Color(0xFF8E7CFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.bar_chart_rounded,
                      size: 18,
                      color: _showChartsView ? Colors.white : const Color(0xFF7A6A5A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'Charts', 'الرسوم البيانية'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _showChartsView ? Colors.white : const Color(0xFF7A6A5A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _showChartsView = false;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: !_showChartsView ? const Color(0xFF8E7CFF) : Colors.transparent,
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      size: 18,
                      color: !_showChartsView ? Colors.white : const Color(0xFF7A6A5A),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tr(context, 'Achievements', 'الإنجازات'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: !_showChartsView ? Colors.white : const Color(0xFF7A6A5A),
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

  Widget _buildChartsView() {
    return const ProgressCharts();
  }

  Widget _buildAchievementsView(
      List<Milestone> allCharacterDiscoveryMilestones,
      List<Milestone> characterDiscoveryMilestones,
      List<Milestone> streakAchievements,
      MilestoneProvider milestoneProvider,
      List<Milestone> allHealingMilestones,
      List<Milestone> healingMilestones,
      List<Milestone> activeAchievements,
      List<Milestone> completedAchievements,
      BuildContext context,
      ) {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _buildWeeklyMoodSection(
      List<String> weekDays,
      int todayIndex,
      List<Map<String, dynamic>> weeklyMoods,
      Map<String, IconData> moodOptions,
      BuildContext context,
      ) {
    return Container(
      padding: const EdgeInsets.all(20),
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
          // Header with emotion theme
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E7CFF).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.emoji_emotions_rounded,
                  color: const Color(0xFF8E7CFF),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(context, 'Mood Predictions', 'توقعات المزاج'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(context, 'Next 1w', 'الأسبوع القادم'),
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

          const SizedBox(height: 20),

          // Weekly mood grid
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (index) {
              final day = weekDays[index];
              final dayData = weeklyMoods.firstWhere(
                    (m) => m['day'] == day,
                orElse: () => {'day': day, 'mood': null},
              );
              final isToday = index == todayIndex;
              final mood = dayData['mood'];
              final hasMood = mood != null;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: index < 6 ? 4 : 0),
                  child: Column(
                    children: [
                      // Day label
                      Text(
                        day,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                          color: isToday
                              ? const Color(0xFF8E7CFF)
                              : const Color(0xFF7A6A5A),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Mood indicator - only tappable for today
                      GestureDetector(
                        onTap: isToday
                            ? () {
                          _showMoodSelectionDialog(context, day, moodOptions);
                        }
                            : null, // No tap for other days
                        child: Container(
                          width: double.infinity,
                          height: 60,
                          decoration: BoxDecoration(
                            color: hasMood
                                ? const Color(0xFF8E7CFF).withOpacity(0.15)
                                : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isToday
                                  ? const Color(0xFF8E7CFF)
                                  : (hasMood
                                  ? const Color(0xFF8E7CFF).withOpacity(0.3)
                                  : const Color(0xFFE5DEFF)),
                              width: isToday ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (hasMood)
                                Icon(
                                  moodOptions[mood] ?? Icons.help_outline_rounded,
                                  color: isToday
                                      ? const Color(0xFF8E7CFF)
                                      : const Color(0xFF9C90B3),
                                  size: 24,
                                )
                              else
                                Icon(
                                  // Show different icon based on whether it's today or not
                                  isToday
                                      ? Icons.add_circle_outline_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  color: isToday
                                      ? const Color(0xFF8E7CFF).withOpacity(0.5)
                                      : const Color(0xFF9C90B3).withOpacity(0.3),
                                  size: 20,
                                ),
                              if (hasMood) ...[
                                const SizedBox(height: 4),
                                Text(
                                  mood,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600,
                                    color: isToday
                                        ? const Color(0xFF8E7CFF)
                                        : const Color(0xFF9C90B3),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                      // Today indicator
                      if (isToday)
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8E7CFF),
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 20),

          // Note about tapping to log mood - updated to only mention today
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: const Color(0xFF7A6A5A).withOpacity(0.6),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  tr(context, 'Tap today\'s mood to update it', 'اضغط على مزاج اليوم لتحديثه'),
                  style: TextStyle(
                    fontSize: 12,
                    color: const Color(0xFF7A6A5A).withOpacity(0.8),
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMoodSelectionDialog(BuildContext context, String day, Map<String, IconData> moodOptions) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Update Today\'s Mood', 'تحديث مزاج اليوم')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: moodOptions.entries.map((entry) {
            return ListTile(
              leading: Icon(entry.value, color: Color(0xFF8E7CFF)),
              title: Text(entry.key),
              onTap: () {
                // This would save to database for today only
                Navigator.pop(context);
                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${entry.key} ${tr(context, 'logged for today', 'تم تسجيله لليوم')}'),
                    backgroundColor: Color(0xFF8E7CFF),
                  ),
                );
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr(context, 'Cancel', 'إلغاء')),
          ),
        ],
      ),
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