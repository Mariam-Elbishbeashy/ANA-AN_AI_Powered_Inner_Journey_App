import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/progress/presentation/providers/milestone_provider.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_charts.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_achievements.dart';
import 'package:ana_ifs_app/features/progress/presentation/widgets/progress_history.dart';
import '../widgets/mood_visuals.dart';
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
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _selectedTabIndex = 0; // 0 = mood, 1 = achievements, 2 = history
  bool _isMoodLoading = true;

  Map<String, String> _savedMoodsByDate = {};
  Set<String> _autoRetrievedMoodDates = <String>{};

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

      await _loadSavedMoods();
    });
  }

  String? get _uid => _auth.currentUser?.uid;

  Future<void> _loadSavedMoods() async {
    try {
      final uid = _uid;
      if (uid == null) {
        debugPrint('No authenticated user found while loading moods.');
        return;
      }

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final startOfWeek = today.subtract(Duration(days: today.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 7));

      final moodMap = <String, String>{};

      final manualSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('progress_moods')
          .where('dateKey', isGreaterThanOrEqualTo: _dateKey(startOfWeek))
          .where('dateKey', isLessThan: _dateKey(endOfWeek))
          .get();

      for (final doc in manualSnapshot.docs) {
        final data = doc.data();
        final moodKey = _normalizeMoodKey(data['moodKey']);
        final dateKey = (data['dateKey'] ?? doc.id).toString();
        if (moodKey != null) {
          moodMap[dateKey] = moodKey;
        }
      }

      final sessionSnapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('sessions')
          .where('type', isEqualTo: 'video')
          .get();

      final latestSessionByDate = <String, _DailyMoodSession>{};
      final autoRetrievedDates = <String>{};

      for (final doc in sessionSnapshot.docs) {
        final data = doc.data();
        final sessionDateTime = _extractSessionDateTime(data);
        if (sessionDateTime == null) continue;

        final normalizedSessionDate = DateTime(
          sessionDateTime.year,
          sessionDateTime.month,
          sessionDateTime.day,
        );

        if (normalizedSessionDate.isBefore(startOfWeek) ||
            !normalizedSessionDate.isBefore(endOfWeek)) {
          continue;
        }

        final moodKey = await _resolveLatestMoodForSession(
          uid: uid,
          sessionId: doc.id,
          sessionData: data,
        );
        if (moodKey == null) continue;

        final dateKey = _dateKey(normalizedSessionDate);
        final candidate = _DailyMoodSession(
          dateTime: sessionDateTime,
          moodKey: moodKey,
        );

        final current = latestSessionByDate[dateKey];
        if (current == null || candidate.dateTime.isAfter(current.dateTime)) {
          latestSessionByDate[dateKey] = candidate;
        }
      }

      for (final entry in latestSessionByDate.entries) {
        moodMap.putIfAbsent(entry.key, () => entry.value.moodKey);
        autoRetrievedDates.add(entry.key);
      }

      if (mounted) {
        setState(() {
          _savedMoodsByDate = moodMap;
          _autoRetrievedMoodDates = autoRetrievedDates;
        });
      } else {
        _savedMoodsByDate = moodMap;
        _autoRetrievedMoodDates = autoRetrievedDates;
      }
    } catch (e) {
      debugPrint('Error loading saved moods from Firestore: $e');
    }

    if (mounted) {
      setState(() {
        _isMoodLoading = false;
      });
    }
  }

  Future<void> _saveMoodForDate({
    required DateTime date,
    required String moodKey,
  }) async {
    final uid = _uid;
    if (uid == null) {
      debugPrint('No authenticated user found while saving mood.');
      return;
    }

    final normalizedMoodKey = _normalizeMoodKey(moodKey);
    if (normalizedMoodKey == null) {
      debugPrint('Unsupported mood key: $moodKey');
      return;
    }

    final dateKey = _dateKey(date);
    final normalizedDate = DateTime(date.year, date.month, date.day);

    setState(() {
      _savedMoodsByDate[dateKey] = normalizedMoodKey;
    });

    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('progress_moods')
          .doc(dateKey)
          .set({
        'dateKey': dateKey,
        'date': Timestamp.fromDate(normalizedDate),
        'moodKey': normalizedMoodKey,
        'source': 'manual',
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error saving mood to Firestore: $e');
    }
  }

  DateTime? _extractSessionDateTime(Map<String, dynamic> data) {
    final faceEmotion = (data['faceEmotion'] as Map<String, dynamic>?) ?? {};

    final dynamic rawDate = faceEmotion['updatedAt'] ??
        data['updatedAt'] ??
        data['endedAt'] ??
        data['lastMessageAt'] ??
        data['startedAt'];

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is DateTime) {
      return rawDate;
    }

    if (rawDate is String) {
      return DateTime.tryParse(rawDate);
    }

    return null;
  }

  Future<String?> _resolveLatestMoodForSession({
    required String uid,
    required String sessionId,
    required Map<String, dynamic> sessionData,
  }) async {
    return _extractDominantEmotionFromSession(sessionData);
  }

  bool _canUserUpdateDate(DateTime date) {
    final dateKey = _dateKey(date);
    return _autoRetrievedMoodDates.contains(dateKey);
  }

  String? _extractDominantEmotionFromSession(Map<String, dynamic> data) {
    final faceEmotion = (data['faceEmotion'] as Map<String, dynamic>?) ?? {};

    final directCandidates = <dynamic>[
      faceEmotion['dominant'],
    ];

    for (final candidate in directCandidates) {
      final normalized = _normalizeMoodKey(candidate);
      if (normalized != null) {
        return normalized;
      }
    }

    return null;
  }

  String? _normalizeMoodKey(dynamic raw) {
    if (raw == null) return null;

    final normalized = raw
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    const aliases = <String, String>{
      'happiness': 'happy',
      'joy': 'happy',
      'sadness': 'sad',
      'anger': 'angry',
      'surprised': 'surprise',
      'surprize': 'surprise',
      'fearful': 'fear',
      'scared': 'fear',
      'disgusted': 'disgust',
    };

    final resolved = aliases[normalized] ?? normalized;
    return moodVisuals.containsKey(resolved) ? resolved : null;
  }

  String _dateKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    return '${normalized.year.toString().padLeft(4, '0')}-'
        '${normalized.month.toString().padLeft(2, '0')}-'
        '${normalized.day.toString().padLeft(2, '0')}';
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _weekdayLabel(BuildContext context, DateTime date) {
    final isAr = isArabic(context);

    const english = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const arabic = ['الإث', 'الثل', 'الأر', 'الخم', 'الجم', 'السب', 'الأح'];

    final index = date.weekday - 1;
    return isAr ? arabic[index] : english[index];
  }

  String _moodLabel(BuildContext context, String moodKey) {
    final mood = moodVisuals[moodKey];
    if (mood == null) return moodKey;
    return isArabic(context) ? mood.labelAr : mood.labelEn;
  }

  _MoodPalette _paletteForMood({required bool isToday}) {
    return _MoodPalette(
      background: isToday
          ? const Color(0xFFEDE7FF)
          : const Color(0xFFF6F1FF),
      border: isToday
          ? const Color(0xFF7A5AF8)
          : const Color(0xFFD8CBFF),
      icon: isToday
          ? const Color(0xFF7A5AF8)
          : const Color(0xFFC0AFE8),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MilestoneProvider>(
      builder: (context, milestoneProvider, child) {
        if ((milestoneProvider.isLoading &&
            milestoneProvider.milestones.isEmpty) ||
            _isMoodLoading) {
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
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF8E7CFF)),
                  const SizedBox(height: 20),
                  Text(
                    tr(context, 'Loading your progress...', 'جاري تحميل تقدمك...'),
                    style: const TextStyle(color: Color(0xFF4B3A66)),
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
            isLoading:
            milestoneProvider.isLoading &&
                milestoneProvider.milestones.isEmpty,
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
                  _buildWeeklyMoodSection(context),
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
        color: const Color(0xFFFFFFFF).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE7E5FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.08),
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

  Widget _buildWeeklyMoodSection(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE6E3FF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.10),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              tr(context, 'Your Mood This Week', 'مزاجك هذا الأسبوع'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4A3572),
                letterSpacing: 0.2,
              ),
            ),
          ),
          Row(
            children: List.generate(7, (index) {
              final date = startOfWeek.add(Duration(days: index));
              final isToday = _isSameDate(date, today);
              final moodKey = _savedMoodsByDate[_dateKey(date)];
              final hasMood = moodKey != null;
              final palette = _paletteForMood(isToday: isToday);

              final canUserUpdate = isToday && _canUserUpdateDate(date);

              return Expanded(
                child: GestureDetector(
                  onTap: canUserUpdate
                      ? () => _showMoodSelectionDialog(context, date)
                      : null,
                  child: Padding(
                    padding: EdgeInsets.only(right: index == 6 ? 0 : 6),
                    child: Column(
                      children: [
                        Text(
                          _weekdayLabel(context, date),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w500,
                            color: isToday
                                ? const Color(0xFF7A5AF8)
                                : const Color(0xFFA694D6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: palette.background,
                            border: Border.all(
                              color: palette.border,
                              width: isToday ? 2.2 : (hasMood ? 1.8 : 1.4),
                            ),
                            boxShadow: isToday
                                ? [
                              BoxShadow(
                                color: palette.border.withValues(alpha: 0.20),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                                : hasMood
                                ? [
                              BoxShadow(
                                color: palette.border.withValues(alpha: 0.10),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                                : null,
                          ),
                          alignment: Alignment.center,
                          child: hasMood
                              ? ClipOval(
                            child: SizedBox.expand(
                              child: buildMoodSvg(moodKey),
                            ),
                          )
                              : Icon(
                            isToday
                                ? Icons.add_reaction_rounded
                                : Icons.sentiment_neutral_rounded,
                            size: 22,
                            color: palette.icon,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight:
                            isToday ? FontWeight.w700 : FontWeight.w600,
                            color: isToday
                                ? const Color(0xFF6E49F6)
                                : const Color(0xFF9A87CC),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.touch_app_rounded,
                  size: 14,
                  color: Color(0xFF9A87CC),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    tr(
                      context,
                      'Only today with an automatic mood can be updated',
                      'يمكن تحديث اليوم فقط عند وجود مزاج تلقائي',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9A87CC),
                      fontWeight: FontWeight.w500,
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

  void _showMoodSelectionDialog(BuildContext context, DateTime selectedDate) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
        title: Text(
          tr(context, 'Update Today\'s Mood', 'تحديث مزاج اليوم'),
          style: const TextStyle(
            color: Color(0xFF4A3572),
            fontWeight: FontWeight.w700,
          ),
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: moodVisuals.entries.map((entry) {
                final mood = entry.value;

                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF6F1FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE1D6FF)),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.white,
                      child: buildMoodSvg(mood.key, size: 30),
                    ),
                    title: Text(
                      isArabic(context) ? mood.labelAr : mood.labelEn,
                      style: const TextStyle(
                        color: Color(0xFF4A3572),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onTap: () async {
                      Navigator.pop(dialogContext);

                      await _saveMoodForDate(
                        date: selectedDate,
                        moodKey: mood.key,
                      );

                      if (!mounted) return;

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${_moodLabel(context, mood.key)} ${tr(context, 'saved for today', 'تم حفظه لليوم')}',
                          ),
                          backgroundColor: const Color(0xFF7A5AF8),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              tr(context, 'Cancel', 'إلغاء'),
              style: const TextStyle(color: Color(0xFF7A5AF8)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressOverview(
      Map<String, dynamic> stats,
      BuildContext context,
      ) {
    final currentStreak = stats['currentStreak'] as int? ?? 0;
    final totalAchieved = stats['totalAchieved'] as int? ?? 0;
    final totalMilestones = stats['totalMilestones'] as int? ?? 0;
    final percent = totalMilestones == 0
        ? 0.0
        : (totalAchieved / totalMilestones).clamp(0.0, 1.0);

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
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.18),
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
                color: const Color(0xFFF5C9EF).withValues(alpha: 0.55),
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
                color: const Color(0xFFF8D4C8).withValues(alpha: 0.45),
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
                color: const Color(0xFFE8C8F7).withValues(alpha: 0.45),
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
                          color: Colors.white.withValues(alpha: 0.85),
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

class _DailyMoodSession {
  final DateTime dateTime;
  final String moodKey;

  const _DailyMoodSession({
    required this.dateTime,
    required this.moodKey,
  });
}

class _MoodPalette {
  final Color background;
  final Color border;
  final Color icon;

  const _MoodPalette({
    required this.background,
    required this.border,
    required this.icon,
  });
}

class _OverviewMetric extends StatelessWidget {
  final String value;
  final String label;

  const _OverviewMetric({
    required this.value,
    required this.label,
  });

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
                Colors.white.withValues(alpha: 0.22),
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
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFFE9F8FF),
              ),
            ),
          ),
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF7D7AE9).withValues(alpha: 0.96),
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