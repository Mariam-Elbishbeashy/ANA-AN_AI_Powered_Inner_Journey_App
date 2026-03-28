import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/guider_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_message_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_thread_model.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/guider_avatar.dart';

/// Screen for chatting with The Guider.
/// The Guider has access to all character conversations and can create healing plans.
class GuiderChatScreen extends StatefulWidget {
  const GuiderChatScreen({super.key});

  @override
  State<GuiderChatScreen> createState() => _GuiderChatScreenState();
}

class _GuiderChatScreenState extends State<GuiderChatScreen> {
  final _chatRemoteDataSource = ChatRemoteDataSource();
  final _guiderAiDataSource = GuiderAiRemoteDataSource();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  ChatThreadModel? _thread;
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

    // Create or get the guider chat thread
    final thread = await _chatRemoteDataSource.ensureChatThread(
      uid: user.uid,
      characterId: 'guider',
      characterType: 'guider',
      title: 'The Guider',
    );

    if (!mounted) return;
    setState(() {
      _thread = thread;
      _isInitializing = false;
    });
  }

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
          'characterId': 'guider',
          'sessionId': thread.sessionId,
        },
      );

      // Get recent messages for context
      final recentMessages = await _chatRemoteDataSource.getRecentMessages(
        uid: user.uid,
        threadId: thread.id,
        limit: 20,
      );

      final messagePayload = recentMessages
          .map((message) => {
                'role': message.role,
                'content': message.content,
              })
          .toList();

      if (messagePayload.isEmpty || messagePayload.last['content'] != text) {
        messagePayload.add({'role': 'user', 'content': text});
      }

      // Fetch guider response from the backend
      final assistantMessage = await _guiderAiDataSource.fetchGuiderResponse(
        uid: user.uid,
        messages: messagePayload,
      );

      // Save assistant response to Firestore
      if (assistantMessage.isNotEmpty) {
        await _chatRemoteDataSource.sendMessage(
          uid: user.uid,
          threadId: thread.id,
          role: 'assistant',
          content: assistantMessage,
          metadata: {
            'characterId': 'guider',
            'sessionId': thread.sessionId,
          },
        );
      }

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      final message = error is TimeoutException
          ? tr(
              context,
              'The Guider is taking longer than usual. Please try again.',
              'المُرشد يستغرق وقتًا أطول من المعتاد. حاول مرة أخرى.',
            )
          : 'Chat error: $error';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _handleTyping() {
    _scrollToBottom();
  }

  void _handleFocusChange() {
    if (_inputFocusNode.hasFocus) {
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
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
              // Header with title and subtitle
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                    Expanded(
                      child: Column(
                        children: [
                          Text(
                            tr(context, 'The Guider', 'المُرشد'),
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(
                              context,
                              'Your companion on the healing journey',
                              'رفيقك في رحلة الشفاء',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B5C82),
                            ),
                          ),
                        ],
                      ),
                    ),
                    _CircleIconButton(
                      icon: Icons.auto_awesome_rounded,
                      onTap: () {
                        // TODO: Show guider info/plan
                      },
                    ),
                  ],
                ),
              ),
              // Chat body
              Expanded(
                child: _isInitializing
                    ? const Center(child: CircularProgressIndicator())
                    : _buildChatBody(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatBody(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final thread = _thread;
    if (user == null || thread == null) {
      return Center(
        child: Text(tr(context, 'Please sign in to chat.', 'يرجى تسجيل الدخول للدردشة.')),
      );
    }

    return Column(
      children: [
        // Messages
        Expanded(
          child: StreamBuilder<List<ChatMessageModel>>(
            stream: _chatRemoteDataSource.streamMessages(
              uid: user.uid,
              threadId: thread.id,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              if (messages.isEmpty) {
                return _buildEmptyState(context);
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
                      label: tr(context, 'The Guider', 'المُرشد'),
                    );
                  }
                  final message = messages[index];
                  return _ChatBubble(
                    isUser: message.role == 'user',
                    text: message.content,
                    avatarPath:
                        message.role == 'assistant' ? guiderAvatarPath : null,
                  );
                },
              );
            },
          ),
        ),
        // Input
        _ChatInput(
          controller: _messageController,
          isSending: _isSending,
          focusNode: _inputFocusNode,
          onSend: _sendMessage,
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Guider image
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFEDE7FF),
                shape: BoxShape.circle,
              ),
              child: const GuiderAvatar(
                size: 100,
                backgroundColor: Colors.transparent,
                fallbackIconSize: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              tr(context, 'Welcome', 'مرحبًا'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                context,
                'Share what\'s on your mind, and I\'ll walk with you.',
                'شاركني ما يدور في ذهنك، وسأسير معك.',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B5C82),
                height: 1.6,
              ),
            ),
          ],
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
            const GuiderAvatar(
              size: 40,
              backgroundColor: const Color(0xFFEDE7FF),
              fallbackIconSize: 20,
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

class _TypingBubble extends StatelessWidget {
  final String label;

  const _TypingBubble({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(
              '$label is thinking...',
              style: const TextStyle(color: Color(0xFF6B5C82)),
            ),
          ],
        ),
      ),
    );
  }
}

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
                  hintText: tr(
                    context,
                    'Share what is on your mind...',
                    'شاركني ما يدور في ذهنك...',
                  ),
                  border: const OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(20)),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
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
