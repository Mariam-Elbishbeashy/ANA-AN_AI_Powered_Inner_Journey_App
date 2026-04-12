// lib/features/guider/presentation/screens/guider_session_viewer_screen.dart
import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import '../../domain/entities/guider_session.dart';
import 'guider_chat_history_screen.dart';

class GuiderSessionViewerScreen extends StatelessWidget {
  final GuiderSession session;
  final String userName;

  const GuiderSessionViewerScreen({
    super.key,
    required this.session,
    required this.userName,
  });

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      return '$minutes min ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return 'Unknown';
    final local = dt.toLocal();
    return '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')} '
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _getEmotionLabel(String emotion) {
    final labels = {
      'happy': '😊 Happy',
      'sad': '😢 Sad',
      'angry': '😠 Angry',
      'fearful': '😨 Fearful',
      'surprised': '😲 Surprised',
      'disgusted': '🤢 Disgusted',
      'neutral': '😐 Neutral',
    };
    return labels[emotion] ?? emotion;
  }

  void _viewChatHistory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuiderChatHistoryScreen(
          session: session,
          userName: userName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F2FF),
              Color(0xFFF2ECFF),
              Color(0xFFEDE7FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Center(
                        child: Text(
                          tr(context, 'Guider Session', 'جلسة المرشد'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFA790ED),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    tr(
                      context,
                      'This Guider session has ended. You\'re viewing it in read-only mode.',
                      'انتهت جلسة المرشد هذه. أنت تعرضها الآن في وضع القراءة فقط.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFE5DEFF)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEDE7FF),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assistant_navigation,
                                    size: 30,
                                    color: Color(0xFFB79CFF),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        tr(context, 'Session with The Guider', 'جلسة مع المرشد'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF2A1E3B),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDateTime(session.startedAt),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Color(0xFF6B5C82),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _InfoRow(
                              label: tr(context, 'User', 'المستخدم'),
                              value: userName,
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              label: tr(context, 'Duration', 'المدة'),
                              value: _formatDuration(session.duration),
                            ),
                            const SizedBox(height: 12),
                            _InfoRow(
                              label: tr(context, 'Status', 'الحالة'),
                              value: session.isActive
                                  ? (isArabicValue ? 'نشطة' : 'Active')
                                  : (isArabicValue ? 'منتهية' : 'Ended'),
                            ),
                            if (session.characterId != null) ...[
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: tr(context, 'Character Focus', 'الشخصية المستهدفة'),
                                value: session.characterId!.replaceAll('_', ' ').toUpperCase(),
                              ),
                            ],
                            if (session.emotionsTracked != null && session.emotionsTracked!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: tr(context, 'Emotions Tracked', 'المشاعر المسجلة'),
                                value: session.emotionsTracked!.join(', '),
                              ),
                            ],
                            if (session.intensityStart != null && session.intensityEnd != null) ...[
                              const SizedBox(height: 12),
                              _InfoRow(
                                label: tr(context, 'Intensity Change', 'تغير الشدة'),
                                value: '${(session.intensityStart! * 100).toInt()}% → ${(session.intensityEnd! * 100).toInt()}%',
                              ),
                            ],
                            const SizedBox(height: 20),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFEDE7FF),
                                foregroundColor: const Color(0xFFB79CFF),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: const Size(double.infinity, 48),
                              ),
                              onPressed: () => _viewChatHistory(context),
                              icon: const Icon(Icons.chat_bubble_outline, size: 20),
                              label: Text(
                                tr(context, 'View Chat History', 'عرض سجل المحادثة'),
                                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (session.faceEmotion != null && session.faceEmotion!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5DEFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.face_rounded,
                                    color: Color(0xFFB79CFF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    tr(context, 'Face Emotion Analysis', 'تحليل مشاعر الوجه'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2A1E3B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              _InfoRow(
                                label: tr(context, 'Dominant Emotion', 'المشاعر السائدة'),
                                value: _getEmotionLabel(session.faceEmotion?['dominant'] ?? 'neutral'),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: tr(context, 'Average Confidence', 'متوسط الثقة'),
                                value: '${((session.faceEmotion?['averageConfidence'] ?? 0) * 100).toInt()}%',
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: tr(context, 'Start Emotion', 'مشاعر البداية'),
                                value: _getEmotionLabel(session.faceEmotion?['startEmotion'] ?? 'neutral'),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: tr(context, 'End Emotion', 'مشاعر النهاية'),
                                value: _getEmotionLabel(session.faceEmotion?['endEmotion'] ?? 'neutral'),
                              ),
                              if ((session.faceEmotion?['totalDetections'] ?? 0) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _InfoRow(
                                    label: tr(context, 'Detections', 'عدد الكشوفات'),
                                    value: '${session.faceEmotion?['totalDetections'] ?? 0}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (session.voiceTone != null && session.voiceTone!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5DEFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(
                                    Icons.mic_rounded,
                                    color: Color(0xFFB79CFF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    tr(context, 'Voice Tone Analysis', 'تحليل نبرة الصوت'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2A1E3B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              _InfoRow(
                                label: tr(context, 'Dominant Tone', 'النبرة السائدة'),
                                value: _getEmotionLabel(session.voiceTone?['dominant'] ?? 'neutral'),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: tr(context, 'Average Confidence', 'متوسط الثقة'),
                                value: '${((session.voiceTone?['averageConfidence'] ?? 0) * 100).toInt()}%',
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: tr(context, 'Start Tone', 'نبرة البداية'),
                                value: _getEmotionLabel(session.voiceTone?['startEmotion'] ?? 'neutral'),
                              ),
                              const SizedBox(height: 8),
                              _InfoRow(
                                label: tr(context, 'End Tone', 'نبرة النهاية'),
                                value: _getEmotionLabel(session.voiceTone?['endEmotion'] ?? 'neutral'),
                              ),
                              if ((session.voiceTone?['totalDetections'] ?? 0) > 0)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: _InfoRow(
                                    label: tr(context, 'Detections', 'عدد الكشوفات'),
                                    value: '${session.voiceTone?['totalDetections'] ?? 0}',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                      if (session.sessionSummary != null && session.sessionSummary!.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFE5DEFF)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.summarize_rounded,
                                    color: const Color(0xFFB79CFF),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    tr(context, 'Session Summary', 'ملخص الجلسة'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2A1E3B),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 15),
                              if (session.sessionSummary!['highlights'] != null)
                                ..._buildHighlights(session.sessionSummary!['highlights']),
                              if (session.sessionSummary!['duration'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: _InfoRow(
                                    label: tr(context, 'Session Duration', 'مدة الجلسة'),
                                    value: _formatDuration(session.sessionSummary!['duration']),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildHighlights(List<dynamic> highlights) {
    return highlights.map<Widget>((highlight) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '• ',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFFB79CFF),
                fontWeight: FontWeight.bold,
              ),
            ),
            Expanded(
              child: Text(
                highlight.toString(),
                style: const TextStyle(
                  fontSize: 14,
                  color: Color(0xFF4B3A66),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }).toList();
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF2A1E3B)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B5C82),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ),
      ],
    );
  }
}