import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_charts.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_achievements.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_history.dart';
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
  int _selectedTabIndex = 0; // 0 = mood, 1 = achievements, 2 = history

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        final provider = Provider.of<MilestoneProvider>(context, listen: false);
        if (!provider.isInitialized) {
          await provider.initialize();
        }
      } catch (e) {
        debugPrint('Error initializing provider: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        if (milestoneProvider.isLoading && milestoneProvider.milestones.isEmpty) {
          return _buildLoadingState();
        }

        final stats = milestoneProvider.getStreakStats();
        return _buildContent(stats, milestoneProvider);
      },
    );
  }

  Widget _buildLoadingState() {
    return ProgressBackground(
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
          const Expanded(
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
      MilestoneProvider milestoneProvider,
      ) {
    final weekDays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final moodOptions = {
      'Happy': Icons.sentiment_satisfied_rounded,
      'Sad': Icons.sentiment_dissatisfied_rounded,
      'Tired': Icons.battery_alert_rounded,
      'Energetic': Icons.bolt_rounded,
      'Calm': Icons.spa_rounded,
      'Anxious': Icons.psychology_rounded,
    };

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
                16,
                20,
                24 + MediaQuery.of(context).padding.bottom + 80,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildWeeklyMoodSection(
                    weekDays,
                    weeklyMoods,
                    moodOptions,
                    context,
                  ),
                  const SizedBox(height: 18),
                  _buildProgressOverview(stats, context),
                  const SizedBox(height: 22),
                  _buildViewToggle(context),
                  const SizedBox(height: 24),
                  if (_selectedTabIndex == 0)
                    const ProgressCharts()
                  else if (_selectedTabIndex == 1)
                    const ProgressAchievements()
                  else
                    const ProgressHistory(),
                  const SizedBox(height: 28),
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
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF).withOpacity(0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7E5FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          _buildToggleTab(
            label: tr(context, 'charts', 'البيانات'),
            isSelected: _selectedTabIndex == 0,
            onTap: () => setState(() => _selectedTabIndex = 0),
          ),
          _buildToggleTab(
            label: tr(context, 'Achievements', 'الإنجازات'),
            isSelected: _selectedTabIndex == 1,
            onTap: () => setState(() => _selectedTabIndex = 1),
          ),
          _buildToggleTab(
            label: tr(context, 'History', 'السجل'),
            isSelected: _selectedTabIndex == 2,
            onTap: () => setState(() => _selectedTabIndex = 2),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTab({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF8E7CFF) : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
              color: isSelected ? Colors.white : const Color(0xFF8D87A6),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyMoodSection(
      List<String> weekDays,
      List<Map<String, dynamic>> weeklyMoods,
      Map<String, IconData> moodOptions,
      BuildContext context,
      ) {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.74),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E3FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withOpacity(0.07),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Your Mood This Week',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3E3563),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Row(
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final day = weekDays[index];
              final dayData = weeklyMoods.firstWhere(
                    (m) => m['day'] == day,
                orElse: () => {'day': day, 'mood': null},
              );
              final isToday =
                  date.year == now.year && date.month == now.month && date.day == now.day;
              final hasMood = dayData['mood'] != null;

              return Expanded(
                child: GestureDetector(
                  onTap: isToday
                      ? () => _showMoodSelectionDialog(context, day, moodOptions)
                      : null,
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 6 ? 0 : 6),
                    child: Column(
                      children: [
                        Text(
                          day,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday
                                ? const Color(0xFF6F67E8)
                                : const Color(0xFF9A95B5),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isToday
                                ? const Color(0xFFE8E6FF)
                                : (hasMood ? const Color(0xFFF7F6FF) : Colors.white),
                            border: Border.all(
                              color: isToday
                                  ? const Color(0xFF7E76F1)
                                  : (hasMood
                                  ? const Color(0xFF8A83F3)
                                  : const Color(0xFFE1DEFA)),
                              width: isToday ? 2.2 : (hasMood ? 2.0 : 1.4),
                            ),
                            boxShadow: isToday
                                ? [
                              BoxShadow(
                                color: const Color(0xFF8E7CFF).withOpacity(0.14),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: isToday
                                  ? const Color(0xFF6F67E8)
                                  : (hasMood
                                  ? const Color(0xFF6F67E8)
                                  : const Color(0xFF7C7895)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.touch_app_rounded,
                size: 14,
                color: Color(0xFF9A95B5),
              ),
              const SizedBox(width: 6),
              Text(
                tr(context, 'Tap today to update mood', 'اضغط على اليوم لتحديث المزاج'),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9A95B5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showMoodSelectionDialog(
      BuildContext context,
      String day,
      Map<String, IconData> moodOptions,
      ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Update Today\'s Mood', 'تحديث مزاج اليوم')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: moodOptions.entries.map((entry) {
            return ListTile(
              leading: Icon(entry.value, color: const Color(0xFF8E7CFF)),
              title: Text(entry.key),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${entry.key} ${tr(context, 'logged for today', 'تم تسجيله لليوم')}',
                    ),
                    backgroundColor: const Color(0xFF8E7CFF),
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

  Widget _buildProgressOverview(Map<String, dynamic> stats, BuildContext context) {
    final currentStreak = stats['currentStreak'] as int? ?? 0;
    final totalAchieved = stats['totalAchieved'] as int? ?? 0;
    final totalMilestones = stats['totalMilestones'] as int? ?? 0;
    final percent =
    totalMilestones == 0 ? 0.0 : (totalAchieved / totalMilestones).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFB7D7F2),
            Color(0xFF95B9F5),
            Color(0xFF8E8DF0),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -32,
            left: -34,
            child: Container(
              width: 126,
              height: 126,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF5C9EF).withOpacity(0.55),
              ),
            ),
          ),
          Positioned(
            bottom: -56,
            right: -24,
            child: Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF8D4C8).withOpacity(0.45),
              ),
            ),
          ),
          Positioned(
            bottom: -40,
            left: 86,
            right: 80,
            child: Container(
              height: 88,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(80),
                color: const Color(0xFFE8C8F7).withOpacity(0.45),
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8, right: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'Your Journey Progress', 'تقدم رحلتك'),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr(
                          context,
                          'A gentle reflection of your growth so far',
                          'انعكاس لطيف لنموك حتى الآن',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          Expanded(
                            child: _OverviewMetric(
                              value: '$currentStreak',
                              label: tr(context, 'Streak', 'السلسلة'),
                            ),
                          ),
                          Expanded(
                            child: _OverviewMetric(
                              value: '$totalAchieved/$totalMilestones',
                              label: tr(context, 'Achievements', 'الإنجازات'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _ProgressRing(progress: percent),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _OverviewMetric extends StatelessWidget {
  final String value;
  final String label;

  const _OverviewMetric({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _ProgressRing extends StatelessWidget {
  final double progress;

  const _ProgressRing({required this.progress});

  @override
  Widget build(BuildContext context) {
    final safeProgress = progress.clamp(0.0, 1.0);

    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: 1,
              strokeWidth: 9,
              backgroundColor: Colors.transparent,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.22),
              ),
            ),
          ),
          SizedBox(
            width: 104,
            height: 104,
            child: CircularProgressIndicator(
              value: safeProgress,
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: Colors.transparent,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE9F8FF)),
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7D7AE9).withOpacity(0.96),
            ),
            alignment: Alignment.center,
            child: Text(
              '${(safeProgress * 100).round()}%',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFFFFF0A5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
