import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

enum AdminCollectionType { users, questions, answers, characters }

typedef AdminSummaryBuilder =
    String Function(Map<String, dynamic> data, String docId);

class AdminCollectionScreen extends StatefulWidget {
  final String title;
  final CollectionReference<Map<String, dynamic>> collection;
  final Query<Map<String, dynamic>>? listQuery;
  final AdminCollectionType type;
  final AdminSummaryBuilder? summaryBuilder;
  final String emptyMessage;
  final void Function(String userId, Map<String, dynamic> data)? onUserTap;
  final void Function(String userId, Map<String, dynamic> data)?
  onUserAnswersTap;
  final void Function(String userId, Map<String, dynamic> data)?
  onUserActivityTap;
  final String? targetUserId;

  const AdminCollectionScreen({
    super.key,
    required this.title,
    required this.collection,
    this.listQuery,
    required this.type,
    this.summaryBuilder,
    this.onUserTap,
    this.onUserAnswersTap,
    this.onUserActivityTap,
    this.targetUserId,
    this.emptyMessage = 'No items yet.',
  });

  @override
  State<AdminCollectionScreen> createState() => _AdminCollectionScreenState();
}

class _AdminCollectionScreenState extends State<AdminCollectionScreen> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];
  final Map<String, _CharacterSessionStats> _characterStatsByKey = {};
  final Map<String, Map<String, dynamic>> _questionsByKey = {};

  @override
  void initState() {
    super.initState();
    _loadDocs();
  }

  Future<void> _loadDocs() async {
    setState(() => _loading = true);
    final snapshot = await (widget.listQuery ?? widget.collection).get();
    if (!mounted) return;
    final docs = snapshot.docs.toList();
    if (widget.type == AdminCollectionType.questions) {
      docs.sort((a, b) {
        final langA = (a.data()['language']?.toString() ?? 'en').toLowerCase();
        final langB = (b.data()['language']?.toString() ?? 'en').toLowerCase();
        int langRank(String lang) {
          if (lang == 'en') return 0;
          if (lang == 'ar') return 1;
          return 2;
        }

        final langCompare = langRank(langA).compareTo(langRank(langB));
        if (langCompare != 0) return langCompare;

        final numA = a.data()['questionNumber'];
        final numB = b.data()['questionNumber'];
        final intA = numA is num ? numA.toInt() : int.tryParse('$numA') ?? 0;
        final intB = numB is num ? numB.toInt() : int.tryParse('$numB') ?? 0;
        return intA.compareTo(intB);
      });
    }
    if (widget.type == AdminCollectionType.users) {
      DateTime parseActivity(Map<String, dynamic> data) {
        final dynamic raw =
            data['lastActivityAt'] ??
            data['lastActiveAt'] ??
            data['updatedAt'] ??
            data['createdAt'];
        if (raw is Timestamp) return raw.toDate();
        if (raw is DateTime) return raw;
        if (raw is String) {
          return DateTime.tryParse(raw) ??
              DateTime.fromMillisecondsSinceEpoch(0);
        }
        return DateTime.fromMillisecondsSinceEpoch(0);
      }

      docs.sort((a, b) {
        final aDate = parseActivity(a.data());
        final bDate = parseActivity(b.data());
        return bDate.compareTo(aDate);
      });
    }
    final statsByKey = <String, _CharacterSessionStats>{};
    final questionsByKey = <String, Map<String, dynamic>>{};
    if (widget.type == AdminCollectionType.characters &&
        widget.targetUserId != null) {
      try {
        final sessionSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(widget.targetUserId)
            .collection('sessions')
            .get();
        for (final doc in sessionSnap.docs) {
          final data = doc.data();
          final key = _normalizeCharacterKey(data['characterId']);
          if (key == null) continue;
          final type = (data['type'] ?? 'chat').toString().trim().toLowerCase();
          final messageCount = _toInt(data['messageCount']);
          final turnsFallback = _toInt(data['userTurnCount']);
          final resolvedMessages = messageCount > 0
              ? messageCount
              : turnsFallback;
          final current = statsByKey[key] ?? const _CharacterSessionStats();
          if (type == 'voice') {
            statsByKey[key] = current.copyWith(
              voiceSessions: current.voiceSessions + 1,
              voiceMessages: current.voiceMessages + resolvedMessages,
            );
          } else if (type == 'video') {
            statsByKey[key] = current.copyWith(
              videoSessions: current.videoSessions + 1,
              videoMessages: current.videoMessages + resolvedMessages,
            );
          } else {
            statsByKey[key] = current.copyWith(
              chatSessions: current.chatSessions + 1,
              chatMessages: current.chatMessages + resolvedMessages,
            );
          }
        }
      } catch (_) {}
    }
    if (widget.type == AdminCollectionType.answers) {
      try {
        final qSnap = await FirebaseFirestore.instance
            .collection('questions')
            .get();
        for (final qDoc in qSnap.docs) {
          final qData = qDoc.data();
          final key = _questionKey(
            qData['questionNumber'],
            (qData['language'] ?? 'en').toString(),
          );
          questionsByKey[key] = qData;
        }
      } catch (_) {}
    }
    setState(() {
      _docs = docs;
      _characterStatsByKey
        ..clear()
        ..addAll(statsByKey);
      _questionsByKey
        ..clear()
        ..addAll(questionsByKey);
      _loading = false;
    });
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  String? _normalizeCharacterKey(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();
    if (raw == null || raw.isEmpty) return null;
    var key = raw.replaceAll('-', '_').replaceAll(' ', '_');
    if (key.startsWith('the_')) {
      key = key.substring(4);
    }
    return key;
  }

  List<String> _candidateCharacterKeys(
    Map<String, dynamic> data,
    String fallbackDocId,
  ) {
    final out = <String>{
      _normalizeCharacterKey(data['characterId']) ?? '',
      _normalizeCharacterKey(data['characterName']) ?? '',
      _normalizeCharacterKey(data['displayName']) ?? '',
      _normalizeCharacterKey(data['displayNameEn']) ?? '',
      _normalizeCharacterKey(fallbackDocId) ?? '',
    }..removeWhere((e) => e.isEmpty);
    return out.toList();
  }

  String _resolveCharacterAsset(
    Map<String, dynamic> data,
    String fallbackDocId,
  ) {
    final rawName =
        data['characterName']?.toString() ??
        data['displayNameEn']?.toString() ??
        data['displayName']?.toString() ??
        fallbackDocId;
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
    if (imageMap.containsKey(rawName)) {
      return 'assets/images/${imageMap[rawName]}';
    }
    final lowerName = rawName.toLowerCase();
    for (final entry in imageMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return 'assets/images/${entry.value}';
      }
    }
    return 'assets/images/inner_critic.png';
  }

  Widget _smallMetric(String label, int value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF2EDFF),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF4B3A66),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$value',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF2A1E3B),
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Delete item?', 'حذف العنصر؟')),
        content: Text(
          tr(
            context,
            'This action cannot be undone.',
            'لا يمكن التراجع عن هذا الإجراء.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Delete', 'حذف')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await doc.reference.delete();
    await _loadDocs();
  }

  Future<void> _editDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    final result = await _showFormDialog(
      title: tr(context, 'Edit item', 'تعديل العنصر', listen: false),
      initialData: doc.data(),
      allowDocId: false,
    );
    if (result == null) return;
    await doc.reference.set(result.data, SetOptions(merge: true));
    await _loadDocs();
  }

  Future<void> _addDoc() async {
    final result = await _showFormDialog(
      title: tr(context, 'Add new item', 'إضافة عنصر جديد', listen: false),
      initialData: const {},
      allowDocId: true,
    );
    if (result == null) return;
    if (result.docId == null || result.docId!.isEmpty) {
      await widget.collection.add(result.data);
    } else {
      await widget.collection
          .doc(result.docId)
          .set(result.data, SetOptions(merge: true));
    }
    await _loadDocs();
  }

  String _buildSummary(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (widget.summaryBuilder != null) {
      return widget.summaryBuilder!(doc.data(), doc.id);
    }
    return doc.id;
  }

  String _formatTimestamp(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    return value?.toString() ?? '-';
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }

  int _countUsersCreatedInDays(int days) {
    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: days));
    int count = 0;
    for (final doc in _docs) {
      final data = doc.data();
      final createdAt = _parseDate(data['createdAt']);
      if (createdAt != null && !createdAt.isBefore(threshold)) {
        count += 1;
      }
    }
    return count;
  }

  int _countUsersActiveInDays(int days) {
    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: days));
    int count = 0;
    for (final doc in _docs) {
      final data = doc.data();
      final lastActivity = _parseDate(
        data['lastActivityAt'] ?? data['lastActiveAt'] ?? data['updatedAt'],
      );
      if (lastActivity != null && !lastActivity.isBefore(threshold)) {
        count += 1;
      }
    }
    return count;
  }

  int _countUsersInactiveForDays(int days) {
    final now = DateTime.now();
    final threshold = now.subtract(Duration(days: days));
    int count = 0;
    for (final doc in _docs) {
      final data = doc.data();
      final lastActivity = _parseDate(
        data['lastActivityAt'] ?? data['lastActiveAt'] ?? data['updatedAt'],
      );
      if (lastActivity == null || lastActivity.isBefore(threshold)) {
        count += 1;
      }
    }
    return count;
  }

  int _countCompletedQuestionnaireUsers() {
    int count = 0;
    for (final doc in _docs) {
      if (doc.data()['hasCompletedQuestionnaire'] == true) count += 1;
    }
    return count;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _topActiveUsers({
    int limit = 3,
  }) {
    final sorted = [..._docs];
    sorted.sort((a, b) {
      final aData = a.data();
      final bData = b.data();
      final aDate =
          _parseDate(
            aData['lastActivityAt'] ??
                aData['lastActiveAt'] ??
                aData['updatedAt'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final bDate =
          _parseDate(
            bData['lastActivityAt'] ??
                bData['lastActiveAt'] ??
                bData['updatedAt'],
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return sorted.take(limit).toList();
  }

  Widget _insightTile({
    required String label,
    required String value,
    required IconData icon,
    required int index,
  }) {
    final baseDelay = 110 * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 520 + baseDelay),
      curve: Curves.easeOutBack,
      builder: (context, t, child) {
        final slide = (1 - t) * 16;
        return Opacity(
          opacity: t.clamp(0, 1),
          child: Transform.translate(
            offset: Offset(0, slide),
            child: child,
          ),
        );
      },
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF2EAFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE3D8FF)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF6A5CFF).withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Stack(
            children: [
              Positioned(
                bottom: -14,
                left: -10,
                child: Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF9B8CFF).withValues(alpha: 0.10),
                  ),
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6A5CFF).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 26, color: const Color(0xFF6A5CFF)),
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF4B3A66),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsGrid({
    required int new7d,
    required int active7d,
    required int inactive30d,
    required int completionRate,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final tileWidth = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            SizedBox(
              width: tileWidth,
              child: _insightTile(
                label: tr(
                  context,
                  'New users (last 7 days)',
                  'مستخدمون جدد (آخر 7 أيام)',
                ),
                value: '$new7d',
                icon: Icons.person_add_alt_1_rounded,
                index: 0,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _insightTile(
                label: tr(
                  context,
                  'Active users (last 7 days)',
                  'مستخدمون نشطون (آخر 7 أيام)',
                ),
                value: '$active7d',
                icon: Icons.bolt_rounded,
                index: 1,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _insightTile(
                label: tr(
                  context,
                  'Inactive users (30+ days)',
                  'مستخدمون غير نشطين (30+ يوم)',
                ),
                value: '$inactive30d',
                icon: Icons.hourglass_bottom_rounded,
                index: 2,
              ),
            ),
            SizedBox(
              width: tileWidth,
              child: _insightTile(
                label: tr(
                  context,
                  'Questionnaire completion rate',
                  'معدل إكمال الاستبيان',
                ),
                value: '$completionRate%',
                icon: Icons.check_circle_outline_rounded,
                index: 3,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildUsersOverviewHeader() {
    final total = _docs.length;
    final new7d = _countUsersCreatedInDays(7);
    final active7d = _countUsersActiveInDays(7);
    final inactive30d = _countUsersInactiveForDays(30);
    final completed = _countCompletedQuestionnaireUsers();
    final completionRate = total > 0 ? ((completed / total) * 100).round() : 0;
    final topActive = _topActiveUsers(limit: 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'User insights', 'إحصاءات المستخدمين'),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
          ),
          const SizedBox(height: 10),
          _buildInsightsGrid(
            new7d: new7d,
            active7d: active7d,
            inactive30d: inactive30d,
            completionRate: completionRate,
          ),
          if (topActive.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              tr(
                context,
                'Most active users recently',
                'أكثر المستخدمين نشاطًا مؤخرًا',
              ),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A5CFF),
              ),
            ),
            const SizedBox(height: 6),
            ...topActive.map((doc) {
              final d = doc.data();
              final first = d['firstName']?.toString().trim() ?? '';
              final last = d['lastName']?.toString().trim() ?? '';
              final name = [first, last].where((e) => e.isNotEmpty).join(' ');
              final email = d['email']?.toString() ?? doc.id;
              final label = name.isEmpty ? email : name;
              final lastActivity = _formatTimestamp(
                d['lastActivityAt'] ?? d['lastActiveAt'] ?? d['updatedAt'],
              );
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• $label — $lastActivity',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF4B3A66),
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildKeyValue(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _formDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF4B3A66),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5DEFF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5DEFF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF8E7CFF), width: 1.4),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: _formDecoration(label),
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> data, String docId) {
    final first = data['firstName']?.toString().trim() ?? '';
    final last = data['lastName']?.toString().trim() ?? '';
    final displayName = [first, last].where((e) => e.isNotEmpty).join(' ');
    final email = data['email']?.toString() ?? docId;
    final isAdmin = data['isAdmin'] == true;
    final language = data['preferredLanguage']?.toString() ?? '-';
    final createdAt = _formatTimestamp(data['createdAt']);
    final lastActiveAt = _formatTimestamp(
      data['lastActivityAt'] ?? data['lastActiveAt'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.person_rounded, color: Color(0xFF8E7CFF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                displayName.isEmpty ? email : displayName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isAdmin
                    ? const Color(0xFF8E7CFF).withValues(alpha: 0.15)
                    : const Color(0xFFEDE7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAdmin
                    ? tr(context, 'Admin', 'مسؤول')
                    : tr(context, 'User', 'مستخدم'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6A5CFF),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildKeyValue(tr(context, 'Email', 'البريد'), email),
        _buildKeyValue(tr(context, 'Language', 'اللغة'), language),
        _buildKeyValue(tr(context, 'Created', 'تاريخ الإنشاء'), createdAt),
        _buildKeyValue(tr(context, 'Last active', 'آخر نشاط'), lastActiveAt),
        if (widget.onUserTap != null ||
            widget.onUserAnswersTap != null ||
            widget.onUserActivityTap != null)
          Wrap(
            spacing: 4,
            runSpacing: 0,
            children: [
              if (widget.onUserTap != null)
                TextButton.icon(
                  onPressed: () => widget.onUserTap!(docId, data),
                  icon: const Icon(
                    Icons.groups_rounded,
                    size: 16,
                    color: Color(0xFF6A5CFF),
                  ),
                  label: Text(
                    tr(context, 'View characters', 'عرض الشخصيات'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A5CFF),
                    ),
                  ),
                ),
              if (widget.onUserActivityTap != null)
                TextButton.icon(
                  onPressed: () => widget.onUserActivityTap!(docId, data),
                  icon: const Icon(
                    Icons.analytics_outlined,
                    size: 16,
                    color: Color(0xFF6A5CFF),
                  ),
                  label: Text(
                    tr(context, 'View activity', 'عرض النشاط'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A5CFF),
                    ),
                  ),
                ),
              if (widget.onUserAnswersTap != null)
                TextButton.icon(
                  onPressed: () => widget.onUserAnswersTap!(docId, data),
                  icon: const Icon(
                    Icons.fact_check_rounded,
                    size: 16,
                    color: Color(0xFF6A5CFF),
                  ),
                  label: Text(
                    tr(context, 'View answers', 'عرض الإجابات'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF6A5CFF),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _buildQuestionCard(Map<String, dynamic> data, String docId) {
    final number = data['questionNumber']?.toString() ?? docId;
    final text = data['text']?.toString() ?? '';
    final language = data['language']?.toString() ?? '-';
    final type = data['type']?.toString() ?? '-';
    final isSlider = data['isSlider'] == true;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.help_rounded, color: Color(0xFF8E7CFF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Q$number',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            Text(
              language.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A5CFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          text,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 13, color: Color(0xFF4B3A66)),
        ),
        const SizedBox(height: 8),
        _buildKeyValue(tr(context, 'Type', 'النوع'), type),
        _buildKeyValue(
          tr(context, 'Mode', 'النمط'),
          isSlider
              ? tr(context, 'Slider', 'شريط')
              : tr(context, 'Options', 'خيارات'),
        ),
      ],
    );
  }

  Future<void> _showQuestionDetails(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final data = doc.data();
    final number = data['questionNumber']?.toString() ?? doc.id;
    final language = data['language']?.toString() ?? '-';
    final type = data['type']?.toString() ?? '-';
    final text = data['text']?.toString() ?? '';
    final isSlider = data['isSlider'] == true;
    final multipleSelect = data['multipleSelect'] == true;
    final minValue = data['minValue']?.toString() ?? '-';
    final maxValue = data['maxValue']?.toString() ?? '-';
    final options = (data['options'] is List)
        ? (data['options'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final sliderLabels = (data['sliderLabels'] is List)
        ? (data['sliderLabels'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'Question details', 'تفاصيل السؤال')),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildKeyValue(
                  tr(context, 'Question number', 'رقم السؤال'),
                  number,
                ),
                _buildKeyValue(tr(context, 'Language', 'اللغة'), language),
                _buildKeyValue(tr(context, 'Type', 'النوع'), type),
                _buildKeyValue(
                  tr(context, 'Mode', 'النمط'),
                  isSlider
                      ? tr(context, 'Slider', 'شريط')
                      : tr(context, 'Options', 'خيارات'),
                ),
                if (!isSlider)
                  _buildKeyValue(
                    tr(context, 'Multiple select', 'اختيار متعدد'),
                    multipleSelect
                        ? tr(context, 'Yes', 'نعم')
                        : tr(context, 'No', 'لا'),
                  ),
                if (isSlider) ...[
                  _buildKeyValue(tr(context, 'Min', 'أدنى'), minValue),
                  _buildKeyValue(tr(context, 'Max', 'أقصى'), maxValue),
                ],
                const SizedBox(height: 8),
                Text(
                  tr(context, 'Question text', 'نص السؤال'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9F6FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Text(
                    text,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.6,
                      color: Color(0xFF3D2D5A),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!isSlider && options.isNotEmpty) ...[
                  Text(
                    tr(context, 'Options', 'الخيارات'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A6A5A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options
                        .map(
                          (option) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF2EDFF),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFE5DEFF),
                              ),
                            ),
                            child: Text(
                              option,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF4B3A66),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
                if (isSlider && sliderLabels.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    tr(context, 'Slider labels', 'تسميات الشريط'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF7A6A5A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sliderLabels
                        .map(
                          (label) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Text(
                              '• $label',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF4B3A66),
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Close', 'إغلاق')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Edit', 'تعديل')),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _editDoc(doc);
    }
  }

  String _questionKey(dynamic questionNumber, String language) {
    final qn = questionNumber?.toString() ?? '';
    return '$qn::${language.trim().toLowerCase()}';
  }

  List<int> _parseSelectedIndices(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e is num ? e.toInt() : int.tryParse(e.toString()))
          .whereType<int>()
          .toList();
    }
    if (value is String) {
      return value
          .split(',')
          .map((e) => int.tryParse(e.trim()))
          .whereType<int>()
          .toList();
    }
    return const [];
  }

  String? _resolveSelectedOptions(
    Map<String, dynamic> answerData,
    Map<String, dynamic>? questionData,
  ) {
    if (questionData == null) return null;
    final optionsRaw = questionData['options'];
    if (optionsRaw is! List) return null;
    final options = optionsRaw.map((e) => e.toString()).toList();
    final selected = _parseSelectedIndices(answerData['selectedIndices']);
    if (selected.isEmpty) return null;
    final labels = <String>[];
    for (final idx in selected) {
      if (idx >= 0 && idx < options.length) {
        labels.add(options[idx]);
      }
    }
    if (labels.isEmpty) return null;
    return labels.join(' | ');
  }

  String? _resolveSliderLabel(
    Map<String, dynamic> answerData,
    Map<String, dynamic>? questionData,
  ) {
    if (questionData == null) return null;
    final labelsRaw = questionData['sliderLabels'];
    if (labelsRaw is! List || labelsRaw.isEmpty) return null;
    final labels = labelsRaw.map((e) => e.toString()).toList();
    final minVal = _toInt(questionData['minValue']);
    final maxVal = _toInt(questionData['maxValue']);
    final sliderRaw = answerData['sliderValue'];
    final sliderValue = sliderRaw is num
        ? sliderRaw.toDouble()
        : double.tryParse('$sliderRaw');
    if (sliderValue == null) return null;
    final range = (maxVal - minVal).abs();
    if (range == 0) return labels.first;
    final normalized = ((sliderValue - minVal) / range).clamp(0.0, 1.0);
    final idx = (normalized * (labels.length - 1)).round().clamp(
      0,
      labels.length - 1,
    );
    return labels[idx];
  }

  Widget _buildAnswerCard(Map<String, dynamic> data, String docId) {
    final number = data['questionNumber']?.toString() ?? '-';
    final language = data['language']?.toString() ?? 'en';
    final answerText = data['answerText']?.toString();
    final slider = data['sliderValue']?.toString();
    final selected = data['selectedIndices']?.toString();
    final answeredAt = _formatTimestamp(data['answeredAt']);
    final qData =
        _questionsByKey[_questionKey(data['questionNumber'], language)];
    final qText = qData?['text']?.toString();
    final selectedReadable = _resolveSelectedOptions(data, qData);
    final sliderReadable = _resolveSliderLabel(data, qData);
    final isSlider = qData?['isSlider'] == true;
    final options = (qData?['options'] is List)
        ? (qData!['options'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final selectedIndices = _parseSelectedIndices(
      data['selectedIndices'],
    ).toSet();
    final sliderLabels = (qData?['sliderLabels'] is List)
        ? (qData!['sliderLabels'] as List).map((e) => e.toString()).toList()
        : <String>[];
    final sliderValue = _toDouble(data['sliderValue']);
    final sliderMin = _toDouble(qData?['minValue']) ?? 0.0;
    final sliderMax = _toDouble(qData?['maxValue']) ?? 10.0;
    final normalizedSlider = (() {
      if (sliderValue == null) return null;
      final range = (sliderMax - sliderMin).abs();
      if (range <= 0) return 0.0;
      return ((sliderValue - sliderMin) / range).clamp(0.0, 1.0);
    })();
    final resolvedAnswer = (() {
      if (answerText != null && answerText.trim().isNotEmpty) {
        return answerText.trim();
      }
      if (selectedReadable != null && selectedReadable.trim().isNotEmpty) {
        return selectedReadable.trim();
      }
      if (sliderReadable != null && sliderReadable.trim().isNotEmpty) {
        return sliderReadable.trim();
      }
      if (slider != null && slider.trim().isNotEmpty) {
        return slider.trim();
      }
      if (selected != null && selected.trim().isNotEmpty) {
        return selected.trim();
      }
      return tr(context, 'No answer value', 'لا توجد إجابة');
    })();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_rounded, color: Color(0xFF8E7CFF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                tr(context, 'Question', 'السؤال'),
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            Text(
              'Q$number',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF6A5CFF),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (qText != null && qText.trim().isNotEmpty)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Text(
              qText,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D2D5A),
              ),
            ),
          ),
        if (!isSlider && options.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            tr(context, 'Options', 'الخيارات'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6A5CFF),
            ),
          ),
          const SizedBox(height: 6),
          ...options.asMap().entries.map((entry) {
            final idx = entry.key;
            final text = entry.value;
            final isSelected = selectedIndices.contains(idx);
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF8E7CFF).withValues(alpha: 0.16)
                    : const Color(0xFFF9F6FF),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF8E7CFF)
                      : const Color(0xFFE5DEFF),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 15,
                    color: isSelected
                        ? const Color(0xFF6A5CFF)
                        : const Color(0xFF9A8CBC),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w600,
                        color: const Color(0xFF3D2D5A),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
        if (isSlider) ...[
          const SizedBox(height: 2),
          Text(
            tr(context, 'Slider response', 'إجابة المؤشر'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6A5CFF),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6FF),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LinearProgressIndicator(
                  value: normalizedSlider,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(999),
                  backgroundColor: const Color(0xFFE5DEFF),
                  color: const Color(0xFF8E7CFF),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      sliderMin.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6A5CFF),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      sliderMax.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF6A5CFF),
                      ),
                    ),
                  ],
                ),
                if (sliderLabels.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    sliderReadable ?? tr(context, 'No label', 'بدون تصنيف'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF3D2D5A),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          tr(context, 'User answer', 'إجابة المستخدم'),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF6A5CFF),
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFFF2EDFF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE5DEFF)),
          ),
          child: Text(
            resolvedAnswer,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF3D2D5A),
            ),
          ),
        ),
        if (selectedReadable != null &&
            selectedReadable.isNotEmpty &&
            selectedReadable.trim() != resolvedAnswer.trim())
          _buildKeyValue(
            tr(context, 'Selected answer', 'الإجابة المختارة'),
            selectedReadable,
          ),
        if (sliderReadable != null &&
            sliderReadable.isNotEmpty &&
            sliderReadable.trim() != resolvedAnswer.trim())
          _buildKeyValue(
            tr(context, 'Slider interpretation', 'تفسير المؤشر'),
            sliderReadable,
          ),
        _buildKeyValue(
          tr(context, 'Language', 'اللغة'),
          language.toUpperCase(),
        ),
        _buildKeyValue(tr(context, 'Answered', 'وقت الإجابة'), answeredAt),
      ],
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> data, String docId) {
    final name =
        data['displayName']?.toString() ??
        data['characterName']?.toString() ??
        docId;
    final archetype = data['archetype']?.toString() ?? '-';
    final rank = data['rank']?.toString() ?? '-';
    final userId = data['userId']?.toString() ?? '-';
    final currentState = (data['currentState'] ?? 'active')
        .toString()
        .trim()
        .toLowerCase();
    final predictedAt = _formatTimestamp(data['predictedAt']);
    final keys = _candidateCharacterKeys(data, docId);
    _CharacterSessionStats stats = const _CharacterSessionStats();
    for (final key in keys) {
      final found = _characterStatsByKey[key];
      if (found != null) {
        stats = found;
        break;
      }
    }
    final imagePath = _resolveCharacterAsset(data, docId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEDE7FF),
              child: ClipOval(
                child: Image.asset(
                  imagePath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Icon(
                    Icons.groups_rounded,
                    color: Color(0xFF8E7CFF),
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: currentState == 'stable'
                    ? const Color(0xFF5CB85C).withValues(alpha: 0.15)
                    : currentState == 'inactive'
                    ? const Color(0xFF9E9E9E).withValues(alpha: 0.2)
                    : const Color(0xFF8E7CFF).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                currentState == 'stable'
                    ? tr(context, 'Stable', 'مستقرة')
                    : currentState == 'inactive'
                    ? tr(context, 'Inactive', 'غير نشط')
                    : tr(context, 'Active', 'نشط'),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildKeyValue(tr(context, 'User', 'المستخدم'), userId),
        _buildKeyValue(tr(context, 'Archetype', 'النمط'), archetype),
        _buildKeyValue(tr(context, 'Rank', 'الترتيب'), rank),
        _buildKeyValue(tr(context, 'Predicted', 'تم التوقع'), predictedAt),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _smallMetric(
              tr(context, 'Chat sessions', 'جلسات الدردشة'),
              stats.chatSessions,
            ),
            _smallMetric(
              tr(context, 'Chat messages', 'رسائل الدردشة'),
              stats.chatMessages,
            ),
            _smallMetric(
              tr(context, 'Voice sessions', 'جلسات الصوت'),
              stats.voiceSessions,
            ),
            _smallMetric(
              tr(context, 'Voice messages', 'رسائل الصوت'),
              stats.voiceMessages,
            ),
            _smallMetric(
              tr(context, 'Video sessions', 'جلسات الفيديو'),
              stats.videoSessions,
            ),
            _smallMetric(
              tr(context, 'Video messages', 'رسائل الفيديو'),
              stats.videoMessages,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFriendlyBody(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    switch (widget.type) {
      case AdminCollectionType.users:
        return _buildUserCard(doc.data(), doc.id);
      case AdminCollectionType.questions:
        return _buildQuestionCard(doc.data(), doc.id);
      case AdminCollectionType.answers:
        return _buildAnswerCard(doc.data(), doc.id);
      case AdminCollectionType.characters:
        return _buildCharacterCard(doc.data(), doc.id);
    }
  }

  Future<_FormResult?> _showFormDialog({
    required String title,
    required Map<String, dynamic> initialData,
    required bool allowDocId,
  }) async {
    switch (widget.type) {
      case AdminCollectionType.users:
        return _showUserForm(title, initialData, allowDocId);
      case AdminCollectionType.questions:
        return _showQuestionForm(title, initialData, allowDocId);
      case AdminCollectionType.answers:
        return _showAnswerForm(title, initialData, allowDocId);
      case AdminCollectionType.characters:
        return _showCharacterForm(title, initialData, allowDocId);
    }
  }

  Future<_FormResult?> _showUserForm(
    String title,
    Map<String, dynamic> initial,
    bool allowDocId,
  ) async {
    final idController = TextEditingController();
    final firstName = TextEditingController(
      text: initial['firstName']?.toString() ?? '',
    );
    final lastName = TextEditingController(
      text: initial['lastName']?.toString() ?? '',
    );
    final email = TextEditingController(
      text: initial['email']?.toString() ?? '',
    );
    final language = TextEditingController(
      text: initial['preferredLanguage']?.toString() ?? '',
    );
    final birthdate = TextEditingController(
      text: initial['birthdate']?.toString() ?? '',
    );
    bool isAdmin = initial['isAdmin'] == true;
    bool hasCompleted = initial['hasCompletedQuestionnaire'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (allowDocId)
                  _formField(
                    controller: idController,
                    label: tr(context, 'User ID (optional)', 'معرّف المستخدم'),
                  ),
                _formField(
                  controller: firstName,
                  label: tr(context, 'First name', 'الاسم الأول'),
                ),
                _formField(
                  controller: lastName,
                  label: tr(context, 'Last name', 'اسم العائلة'),
                ),
                _formField(
                  controller: email,
                  label: tr(context, 'Email', 'البريد الإلكتروني'),
                  keyboardType: TextInputType.emailAddress,
                ),
                _formField(
                  controller: language,
                  label: tr(context, 'Language', 'اللغة'),
                ),
                _formField(
                  controller: birthdate,
                  label: tr(context, 'Birthdate (YYYY-MM-DD)', 'تاريخ الميلاد'),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: isAdmin,
                  onChanged: (value) => isAdmin = value,
                  title: Text(tr(context, 'Admin', 'مسؤول')),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: hasCompleted,
                  onChanged: (value) => hasCompleted = value,
                  title: Text(
                    tr(context, 'Completed questionnaire', 'أكمل الاستبيان'),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Save', 'حفظ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    return _FormResult(
      docId: allowDocId ? idController.text.trim() : null,
      data: {
        'firstName': firstName.text.trim(),
        'lastName': lastName.text.trim().isEmpty ? null : lastName.text.trim(),
        'email': email.text.trim().toLowerCase(),
        'preferredLanguage': language.text.trim().isEmpty
            ? null
            : language.text.trim(),
        'birthdate': birthdate.text.trim().isEmpty
            ? null
            : birthdate.text.trim(),
        'isAdmin': isAdmin,
        'hasCompletedQuestionnaire': hasCompleted,
        'updatedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<_FormResult?> _showQuestionForm(
    String title,
    Map<String, dynamic> initial,
    bool allowDocId,
  ) async {
    final idController = TextEditingController();
    final number = TextEditingController(
      text: initial['questionNumber']?.toString() ?? '',
    );
    final language = TextEditingController(
      text: initial['language']?.toString() ?? '',
    );
    final text = TextEditingController(text: initial['text']?.toString() ?? '');
    final type = TextEditingController(text: initial['type']?.toString() ?? '');
    bool isSlider = initial['isSlider'] == true;
    bool multipleSelect = initial['multipleSelect'] == true;
    final minValue = TextEditingController(
      text: initial['minValue']?.toString() ?? '',
    );
    final maxValue = TextEditingController(
      text: initial['maxValue']?.toString() ?? '',
    );
    final options = TextEditingController(
      text: (initial['options'] is List)
          ? (initial['options'] as List).join('\n')
          : '',
    );
    final sliderLabels = TextEditingController(
      text: (initial['sliderLabels'] is List)
          ? (initial['sliderLabels'] as List).join('\n')
          : '',
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (allowDocId)
                  _formField(
                    controller: idController,
                    label: tr(
                      context,
                      'Question ID (optional)',
                      'معرّف السؤال',
                    ),
                  ),
                _formField(
                  controller: number,
                  keyboardType: TextInputType.number,
                  label: tr(context, 'Question number', 'رقم السؤال'),
                ),
                _formField(
                  controller: language,
                  label: tr(context, 'Language', 'اللغة'),
                ),
                _formField(
                  controller: text,
                  maxLines: 4,
                  label: tr(context, 'Question text', 'نص السؤال'),
                ),
                _formField(
                  controller: type,
                  label: tr(context, 'Type (optional)', 'النوع (اختياري)'),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: isSlider,
                  onChanged: (value) => isSlider = value,
                  title: Text(tr(context, 'Slider question', 'سؤال شريطي')),
                  contentPadding: EdgeInsets.zero,
                ),
                if (!isSlider) ...[
                  SwitchListTile(
                    value: multipleSelect,
                    onChanged: (value) => multipleSelect = value,
                    title: Text(tr(context, 'Multiple select', 'اختيار متعدد')),
                    contentPadding: EdgeInsets.zero,
                  ),
                  _formField(
                    controller: options,
                    label: tr(
                      context,
                      'Options (one per line)',
                      'الخيارات (كل سطر خيار)',
                    ),
                    maxLines: 5,
                  ),
                ],
                if (isSlider) ...[
                  _formField(
                    controller: minValue,
                    keyboardType: TextInputType.number,
                    label: tr(context, 'Min value', 'الحد الأدنى'),
                  ),
                  _formField(
                    controller: maxValue,
                    keyboardType: TextInputType.number,
                    label: tr(context, 'Max value', 'الحد الأقصى'),
                  ),
                  _formField(
                    controller: sliderLabels,
                    label: tr(
                      context,
                      'Slider labels (one per line)',
                      'تسميات الشريط',
                    ),
                    maxLines: 3,
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Save', 'حفظ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    final parsedOptions = options.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final parsedLabels = sliderLabels.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    return _FormResult(
      docId: allowDocId ? idController.text.trim() : null,
      data: {
        'questionNumber': int.tryParse(number.text.trim()) ?? 0,
        'language': language.text.trim().isEmpty ? 'en' : language.text.trim(),
        'text': text.text.trim(),
        'type': type.text.trim().isEmpty ? null : type.text.trim(),
        'isSlider': isSlider,
        'multipleSelect': isSlider ? false : multipleSelect,
        'minValue': isSlider ? int.tryParse(minValue.text.trim()) : null,
        'maxValue': isSlider ? int.tryParse(maxValue.text.trim()) : null,
        'options': isSlider ? [] : parsedOptions,
        'sliderLabels': isSlider ? parsedLabels : [],
      },
    );
  }

  Future<_FormResult?> _showAnswerForm(
    String title,
    Map<String, dynamic> initial,
    bool allowDocId,
  ) async {
    final idController = TextEditingController();
    final userId = TextEditingController(
      text: initial['userId']?.toString() ?? '',
    );
    final questionNumber = TextEditingController(
      text: initial['questionNumber']?.toString() ?? '',
    );
    final answerText = TextEditingController(
      text: initial['answerText']?.toString() ?? '',
    );
    final sliderValue = TextEditingController(
      text: initial['sliderValue']?.toString() ?? '',
    );
    final selectedIndices = TextEditingController(
      text: (initial['selectedIndices'] is Iterable)
          ? (initial['selectedIndices'] as Iterable).join(',')
          : (initial['selectedIndices']?.toString() ?? ''),
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (allowDocId)
                  _formField(
                    controller: idController,
                    label: tr(context, 'Answer ID (optional)', 'معرّف الإجابة'),
                  ),
                _formField(
                  controller: userId,
                  label: tr(context, 'User ID', 'معرّف المستخدم'),
                ),
                _formField(
                  controller: questionNumber,
                  keyboardType: TextInputType.number,
                  label: tr(context, 'Question number', 'رقم السؤال'),
                ),
                _formField(
                  controller: answerText,
                  maxLines: 3,
                  label: tr(context, 'Answer text', 'نص الإجابة'),
                ),
                _formField(
                  controller: sliderValue,
                  keyboardType: TextInputType.number,
                  label: tr(context, 'Slider value', 'قيمة المؤشر'),
                ),
                _formField(
                  controller: selectedIndices,
                  label: tr(
                    context,
                    'Selected indices (comma)',
                    'الاختيارات (فاصلة)',
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Save', 'حفظ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;

    final parsedSelected = selectedIndices.text
        .split(',')
        .map((e) => int.tryParse(e.trim()))
        .whereType<int>()
        .toList();

    return _FormResult(
      docId: allowDocId ? idController.text.trim() : null,
      data: {
        'userId': userId.text.trim(),
        'questionNumber': int.tryParse(questionNumber.text.trim()) ?? 0,
        'answerText': answerText.text.trim().isEmpty
            ? null
            : answerText.text.trim(),
        'sliderValue': double.tryParse(sliderValue.text.trim()),
        'selectedIndices': parsedSelected,
        'answeredAt': DateTime.now().toIso8601String(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<_FormResult?> _showCharacterForm(
    String title,
    Map<String, dynamic> initial,
    bool allowDocId,
  ) async {
    final idController = TextEditingController();
    final displayName = TextEditingController(
      text: initial['displayName']?.toString() ?? '',
    );
    final characterName = TextEditingController(
      text: initial['characterName']?.toString() ?? '',
    );
    final archetype = TextEditingController(
      text: initial['archetype']?.toString() ?? '',
    );
    final rank = TextEditingController(text: initial['rank']?.toString() ?? '');
    final userId = TextEditingController(
      text: initial['userId']?.toString() ?? '',
    );
    final glbFile = TextEditingController(
      text: initial['glbFileName']?.toString() ?? '',
    );
    final description = TextEditingController(
      text: initial['description']?.toString() ?? '',
    );
    final language = TextEditingController(
      text: initial['language']?.toString() ?? 'en',
    );
    final confidence = TextEditingController(
      text: initial['confidence']?.toString() ?? '0.8',
    );
    bool isHealed = initial['isHealed'] == true;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (allowDocId)
                  _formField(
                    controller: idController,
                    label: tr(
                      context,
                      'Character ID (optional)',
                      'معرّف الشخصية',
                    ),
                  ),
                _formField(
                  controller: displayName,
                  label: tr(context, 'Display name', 'الاسم الظاهر'),
                ),
                _formField(
                  controller: characterName,
                  label: tr(context, 'Character name', 'اسم الشخصية'),
                ),
                _formField(
                  controller: archetype,
                  label: tr(context, 'Archetype', 'النمط'),
                ),
                _formField(
                  controller: rank,
                  keyboardType: TextInputType.number,
                  label: tr(context, 'Rank', 'الترتيب'),
                ),
                _formField(
                  controller: userId,
                  label: tr(context, 'User ID', 'معرّف المستخدم'),
                ),
                _formField(
                  controller: glbFile,
                  label: tr(context, 'GLB file name', 'ملف GLB'),
                ),
                _formField(
                  controller: description,
                  maxLines: 2,
                  label: tr(context, 'Description', 'الوصف'),
                ),
                _formField(
                  controller: language,
                  label: tr(context, 'Language', 'اللغة'),
                ),
                _formField(
                  controller: confidence,
                  keyboardType: TextInputType.number,
                  label: tr(context, 'Confidence', 'الثقة'),
                ),
                const SizedBox(height: 4),
                SwitchListTile(
                  value: isHealed,
                  onChanged: (value) => isHealed = value,
                  title: Text(tr(context, 'Healed', 'تم الشفاء')),
                  contentPadding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Cancel', 'إلغاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'Save', 'حفظ')),
          ),
        ],
      ),
    );
    if (confirmed != true) return null;
    final now = DateTime.now();
    return _FormResult(
      docId: allowDocId ? idController.text.trim() : null,
      data: {
        'displayName': displayName.text.trim(),
        'characterName': characterName.text.trim(),
        'archetype': archetype.text.trim(),
        'rank': int.tryParse(rank.text.trim()) ?? 0,
        'userId': userId.text.trim(),
        'glbFileName': glbFile.text.trim(),
        'description': description.text.trim(),
        'language': language.text.trim().isEmpty ? 'en' : language.text.trim(),
        'confidence': double.tryParse(confidence.text.trim()) ?? 0.8,
        'predictedAt': initial['predictedAt'] ?? now.toIso8601String(),
        'isHealed': isHealed,
        'healedAt': isHealed ? now.toIso8601String() : null,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          widget.title,
          style: const TextStyle(
            color: Color(0xFF2A1E3B),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _loadDocs,
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF8E7CFF)),
          ),
          IconButton(
            onPressed: _addDoc,
            icon: const Icon(
              Icons.add_circle_rounded,
              color: Color(0xFF8E7CFF),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
            )
          : _docs.isEmpty
          ? Center(
              child: Text(
                widget.emptyMessage,
                style: const TextStyle(color: Color(0xFF7A6A5A)),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.type == AdminCollectionType.users
                  ? _docs.length + 1
                  : _docs.length,
              itemBuilder: (context, index) {
                if (widget.type == AdminCollectionType.users && index == 0) {
                  return _buildUsersOverviewHeader();
                }
                final docIndex = widget.type == AdminCollectionType.users
                    ? index - 1
                    : index;
                final doc = _docs[docIndex];
                final card = Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 6,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _buildSummary(doc),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => _editDoc(doc),
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Color(0xFF8E7CFF),
                            ),
                            tooltip: tr(context, 'Edit', 'تعديل'),
                          ),
                          IconButton(
                            onPressed: () => _deleteDoc(doc),
                            icon: const Icon(
                              Icons.delete_rounded,
                              color: Color(0xFFD9534F),
                            ),
                            tooltip: tr(context, 'Delete', 'حذف'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildFriendlyBody(doc),
                    ],
                  ),
                );
                if (widget.type == AdminCollectionType.questions) {
                  return GestureDetector(
                    onTap: () => _showQuestionDetails(doc),
                    child: card,
                  );
                }
                return card;
              },
            ),
    );
  }
}

class _FormResult {
  final String? docId;
  final Map<String, dynamic> data;

  const _FormResult({required this.docId, required this.data});
}

class _CharacterSessionStats {
  final int chatSessions;
  final int voiceSessions;
  final int videoSessions;
  final int chatMessages;
  final int voiceMessages;
  final int videoMessages;

  const _CharacterSessionStats({
    this.chatSessions = 0,
    this.voiceSessions = 0,
    this.videoSessions = 0,
    this.chatMessages = 0,
    this.voiceMessages = 0,
    this.videoMessages = 0,
  });

  _CharacterSessionStats copyWith({
    int? chatSessions,
    int? voiceSessions,
    int? videoSessions,
    int? chatMessages,
    int? voiceMessages,
    int? videoMessages,
  }) {
    return _CharacterSessionStats(
      chatSessions: chatSessions ?? this.chatSessions,
      voiceSessions: voiceSessions ?? this.voiceSessions,
      videoSessions: videoSessions ?? this.videoSessions,
      chatMessages: chatMessages ?? this.chatMessages,
      voiceMessages: voiceMessages ?? this.voiceMessages,
      videoMessages: videoMessages ?? this.videoMessages,
    );
  }
}
