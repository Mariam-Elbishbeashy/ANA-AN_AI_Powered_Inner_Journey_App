import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/video_chat/domain/entities/video_session.dart';
import 'package:ana_ifs_app/features/video_chat/domain/entities/video_message.dart';
import 'package:ana_ifs_app/features/video_chat/data/repositories/video_session_repository.dart';

class VideoChatHistoryScreen extends StatefulWidget {
  final UserCharacter character;
  final VideoSession session;

  const VideoChatHistoryScreen({
    super.key,
    required this.character,
    required this.session,
  });

  @override
  State<VideoChatHistoryScreen> createState() => _VideoChatHistoryScreenState();
}

class _VideoChatHistoryScreenState extends State<VideoChatHistoryScreen> {
  late final VideoSessionRepository _sessionRepository;
  List<VideoMessage> _messages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _sessionRepository = VideoSessionRepository();
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

  String _formatDate(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String _getCharacterDisplayName() {
    final isArabic = _isArabic();
    return widget.character.getDisplayName(isArabic ? 'ar' : 'en');
  }

  bool _isArabic() {
    return tr(context, 'en', 'ar') == 'ar';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic();
    final characterName = _getCharacterDisplayName();
    final sessionDate = _formatDate(widget.session.startedAt);

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
              _buildAppBar(isArabic),

              _buildSessionBanner(isArabic, sessionDate),

              _buildCharacterHeader(isArabic, characterName),

              const Divider(height: 1, color: Color(0xFFE5DEFF)),

              Expanded(child: _buildMessageList(isArabic, characterName)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isArabic) {
    return Padding(
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
                tr(context, 'Chat History', 'سجل المحادثة'),
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
    );
  }

  Widget _buildSessionBanner(bool isArabic, String sessionDate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFA790ED),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            const Icon(Icons.history, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isArabic
                    ? 'سجل المحادثة للقراءة فقط - $sessionDate'
                    : 'Read-only chat history - $sessionDate',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCharacterHeader(bool isArabic, String characterName) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFEDE7FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_outline,
              color: const Color(0xFF8E7CFF),
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  characterName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isArabic
                      ? '${_messages.length} رسالة'
                      : '${_messages.length} messages',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B5C82),
                  ),
                ),
              ],
            ),
          ),
          if (widget.session.guiderJoined)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFB79CFF).withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.assistant_navigation,
                    size: 14,
                    color: Color(0xFFB79CFF),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    tr(context, 'Guider', 'مرشد'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFB79CFF),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isArabic, String characterName) {
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
            const Icon(Icons.error_outline, color: Color(0xFFE57373), size: 54),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF6B5C82), fontSize: 14),
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

class _ChatBubble extends StatelessWidget {
  final String message;
  final String sender;
  final DateTime? timestamp;
  final bool isUser;
  final bool isGuider;
  final bool isArabic;

  const _ChatBubble({
    required this.message,
    required this.sender,
    this.timestamp,
    required this.isUser,
    required this.isGuider,
    required this.isArabic,
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
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: isGuider
                    ? const Color(0xFFB79CFF).withOpacity(0.15)
                    : const Color(0xFFEDE7FF),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGuider ? Icons.assistant_navigation : Icons.psychology_alt,
                size: 20,
                color: isGuider ? const Color(0xFFB79CFF) : const Color(0xFF8E7CFF),
              ),
            ),
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF8E7CFF)
                    : (isGuider
                    ? const Color(0xFFF5F0FF)
                    : Colors.white),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: Radius.circular(isUser ? 20 : 6),
                  bottomRight: Radius.circular(isUser ? 6 : 20),
                ),
                border: (!isUser && !isGuider)
                    ? Border.all(color: const Color(0xFFE5DEFF))
                    : null,
              ),
              child: Column(
                crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isUser)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        sender,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: isGuider
                              ? const Color(0xFFB79CFF)
                              : const Color(0xFF8E7CFF),
                        ),
                      ),
                    ),
                  Text(
                    message,
                    style: TextStyle(
                      fontSize: 14,
                      color: isUser ? Colors.white : const Color(0xFF2A1E3B),
                      height: 1.4,
                    ),
                  ),
                  if (timestamp != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        _formatTime(),
                        style: TextStyle(
                          fontSize: 10,
                          color: isUser
                              ? Colors.white.withOpacity(0.7)
                              : const Color(0xFF6B5C82),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(left: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF8E7CFF).withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_outline,
                size: 20,
                color: Color(0xFF8E7CFF),
              ),
            ),
        ],
      ),
    );
  }
}