import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/guider_chat_session_screen.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/guider_avatar.dart';

/// Session history screen for The Guider chat.
///
/// Mirrors the character sessions flow:
/// - show all previous guider sessions
/// - start a new session
/// - open active sessions in editable mode
/// - open ended sessions in read-only mode
class GuiderChatSessionsScreen extends StatefulWidget {
  final String? currentlyOpenSessionId;

  const GuiderChatSessionsScreen({
    super.key,
    this.currentlyOpenSessionId,
  });

  @override
  State<GuiderChatSessionsScreen> createState() => _GuiderChatSessionsScreenState();
}

class _GuiderChatSessionsScreenState extends State<GuiderChatSessionsScreen> {
  final _chatRemoteDataSource = ChatRemoteDataSource();

  String _formatWhen(DateTime? dt) {
    if (dt == null) return tr(context, 'Just now', 'الآن');
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d  $hh:$mm';
  }

  Future<void> _startNewSession({required String uid}) async {
    final active = await _chatRemoteDataSource.getActiveChatSessionForCharacter(
      uid: uid,
      characterId: 'guider',
    );

    if (!mounted) return;

    if (active != null) {
      final shouldEnd = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(tr(context, 'Active session exists', 'هناك جلسة نشطة')),
          content: Text(
            tr(
              context,
              'You already have an active session with The Guider. To start a new one, the current session must be ended first.',
              'لديك بالفعل جلسة نشطة مع المُرشد. لبدء جلسة جديدة، يجب إنهاء الجلسة الحالية أولاً.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'End & start new', 'إنهاء وبدء جديد')),
            ),
          ],
        ),
      );

      if (shouldEnd != true) return;

      await _chatRemoteDataSource.endChatSession(
        uid: uid,
        sessionId: active.id,
        threadId: active.threadId,
      );
    }

    final session = await _chatRemoteDataSource.createNewChatSession(
      uid: uid,
      characterId: 'guider',
      characterType: 'guider',
      title: 'The Guider',
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuiderChatSessionScreen(session: session),
      ),
    );
  }

  Future<void> _openSession({
    required String uid,
    required ChatSessionModel session,
  }) async {
    if (!mounted) return;

    if (widget.currentlyOpenSessionId != null &&
        widget.currentlyOpenSessionId == session.id) {
      Navigator.of(context).pop();
      return;
    }

    var resolved = session;
    if (resolved.threadId.isEmpty) {
      final thread = await _chatRemoteDataSource.getThreadBySessionId(
        uid: uid,
        sessionId: resolved.id,
      );
      if (thread != null) {
        await _chatRemoteDataSource.setSessionThreadId(
          uid: uid,
          sessionId: resolved.id,
          threadId: thread.id,
        );
        resolved = ChatSessionModel(
          id: resolved.id,
          type: resolved.type,
          characterId: resolved.characterId,
          characterType: resolved.characterType,
          threadId: thread.id,
          status: resolved.status,
          title: resolved.title,
          startedAt: resolved.startedAt,
          endedAt: resolved.endedAt,
          updatedAt: resolved.updatedAt,
          lastMessageAt: resolved.lastMessageAt,
        );
      }
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GuiderChatSessionScreen(
          session: resolved,
          readOnly: !resolved.isActive,
        ),
      ),
    );
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
                          tr(context, 'Chat sessions', 'جلسات الدردشة'),
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
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Row(
                    children: [
                      const GuiderAvatar(
                        size: 52,
                        backgroundColor: Color(0xFFEDE7FF),
                        fallbackIconSize: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr(context, 'The Guider', 'المُرشد'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              tr(
                                context,
                                'Pick a past session or start a new one.',
                                'اختر جلسة سابقة أو ابدأ جلسة جديدة.',
                              ),
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
                ),
              ),
              Expanded(
                child: StreamBuilder<List<ChatSessionModel>>(
                  stream: _chatRemoteDataSource.streamChatSessionsForCharacter(
                    uid: user.uid,
                    characterId: 'guider',
                  ),
                  builder: (context, snapshot) {
                    final sessions = snapshot.data ?? const <ChatSessionModel>[];

                    if (sessions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            tr(
                              context,
                              'No sessions yet. Start your first session to begin chatting.',
                              'لا توجد جلسات بعد. ابدأ أول جلسة لبدء الدردشة.',
                            ),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF4B3A66),
                              height: 1.5,
                            ),
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
                        final when = _formatWhen(s.startedAt);
                        final statusLabel = s.isActive
                            ? tr(context, 'Active', 'نشطة')
                            : tr(context, 'Ended', 'منتهية');

                        return _SessionTile(
                          title: tr(
                            context,
                            'Session ${sessions.length - index}',
                            'الجلسة ${sessions.length - index}',
                          ),
                          subtitle: tr(context, 'Started: $when', 'بدأت: $when'),
                          statusLabel: statusLabel,
                          isActive: s.isActive,
                          onTap: () => _openSession(uid: user.uid, session: s),
                        );
                      },
                    );
                  },
                ),
              ),
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
                    onPressed: () => _startNewSession(uid: user.uid),
                    icon: const Icon(Icons.add_rounded),
                    label: Text(tr(context, 'Start a new session', 'ابدأ جلسة جديدة')),
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

class _SessionTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String statusLabel;
  final bool isActive;
  final VoidCallback onTap;

  const _SessionTile({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.isActive,
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
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF8E7CFF).withOpacity(0.18)
                    : const Color(0xFFEDE7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isActive ? Icons.chat_bubble_rounded : Icons.history_rounded,
                color: isActive ? const Color(0xFF8E7CFF) : const Color(0xFF6B5C82),
                size: 20,
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
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isActive
                    ? const Color(0xFF8E7CFF).withOpacity(0.12)
                    : const Color(0xFF6B5C82).withOpacity(0.10),
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
