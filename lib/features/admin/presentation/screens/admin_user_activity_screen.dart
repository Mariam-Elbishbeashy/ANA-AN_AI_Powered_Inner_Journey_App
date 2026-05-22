import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

class AdminUserActivityScreen extends StatefulWidget {
  final String userId;
  final String title;

  const AdminUserActivityScreen({
    super.key,
    required this.userId,
    required this.title,
  });

  @override
  State<AdminUserActivityScreen> createState() =>
      _AdminUserActivityScreenState();
}

class _AdminUserActivityScreenState extends State<AdminUserActivityScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _loading = true;
  Map<String, dynamic> _userData = const {};
  _ActivityStats _stats = const _ActivityStats();
  List<_SessionRow> _recentSessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final userFuture = _firestore
          .collection('users')
          .doc(widget.userId)
          .get();
      final sessionsFuture = _firestore
          .collection('users')
          .doc(widget.userId)
          .collection('sessions')
          .get();
      final milestonesFuture = _firestore
          .collection('user_milestones')
          .where('userId', isEqualTo: widget.userId)
          .get();
      final charsFuture = _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: widget.userId)
          .get();

      final results = await Future.wait([
        userFuture,
        sessionsFuture,
        milestonesFuture,
        charsFuture,
      ]);

      final userDoc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
      final sessionSnap = results[1] as QuerySnapshot<Map<String, dynamic>>;
      final milestoneSnap = results[2] as QuerySnapshot<Map<String, dynamic>>;
      final charsSnap = results[3] as QuerySnapshot<Map<String, dynamic>>;

      final stats = _buildStats(
        sessionSnap.docs,
        milestoneSnap.docs,
        charsSnap.docs,
      );
      final recent = _buildRecentSessions(sessionSnap.docs);

      if (!mounted) return;
      setState(() {
        _userData = userDoc.data() ?? {};
        _stats = stats;
        _recentSessions = recent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  _ActivityStats _buildStats(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sessionDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> milestoneDocs,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> characterDocs,
  ) {
    int chatSessions = 0;
    int voiceSessions = 0;
    int videoSessions = 0;
    int chatMessages = 0;
    int voiceMessages = 0;
    int videoMessages = 0;
    int activeSessions = 0;
    int endedSessions = 0;

    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    int activeLast7Days = 0;

    for (final doc in sessionDocs) {
      final data = doc.data();
      final type = (data['type'] ?? 'chat').toString().trim().toLowerCase();
      final status = (data['status'] ?? '').toString().trim().toLowerCase();
      if (status == 'active') {
        activeSessions += 1;
      } else if (status == 'ended') {
        endedSessions += 1;
      }

      final updatedAt =
          _parseDate(
            data['updatedAt'] ??
                data['endedAt'] ??
                data['lastMessageAt'] ??
                data['startedAt'],
          ) ??
          now;
      if (!updatedAt.isBefore(sevenDaysAgo)) {
        activeLast7Days += 1;
      }

      final messageCount = _asInt(data['messageCount']);
      final fallbackTurns = _asInt(data['userTurnCount']);
      final resolvedMessages = messageCount > 0 ? messageCount : fallbackTurns;

      if (type == 'voice') {
        voiceSessions += 1;
        voiceMessages += resolvedMessages;
      } else if (type == 'video') {
        videoSessions += 1;
        videoMessages += resolvedMessages;
      } else {
        chatSessions += 1;
        chatMessages += resolvedMessages;
      }
    }

    int milestonesCompleted = 0;
    int milestonesTotal = milestoneDocs.length;
    int bestStreak = 0;
    for (final doc in milestoneDocs) {
      final data = doc.data();
      if (data['isCompleted'] == true) milestonesCompleted += 1;
      final streak = _asInt(data['streakDays']);
      if (streak > bestStreak) bestStreak = streak;
    }

    int stableCharacters = 0;
    int activeCharacters = 0;
    int inactiveCharacters = 0;
    for (final doc in characterDocs) {
      final data = doc.data();
      final state = (data['currentState'] ?? '')
          .toString()
          .trim()
          .toLowerCase();
      if (state == 'stable') {
        stableCharacters += 1;
      } else if (state == 'inactive') {
        inactiveCharacters += 1;
      } else {
        activeCharacters += 1;
      }
    }

    return _ActivityStats(
      chatSessions: chatSessions,
      voiceSessions: voiceSessions,
      videoSessions: videoSessions,
      chatMessages: chatMessages,
      voiceMessages: voiceMessages,
      videoMessages: videoMessages,
      activeSessions: activeSessions,
      endedSessions: endedSessions,
      activeLast7Days: activeLast7Days,
      milestonesTotal: milestonesTotal,
      milestonesCompleted: milestonesCompleted,
      bestStreakDays: bestStreak,
      charactersTotal: characterDocs.length,
      charactersStable: stableCharacters,
      charactersActive: activeCharacters,
      charactersInactive: inactiveCharacters,
    );
  }

  List<_SessionRow> _buildRecentSessions(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final rows = docs.map((doc) {
      final data = doc.data();
      final when = _parseDate(
        data['updatedAt'] ??
            data['endedAt'] ??
            data['lastMessageAt'] ??
            data['startedAt'],
      );
      final type = (data['type'] ?? 'chat').toString();
      final status = (data['status'] ?? '-').toString();
      final messages = _asInt(data['messageCount']);
      final turns = _asInt(data['userTurnCount']);
      return _SessionRow(
        id: doc.id,
        type: type,
        status: status,
        timestamp: when,
        messages: messages > 0 ? messages : turns,
      );
    }).toList();

    rows.sort((a, b) {
      final aTs = a.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bTs = b.timestamp ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bTs.compareTo(aTs);
    });
    return rows.take(12).toList();
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  String _fmtDate(DateTime? value) {
    if (value == null) return '-';
    return value.toIso8601String().replaceFirst('T', ' ').substring(0, 16);
  }

  Widget _metricTile({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE7DEFF)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
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

  Widget _quickBadge({required IconData icon, required String text}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EDFF),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE7DEFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF6A5CFF)),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF4B3A66),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firstName = _userData['firstName']?.toString().trim() ?? '';
    final lastName = _userData['lastName']?.toString().trim() ?? '';
    final fullName = [firstName, lastName].where((s) => s.isNotEmpty).join(' ');
    final email = _userData['email']?.toString() ?? widget.userId;
    final lastActivityAt = _fmtDate(_parseDate(_userData['lastActivityAt']));

    return Scaffold(
      backgroundColor: const Color(0xFFF6F3FF),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color(0xFFF6F3FF),
        foregroundColor: const Color(0xFF2A1E3B),
        elevation: 0,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFFFFFF), Color(0xFFF7F2FF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE7DEFF)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(
                            0xFF8E7CFF,
                          ).withValues(alpha: 0.08),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? email : fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          email,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6A5CFF),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${tr(context, 'Last activity', 'آخر نشاط')}: $lastActivityAt',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B3A66),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _quickBadge(
                              icon: Icons.groups_rounded,
                              text:
                                  '${_stats.charactersTotal} ${tr(context, 'characters', 'شخصيات')}',
                            ),
                            _quickBadge(
                              icon: Icons.check_circle_outline_rounded,
                              text:
                                  '${_stats.charactersStable} ${tr(context, 'stable', 'مستقرة')}',
                            ),
                            _quickBadge(
                              icon: Icons.chat_bubble_outline_rounded,
                              text:
                                  '${_stats.chatSessions + _stats.voiceSessions + _stats.videoSessions} ${tr(context, 'sessions', 'جلسات')}',
                            ),
                            _quickBadge(
                              icon: Icons.local_fire_department_outlined,
                              text:
                                  '${_stats.bestStreakDays} ${tr(context, 'days streak', 'أيام سلسلة')}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _metricTile(
                    icon: Icons.chat_bubble_outline_rounded,
                    label: tr(
                      context,
                      'Chat sessions/messages',
                      'جلسات/رسائل الدردشة',
                    ),
                    value: '${_stats.chatSessions} / ${_stats.chatMessages}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.mic_none_rounded,
                    label: tr(
                      context,
                      'Voice sessions/messages',
                      'جلسات/رسائل الصوت',
                    ),
                    value: '${_stats.voiceSessions} / ${_stats.voiceMessages}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.videocam_outlined,
                    label: tr(
                      context,
                      'Video sessions/messages',
                      'جلسات/رسائل الفيديو',
                    ),
                    value: '${_stats.videoSessions} / ${_stats.videoMessages}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.timeline_rounded,
                    label: tr(
                      context,
                      'Active/ended sessions',
                      'الجلسات النشطة/المنتهية',
                    ),
                    value: '${_stats.activeSessions} / ${_stats.endedSessions}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.calendar_month_rounded,
                    label: tr(
                      context,
                      'Sessions in last 7 days',
                      'جلسات آخر 7 أيام',
                    ),
                    value: '${_stats.activeLast7Days}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.emoji_events_outlined,
                    label: tr(
                      context,
                      'Milestones completed/total',
                      'الإنجازات المكتملة/الإجمالي',
                    ),
                    value:
                        '${_stats.milestonesCompleted} / ${_stats.milestonesTotal}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.local_fire_department_outlined,
                    label: tr(
                      context,
                      'Best streak (days)',
                      'أفضل سلسلة (أيام)',
                    ),
                    value: '${_stats.bestStreakDays}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.groups_rounded,
                    label: tr(
                      context,
                      'Characters (Stable/total)',
                      'الشخصيات (مستقرة/إجمالي)',
                    ),
                    value:
                        '${_stats.charactersStable} / ${_stats.charactersTotal}',
                  ),
                  const SizedBox(height: 8),
                  _metricTile(
                    icon: Icons.hub_outlined,
                    label: tr(
                      context,
                      'Character states (active/inactive/stable)',
                      'حالات الشخصيات (نشطة/غير نشطة/مستقرة)',
                    ),
                    value:
                        '${_stats.charactersActive} / ${_stats.charactersInactive} / ${_stats.charactersStable}',
                  ),
                  const SizedBox(height: 18),
                  Text(
                    tr(
                      context,
                      'Recent session activity',
                      'نشاط الجلسات الأخير',
                    ),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (_recentSessions.isEmpty)
                    Text(
                      tr(
                        context,
                        'No session activity yet.',
                        'لا يوجد نشاط جلسات بعد.',
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4B3A66),
                      ),
                    )
                  else
                    ..._recentSessions.map(
                      (row) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE7DEFF)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFF8E7CFF,
                              ).withValues(alpha: 0.04),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              row.type.toLowerCase() == 'video'
                                  ? Icons.videocam_outlined
                                  : row.type.toLowerCase() == 'voice'
                                  ? Icons.mic_none_rounded
                                  : Icons.chat_bubble_outline_rounded,
                              size: 16,
                              color: const Color(0xFF6A5CFF),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${row.type.toUpperCase()} • ${row.status}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2A1E3B),
                                ),
                              ),
                            ),
                            Text(
                              '${tr(context, 'Msgs', 'رسائل')}: ${row.messages}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B3A66),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _fmtDate(row.timestamp),
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFF6A5CFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _SessionRow {
  final String id;
  final String type;
  final String status;
  final DateTime? timestamp;
  final int messages;

  const _SessionRow({
    required this.id,
    required this.type,
    required this.status,
    required this.timestamp,
    required this.messages,
  });
}

class _ActivityStats {
  final int chatSessions;
  final int voiceSessions;
  final int videoSessions;
  final int chatMessages;
  final int voiceMessages;
  final int videoMessages;
  final int activeSessions;
  final int endedSessions;
  final int activeLast7Days;
  final int milestonesTotal;
  final int milestonesCompleted;
  final int bestStreakDays;
  final int charactersTotal;
  final int charactersStable;
  final int charactersActive;
  final int charactersInactive;

  const _ActivityStats({
    this.chatSessions = 0,
    this.voiceSessions = 0,
    this.videoSessions = 0,
    this.chatMessages = 0,
    this.voiceMessages = 0,
    this.videoMessages = 0,
    this.activeSessions = 0,
    this.endedSessions = 0,
    this.activeLast7Days = 0,
    this.milestonesTotal = 0,
    this.milestonesCompleted = 0,
    this.bestStreakDays = 0,
    this.charactersTotal = 0,
    this.charactersStable = 0,
    this.charactersActive = 0,
    this.charactersInactive = 0,
  });
}
