import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import '../../domain/entities/milestone.dart';
import '../../domain/entities/stable_character_history.dart';

String _milestoneTitle(BuildContext context, Milestone milestone) {
  return isArabic(context) ? milestone.titleAr : milestone.titleEn;
}

String _milestoneDescription(BuildContext context, Milestone milestone) {
  return isArabic(context) ? milestone.descriptionAr : milestone.descriptionEn;
}

class ProgressHistory extends StatefulWidget {
  const ProgressHistory({super.key});

  @override
  State<ProgressHistory> createState() => _ProgressHistoryState();
}

class _ProgressHistoryState extends State<ProgressHistory> {
  final FirestoreService _firestoreService = FirestoreService();

  static const int _collapsedStableHistoryLimit = 2;
  static const int _expandedStableHistoryLimit = 50;
  static const int _collapsedAchievementHistoryLimit = 3;

  bool _showAllStableHistory = false;
  bool _showAllAchievementHistory = false;
  late final Stream<List<StableCharacterHistory>> _stableHistoryStream;

  @override
  void initState() {
    super.initState();
    _stableHistoryStream = _firestoreService.watchStableCharacterHistory();
  }

  @override
  void dispose() {
    _firestoreService.stopStableCharactersRealtimeSync();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        final completedAchievements = List<Milestone>.from(
          milestoneProvider.getCompletedAchievements(),
        )..sort((a, b) {
          final aDate = a.achievedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate = b.achievedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

        final visibleAchievements = _showAllAchievementHistory
            ? completedAchievements
            : completedAchievements.take(_collapsedAchievementHistoryLimit).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StreamBuilder<List<StableCharacterHistory>>(
              stream: _stableHistoryStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData && snapshot.connectionState == ConnectionState.waiting) {
                  return _LoadingHistoryCard(
                    title: tr(context, 'Stable Characters History', 'سجل الشخصيات المستقرة'),
                  );
                }

                final stableHistory = List<StableCharacterHistory>.from(
                  snapshot.data ?? const <StableCharacterHistory>[],
                )..sort((a, b) => b.stableAt.compareTo(a.stableAt));

                final hasMoreStableHistory =
                    stableHistory.length > _collapsedStableHistoryLimit;

                if (stableHistory.isEmpty) {
                  return _EmptyHistoryCard(
                    title: tr(context, 'Stable Characters History', 'سجل الشخصيات المستقرة'),
                    subtitle: tr(
                      context,
                      'Stable characters will appear here.',
                      'ستظهر الشخصيات المستقرة هنا.',
                    ),
                  );
                }

                final visibleHistory = _showAllStableHistory
                    ? stableHistory
                    : stableHistory.take(_collapsedStableHistoryLimit).toList();

                return _HistorySectionShell(
                  title: tr(context, 'Stable Characters History', 'سجل الشخصيات المستقرة'),
                  subtitle: tr(
                    context,
                    'A quiet record of parts that have reached inner balance.',
                    'سجل هادئ للأجزاء التي وصلت إلى توازن داخلي.',
                  ),
                  action: hasMoreStableHistory
                      ? TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllStableHistory = !_showAllStableHistory;
                      });
                    },
                    child: Text(
                      _showAllStableHistory
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
                    children: visibleHistory
                        .map(
                          (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _StableCharacterHistoryCard(
                          key: ValueKey(
                            'stable-card-${item.characterName}-${item.glbFileName}-${item.stableAt.millisecondsSinceEpoch}',
                          ),
                          item: item,
                          onTap: () => _showStableCharacterHistoryDialog(item, context),
                        ),
                      ),
                    )
                        .toList(),
                  ),
                );
              },
            ),
            if (completedAchievements.isNotEmpty) const SizedBox(height: 28),
            if (completedAchievements.isNotEmpty)
              _buildAchievementHistorySection(
                completedAchievements,
                visibleAchievements,
                context,
              ),
          ],
        );
      },
    );
  }

  Widget _buildAchievementHistorySection(
      List<Milestone> allAchievements,
      List<Milestone> visibleAchievements,
      BuildContext context,
      ) {
    return _HistorySectionShell(
      title: tr(context, 'Achievement History', 'سجل الإنجازات'),
      subtitle: tr(
        context,
        'Unlocked badges.',
        'الشارات التي تم فتحها.',
      ),
      action: allAchievements.length > _collapsedAchievementHistoryLimit
          ? TextButton(
        onPressed: () {
          setState(() {
            _showAllAchievementHistory = !_showAllAchievementHistory;
          });
        },
        child: Text(
          _showAllAchievementHistory
              ? tr(context, 'See Less', 'عرض أقل')
              : tr(context, 'See More', 'عرض المزيد'),
          style: const TextStyle(
            color: Color(0xFF8E7CFF),
            fontWeight: FontWeight.w700,
          ),
        ),
      )
          : null,
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: visibleAchievements.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 14,
          childAspectRatio: 0.78,
        ),
        itemBuilder: (context, index) {
          final achievement = visibleAchievements[index];
          return _AchievementBadgeCard(
            milestone: achievement,
            onTap: () => _showAchievementDetails(achievement, context),
          );
        },
      ),
    );
  }

  void _showStableCharacterHistoryDialog(
      StableCharacterHistory item,
      BuildContext context,
      ) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) {
        final isAr = isArabic(dialogContext);
        final characterName = isAr
            ? (item.displayNameAr ?? item.characterName)
            : (item.displayNameEn ?? item.characterName);

        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF59A874).withValues(alpha: 0.16),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _PopupCharacterModelPreview(
                  glbFileName: item.glbFileName,
                  height: 180,
                  width: double.infinity,
                ),
                const SizedBox(height: 16),
                Text(
                  characterName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2D2344),
                  ),
                ),
                const SizedBox(height: 14),
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
                        label: tr(dialogContext, 'Archetype', 'النمط'),
                        value: _localizedArchetype(dialogContext, item.archetype),
                      ),
                      const SizedBox(height: 10),
                      _DialogInfoRow(
                        label: tr(dialogContext, 'Stable on', 'تاريخ الاستقرار'),
                        value: _formatDate(item.stableAt),
                        valueColor: const Color(0xFF59A874),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFF59A874),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                    ),
                    child: Text(tr(dialogContext, 'Close', 'إغلاق')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAchievementDetails(Milestone milestone, BuildContext context) {
    final badgeStyle = _AchievementBadgeStyle.fromMilestone(milestone);

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: badgeStyle.mainColor.withValues(alpha: 0.14),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _HexagonBadge(
                size: 94,
                style: badgeStyle,
              ),
              const SizedBox(height: 16),
              Text(
                _milestoneTitle(dialogContext, milestone),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF2D2344),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _milestoneDescription(dialogContext, milestone),
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
                      label: tr(dialogContext, 'Category', 'الفئة'),
                      value: _localizedCategory(dialogContext, milestone.category),
                    ),
                    const SizedBox(height: 10),
                    _DialogInfoRow(
                      label: tr(dialogContext, 'Progress', 'التقدم'),
                      value: '${milestone.currentCount}/${milestone.targetCount}',
                    ),
                    if (milestone.achievedAt != null) ...[
                      const SizedBox(height: 10),
                      _DialogInfoRow(
                        label: tr(dialogContext, 'Unlocked on', 'تم فتحه في'),
                        value: _formatDate(milestone.achievedAt!),
                        valueColor: badgeStyle.mainColor,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: badgeStyle.mainColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(tr(dialogContext, 'Close', 'إغلاق')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _localizedArchetype(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'Manager', 'مدير');
      case 'firefighter':
        return tr(context, 'Firefighter', 'إطفائي');
      case 'exile':
        return tr(context, 'Exile', 'منفى');
      default:
        return archetype;
    }
  }

  String _localizedCategory(BuildContext context, String category) {
    switch (category.toLowerCase()) {
      case 'streak':
        return tr(context, 'Streak', 'السلسلة');
      case 'character_discovery':
        return tr(context, 'Character Discovery', 'اكتشاف الشخصيات');
      case 'stable':
        return tr(context, 'Stability', 'الاستقرار');
      case 'daily':
        return tr(context, 'Daily', 'يومي');
      default:
        return tr(context, 'Achievement', 'إنجاز');
    }
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

class _HistorySectionShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? action;

  const _HistorySectionShell({
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

class _LoadingHistoryCard extends StatelessWidget {
  final String title;

  const _LoadingHistoryCard({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E3FF)),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: Color(0xFF8E7CFF),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D2344),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _EmptyHistoryCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE7E3FF)),
      ),
      child: Column(
        children: [
          const _CircleBadge(
            icon: Icons.history_rounded,
            backgroundColor: Color(0xFFF0EDFF),
            iconColor: Color(0xFF8E7CFF),
            size: 58,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2D2344),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF8F87B3),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _StableCharacterHistoryCard extends StatelessWidget {
  final StableCharacterHistory item;
  final VoidCallback onTap;

  const _StableCharacterHistoryCard({
    super.key,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = isArabic(context);

    final displayName = isAr
        ? (item.displayNameAr ?? item.characterName)
        : (item.displayNameEn ?? item.characterName);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD6EEDD)),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF59A874).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            _StableCharacterCardPreview(
              key: ValueKey(
                'stable-preview-${item.characterName}-${item.glbFileName}-${item.stableAt.millisecondsSinceEpoch}',
              ),
              glbFileName: item.glbFileName,
              height: 108,
              width: 96,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D2344),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HistoryChip(
                        text: _localizedArchetype(context, item.archetype),
                        background: const Color(0xFFF0EDFF),
                        color: const Color(0xFF8E7CFF),
                      ),
                      _HistoryChip(
                        text: '${tr(context, 'Stable', 'مستقرة')} • ${_formatCompactDate(item.stableAt)}',
                        background: const Color(0xFFE8F8EE),
                        color: const Color(0xFF59A874),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFFAEA7C9),
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  String _formatCompactDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _localizedArchetype(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'Manager', 'مدير');
      case 'firefighter':
        return tr(context, 'Firefighter', 'إطفائي');
      case 'exile':
        return tr(context, 'Exile', 'منفى');
      default:
        return archetype;
    }
  }
}

class _StableCharacterCardPreview extends StatelessWidget {
  final String glbFileName;
  final double width;
  final double height;

  const _StableCharacterCardPreview({
    super.key,
    required this.glbFileName,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final modelPath = 'assets/models/$glbFileName';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FBF8),
            Color(0xFFE8F8EE),
          ],
        ),
        border: Border.all(color: const Color(0xFFD8EFE1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: IgnorePointer(
        ignoring: true,
        child: ModelViewer(
          key: ValueKey('card-model-$glbFileName'),
          src: modelPath,
          alt: glbFileName,
          ar: false,
          autoRotate: false,
          cameraControls: false,
          disableZoom: true,
          disableTap: true,
          interactionPrompt: InteractionPrompt.none,
          backgroundColor: const Color(0x00000000),
        ),
      ),
    );
  }
}

class _PopupCharacterModelPreview extends StatelessWidget {
  final String glbFileName;
  final double width;
  final double height;

  const _PopupCharacterModelPreview({
    super.key,
    required this.glbFileName,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final modelPath = 'assets/models/$glbFileName';

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF7FBF8),
            Color(0xFFE8F8EE),
          ],
        ),
        border: Border.all(color: const Color(0xFFD8EFE1)),
      ),
      clipBehavior: Clip.antiAlias,
      child: ModelViewer(
        key: ValueKey('popup-model-$glbFileName'),
        src: modelPath,
        alt: glbFileName,
        ar: false,
        autoRotate: true,
        cameraControls: true,
        disableZoom: true,
        backgroundColor: const Color(0x00000000),
      ),
    );
  }
}

class _AchievementBadgeCard extends StatelessWidget {
  final Milestone milestone;
  final VoidCallback onTap;

  const _AchievementBadgeCard({
    required this.milestone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final style = _AchievementBadgeStyle.fromMilestone(milestone);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 10, 8, 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.66),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.45),
          ),
          boxShadow: [
            BoxShadow(
              color: style.mainColor.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            _HexagonBadge(
              size: 78,
              style: style,
            ),
            const SizedBox(height: 10),
            Text(
              _milestoneTitle(context, milestone),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF3D345F),
                height: 1.18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementBadgeStyle {
  final Color mainColor;
  final Color darkColor;
  final Color lightColor;
  final Color rayColor;
  final Color glowColor;

  const _AchievementBadgeStyle({
    required this.mainColor,
    required this.darkColor,
    required this.lightColor,
    required this.rayColor,
    required this.glowColor,
  });

  factory _AchievementBadgeStyle.fromMilestone(Milestone milestone) {
    final base = _getCategoryColor(milestone.category);
    return _AchievementBadgeStyle(
      mainColor: base,
      darkColor: _shade(base, -0.10),
      lightColor: _shade(base, 0.08),
      rayColor: Colors.white.withValues(alpha: 0.07),
      glowColor: base.withValues(alpha: 0.16),
    );
  }

  static Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'streak':
        return const Color(0xFFFF8A3D);
      case 'character_discovery':
        return const Color(0xFF8E7CFF);
      case 'stable':
        return const Color(0xFF59A874);
      case 'daily':
        return const Color(0xFFB39DFF);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  static Color _shade(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }
}

class _HexagonBadge extends StatelessWidget {
  final double size;
  final _AchievementBadgeStyle style;

  const _HexagonBadge({
    required this.size,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    final height = size * 0.92;

    return SizedBox(
      width: size,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size,
            height: height,
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: style.glowColor,
                  blurRadius: 16,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
          ),
          ClipPath(
            clipper: _HexagonClipper(),
            child: Container(
              width: size,
              height: height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    style.lightColor,
                    style.mainColor,
                    style.darkColor,
                  ],
                ),
              ),
              child: CustomPaint(
                painter: _BadgeRaysPainter(rayColor: style.rayColor),
              ),
            ),
          ),
          ClipPath(
            clipper: _HexagonClipper(),
            child: SizedBox(
              width: size * 0.78,
              height: height * 0.76,
              child: CustomPaint(
                painter: _BadgeRaysPainter(
                  rayColor: style.rayColor,
                ),
              ),
            ),
          ),
          _TrophyMedallion(size: size * 0.5),
        ],
      ),
    );
  }
}

class _TrophyMedallion extends StatelessWidget {
  final double size;

  const _TrophyMedallion({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFD45C).withValues(alpha: 0.16),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: size * 0.94,
            height: size * 0.94,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFE7A1).withValues(alpha: 0.95),
            ),
          ),
          Container(
            width: size * 0.76,
            height: size * 0.76,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFFFD96B),
              border: Border.all(
                color: const Color(0xFFF2BC2F),
                width: 1.6,
              ),
            ),
          ),
          Icon(
            Icons.emoji_events_rounded,
            color: const Color(0xFFC98A06),
            size: size * 0.46,
          ),
        ],
      ),
    );
  }
}

class _BadgeRaysPainter extends CustomPainter {
  final Color rayColor;

  _BadgeRaysPainter({required this.rayColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = math.min(size.width, size.height) * 0.48;
    final innerRadius = outerRadius * 0.22;

    final paint = Paint()
      ..color = rayColor
      ..style = PaintingStyle.fill;

    const int rays = 16;
    for (int i = 0; i < rays; i++) {
      final angle = (2 * math.pi / rays) * i;
      final angle2 = angle + 0.10;

      final p1 = Offset(
        center.dx + math.cos(angle) * innerRadius,
        center.dy + math.sin(angle) * innerRadius,
      );
      final p2 = Offset(
        center.dx + math.cos(angle2) * outerRadius,
        center.dy + math.sin(angle2) * outerRadius,
      );
      final p3 = Offset(
        center.dx + math.cos(angle - 0.10) * outerRadius,
        center.dy + math.sin(angle - 0.10) * outerRadius,
      );

      final path = Path()
        ..moveTo(p1.dx, p1.dy)
        ..lineTo(p2.dx, p2.dy)
        ..lineTo(p3.dx, p3.dy)
        ..close();

      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BadgeRaysPainter oldDelegate) {
    return oldDelegate.rayColor != rayColor;
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
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: TextStyle(
              fontSize: 13,
              color: valueColor ?? const Color(0xFF2D2344),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryChip extends StatelessWidget {
  final String text;
  final Color background;
  final Color color;

  const _HistoryChip({
    required this.text,
    required this.background,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _CircleBadge extends StatelessWidget {
  final IconData icon;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  const _CircleBadge({
    required this.icon,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: iconColor, size: size * 0.46),
    );
  }
}

class _HexagonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    final w = size.width;
    final h = size.height;

    path.moveTo(w * 0.22, 0);
    path.lineTo(w * 0.78, 0);
    path.lineTo(w, h * 0.5);
    path.lineTo(w * 0.78, h);
    path.lineTo(w * 0.22, h);
    path.lineTo(0, h * 0.5);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
