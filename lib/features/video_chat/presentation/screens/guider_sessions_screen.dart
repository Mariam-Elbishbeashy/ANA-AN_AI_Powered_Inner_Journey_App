// lib/features/guider/presentation/screens/guider_sessions_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import '../../data/repositories/guider_session_repository.dart';
import '../../domain/entities/guider_session.dart';
import 'guider_session_viewer_screen.dart';
import 'guider_video_call_screen.dart';

class GuiderSessionsScreen extends StatefulWidget {
  final String userName;
  final String? characterId;

  const GuiderSessionsScreen({
    super.key,
    required this.userName,
    this.characterId,
  });

  @override
  State<GuiderSessionsScreen> createState() => _GuiderSessionsScreenState();
}

class _GuiderSessionsScreenState extends State<GuiderSessionsScreen> {
  late final GuiderSessionRepository _repository;
  final _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();

  @override
  void initState() {
    super.initState();
    _repository = GuiderSessionRepository();
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return tr(context, 'Just started', 'بدأت للتو');
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      final minutesText = tr(context, 'min', 'دقيقة');
      return '$minutes $minutesText ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return tr(context, 'Just now', 'الآن');
    final local = dt.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(local.year, local.month, local.day);

    if (date == today) {
      return 'Today ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (date == yesterday) {
      return 'Yesterday ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    }

    return '${local.day}/${local.month}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _startNewSession() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuiderVideoCallScreen(
          userName: widget.userName,
          characterId: widget.characterId,
        ),
      ),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openSession(GuiderSession session) async {
    if (!mounted) return;

    if (session.isActive) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GuiderVideoCallScreen(
            userName: widget.userName,
            characterId: widget.characterId,
          ),
        ),
      );
      if (mounted) {
        setState(() {});
      }
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => GuiderSessionViewerScreen(
            session: session,
            userName: widget.userName,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F6FF),
        body: Center(
          child: Text(tr(context, 'Please sign in to continue.', 'يرجى تسجيل الدخول للمتابعة.')),
        ),
      );
    }

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
              // App Bar
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
                          tr(context, 'Guider Sessions', 'جلسات المرشد'),
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
              // Header Card with Guider Image
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: _HeaderCard(
                  title: tr(context, 'The Guider', 'المرشد'),
                  subtitle: tr(
                    context,
                    'Pick a past session or start a new video call with The Guider.',
                    'اختر جلسة سابقة أو ابدأ مكالمة فيديو جديدة مع المرشد.',
                  ),
                ),
              ),
              // Sessions List
              Expanded(
                child: RefreshIndicator(
                  key: _refreshIndicatorKey,
                  onRefresh: () async {
                    setState(() {});
                    await Future.delayed(const Duration(milliseconds: 500));
                  },
                  child: StreamBuilder<List<GuiderSession>>(
                    stream: _repository.streamGuiderSessions(uid: user.uid),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E7CFF)),
                          ),
                        );
                      }

                      if (snapshot.hasError) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 48),
                                const SizedBox(height: 16),
                                Text(
                                  tr(context, 'Error loading sessions', 'خطأ في تحميل الجلسات'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Color(0xFF6B5C82)),
                                ),
                                const SizedBox(height: 12),
                                TextButton(
                                  onPressed: () => setState(() {}),
                                  child: Text(tr(context, 'Retry', 'إعادة المحاولة')),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      final allSessions = snapshot.data ?? const <GuiderSession>[];

                      // Filter sessions: show active sessions AND completed sessions with content
                      final sessions = allSessions.where((session) {
                        if (session.isActive) return true;
                        if (session.threadId.isNotEmpty) return true;
                        if (session.duration > 0) return true;
                        if (session.endedAt != null) return true;

                        final hasFaceEmotion = (session.faceEmotion?['totalDetections'] ?? 0) > 0;
                        final hasVoiceEmotion = (session.voiceTone?['totalDetections'] ?? 0) > 0;
                        if (hasFaceEmotion || hasVoiceEmotion) return true;

                        return false;
                      }).toList();

                      if (sessions.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 28),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.assistant_navigation,
                                  color: Color(0xFFB79CFF),
                                  size: 54,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  tr(
                                    context,
                                    'No Guider sessions yet. Start your first session to begin.',
                                    'لا توجد جلسات مرشد بعد. ابدأ أول جلسة لتبدأ.',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Color(0xFF4B3A66),
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF8E7CFF),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: _startNewSession,
                                  icon: const Icon(Icons.videocam_rounded),
                                  label: Text(tr(context, 'Start a Session', 'ابدأ جلسة')),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return ListView.separated(
                        padding: const EdgeInsets.fromLTRB(18, 8, 18, 100),
                        itemCount: sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final s = sessions[index];
                          final when = _formatDateTime(s.startedAt);
                          final duration = _formatDuration(s.duration);

                          final subtitle = s.isActive
                              ? tr(context, 'Started: $when', 'بدأت: $when')
                              : (s.duration > 0
                              ? tr(context, '$when • $duration', '$when • $duration')
                              : when);

                          final statusLabel = s.isActive
                              ? tr(context, 'Active', 'نشطة')
                              : tr(context, 'Ended', 'منتهية');

                          return _SessionTile(
                            title: tr(
                              context,
                              'Session ${sessions.length - index}',
                              'الجلسة ${sessions.length - index}',
                            ),
                            subtitle: subtitle,
                            statusLabel: statusLabel,
                            isActive: s.isActive,
                            hasGuider: true, // Always true for Guider sessions
                            onTap: () => _openSession(s),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              // Start New Session Button
              Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  10,
                  18,
                  18 + MediaQuery.of(context).padding.bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E7CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _startNewSession,
                    icon: const Icon(Icons.videocam_rounded),
                    label: Text(
                      tr(context, 'Start a new Guider session', 'ابدأ جلسة مرشد جديدة'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
              color: Colors.black.withValues(alpha: 0.06),
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

class _HeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _HeaderCard({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: const Color(0xFFB79CFF).withValues(alpha: 0.18),
            child: ClipOval(
              child: Image.asset(
                'assets/images/guider.png',
                width: 52,
                height: 52,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.assistant_navigation,
                  size: 28,
                  color: Color(0xFF8E7CFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B5C82),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool isActive;
  final bool hasGuider;
  final VoidCallback onTap;

  const _SessionTile({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.isActive,
    required this.hasGuider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5DEFF)),
        ),
        child: Row(
          children: [
            // Icon Container
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF8E7CFF).withValues(alpha: 0.18)
                    : const Color(0xFFEDE7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.videocam_rounded : Icons.history_rounded,
                color: isActive ? const Color(0xFF8E7CFF) : const Color(0xFF6B5C82),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            // Title and Subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      if (hasGuider) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB79CFF).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.assistant_navigation,
                                size: 10,
                                color: Color(0xFFB79CFF),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Guider',
                                style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFB79CFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B5C82),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF8E7CFF).withValues(alpha: 0.12)
                    : const Color(0xFF6B5C82).withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isActive ? const Color(0xFF8E7CFF) : const Color(0xFF6B5C82),
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF6B5C82)),
          ],
        ),
      ),
    );
  }
}