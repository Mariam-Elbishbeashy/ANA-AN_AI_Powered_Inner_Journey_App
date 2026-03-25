import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import '../../domain/entities/milestone.dart';

String _milestoneTitle(BuildContext context, Milestone milestone) {
  return isArabic(context) ? milestone.titleAr : milestone.titleEn;
}

String _milestoneDescription(BuildContext context, Milestone milestone) {
  return isArabic(context) ? milestone.descriptionAr : milestone.descriptionEn;
}

class ProgressAchievements extends StatefulWidget {
  const ProgressAchievements({super.key});

  @override
  State<ProgressAchievements> createState() => _ProgressAchievementsState();
}

class _ProgressAchievementsState extends State<ProgressAchievements> {
  bool _showAllStreakAchievements = false;
  bool _showAllCharacterDiscovery = false;
  bool _showAllStableAchievements = false;

  List<Milestone> _orderedAchievements(List<Milestone> milestones) {
    final pending = milestones.where((m) => !m.isAchieved).toList()
      ..sort((a, b) => a.targetCount.compareTo(b.targetCount));

    final completed = milestones.where((m) => m.isAchieved).toList()
      ..sort((a, b) {
        final aDate = a.achievedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b.achievedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });

    return [...pending, ...completed];
  }

  List<Milestone> _visibleAchievements(
      List<Milestone> milestones,
      bool showAll,
      ) {
    final ordered = _orderedAchievements(milestones);
    if (showAll || ordered.length <= 2) return ordered;
    return ordered.sublist(0, 2);
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        final allStableMilestones =
        _orderedAchievements(milestoneProvider.getStableMilestones());

        final allCharacterDiscoveryMilestones = _orderedAchievements(
          milestoneProvider.getCharacterDiscoveryMilestones(),
        );

        final allStreakAchievements =
        _orderedAchievements(milestoneProvider.getAllStreakAchievements());

        final characterDiscoveryMilestones = _visibleAchievements(
          allCharacterDiscoveryMilestones,
          _showAllCharacterDiscovery,
        );

        final stableMilestones = _visibleAchievements(
          allStableMilestones,
          _showAllStableAchievements,
        );

        final streakAchievements = _visibleAchievements(
          allStreakAchievements,
          _showAllStreakAchievements,
        );

        return Column(
          children: [
            if (allCharacterDiscoveryMilestones.isNotEmpty)
              _buildCharacterDiscoverySection(
                characterDiscoveryMilestones,
                allCharacterDiscoveryMilestones,
                context,
              ),
            if (allCharacterDiscoveryMilestones.isNotEmpty &&
                (streakAchievements.isNotEmpty || allStableMilestones.isNotEmpty))
              const SizedBox(height: 28),
            if (allStreakAchievements.isNotEmpty)
              _buildStreakAchievementsSection(
                streakAchievements,
                allStreakAchievements,
                milestoneProvider,
                context,
              ),
            if (allStreakAchievements.isNotEmpty && allStableMilestones.isNotEmpty)
              const SizedBox(height: 28),
            if (allStableMilestones.isNotEmpty)
              _buildStableSection(
                stableMilestones,
                allStableMilestones,
                context,
              ),
          ],
        );
      },
    );
  }

  Widget _buildCharacterDiscoverySection(
      List<Milestone> milestones,
      List<Milestone> allMilestones,
      BuildContext context,
      ) {
    return _AchievementSectionShell(
      title: tr(context, 'Character Discovery', 'اكتشاف الشخصيات'),
      subtitle: tr(
        context,
        'Discover your inner characters',
        'اكتشف شخصياتك الداخلية',
      ),
      action: allMilestones.length > 2
          ? TextButton(
        onPressed: () {
          setState(() {
            _showAllCharacterDiscovery = !_showAllCharacterDiscovery;
          });
        },
        child: Text(
          _showAllCharacterDiscovery
              ? tr(context, 'See Less', 'عرض أقل')
              : tr(context, 'See More', 'عرض المزيد'),
          style: const TextStyle(
            color: Color(0xFF8E7CFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : null,
      child: Column(
        children: milestones
            .map(
              (achievement) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _AchievementCard(milestone: achievement),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildStableSection(
      List<Milestone> milestones,
      List<Milestone> allMilestones,
      BuildContext context,
      ) {
    return _AchievementSectionShell(
      title: tr(context, 'Stable Milestones', 'إنجازات الاستقرار'),
      subtitle: tr(
        context,
        'Celebrate every character that reaches stability',
        'احتفلي بكل شخصية تصل إلى الاستقرار',
      ),
      action: allMilestones.length > 2
          ? TextButton(
        onPressed: () {
          setState(() {
            _showAllStableAchievements = !_showAllStableAchievements;
          });
        },
        child: Text(
          _showAllStableAchievements
              ? tr(context, 'See Less', 'عرض أقل')
              : tr(context, 'See More', 'عرض المزيد'),
          style: const TextStyle(
            color: Color(0xFF59A874),
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : null,
      child: Column(
        children: milestones
            .map(
              (achievement) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _AchievementCard(milestone: achievement),
          ),
        )
            .toList(),
      ),
    );
  }

  Widget _buildStreakAchievementsSection(
      List<Milestone> streakAchievements,
      List<Milestone> allStreakAchievements,
      MilestoneProvider milestoneProvider,
      BuildContext context,
      ) {
    return _AchievementSectionShell(
      title: tr(context, 'Streak Achievements', 'إنجازات السلسلة'),
      subtitle: tr(
        context,
        'Maintaining your daily streak',
        'افتح الإنجازات بالمحافظة على سلسلتك اليومية',
      ),
      action: allStreakAchievements.length > 2
          ? TextButton(
        onPressed: () {
          setState(() {
            _showAllStreakAchievements = !_showAllStreakAchievements;
          });
        },
        child: Text(
          _showAllStreakAchievements
              ? tr(context, 'See Less', 'عرض أقل')
              : tr(context, 'See More', 'عرض المزيد'),
          style: const TextStyle(
            color: Color(0xFFFF8A3D),
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : null,
      child: Column(
        children: streakAchievements.map((achievement) {
          final streakProgress = milestoneProvider.getStreakProgress(achievement);
          final displayCurrentCount = streakProgress['currentStreak'] as int;
          final shouldBeAchieved = streakProgress['shouldBeAchieved'] as bool;

          return Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _StreakAchievementCard(
              milestone: achievement,
              currentStreak: displayCurrentCount,
              shouldBeAchieved: shouldBeAchieved,
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showAchievementDetails(Milestone milestone, BuildContext context) {
    final accent = _getCategoryColor(milestone.category);
    final soft = _getCategorySoftColor(
      milestone.category,
      achieved: milestone.isAchieved,
    );

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.18),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: accent.withOpacity(0.18),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HexagonIconBadge(
                icon: _getAchievementIcon(milestone),
                backgroundColor: soft,
                iconColor: accent,
                size: 72,
              ),
              const SizedBox(height: 14),
              Text(
                _milestoneTitle(context, milestone),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2344),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _milestoneDescription(context, milestone),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: Color(0xFF7E769B),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFE7E3FF)),
                ),
                child: Column(
                  children: [
                    _DialogInfoRow(
                      label: tr(context, 'Category', 'الفئة'),
                      value: _localizedCategory(context, milestone.category),
                    ),
                    const SizedBox(height: 10),
                    _DialogInfoRow(
                      label: tr(context, 'Progress', 'التقدم'),
                      value: '${milestone.currentCount}/${milestone.targetCount}',
                    ),
                    if (milestone.streakDays > 0) ...[
                      const SizedBox(height: 10),
                      _DialogInfoRow(
                        label: tr(context, 'Current streak', 'السلسلة الحالية'),
                        value: '${milestone.streakDays}',
                      ),
                    ],
                    if (milestone.achievedAt != null) ...[
                      const SizedBox(height: 10),
                      _DialogInfoRow(
                        label: tr(context, 'Unlocked on', 'تم فتحه في'),
                        value: milestone.achievedAt!.toString().split(' ')[0],
                        valueColor: accent,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(tr(context, 'Close', 'إغلاق')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedCategory(BuildContext context, String category) {
    switch (category) {
      case 'streak':
        return tr(context, 'Streak', 'السلسلة');
      case 'character_discovery':
        return tr(context, 'Character Discovery', 'اكتشاف الشخصيات');
      case 'stable':
        return tr(context, 'Stability', 'الاستقرار');
      default:
        return tr(context, 'Achievement', 'إنجاز');
    }
  }

  IconData _getAchievementIcon(Milestone milestone) {
    if (milestone.isAchieved) return Icons.emoji_events_rounded;

    switch (milestone.category) {
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.auto_awesome_rounded;
      case 'stable':
        return Icons.shield_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'streak':
        return const Color(0xFFFF8A3D);
      case 'character_discovery':
        return const Color(0xFF8E7CFF);
      case 'stable':
        return const Color(0xFF59A874);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  Color _getCategorySoftColor(String category, {bool achieved = false}) {
    switch (category) {
      case 'streak':
        return achieved ? const Color(0xFFFFF4EC) : const Color(0xFFFFF1E7);
      case 'character_discovery':
        return achieved ? const Color(0xFFF5F2FF) : const Color(0xFFF0EDFF);
      case 'stable':
        return achieved ? const Color(0xFFEEF9F1) : const Color(0xFFE8F8EE);
      default:
        return achieved ? const Color(0xFFF5F2FF) : const Color(0xFFF0EDFF);
    }
  }
}

class _AchievementSectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _AchievementSectionShell({
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

class _AchievementCard extends StatelessWidget {
  final Milestone milestone;

  const _AchievementCard({required this.milestone});

  @override
  Widget build(BuildContext context) {
    final progress = milestone.targetCount == 0
        ? 0.0
        : milestone.currentCount / milestone.targetCount;
    final color = _getCategoryColor(milestone.category);
    final softColor = _getCategorySoftColor(milestone.category);
    final achievedTint = _getCategorySoftColor(milestone.category, achieved: true);

    return GestureDetector(
      onTap: () => _showCardDetails(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: milestone.isAchieved
              ? achievedTint
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: milestone.isAchieved
                ? color.withOpacity(0.28)
                : const Color(0xFFE7E3FF),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(milestone.isAchieved ? 0.12 : 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _HexagonIconBadge(
              icon: _getAchievementIcon(milestone),
              backgroundColor:
              milestone.isAchieved ? color.withOpacity(0.14) : softColor,
              iconColor: color,
              size: 58,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _milestoneTitle(context, milestone),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2344),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _milestoneDescription(context, milestone),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8881A1),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!milestone.isAchieved) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 8,
                        backgroundColor: softColor,
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SoftChip(
                          text: '${milestone.currentCount}/${milestone.targetCount}',
                          background: softColor,
                          color: color,
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        _SoftChip(
                          text: tr(context, 'Completed', 'مكتمل'),
                          background: color.withOpacity(0.12),
                          color: color,
                          icon: Icons.check_rounded,
                        ),
                      ],
                    ),
                    if (milestone.achievedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${tr(context, 'Unlocked on', 'تم فتحه في')} ${milestone.achievedAt!.toString().split(' ')[0]}',
                        style: TextStyle(
                          fontSize: 12,
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              milestone.isAchieved
                  ? Icons.check_circle_rounded
                  : Icons.chevron_right_rounded,
              color: milestone.isAchieved ? color : const Color(0xFFAEA7C9),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  void _showCardDetails(BuildContext context) {
    final state = context.findAncestorStateOfType<_ProgressAchievementsState>();
    state?._showAchievementDetails(milestone, context);
  }

  IconData _getAchievementIcon(Milestone milestone) {
    if (milestone.isAchieved) return Icons.emoji_events_rounded;

    switch (milestone.category) {
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.auto_awesome_rounded;
      case 'stable':
        return Icons.shield_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'streak':
        return const Color(0xFFFF8A3D);
      case 'character_discovery':
        return const Color(0xFF8E7CFF);
      case 'stable':
        return const Color(0xFF59A874);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  Color _getCategorySoftColor(String category, {bool achieved = false}) {
    switch (category) {
      case 'streak':
        return achieved ? const Color(0xFFFFF4EC) : const Color(0xFFFFF1E7);
      case 'character_discovery':
        return achieved ? const Color(0xFFF5F2FF) : const Color(0xFFF0EDFF);
      case 'stable':
        return achieved ? const Color(0xFFEEF9F1) : const Color(0xFFE8F8EE);
      default:
        return achieved ? const Color(0xFFF5F2FF) : const Color(0xFFF0EDFF);
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
    final progress =
    milestone.targetCount == 0 ? 0.0 : currentStreak / milestone.targetCount;
    final progressPercentage = progress.clamp(0.0, 1.0);
    const streakColor = Color(0xFFFF8A3D);
    const streakSoft = Color(0xFFFFF1E7);
    const streakAchievedTint = Color(0xFFFFF4EC);

    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_ProgressAchievementsState>();
        state?._showAchievementDetails(milestone, context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isActuallyAchieved
              ? streakAchievedTint
              : Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActuallyAchieved
                ? streakColor.withOpacity(0.28)
                : const Color(0xFFE7E3FF),
          ),
          boxShadow: [
            BoxShadow(
              color: streakColor.withOpacity(isActuallyAchieved ? 0.14 : 0.10),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _HexagonIconBadge(
              icon: Icons.local_fire_department_rounded,
              backgroundColor: isActuallyAchieved
                  ? streakColor.withOpacity(0.14)
                  : streakSoft,
              iconColor: streakColor,
              size: 58,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _milestoneTitle(context, milestone),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2344),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    _milestoneDescription(context, milestone),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF8881A1),
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!isActuallyAchieved) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(30),
                      child: LinearProgressIndicator(
                        value: progressPercentage,
                        minHeight: 8,
                        backgroundColor: streakSoft,
                        valueColor:
                        const AlwaysStoppedAnimation<Color>(streakColor),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SoftChip(
                          text: '$currentStreak/${milestone.targetCount}',
                          background: streakSoft,
                          color: streakColor,
                        ),
                        const SizedBox(width: 8),
                        if (shouldBeAchieved)
                          _SoftChip(
                            text: tr(context, 'Ready', 'جاهز'),
                            background: streakColor.withOpacity(0.14),
                            color: streakColor,
                            icon: Icons.auto_awesome_rounded,
                          ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        _SoftChip(
                          text: tr(context, 'Completed', 'مكتمل'),
                          background: streakColor.withOpacity(0.12),
                          color: streakColor,
                          icon: Icons.check_rounded,
                        ),
                      ],
                    ),
                    if (milestone.achievedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${tr(context, 'Unlocked on', 'تم فتحه في')} ${milestone.achievedAt!.toString().split(' ')[0]}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: streakColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isActuallyAchieved
                  ? Icons.check_circle_rounded
                  : (shouldBeAchieved
                  ? Icons.auto_awesome_rounded
                  : Icons.chevron_right_rounded),
              color: streakColor,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _DialogInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8A84A4),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            color: valueColor ?? const Color(0xFF2D2344),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SoftChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color color;
  final IconData? icon;

  const _SoftChip({
    required this.text,
    required this.background,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: icon != null ? 10 : 12,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HexagonIconBadge extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  const _HexagonIconBadge({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _HexagonClipper(),
      child: Container(
        width: size,
        height: size,
        color: backgroundColor,
        alignment: Alignment.center,
        child: Icon(icon, color: iconColor, size: size * 0.44),
      ),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.25, 0);
    path.lineTo(w * 0.75, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.75, h);
    path.lineTo(w * 0.25, h);
    path.lineTo(0, h * 0.5);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}