import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/features/chat/data/datasources/chat_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_message_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_thread_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';

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
      await _chatRemoteDataSource.sendMessage(
        uid: user.uid,
        threadId: thread.id,
        role: 'user',
        content: text,
        metadata: {
          'characterId': widget.characterId,
          'sessionId': thread.sessionId,
        },
      );

      //Get recent messages from the chat server.
      //remembers the last 20 messages.
      final recentMessages = await _chatRemoteDataSource.getRecentMessages(
        uid: user.uid,
        threadId: thread.id,
        limit: 20,
      );

      //Build a message payload for the chat server.
      final messagePayload = recentMessages
          .map(
            (message) => {
              'role': message.role,
              'content': message.content,
            },
          )
          .toList();

      //Add the new message to the message payload.
      if (messagePayload.isEmpty ||
          messagePayload.last['content'] != text) {
        messagePayload.add({'role': 'user', 'content': text});
      }

      //Fetch a chat response from the chat server.
      final assistantMessage =
          await _chatAiRemoteDataSource.fetchAssistantMessage(
        uid: user.uid,
        threadId: thread.id,
        sessionId: thread.sessionId,
        characterId: widget.characterId,
        characterProfile: _buildCharacterPrompt(),
        messages: messagePayload,
      );

      //Send the chat response to the chat server.
      if (assistantMessage.isNotEmpty) {
        await _chatRemoteDataSource.sendMessage(
          uid: user.uid,
          threadId: thread.id,
          role: 'assistant',
          content: assistantMessage,
          metadata: {
            'characterId': widget.characterId,
            'sessionId': thread.sessionId,
          },
        );
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
        Expanded(
          child: StreamBuilder<List<ChatMessageModel>>(
            stream: _chatRemoteDataSource.streamMessages(
              uid: user.uid,
              threadId: thread.id,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return const Center(
                  child: Text('Start the conversation when you are ready.'),
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
                    return _TypingBubble(label: headerTitle);
                  }
                  final message = messages[index];
                  return _ChatBubble(
                    isUser: message.role == 'user',
                    text: message.content,
                    avatarPath: widget.showAssistantAvatar &&
                            message.role == 'assistant'
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

//Bubble for the chat conversation.
class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final String? avatarPath;

  const _ChatBubble({
    required this.isUser,
    required this.text,
    this.avatarPath,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = Colors.white;
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
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Text(
        text,
        style: TextStyle(color: textColor, height: 1.4),
      ),
    );

    if (!isUser && avatarPath != null) {
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
                  avatarPath!,
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
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text(
          '$label is thinking...',
          style: const TextStyle(color: Color(0xFF6B5C82)),
        ),
      ),
    );
  }
}

//Input for the chat conversation.
//Allows the user to type and send messages to the chat server.
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
                decoration: const InputDecoration(
                  hintText: 'Share what is on your mind...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
