import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/character_chat_sessions_screen.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/chat_conversation.dart';

/// guider avatar path constant (kept identical to chat_conversation.dart)
const String guiderAvatarPath = 'assets/images/characters_full_body/guider.png';

/// The "normal" chat screen for an ACTIVE session.

class ChatSessionScreen extends StatefulWidget {
  final UserCharacter character;
  final InnerCharacterProfile? profile;
  final String assistantAvatarPath;
  final String characterId;
  final String characterType;
  final ChatSessionModel session;

  const ChatSessionScreen({
    super.key,
    required this.character,
    required this.profile,
    required this.assistantAvatarPath,
    required this.characterId,
    required this.characterType,
    required this.session,
  });

  @override
  State<ChatSessionScreen> createState() => _ChatSessionScreenState();
}

class _ChatSessionScreenState extends State<ChatSessionScreen> {
  final _chatRemoteDataSource = ChatRemoteDataSource();
  final _chatAiRemoteDataSource = ChatAiRemoteDataSource();

  // guider state is supported
  bool _isGuiderInChat = false;

  bool _ending = false;

  /// show modal to invite or remove the Guider

  void _showGuiderModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GuiderModal(
        isGuiderInChat: _isGuiderInChat,
        characterName: widget.character.displayNameEn,
        onInviteGuider: () {
          Navigator.pop(context);
          setState(() {
            _isGuiderInChat = true;
          });
        },
        onRemoveGuider: () {
          Navigator.pop(context);
          setState(() {
            _isGuiderInChat = false;
          });
        },
      ),
    );
  }

  Future<bool> _confirmEndSession() async {
    // this dialog is the contract: leaving this screen = ending the session
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text(tr(context, 'End session?', 'إنهاء الجلسة؟')),
        content: Text(
          tr(
            context,
            'Are you sure you want to end this session? This can’t be undone.',
            'هل أنت متأكد أنك تريد إنهاء هذه الجلسة؟ لا يمكن التراجع عن ذلك.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr(context, 'Stay', 'البقاء')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr(context, 'End session', 'إنهاء الجلسة')),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _endSessionAndExit() async {
    if (_ending) return;
    setState(() => _ending = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      // backend analysis (intensity end + summary + logs).
      // if it fails, we still allow ending the session (we don't block the user)
      try {
        await _chatAiRemoteDataSource.endAnalyzeSession(
          uid: user.uid,
          sessionId: widget.session.id,
          threadId: widget.session.threadId,
          characterId: widget.characterId,
        );
      } catch (_) {}

      await _chatRemoteDataSource.endChatSession(
        uid: user.uid,
        sessionId: widget.session.id,
        threadId: widget.session.threadId,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // back to session history
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end session: $e')),
      );
      setState(() => _ending = false);
    }
  }

  /// we intercept all back navigation
  ///
  /// if the user confirms, we end the session first
  Future<void> _handleExitAttempt() async {
    if (_ending) return;
    final ok = await _confirmEndSession();
    if (!ok) return;
    await _endSessionAndExit();
  }

  @override
  Widget build(BuildContext context) {

    // display the character name directly from firestore UserCharacter
    final title =
        widget.character.getDisplayName(isArabic(context) ? 'ar' : 'en');

    return PopScope(
      // we block pop, and perform it ourselves after ending the session
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        await _handleExitAttempt();
      },
      child: Scaffold(
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
                        onTap: _handleExitAttempt,
                      ),
                      Expanded(
                        child: Center(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                        ),
                      ),
                      _CircleIconButton(
                        icon: Icons.history_rounded,
                        onTap: () {
                          // this allows the user to view session history WHILE the
                          // current session is still active, without triggering the
                          // "end session" confirmation (which only happens on back)
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CharacterChatSessionsScreen(
                                character: widget.character,
                                currentlyOpenSessionId: widget.session.id,
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(width: 10),
                      _GuiderIconButton(
                        isGuiderInChat: _isGuiderInChat,
                        onTap: _showGuiderModal,
                      ),
                    ],
                  ),
                ),
                if (_ending)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          tr(context, 'Ending session…', 'جاري إنهاء الجلسة…'),
                          style: const TextStyle(
                            color: Color(0xFF6B5C82),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: ChatConversation(
                    // we open an existing thread directly (session flow)
                    threadId: widget.session.threadId,
                    characterId: widget.characterId,
                    characterType: widget.characterType,
                    // pass the Firebase-based display name down (for typing label, etc.)
                    fallbackTitle: title,
                    fallbackSubtitle: tr(
                      context,
                      'A protective inner part.',
                      'جزء داخلي حامٍ.',
                    ),
                    fallbackRole: widget.character.archetype,
                    assistantAvatarPath: widget.assistantAvatarPath,
                    showHeader: false,
                    characterProfile: widget.profile,
                    isGuiderInChat: _isGuiderInChat,
                    onGuiderStateChanged: (isIn) {
                      setState(() => _isGuiderInChat = isIn);
                    },
                  ),
                ),
              ],
            ),
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

/// Guider icon button that shows the Guider avatar
///
/// matches CharacterChatScreen
class _GuiderIconButton extends StatelessWidget {
  final bool isGuiderInChat;
  final VoidCallback onTap;

  const _GuiderIconButton({
    required this.isGuiderInChat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isGuiderInChat ? const Color(0xFFB79CFF) : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isGuiderInChat
                  ? const Color(0xFFB79CFF).withOpacity(0.3)
                  : Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: isGuiderInChat
              ? Border.all(color: const Color(0xFF9B7BFF), width: 2)
              : null,
        ),
        child: ClipOval(
          child: Image.asset(
            guiderAvatarPath,
            width: 44,
            height: 44,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
            errorBuilder: (_, __, ___) => Icon(
              Icons.auto_awesome_rounded,
              color: isGuiderInChat ? Colors.white : const Color(0xFF2A1E3B),
              size: 22,
            ),
          ),
        ),
      ),
    );
  }
}

/// modal for inviting or removing the Guider
///
/// matches CharacterChatScreen
class _GuiderModal extends StatelessWidget {
  final bool isGuiderInChat;
  final String characterName;
  final VoidCallback onInviteGuider;
  final VoidCallback onRemoveGuider;

  const _GuiderModal({
    required this.isGuiderInChat,
    required this.characterName,
    required this.onInviteGuider,
    required this.onRemoveGuider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB79CFF).withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5DEFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Guider avatar
            CircleAvatar(
              radius: 40,
              backgroundColor: const Color(0xFFB79CFF),
              child: ClipOval(
                child: Image.asset(
                  guiderAvatarPath,
                  width: 80,
                  height: 80,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, 'The Guider', 'المُرشد'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isGuiderInChat
                  ? tr(
                      context,
                      'The Guider is currently in this conversation, helping you and your $characterName understand each other better.',
                      'المُرشد موجود حاليًا في هذه المحادثة، يساعدك أنت و$characterName على فهم بعضكم البعض بشكل أفضل.',
                    )
                  : tr(
                      context,
                      'Would you like The Guider to join this conversation? They can help you and your $characterName communicate with more clarity and compassion.',
                      'هل تريد أن ينضم المُرشد إلى هذه المحادثة؟ يمكنه مساعدتك أنت و$characterName على التواصل بوضوح وتعاطف أكبر.',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B5C82),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (isGuiderInChat)
              // Remove Guider button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRemoveGuider,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B7EC8),
                    side: const BorderSide(color: Color(0xFFB79CFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    tr(context, 'Continue without The Guider', 'استمر بدون المُرشد'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              // Invite Guider buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onInviteGuider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB79CFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr(context, 'Yes, invite The Guider', 'نعم، ادعُ المُرشد'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B7EC8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr(context, 'Not now', 'ليس الآن'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

