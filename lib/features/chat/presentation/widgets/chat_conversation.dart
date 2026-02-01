import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_message_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_thread_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/guider_intervention_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';

/// Guider avatar path constant
const String guiderAvatarPath = 'assets/images/characters_full_body/guider.png';

class ChatConversation extends StatefulWidget {
  final String characterId;
  final String characterType;
  final String fallbackTitle;
  final String fallbackSubtitle;
  final String? fallbackRole;
  final String? assistantAvatarPath;
  final bool showAssistantAvatar;
  final bool showHeader;
  final InnerCharacterProfile? characterProfile;

  /// Whether the Guider is currently in the conversation (controlled by parent)
  final bool isGuiderInChat;

  /// Callback when user wants to invite/remove the Guider
  final ValueChanged<bool>? onGuiderStateChanged;

  const ChatConversation({
    super.key,
    required this.characterId,
    required this.characterType,
    required this.fallbackTitle,
    required this.fallbackSubtitle,
    this.fallbackRole,
    this.assistantAvatarPath,
    this.showAssistantAvatar = true,
    this.showHeader = true,
    this.characterProfile,
    this.isGuiderInChat = false,
    this.onGuiderStateChanged,
  });

  @override
  State<ChatConversation> createState() => _ChatConversationState();
}

//State for the chat conversation.
class _ChatConversationState extends State<ChatConversation> {
  final _chatRemoteDataSource = ChatRemoteDataSource();
  final _chatAiRemoteDataSource = ChatAiRemoteDataSource();
  final _characterLocalDataSource = InnerCharacterLocalDataSource();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  //Data for the chat conversation.
  ChatThreadModel? _thread;
  InnerCharacterProfile? _characterProfile;
  bool _isInitializing = true;
  bool _isSending = false;

  // Guider intervention state
  GuiderInterventionModel? _pendingIntervention;
  bool _interventionDismissed = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _messageController.addListener(_handleTyping);
    _inputFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  Future<void> _initializeChat() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final character = widget.characterProfile ??
        await _characterLocalDataSource.getCharacterById(widget.characterId);
    final thread = await _chatRemoteDataSource.ensureChatThread(
      uid: user.uid,
      characterId: widget.characterId,
      characterType: widget.characterType,
      title: character?.displayName ?? widget.fallbackTitle,
    );

    if (!mounted) return;
    setState(() {
      _characterProfile = character;
      _thread = thread;
      _isInitializing = false;
    });
  }

  //Send a new chat message to the chat server.
  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    final thread = _thread;
    if (user == null || thread == null) return;

    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    _messageController.clear();

    try {
      // Save user message to Firestore
      await _chatRemoteDataSource.sendMessage(
        uid: user.uid,
        threadId: thread.id,
        role: 'user',
        content: text,
        metadata: {
          'characterId': widget.characterId,
          'sessionId': thread.sessionId,
          'sender': 'user',
        },
      );

      // Get recent messages from the chat server
      final recentMessages = await _chatRemoteDataSource.getRecentMessages(
        uid: user.uid,
        threadId: thread.id,
        limit: 20,
      );

      // Build a message payload for the chat server
      final messagePayload = recentMessages.map((message) {
        final metadata = message.metadata ?? {};
        return {
          'role': message.role,
          'content': message.content,
          'sender': metadata['sender'] ?? (message.role == 'user' ? 'user' : 'character'),
        };
      }).toList();

      // Add the new message if not already present
      if (messagePayload.isEmpty || messagePayload.last['content'] != text) {
        messagePayload.add({'role': 'user', 'content': text, 'sender': 'user'});
      }

      if (widget.isGuiderInChat) {
        // Use guided chat endpoint when Guider is in the conversation
        await _sendGuidedMessage(user.uid, thread, messagePayload);
      } else {
        // Use regular chat endpoint
        await _sendRegularMessage(user.uid, thread, messagePayload);
      }

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Chat error: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  /// Send a regular message (character only)
  Future<void> _sendRegularMessage(
    String uid,
    ChatThreadModel thread,
    List<Map<String, dynamic>> messagePayload,
  ) async {
    // Convert to expected type for regular chat
    final stringPayload = messagePayload
        .map((m) => {'role': m['role'] as String, 'content': m['content'] as String})
        .toList();

    final aiResponse = await _chatAiRemoteDataSource.fetchAssistantResponse(
      uid: uid,
      threadId: thread.id,
      sessionId: thread.sessionId,
      characterId: widget.characterId,
      characterProfile: _buildCharacterPrompt(),
      messages: stringPayload,
      checkIntervention: !_interventionDismissed,
    );

    // Save character response to Firestore
    if (aiResponse.assistantMessage.isNotEmpty) {
      await _chatRemoteDataSource.sendMessage(
        uid: uid,
        threadId: thread.id,
        role: 'assistant',
        content: aiResponse.assistantMessage,
        metadata: {
          'characterId': widget.characterId,
          'sessionId': thread.sessionId,
          'sender': 'character',
        },
      );
    }

    // Handle Guider intervention if triggered
    if (aiResponse.intervention.shouldIntervene && !_interventionDismissed) {
      setState(() {
        _pendingIntervention = aiResponse.intervention;
      });
    }
  }

  /// Send a guided message (character + Guider respond)
  Future<void> _sendGuidedMessage(
    String uid,
    ChatThreadModel thread,
    List<Map<String, dynamic>> messagePayload,
  ) async {
    final guidedResponse = await _chatAiRemoteDataSource.fetchGuidedResponse(
      uid: uid,
      threadId: thread.id,
      sessionId: thread.sessionId,
      characterId: widget.characterId,
      characterProfile: _buildCharacterPrompt(),
      messages: messagePayload,
    );

    // Save character response to Firestore
    if (guidedResponse.characterMessage.isNotEmpty) {
      await _chatRemoteDataSource.sendMessage(
        uid: uid,
        threadId: thread.id,
        role: 'assistant',
        content: guidedResponse.characterMessage,
        metadata: {
          'characterId': widget.characterId,
          'sessionId': thread.sessionId,
          'sender': 'character',
        },
      );
    }

    // Save Guider response to Firestore
    if (guidedResponse.guiderMessage.isNotEmpty) {
      await _chatRemoteDataSource.sendMessage(
        uid: uid,
        threadId: thread.id,
        role: 'assistant',
        content: guidedResponse.guiderMessage,
        metadata: {
          'characterId': 'guider',
          'sessionId': thread.sessionId,
          'sender': 'guider',
        },
      );
    }
  }

  // Dismiss the current intervention (continue alone)
  void _dismissIntervention() {
    setState(() {
      _pendingIntervention = null;
      _interventionDismissed = true;
    });
  }

  // Let the Guider join the conversation
  void _letGuiderIn() {
    setState(() {
      _pendingIntervention = null;
    });
    widget.onGuiderStateChanged?.call(true);
  }

  //Build a system prompt for the inner character.
  Map<String, dynamic> _buildCharacterPrompt() {
    final profile = _characterProfile;
    if (profile != null) {
      return profile.toPromptMap();
    }
    return {
      'id': widget.characterId,
      'displayName': widget.fallbackTitle,
      'role': widget.fallbackRole ?? 'Manager',
      'shortDescription': widget.fallbackSubtitle,
      'whyIExist': '',
      'triggers': [],
      'coreBelief': '',
      'intention': '',
      'fear': '',
      'whatINeed': [],
    };
  }

  //Scroll to the bottom of the chat conversation.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  //Handle typing in the chat conversation.
  void _handleTyping() {
    _scrollToBottom();
  }

  //Handle focus change in the chat conversation.
  void _handleFocusChange() {
    if (_inputFocusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isInitializing
        ? const Center(child: CircularProgressIndicator())
        : _buildChatBody(context);
  }

  //Build the chat body.
  Widget _buildChatBody(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final thread = _thread;
    if (user == null || thread == null) {
      return const Center(child: Text('Please sign in to chat.'));
    }

    final headerTitle =
        _characterProfile?.displayName ?? widget.fallbackTitle;
    final headerSubtitle =
        _characterProfile?.shortDescription ?? widget.fallbackSubtitle;

    return Column(
      children: [
        if (widget.showHeader)
          _ChatHeader(
            title: headerTitle,
            subtitle: headerSubtitle,
          ),
        // Show Guider intervention card if pending
        if (_pendingIntervention != null)
          _GuiderInterventionCard(
            intervention: _pendingIntervention!,
            onContinueAlone: _dismissIntervention,
            onLetGuiderIn: _letGuiderIn,
          ),
        // Show Guider joined banner
        if (widget.isGuiderInChat && _pendingIntervention == null)
          _GuiderJoinedBanner(),
        Expanded(
          child: StreamBuilder<List<ChatMessageModel>>(
            stream: _chatRemoteDataSource.streamMessages(
              uid: user.uid,
              threadId: thread.id,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    tr(context, 'Start the conversation when you are ready.',
                        'ابدأ المحادثة عندما تكون مستعدًا.'),
                  ),
                );
              }

              return ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: messages.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && index == messages.length) {
                    return _TypingBubble(
                      label: widget.isGuiderInChat
                          ? tr(context, 'Thinking', 'يفكرون')
                          : headerTitle,
                    );
                  }
                  final message = messages[index];
                  final metadata = message.metadata ?? {};
                  final sender = metadata['sender'] ?? 
                      (message.role == 'user' ? 'user' : 'character');

                  return _ChatBubble(
                    isUser: message.role == 'user',
                    isGuider: sender == 'guider',
                    text: message.content,
                    characterAvatarPath: widget.showAssistantAvatar &&
                            message.role == 'assistant' &&
                            sender == 'character'
                        ? widget.assistantAvatarPath
                        : null,
                  );
                },
              );
            },
          ),
        ),
        _ChatInput(
          controller: _messageController,
          isSending: _isSending,
          focusNode: _inputFocusNode,
          onSend: _sendMessage,
        ),
      ],
    );
  }
}

//Header for the chat conversation.
class _ChatHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ChatHeader({
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(color: Color(0xFFEDE7FF)),
        ),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 20,
            backgroundColor: Color(0xFFB79CFF),
            child: Icon(Icons.psychology_alt, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
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
    );
  }
}

/// Banner showing when Guider has joined the conversation
class _GuiderJoinedBanner extends StatelessWidget {
  const _GuiderJoinedBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEDE7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFB79CFF).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFB79CFF),
            child: ClipOval(
              child: Image.asset(
                guiderAvatarPath,
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                alignment: Alignment.topCenter,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr(context, 'The Guider is here to help',
                  'المُرشد هنا للمساعدة'),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B5C82),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//Bubble for the chat conversation.
class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final bool isGuider;
  final String text;
  final String? characterAvatarPath;

  const _ChatBubble({
    required this.isUser,
    required this.text,
    this.isGuider = false,
    this.characterAvatarPath,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isGuider 
        ? const Color(0xFFF3EFFF) // Slightly different for Guider
        : Colors.white;
    final textColor = const Color(0xFF2A1E3B);
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final radius = BorderRadius.circular(18);
    
    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: radius,
        border: Border.all(
          color: isGuider 
              ? const Color(0xFFB79CFF) 
              : const Color(0xFFE5DEFF),
        ),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, height: 1.4),
      ),
    );

    // Guider messages with Guider avatar
    if (!isUser && isGuider) {
      return Align(
        alignment: alignment,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFB79CFF),
              child: ClipOval(
                child: Image.asset(
                  guiderAvatarPath,
                  width: 40,
                  height: 40,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.auto_awesome_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    // Character messages with character avatar
    if (!isUser && characterAvatarPath != null) {
      return Align(
        alignment: alignment,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFFEDE7FF),
              child: ClipOval(
                child: Image.asset(
                  characterAvatarPath!,
                  width: 40,
                  height: 40,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Align(
      alignment: alignment,
      child: bubble,
    );
  }
}

//Typing bubble for the chat conversation.
class _TypingBubble extends StatelessWidget {
  final String label;

  const _TypingBubble({required this.label});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '$label is thinking...',
          style: const TextStyle(color: Color(0xFF6B5C82)),
        ),
      ),
    );
  }
}

//Input for the chat conversation.
class _ChatInput extends StatelessWidget {
  final TextEditingController controller;
  final bool isSending;
  final FocusNode focusNode;
  final VoidCallback onSend;

  const _ChatInput({
    required this.controller,
    required this.isSending,
    required this.focusNode,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: tr(context, 'Share what is on your mind...',
                      'شاركني ما يدور في ذهنك...'),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton(
              onPressed: isSending ? null : onSend,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB79CFF),
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(14),
              ),
              child: isSending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

/// Guider intervention card shown when the Guider detects the user may need support.
class _GuiderInterventionCard extends StatelessWidget {
  final GuiderInterventionModel intervention;
  final VoidCallback onContinueAlone;
  final VoidCallback onLetGuiderIn;

  const _GuiderInterventionCard({
    required this.intervention,
    required this.onContinueAlone,
    required this.onLetGuiderIn,
  });

  @override
  Widget build(BuildContext context) {
    // Different styling based on severity
    final isCrisis = intervention.isCrisis;
    final backgroundColor = isCrisis
        ? const Color(0xFFFFF3E0) // Warmer orange for crisis
        : const Color(0xFFEDE7FF); // Soft purple for normal
    final borderColor = isCrisis
        ? const Color(0xFFFFB74D)
        : const Color(0xFFB79CFF);
    final iconColor = isCrisis
        ? const Color(0xFFFF9800)
        : const Color(0xFF8B7EC8);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: borderColor.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: borderColor,
                child: ClipOval(
                  child: Image.asset(
                    guiderAvatarPath,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                    errorBuilder: (_, __, ___) => Icon(
                      isCrisis ? Icons.favorite_rounded : Icons.auto_awesome_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr(context, 'The Guider', 'المُرشد'),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: iconColor,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onContinueAlone,
                child: Icon(
                  Icons.close_rounded,
                  color: iconColor.withOpacity(0.6),
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            intervention.guiderMessage ?? tr(
              context,
              'I\'m here if you want to talk.',
              'أنا هنا إن أردت التحدث.',
            ),
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF2A1E3B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onContinueAlone,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: iconColor,
                    side: BorderSide(color: borderColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    tr(context, 'It\'s okay, continue alone', 
                        'لا بأس، استمر بمفردي'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onLetGuiderIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: borderColor,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: Text(
                    tr(context, 'Let the Guider in', 
                        'دع المُرشد يدخل'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
