import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/voice_analysis/domain/repositories/voice_session_repository.dart';

class VoiceChatHistoryScreen extends StatefulWidget {
  final UserCharacter character;
  final VoiceSession session;

  const VoiceChatHistoryScreen({
    super.key,
    required this.character,
    required this.session,
  });

  @override
  State<VoiceChatHistoryScreen> createState() => _VoiceChatHistoryScreenState();
}

class _VoiceChatHistoryScreenState extends State<VoiceChatHistoryScreen> {
  late final VoiceSessionRepository _sessionRepository;
  List<VoiceMessage> _messages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionRepository = VoiceSessionRepository();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'User not logged in';
        _isLoading = false;
      });
      return;
    }

    if (widget.session.threadId == null || widget.session.threadId!.isEmpty) {
      setState(() {
        _error = 'No chat history available for this session';
        _isLoading = false;
      });
      return;
    }

    try {
      final messages = await _sessionRepository.getMessages(
        uid: user.uid,
        threadId: widget.session.threadId!,
      );
      setState(() {
        _messages = messages;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading messages: $e';
        _isLoading = false;
      });
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  String _getCharacterDisplayName() {
    final isArabic = _isArabic();
    return widget.character.getDisplayName(isArabic ? 'ar' : 'en');
  }

  String _getCharacterAvatarPath() {
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

    final characterName = widget.character.characterName;
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

  bool _isArabic() {
    return tr(context, 'en', 'ar') == 'ar';
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

    final isArabic = _isArabic();
    final characterName = _getCharacterDisplayName();
    final characterAvatarPath = _getCharacterAvatarPath();

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
                          characterName,
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
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Text(
                    tr(
                      context,
                      'This session has ended. You\'re viewing it in read-only mode.',
                      'انتهت هذه الجلسة. أنت تعرضها الآن في وضع القراءة فقط.',
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
                child: _buildMessageList(isArabic, characterName, characterAvatarPath),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageList(bool isArabic, String characterName, String characterAvatarPath) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E7CFF)),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 48),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B5C82)),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                setState(() {
                  _loadMessages();
                });
              },
              child: Text(tr(context, 'Retry', 'إعادة المحاولة')),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, color: Color(0xFFB79CFF), size: 54),
            const SizedBox(height: 16),
            Text(
              tr(context, 'No messages in this session', 'لا توجد رسائل في هذه الجلسة'),
              style: const TextStyle(color: Color(0xFF6B5C82), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isUser = message.role == 'user';
        final isGuider = message.sender == 'guider';
        final senderName = isUser
            ? tr(context, 'You', 'أنت')
            : (isGuider
            ? tr(context, 'The Guider', 'المرشد')
            : characterName);

        return _ChatBubble(
          message: message.content,
          sender: senderName,
          timestamp: message.createdAt,
          isUser: isUser,
          isGuider: isGuider,
          isArabic: isArabic,
          characterName: characterName,
          characterAvatarPath: characterAvatarPath,
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

class _ChatBubble extends StatelessWidget {
  final String message;
  final String sender;
  final DateTime? timestamp;
  final bool isUser;
  final bool isGuider;
  final bool isArabic;
  final String characterName;
  final String characterAvatarPath;

  const _ChatBubble({
    required this.message,
    required this.sender,
    this.timestamp,
    required this.isUser,
    required this.isGuider,
    required this.isArabic,
    required this.characterName,
    required this.characterAvatarPath,
  });

  String _formatTime() {
    if (timestamp == null) return '';
    final local = timestamp!.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Character avatar for non-user messages
          if (!isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              child: ClipOval(
                child: Image.asset(
                  characterAvatarPath,
                  width: 36,
                  height: 36,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isGuider
                          ? const Color(0xFFB79CFF).withValues(alpha: 0.18)
                          : const Color(0xFFEDE7FF),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isGuider ? Icons.assistant_navigation : Icons.mic_rounded,
                      size: 20,
                      color: isGuider ? const Color(0xFFB79CFF) : const Color(0xFF8E7CFF),
                    ),
                  ),
                ),
              ),
            ),

          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Sender name for non-user messages
                if (!isUser)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Text(
                      sender,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isGuider
                            ? const Color(0xFFB79CFF)
                            : const Color(0xFF8E7CFF),
                      ),
                    ),
                  ),

                // Message bubble - white with border (EXACTLY like video)
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.72,
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(20),
                      topRight: const Radius.circular(20),
                      bottomLeft: Radius.circular(isUser ? 20 : 6),
                      bottomRight: Radius.circular(isUser ? 6 : 20),
                    ),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                    children: [
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF2A1E3B),
                          height: 1.4,
                        ),
                      ),
                      if (timestamp != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            _formatTime(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Color(0xFF6B5C82),
                            ),
                          ),
                        ),
                    ],
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