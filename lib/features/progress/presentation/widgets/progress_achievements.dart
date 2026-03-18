
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import '../../domain/entities/milestone.dart';

class ProgressAchievements extends StatefulWidget {
  const ProgressAchievements({super.key});

  @override
  State<ProgressAchievements> createState() => _ProgressAchievementsState();
}

class _ProgressAchievementsState extends State<ProgressAchievements> {
  bool _showAllStreakAchievements = false;
  bool _showAllCharacterDiscovery = false;
  bool _showAllHealingProgress = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        final activeAchievements = milestoneProvider.getActiveAchievements();
        final allHealingMilestones = milestoneProvider.getHealingMilestones();
        final allCharacterDiscoveryMilestones =
        milestoneProvider.getCharacterDiscoveryMilestones();

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

        final streakAchievements = _showAllStreakAchievements
            ? milestoneProvider.getAllStreakAchievements()
            : milestoneProvider.getLimitedStreakAchievements();

        return Column(
          children: [
            if (allCharacterDiscoveryMilestones.isNotEmpty)
              _buildCharacterDiscoverySection(
                characterDiscoveryMilestones,
                allCharacterDiscoveryMilestones,
                context,
              ),
            const SizedBox(height: 28),
            if (streakAchievements.isNotEmpty)
              _buildStreakAchievementsSection(
                streakAchievements,
                milestoneProvider,
                context,
              ),
            const SizedBox(height: 28),
            if (allHealingMilestones.isNotEmpty)
              _buildHealingSection(
                healingMilestones,
                allHealingMilestones,
                context,
              ),
            const SizedBox(height: 12),
            if (activeAchievements.isNotEmpty)
              _buildActiveAchievementsSection(activeAchievements, context),
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
      subtitle: tr(context, 'Discover your inner characters', 'اكتشف شخصياتك الداخلية'),
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
            .map((achievement) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AchievementCard(milestone: achievement),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildHealingSection(
      List<Milestone> milestones,
      List<Milestone> allMilestones,
      BuildContext context,
      ) {
    return _AchievementSectionShell(
      title: tr(context, 'Healing Progress', 'تقدم الشفاء'),
      subtitle: tr(
        context,
        'Track your healing journey milestones',
        'تتبع معالم رحلة الشفاء الخاصة بك',
      ),
      action: allMilestones.length > 2
          ? TextButton(
        onPressed: () {
          setState(() {
            _showAllHealingProgress = !_showAllHealingProgress;
          });
        },
        child: Text(
          _showAllHealingProgress
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
            .map((achievement) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AchievementCard(milestone: achievement),
        ))
            .toList(),
      ),
    );
  }

  Widget _buildStreakAchievementsSection(
      List<Milestone> streakAchievements,
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
      action: milestoneProvider.getAllStreakAchievements().length > 2
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
            color: Color(0xFF8E7CFF),
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

  Widget _buildActiveAchievementsSection(
      List<Milestone> achievements,
      BuildContext context,
      ) {
    return _AchievementSectionShell(
      title: tr(context, 'Active Milestones', 'المعالم النشطة'),
      subtitle: tr(context, 'Work in progress achievements', 'الإنجازات قيد التقدم'),
      child: Column(
        children: achievements
            .map((achievement) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _AchievementCard(milestone: achievement),
        ))
            .toList(),
      ),
    );
  }

  void _showAchievementDetails(Milestone milestone, BuildContext context) {
    final isAchieved = milestone.isAchieved;
    final accent = isAchieved ? const Color(0xFF59A874) : const Color(0xFF8E7CFF);
    final soft = isAchieved ? const Color(0xFFE8F8EE) : const Color(0xFFF0EDFF);

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
                milestone.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2344),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                milestone.description,
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
                      value: milestone.category,
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
                        valueColor: const Color(0xFF59A874),
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

  IconData _getAchievementIcon(Milestone milestone) {
    if (milestone.isAchieved) return Icons.emoji_events_rounded;

    switch (milestone.category) {
      case 'healing':
        return Icons.favorite_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.auto_awesome_rounded;
      case 'daily':
        return Icons.check_circle_rounded;
      default:
        return Icons.flag_rounded;
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
    final progress = milestone.targetCount == 0 ? 0.0 : milestone.currentCount / milestone.targetCount;
    final color = _getCategoryColor(milestone.category);
    final softColor = color.withOpacity(0.10);

    return GestureDetector(
      onTap: () => _showCardDetails(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: milestone.isAchieved ? const Color(0xFFBDE5C8) : const Color(0xFFE7E3FF),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _HexagonIconBadge(
              icon: _getAchievementIcon(milestone),
              backgroundColor: milestone.isAchieved ? const Color(0xFFE8F8EE) : softColor,
              iconColor: milestone.isAchieved ? const Color(0xFF59A874) : color,
              size: 58,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2344),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    milestone.description,
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
                        backgroundColor: const Color(0xFFEEEAFE),
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
                    if (milestone.achievedAt != null)
                      Text(
                        milestone.achievedAt!.toString().split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7FA08A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              milestone.isAchieved ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: milestone.isAchieved ? const Color(0xFF59A874) : const Color(0xFFAEA7C9),
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
      case 'healing':
        return Icons.favorite_rounded;
      case 'streak':
        return Icons.local_fire_department_rounded;
      case 'character_discovery':
        return Icons.psychology_rounded;
      case 'daily':
        return Icons.check_circle_rounded;
      default:
        return Icons.flag_rounded;
    }
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'healing':
        return const Color(0xFF8E7CFF);
      case 'streak':
        return const Color(0xFFFF8A3D);
      case 'character_discovery':
        return const Color(0xFF4DA6FF);
      case 'daily':
        return const Color(0xFF9E8CFF);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  String _categoryLabel(BuildContext context, String category) {
    switch (category) {
      case 'healing':
        return tr(context, 'Healing', 'الشفاء');
      case 'streak':
        return tr(context, 'Streak', 'السلسلة');
      case 'character_discovery':
        return tr(context, 'Discovery', 'الاكتشاف');
      case 'daily':
        return tr(context, 'Daily', 'يومي');
      default:
        return tr(context, 'Progress', 'التقدم');
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
    final progress = milestone.targetCount == 0 ? 0.0 : currentStreak / milestone.targetCount;
    final progressPercentage = progress.clamp(0.0, 1.0);

    return GestureDetector(
      onTap: () {
        final state = context.findAncestorStateOfType<_ProgressAchievementsState>();
        state?._showAchievementDetails(milestone, context);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActuallyAchieved ? const Color(0xFFBDE5C8) : const Color(0xFFE7E3FF),
          ),
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
            _HexagonIconBadge(
              icon: Icons.local_fire_department_rounded,
              backgroundColor: isActuallyAchieved ? const Color(0xFFE8F8EE) : const Color(0xFFFFF1E7),
              iconColor: isActuallyAchieved ? const Color(0xFF59A874) : const Color(0xFFFF8A3D),
              size: 58,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    milestone.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2344),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    milestone.description,
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
                        backgroundColor: const Color(0xFFFFE7D6),
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFF8A3D)),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _SoftChip(
                          text: '$currentStreak/${milestone.targetCount}',
                          background: const Color(0xFFFFF1E7),
                          color: const Color(0xFFFF8A3D),
                        ),
                        const SizedBox(width: 8),
                        if (shouldBeAchieved)
                          const _SoftChip(
                            text: 'Ready',
                            background: Color(0xFFE8F8EE),
                            color: Color(0xFF59A874),
                            icon: Icons.auto_awesome_rounded,
                          ),
                      ],
                    ),
                  ] else ...[
                    if (milestone.achievedAt != null)
                      Text(
                        milestone.achievedAt!.toString().split(' ')[0],
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7FA08A),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              isActuallyAchieved
                  ? Icons.check_circle_rounded
                  : (shouldBeAchieved ? Icons.auto_awesome_rounded : Icons.chevron_right_rounded),
              color: isActuallyAchieved ? const Color(0xFF59A874) : const Color(0xFF8E7CFF),
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

  const _DialogInfoRow({required this.label, required this.value, this.valueColor});

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
