import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

enum AdminCollectionType { users, questions, answers, characters }

typedef AdminSummaryBuilder = String Function(
  Map<String, dynamic> data,
  String docId,
);

class AdminCollectionScreen extends StatefulWidget {
  final String title;
  final CollectionReference<Map<String, dynamic>> collection;
  final Query<Map<String, dynamic>>? listQuery;
  final AdminCollectionType type;
  final AdminSummaryBuilder? summaryBuilder;
  final String emptyMessage;
  final void Function(String userId, Map<String, dynamic> data)? onUserTap;
  final void Function(String userId, Map<String, dynamic> data)? onUserAnswersTap;

  const AdminCollectionScreen({
    super.key,
    required this.title,
    required this.collection,
    this.listQuery,
    required this.type,
    this.summaryBuilder,
    this.onUserTap,
    this.onUserAnswersTap,
    this.emptyMessage = 'No items yet.',
  });

  @override
  State<AdminCollectionScreen> createState() => _AdminCollectionScreenState();
}

class _AdminCollectionScreenState extends State<AdminCollectionScreen> {
  bool _loading = true;
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _docs = [];

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
    setState(() {
      _docs = docs;
      _loading = false;
    });
  }

  Future<void> _deleteDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
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

  Future<void> _editDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final result = await _showFormDialog(
      title: tr(
        context,
        'Edit item',
        'تعديل العنصر',
        listen: false,
      ),
      initialData: doc.data(),
      allowDocId: false,
    );
    if (result == null) return;
    await doc.reference.set(result.data, SetOptions(merge: true));
    await _loadDocs();
  }

  Future<void> _addDoc() async {
    final result = await _showFormDialog(
      title: tr(
        context,
        'Add new item',
        'إضافة عنصر جديد',
        listen: false,
      ),
      initialData: const {},
      allowDocId: true,
    );
    if (result == null) return;
    if (result.docId == null || result.docId!.isEmpty) {
      await widget.collection.add(result.data);
    } else {
      await widget.collection.doc(result.docId).set(
            result.data,
            SetOptions(merge: true),
          );
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
    final lastActiveAt = _formatTimestamp(data['lastActiveAt']);

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
                    ? const Color(0xFF8E7CFF).withOpacity(0.15)
                    : const Color(0xFFEDE7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isAdmin ? tr(context, 'Admin', 'مسؤول') : tr(context, 'User', 'مستخدم'),
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
        if (widget.onUserTap != null || widget.onUserAnswersTap != null)
          Row(
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
          isSlider ? tr(context, 'Slider', 'شريط') : tr(context, 'Options', 'خيارات'),
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
                    multipleSelect ? tr(context, 'Yes', 'نعم') : tr(context, 'No', 'لا'),
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
                              border: Border.all(color: const Color(0xFFE5DEFF)),
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

  Widget _buildAnswerCard(Map<String, dynamic> data, String docId) {
    final userId = data['userId']?.toString() ?? '-';
    final number = data['questionNumber']?.toString() ?? '-';
    final answerText = data['answerText']?.toString();
    final slider = data['sliderValue']?.toString();
    final selected = data['selectedIndices']?.toString();
    final answeredAt = _formatTimestamp(data['answeredAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.fact_check_rounded, color: Color(0xFF8E7CFF)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'User $userId',
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
        if (answerText != null && answerText.isNotEmpty)
          Text(
            answerText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: Color(0xFF4B3A66)),
          ),
        if (slider != null) _buildKeyValue('Slider', slider),
        if (selected != null) _buildKeyValue('Selected', selected),
        _buildKeyValue(tr(context, 'Answered', 'وقت الإجابة'), answeredAt),
      ],
    );
  }

  Widget _buildCharacterCard(Map<String, dynamic> data, String docId) {
    final name = data['displayName']?.toString() ??
        data['characterName']?.toString() ??
        docId;
    final archetype = data['archetype']?.toString() ?? '-';
    final rank = data['rank']?.toString() ?? '-';
    final userId = data['userId']?.toString() ?? '-';
    final isHealed = data['isHealed'] == true;
    final predictedAt = _formatTimestamp(data['predictedAt']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.groups_rounded, color: Color(0xFF8E7CFF)),
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
                color: isHealed
                    ? const Color(0xFF5CB85C).withOpacity(0.15)
                    : const Color(0xFF8E7CFF).withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isHealed
                    ? tr(context, 'Healed', 'تم الشفاء')
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
    final firstName = TextEditingController(text: initial['firstName']?.toString() ?? '');
    final lastName = TextEditingController(text: initial['lastName']?.toString() ?? '');
    final email = TextEditingController(text: initial['email']?.toString() ?? '');
    final language =
        TextEditingController(text: initial['preferredLanguage']?.toString() ?? '');
    final birthdate =
        TextEditingController(text: initial['birthdate']?.toString() ?? '');
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
                  title: Text(tr(context, 'Completed questionnaire', 'أكمل الاستبيان')),
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
        'preferredLanguage': language.text.trim().isEmpty ? null : language.text.trim(),
        'birthdate': birthdate.text.trim().isEmpty ? null : birthdate.text.trim(),
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
    final number =
        TextEditingController(text: initial['questionNumber']?.toString() ?? '');
    final language =
        TextEditingController(text: initial['language']?.toString() ?? '');
    final text = TextEditingController(text: initial['text']?.toString() ?? '');
    final type = TextEditingController(text: initial['type']?.toString() ?? '');
    bool isSlider = initial['isSlider'] == true;
    bool multipleSelect = initial['multipleSelect'] == true;
    final minValue =
        TextEditingController(text: initial['minValue']?.toString() ?? '');
    final maxValue =
        TextEditingController(text: initial['maxValue']?.toString() ?? '');
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
                    label: tr(context, 'Question ID (optional)', 'معرّف السؤال'),
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
                    label: tr(context, 'Options (one per line)', 'الخيارات (كل سطر خيار)'),
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
                    label: tr(context, 'Slider labels (one per line)', 'تسميات الشريط'),
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
    final userId = TextEditingController(text: initial['userId']?.toString() ?? '');
    final questionNumber =
        TextEditingController(text: initial['questionNumber']?.toString() ?? '');
    final answerText =
        TextEditingController(text: initial['answerText']?.toString() ?? '');
    final sliderValue =
        TextEditingController(text: initial['sliderValue']?.toString() ?? '');
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
                  label: tr(context, 'Selected indices (comma)', 'الاختيارات (فاصلة)'),
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
        'answerText': answerText.text.trim().isEmpty ? null : answerText.text.trim(),
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
    final displayName =
        TextEditingController(text: initial['displayName']?.toString() ?? '');
    final characterName =
        TextEditingController(text: initial['characterName']?.toString() ?? '');
    final archetype =
        TextEditingController(text: initial['archetype']?.toString() ?? '');
    final rank = TextEditingController(text: initial['rank']?.toString() ?? '');
    final userId = TextEditingController(text: initial['userId']?.toString() ?? '');
    final glbFile = TextEditingController(text: initial['glbFileName']?.toString() ?? '');
    final description =
        TextEditingController(text: initial['description']?.toString() ?? '');
    final language =
        TextEditingController(text: initial['language']?.toString() ?? 'en');
    final confidence =
        TextEditingController(text: initial['confidence']?.toString() ?? '0.8');
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
                    label: tr(context, 'Character ID (optional)', 'معرّف الشخصية'),
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

  dynamic _sanitizeForJson(dynamic value) {
    if (value is Timestamp) {
      return value.toDate().toIso8601String();
    }
    if (value is DateTime) {
      return value.toIso8601String();
    }
    if (value is DocumentReference) {
      return value.path;
    }
    if (value is Map) {
      return value.map((key, val) => MapEntry(key.toString(), _sanitizeForJson(val)));
    }
    if (value is Iterable) {
      return value.map(_sanitizeForJson).toList();
    }
    return value;
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
            icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF8E7CFF)),
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
                  itemCount: _docs.length,
                  itemBuilder: (context, index) {
                    final doc = _docs[index];
                    final card = Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE5DEFF)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
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
