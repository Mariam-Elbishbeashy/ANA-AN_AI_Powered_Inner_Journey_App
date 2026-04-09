// lib/features/video_chat/presentation/screens/video_sessions_screen.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/video_chat/presentation/screens/video_call_screen.dart';
import 'package:ana_ifs_app/features/video_chat/presentation/screens/video_session_viewer_screen.dart';
import 'package:ana_ifs_app/features/video_chat/data/repositories/video_session_repository.dart';
import 'package:ana_ifs_app/features/video_chat/domain/entities/video_session.dart';

class VideoSessionsScreen extends StatefulWidget {
  final UserCharacter character;

  const VideoSessionsScreen({
    super.key,
    required this.character,
  });

  @override
  State<VideoSessionsScreen> createState() => _VideoSessionsScreenState();
}

class _VideoSessionsScreenState extends State<VideoSessionsScreen> {
  late final VideoSessionRepository _sessionRepository;
  late final InnerCharacterLocalDataSource _characterLocalDataSource;

  late final String _characterIdForBackend;
  late final String _assistantAvatarPath;

  @override
  void initState() {
    super.initState();
    _sessionRepository = VideoSessionRepository();
    _characterLocalDataSource = InnerCharacterLocalDataSource();
    _characterIdForBackend = _getCharacterIdForBackend(widget.character.characterName);
    _assistantAvatarPath = _getImagePathForCharacter(widget.character.characterName);
  }

  String _getCharacterIdForBackend(String characterName) {
    final idMap = {
      'Inner Critic': 'inner_critic',
      'People Pleaser': 'people_pleaser',
      'Lonely Part': 'lonely',
      'Jealous Part': 'jealous',
      'Ashamed Part': 'ashamed',
      'Workaholic': 'workaholic',
      'Perfectionist': 'perfectionist',
      'Procrastinator': 'procrastinator',
      'Excessive Gamer': 'excessive_gamer',
      'Confused Part': 'confused',
      'Dependent Part': 'dependent',
      'Fearful Part': 'fearful',
      'Neglected Part': 'neglected',
      'Overeater': 'overater_binger',
      'Overeater/Binger': 'overater_binger',
      'Overwhelmed Part': 'overwhelmed',
      'Stoic Part': 'stoic',
      'Wounded Child': 'wounded_child',
      'Controller': 'controller',
      'Controller Part': 'controller',
    };
    return idMap[characterName] ?? characterName.toLowerCase().replaceAll(' ', '_');
  }

  String _getImagePathForCharacter(String characterName) {
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    if (minutes > 0) {
      final minutesText = tr(context, 'min', 'دقيقة');
      return '$minutes $minutesText ${remainingSeconds}s';
    }
    return '${remainingSeconds}s';
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

  Future<void> _startNewSession() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Check for active session
    final active = await _sessionRepository.getActiveVideoSession(
      uid: user.uid,
      characterId: _characterIdForBackend,
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
              'You already have an active video session with this character. To start a new one, the current session must be ended first.',
              'لديك بالفعل جلسة فيديو نشطة مع هذه الشخصية. لبدء جلسة جديدة، يجب إنهاء الجلسة الحالية أولاً.',
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

      await _sessionRepository.endVideoSession(
        uid: user.uid,
        sessionId: active.id,
      );
    }

    // Navigate to video call screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VideoCallScreen(
          character: widget.character,
        ),
      ),
    );
  }

  Future<void> _openSession(VideoSession session) async {
    if (!mounted) return;

    if (session.isActive) {
      // Resume active session
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            character: widget.character,
            existingSessionId: session.id,
          ),
        ),
      );
    } else {
      // View ended session (read-only)
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => VideoSessionViewerScreen(
            character: widget.character,
            session: session,
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

    final title = widget.character.getDisplayName(isArabic(context) ? 'ar' : 'en');

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
                          tr(context, 'Video Sessions', 'جلسات الفيديو'),
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
                    'Pick a past session or start a new video call.',
                    'اختر جلسة سابقة أو ابدأ مكالمة فيديو جديدة.',
                  ),
                  avatarPath: _assistantAvatarPath,
                ),
              ),
              Expanded(
                child: StreamBuilder<List<VideoSession>>(
                  stream: _sessionRepository.streamVideoSessionsForCharacter(
                    uid: user.uid,
                    characterId: _characterIdForBackend,
                  ),
                  builder: (context, snapshot) {
                    final sessions = snapshot.data ?? const <VideoSession>[];

                    if (sessions.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: Text(
                            tr(
                              context,
                              'No video sessions yet. Start your first session to begin.',
                              'لا توجد جلسات فيديو بعد. ابدأ أول جلسة لتبدأ.',
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
                        final duration = _formatDuration(s.duration);

                        final statusLabel = s.isActive
                            ? tr(context, 'Active', 'نشطة')
                            : tr(context, 'Ended', 'منتهية');

                        final subtitle = s.isActive
                            ? tr(context, 'Started: $when', 'بدأت: $when')
                            : tr(context, '$when • $duration', '$when • $duration');

                        return _SessionTile(
                          title: tr(
                            context,
                            'Session ${sessions.length - index}',
                            'الجلسة ${sessions.length - index}',
                          ),
                          subtitle: subtitle,
                          statusLabel: statusLabel,
                          isActive: s.isActive,
                          guiderJoined: s.guiderJoined,
                          onTap: () => _openSession(s),
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
                    onPressed: _startNewSession,
                    icon: const Icon(Icons.videocam_rounded),
                    label: Text(tr(context, 'Start a new video session', 'ابدأ جلسة فيديو جديدة')),
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
            backgroundColor: const Color(0xFFB79CFF).withOpacity(0.18),
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
  final bool guiderJoined;
  final VoidCallback onTap;

  const _SessionTile({
    required this.title,
    required this.subtitle,
    required this.statusLabel,
    required this.isActive,
    required this.guiderJoined,
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
                isActive ? Icons.videocam_rounded : Icons.history_rounded,
                color: isActive ? const Color(0xFF8E7CFF) : const Color(0xFF6B5C82),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
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
                      if (guiderJoined) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFB79CFF).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.assistant_navigation,
                                size: 10,
                                color: const Color(0xFFB79CFF),
                              ),
                              const SizedBox(width: 2),
                              Text(
                                'Guider',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFB79CFF),
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