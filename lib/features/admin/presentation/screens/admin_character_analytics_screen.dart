import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

class AdminCharacterAnalyticsScreen extends StatefulWidget {
  const AdminCharacterAnalyticsScreen({super.key});

  @override
  State<AdminCharacterAnalyticsScreen> createState() =>
      _AdminCharacterAnalyticsScreenState();
}

class _AdminCharacterAnalyticsScreenState
    extends State<AdminCharacterAnalyticsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  _CharacterAnalyticsTotals _totals = const _CharacterAnalyticsTotals();
  List<_CharacterAggregate> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final charsFuture = _firestore.collection('user_characters').get();
      final usersFuture = _firestore.collection('users').get();
      final results = await Future.wait([charsFuture, usersFuture]);

      final charDocs = results[0];
      final userDocs = results[1];

      final userBirth = <String, DateTime?>{};
      for (final doc in userDocs.docs) {
        userBirth[doc.id] = _parseBirthdate(doc.data()['birthdate']);
      }

      final byCharacter = <String, _CharacterAccumulator>{};
      int globalStable = 0;
      int globalActive = 0;
      int globalInactive = 0;
      final uniqueUsers = <String>{};

      for (final doc in charDocs.docs) {
        final data = doc.data();
        final userId = (data['userId'] ?? '').toString().trim();
        if (userId.isNotEmpty) uniqueUsers.add(userId);
        final key = _characterKey(data, doc.id);
        final displayName = _characterDisplayName(data, doc.id);
        final acc = byCharacter.putIfAbsent(
          key,
          () => _CharacterAccumulator(name: displayName),
        );
        acc.totalRecords += 1;
        if (userId.isNotEmpty) {
          acc.userIds.add(userId);
          final birthdate = userBirth[userId];
          final age = _ageFromBirthdate(birthdate);
          if (age != null) {
            acc.ageSum += age;
            acc.ageCount += 1;
            if (age < acc.minAge) acc.minAge = age;
            if (age > acc.maxAge) acc.maxAge = age;
          }
        }

        final confidence = _toDouble(data['confidence']);
        if (confidence != null) {
          acc.confidenceSum += confidence;
          acc.confidenceCount += 1;
        }

        final rank = _toInt(data['rank']);
        if (rank != null) {
          acc.rankFrequency[rank] = (acc.rankFrequency[rank] ?? 0) + 1;
        }

        final state = (data['currentState'] ?? 'active')
            .toString()
            .trim()
            .toLowerCase();
        if (state == 'stable') {
          acc.stableCount += 1;
          globalStable += 1;
        } else if (state == 'inactive') {
          acc.inactiveCount += 1;
          globalInactive += 1;
        } else {
          acc.activeCount += 1;
          globalActive += 1;
        }
      }

      final items =
          byCharacter.entries.map((entry) => entry.value.toAggregate()).toList()
            ..sort((a, b) {
              final userCompare = b.uniqueUsers.compareTo(a.uniqueUsers);
              if (userCompare != 0) return userCompare;
              return b.totalRecords.compareTo(a.totalRecords);
            });

      if (!mounted) return;
      setState(() {
        _totals = _CharacterAnalyticsTotals(
          uniqueUsers: uniqueUsers.length,
          characterTypes: items.length,
          totalCharacterRecords: charDocs.docs.length,
          stableRecords: globalStable,
          activeRecords: globalActive,
          inactiveRecords: globalInactive,
        );
        _items = items;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _characterKey(Map<String, dynamic> data, String fallback) {
    final raw =
        (data['characterName'] ??
                data['displayNameEn'] ??
                data['displayName'] ??
                fallback)
            .toString()
            .trim()
            .toLowerCase();
    return raw.replaceAll('-', '_').replaceAll(' ', '_');
  }

  String _characterDisplayName(Map<String, dynamic> data, String fallback) {
    return (data['displayNameEn'] ??
            data['displayName'] ??
            data['characterName'] ??
            fallback)
        .toString();
  }

  String _resolveCharacterAsset(String name) {
    final imageMap = {
      'Inner Critic': 'inner_critic.png',
      'People Pleaser': 'people_pleaser.png',
      'Lonely Part': 'lonely.png',
      'Jealous Part': 'jealous.png',
      'Ashamed Part': 'ashamed.png',
      'Workaholic': 'workaholic.png',
      'Perfectionist': 'perfictionist.png',
      'Procrastinator': 'procrastinator.png',
      'Excessive Gamer': 'excessive_gamer.png',
      'Confused Part': 'confused.png',
      'Dependent Part': 'dependant.png',
      'Fearful Part': 'fearful.png',
      'Neglected Part': 'neglected.png',
      'Overeater': 'overeater_binger.png',
      'Binger': 'overeater_binger.png',
      'Overeater/Binger': 'overeater_binger.png',
      'Overwhelmed Part': 'overwhelmed.png',
      'Stoic Part': 'stoic.png',
      'Wounded Child': 'wounded_child.png',
      'Controller': 'controller.png',
      'Controller Part': 'controller.png',
    };
    if (imageMap.containsKey(name)) {
      return 'assets/images/${imageMap[name]}';
    }
    final lowerName = name.toLowerCase();
    for (final entry in imageMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return 'assets/images/${entry.value}';
      }
    }
    return 'assets/images/inner_critic.png';
  }

  DateTime? _parseBirthdate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int? _ageFromBirthdate(DateTime? birthdate) {
    if (birthdate == null) return null;
    final now = DateTime.now();
    int age = now.year - birthdate.year;
    if (now.month < birthdate.month ||
        (now.month == birthdate.month && now.day < birthdate.day)) {
      age -= 1;
    }
    if (age < 0 || age > 120) return null;
    return age;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  Widget _topTile({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6A5CFF)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B3A66),
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statBlock({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F6FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6A5CFF)),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6A5CFF),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _stateDistributionBar(_CharacterAggregate item) {
    final total = item.activeCount + item.inactiveCount + item.stableCount;
    if (total <= 0) {
      return Container(
        height: 10,
        decoration: BoxDecoration(
          color: const Color(0xFFEDE7FF),
          borderRadius: BorderRadius.circular(999),
        ),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Row(
        children: [
          if (item.activeCount > 0)
            Expanded(
              flex: item.activeCount,
              child: Container(height: 10, color: const Color(0xFF8E7CFF)),
            ),
          if (item.inactiveCount > 0)
            Expanded(
              flex: item.inactiveCount,
              child: Container(height: 10, color: const Color(0xFF9E9E9E)),
            ),
          if (item.stableCount > 0)
            Expanded(
              flex: item.stableCount,
              child: Container(height: 10, color: const Color(0xFF5CB85C)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text(
          tr(context, 'User Character Analytics', 'تحليلات شخصيات المستخدمين'),
        ),
        backgroundColor: const Color(0xFFF6F3FF),
        foregroundColor: const Color(0xFF2A1E3B),
        elevation: 0,
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                _topTile(
                  label: tr(context, 'Unique users', 'عدد المستخدمين'),
                  value: '${_totals.uniqueUsers}',
                  icon: Icons.people_alt_outlined,
                ),
                const SizedBox(height: 8),
                _topTile(
                  label: tr(context, 'Character types', 'أنواع الشخصيات'),
                  value: '${_totals.characterTypes}',
                  icon: Icons.category_outlined,
                ),
                const SizedBox(height: 8),
                _topTile(
                  label: tr(
                    context,
                    'Total character records',
                    'إجمالي سجلات الشخصيات',
                  ),
                  value: '${_totals.totalCharacterRecords}',
                  icon: Icons.dataset_outlined,
                ),
                const SizedBox(height: 8),
                _topTile(
                  label: tr(
                    context,
                    'State distribution (active/inactive/stable)',
                    'توزيع الحالات (نشط/غير نشط/مستقر)',
                  ),
                  value:
                      '${_totals.activeRecords} / ${_totals.inactiveRecords} / ${_totals.stableRecords}',
                  icon: Icons.hub_outlined,
                ),
                const SizedBox(height: 18),
                Text(
                  tr(context, 'Per-character statistics', 'إحصائيات كل شخصية'),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 10),
                if (_items.isEmpty)
                  Text(
                    tr(
                      context,
                      'No character data found.',
                      'لا توجد بيانات شخصيات.',
                    ),
                    style: const TextStyle(color: Color(0xFF4B3A66)),
                  )
                else
                  ..._items.map(
                    (item) => Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5DEFF)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: const Color(0xFFEDE7FF),
                                child: ClipOval(
                                  child: Image.asset(
                                    _resolveCharacterAsset(item.name),
                                    width: 36,
                                    height: 36,
                                    fit: BoxFit.contain,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                              Icons.groups_rounded,
                                              size: 18,
                                              color: Color(0xFF8E7CFF),
                                            ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF2A1E3B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              SizedBox(
                                width: 164,
                                child: _statBlock(
                                  label: tr(context, 'Users', 'المستخدمون'),
                                  value: '${item.uniqueUsers}',
                                  icon: Icons.people_alt_outlined,
                                ),
                              ),
                              SizedBox(
                                width: 164,
                                child: _statBlock(
                                  label: tr(context, 'Age range', 'نطاق العمر'),
                                  value:
                                      item.minAge != null && item.maxAge != null
                                      ? '${item.minAge}-${item.maxAge}'
                                      : '-',
                                  icon: Icons.cake_outlined,
                                ),
                              ),
                              SizedBox(
                                width: 164,
                                child: _statBlock(
                                  label: tr(
                                    context,
                                    'Confidence avg',
                                    'متوسط الثقة',
                                  ),
                                  value: item.avgConfidence != null
                                      ? item.avgConfidence!.toStringAsFixed(2)
                                      : '-',
                                  icon: Icons.insights_outlined,
                                ),
                              ),
                              SizedBox(
                                width: 164,
                                child: _statBlock(
                                  label: tr(
                                    context,
                                    'Most common rank',
                                    'الترتيب الأكثر شيوعًا',
                                  ),
                                  value: item.mostCommonRank != null
                                      ? '${item.mostCommonRank}'
                                      : '-',
                                  icon: Icons.leaderboard_outlined,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          _stateDistributionBar(item),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${tr(context, 'Active', 'نشط')}: ${item.activeCount}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF8E7CFF),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${tr(context, 'Inactive', 'غير نشط')}: ${item.inactiveCount}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF7A6A5A),
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '${tr(context, 'Stable', 'مستقر')}: ${item.stableCount}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF5CB85C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _CharacterAnalyticsTotals {
  final int uniqueUsers;
  final int characterTypes;
  final int totalCharacterRecords;
  final int stableRecords;
  final int activeRecords;
  final int inactiveRecords;

  const _CharacterAnalyticsTotals({
    this.uniqueUsers = 0,
    this.characterTypes = 0,
    this.totalCharacterRecords = 0,
    this.stableRecords = 0,
    this.activeRecords = 0,
    this.inactiveRecords = 0,
  });
}

class _CharacterAccumulator {
  final String name;
  int totalRecords = 0;
  final Set<String> userIds = {};
  int stableCount = 0;
  int activeCount = 0;
  int inactiveCount = 0;
  double confidenceSum = 0;
  int confidenceCount = 0;
  final Map<int, int> rankFrequency = {};
  int ageSum = 0;
  int ageCount = 0;
  int minAge = 999;
  int maxAge = -1;

  _CharacterAccumulator({required this.name});

  _CharacterAggregate toAggregate() {
    int? mostCommonRank;
    if (rankFrequency.isNotEmpty) {
      final entries = rankFrequency.entries.toList()
        ..sort((a, b) {
          final freq = b.value.compareTo(a.value);
          if (freq != 0) return freq;
          return a.key.compareTo(b.key);
        });
      mostCommonRank = entries.first.key;
    }
    return _CharacterAggregate(
      name: name,
      uniqueUsers: userIds.length,
      totalRecords: totalRecords,
      stableCount: stableCount,
      activeCount: activeCount,
      inactiveCount: inactiveCount,
      avgConfidence: confidenceCount > 0
          ? confidenceSum / confidenceCount
          : null,
      mostCommonRank: mostCommonRank,
      avgAge: ageCount > 0 ? ageSum / ageCount : null,
      minAge: ageCount > 0 ? minAge : null,
      maxAge: ageCount > 0 ? maxAge : null,
    );
  }
}

class _CharacterAggregate {
  final String name;
  final int uniqueUsers;
  final int totalRecords;
  final int stableCount;
  final int activeCount;
  final int inactiveCount;
  final double? avgConfidence;
  final int? mostCommonRank;
  final double? avgAge;
  final int? minAge;
  final int? maxAge;

  const _CharacterAggregate({
    required this.name,
    required this.uniqueUsers,
    required this.totalRecords,
    required this.stableCount,
    required this.activeCount,
    required this.inactiveCount,
    required this.avgConfidence,
    required this.mostCommonRank,
    required this.avgAge,
    required this.minAge,
    required this.maxAge,
  });
}
