import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/chat_session_screen.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/chat_session_viewer_screen.dart';

/// Session history screen for ONE character.

/// - when user taps Chat from character profile:
///   - show all previous sessions with this character
///   - allow "Start a new session"
/// - each session is clickable:
///   - active session => open normal chat (editable)
///   - ended session  => open read-only viewer
class CharacterChatSessionsScreen extends StatefulWidget {
  final UserCharacter character;

  /// if this screen was opened from an already-active session, pass the session id
  /// here so we can avoid pushing a duplicate chat screen when the user taps it
  
  /// - user is chatting (active session)
  /// - user opens "history" to view previous sessions
  /// - If they tap the same active session, we just go back to the chat screen.
  final String? currentlyOpenSessionId;

  const CharacterChatSessionsScreen({
    super.key,
    required this.character,
    this.currentlyOpenSessionId,
  });

  @override
  State<CharacterChatSessionsScreen> createState() =>
      _CharacterChatSessionsScreenState();
}

class _CharacterChatSessionsScreenState extends State<CharacterChatSessionsScreen> {
  final _chatRemoteDataSource = ChatRemoteDataSource();
  final _characterLocalDataSource = InnerCharacterLocalDataSource();

  late Future<InnerCharacterProfile?> _characterFuture;
  late final String _assistantAvatarPath;

  @override
  void initState() {
    super.initState();
    _characterFuture = _loadCharacterProfile();
    _assistantAvatarPath = _getImagePathForCharacter(widget.character.characterName);
  }

  Future<InnerCharacterProfile?> _loadCharacterProfile() {
    // mapping the user's character name to the canonical JSON character id.
    // that id is what the backend expects (and what we store in sessions.characterId)
    final primaryName = widget.character.displayNameEn;
    final secondaryName = widget.character.characterName;
    return _characterLocalDataSource
        .findCharacterByName(primaryName)
        .then((value) => value ?? _characterLocalDataSource.findCharacterByName(secondaryName));
  }

  String _fallbackCharacterId() {
    // same fallback logic used in CharacterChatScreen
    final raw = widget.character.characterName.isNotEmpty
        ? widget.character.characterName
        : widget.character.displayNameEn;
    final normalized = raw
        .toLowerCase()
        .replaceAll('the ', '')
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? 'inner_critic' : normalized;
  }

  String _getImagePathForCharacter(String characterName) {
    // copied from the existing character chat screen so the UI stays consistent
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

    if (imageMap.containsKey(characterName)) {
      return 'assets/images/${imageMap[characterName]}';
    }

    final lowerName = characterName.toLowerCase();
    for (final entry in imageMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return 'assets/images/${entry.value}';
      }
    }

    return 'assets/images/inner_critic.png';
  }

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

  Future<void> _startNewSession({
    required String uid,
    required String characterId,
    required String characterType,
    required String title,
    required InnerCharacterProfile? profile,
  }) async {
    // enforcing one active session per character to keep the UX simple
    // - either resume the active one, or end it first, then start a new one
    final active = await _chatRemoteDataSource.getActiveChatSessionForCharacter(
      uid: uid,
      characterId: characterId,
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
              'You already have an active session with this character. To start a new one, the current session must be ended first.',
              'لديك بالفعل جلسة نشطة مع هذه الشخصية. لبدء جلسة جديدة، يجب إنهاء الجلسة الحالية أولاً.',
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
      characterId: characterId,
      characterType: characterType,
      title: title,
    );

    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSessionScreen(
          character: widget.character,
          profile: profile,
          assistantAvatarPath: _assistantAvatarPath,
          characterId: characterId,
          characterType: characterType,
          session: session,
        ),
      ),
    );
  }

  Future<void> _openSession({
    required ChatSessionModel session,
    required InnerCharacterProfile? profile,
    required String characterId,
    required String characterType,
  }) async {
    if (!mounted) return;

    // If the user taps the session that's already open behind this screen,
    // simply pop back to it (do not push a duplicate screen).
    if (widget.currentlyOpenSessionId != null &&
        widget.currentlyOpenSessionId == session.id) {
      Navigator.of(context).pop();
      return;
    }

    // Migration safety:
    // Older session docs may exist without `threadId`. If so, we recover the
    // thread by `sessionId` and write the link back for next time.
    var resolved = session;
    if (resolved.threadId.isEmpty) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final thread = await _chatRemoteDataSource.getThreadBySessionId(
          uid: user.uid,
          sessionId: resolved.id,
        );
        if (thread != null) {
          await _chatRemoteDataSource.setSessionThreadId(
            uid: user.uid,
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
    }

    if (resolved.isActive) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ChatSessionScreen(
            character: widget.character,
            profile: profile,
            assistantAvatarPath: _assistantAvatarPath,
            characterId: characterId,
            characterType: characterType,
            session: resolved,
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChatSessionViewerScreen(
          character: widget.character,
          profile: profile,
          assistantAvatarPath: _assistantAvatarPath,
          characterId: characterId,
          characterType: characterType,
          session: resolved,
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

    return FutureBuilder<InnerCharacterProfile?>(
      future: _characterFuture,
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final characterId = profile?.id ?? _fallbackCharacterId();
        final characterType = 'inner_character';

        // display the character name from Firestore (`UserCharacter`)
        final title =
            widget.character.getDisplayName(isArabic(context) ? 'ar' : 'en');

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
                    child: _CharacterHeaderCard(
                      title: title,
                      subtitle: tr(
                        context,
                        'Pick a past session or start a new one.',
                        'اختر جلسة سابقة أو ابدأ جلسة جديدة.',
                      ),
                      avatarPath: _assistantAvatarPath,
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<List<ChatSessionModel>>(
                      stream: _chatRemoteDataSource.streamChatSessionsForCharacter(
                        uid: user.uid,
                        characterId: characterId,
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
                            final ended = s.endedAt != null;
                            final statusLabel = s.isActive
                                ? tr(context, 'Active', 'نشطة')
                                : tr(context, 'Ended', 'منتهية');

                            return _SessionTile(
                              title: tr(
                                context,
                                'Session ${sessions.length - index}',
                                'الجلسة ${sessions.length - index}',
                              ),
                              subtitle: ended
                                  ? tr(
                                      context,
                                      'Started: $when',
                                      'بدأت: $when',
                                    )
                                  : tr(
                                      context,
                                      'Started: $when',
                                      'بدأت: $when',
                                    ),
                              statusLabel: statusLabel,
                              isActive: s.isActive,
                              onTap: () => _openSession(
                                session: s,
                                profile: profile,
                                characterId: characterId,
                                characterType: characterType,
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),

                  // Bottom "Start new session" button (fixed).
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
                        onPressed: () => _startNewSession(
                          uid: user.uid,
                          characterId: characterId,
                          characterType: characterType,
                          title: title,
                          profile: profile,
                        ),
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
      },
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

class _CharacterHeaderCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String avatarPath;

  const _CharacterHeaderCard({
    required this.title,
    required this.subtitle,
    required this.avatarPath,
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
                avatarPath,
                width: 54,
                height: 54,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.psychology_alt_rounded,
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
                    ? const Color(0xFF8E7CFF).withValues(alpha: 0.18)
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

