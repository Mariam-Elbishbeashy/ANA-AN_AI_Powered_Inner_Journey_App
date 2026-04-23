import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/guider_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_message_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_thread_model.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/guider_session_history_screen.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/guider_avatar.dart';

/// Active/read-only screen for a specific guider session.
class GuiderChatSessionScreen extends StatefulWidget {
  final ChatSessionModel session;
  final bool readOnly;

  const GuiderChatSessionScreen({
    super.key,
    required this.session,
    this.readOnly = false,
  });

  @override
  State<GuiderChatSessionScreen> createState() => _GuiderChatSessionScreenState();
}

class _GuiderChatSessionScreenState extends State<GuiderChatSessionScreen> {
  final _chatRemoteDataSource = ChatRemoteDataSource();
  final _chatAiRemoteDataSource = ChatAiRemoteDataSource();
  final _guiderAiDataSource = GuiderAiRemoteDataSource();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _inputFocusNode = FocusNode();

  ChatThreadModel? _thread;
  bool _isInitializing = true;
  bool _isSending = false;
  bool _ending = false;
  int _lastRenderedMessageCount = 0;

  bool get _isActiveSession => widget.session.isActive && !widget.readOnly;

  @override
  void initState() {
    super.initState();
    _initializeChat();
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

    final thread = await _chatRemoteDataSource.getThreadById(
      uid: user.uid,
      threadId: widget.session.threadId,
    );

    if (!mounted) return;
    setState(() {
      _thread = thread;
      _isInitializing = false;
    });
  }

  Future<bool> _confirmEndSession() async {
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

      try {
        await _chatAiRemoteDataSource.endAnalyzeSession(
          uid: user.uid,
          sessionId: widget.session.id,
          threadId: widget.session.threadId,
          characterId: 'guider',
        );
      } catch (_) {}

      await _chatRemoteDataSource.endChatSession(
        uid: user.uid,
        sessionId: widget.session.id,
        threadId: widget.session.threadId,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to end session: $e')),
      );
      setState(() => _ending = false);
    }
  }

  Future<void> _handleExitAttempt() async {
    if (!_isActiveSession) {
      if (mounted) Navigator.of(context).pop();
      return;
    }
    if (_ending) return;
    final ok = await _confirmEndSession();
    if (!ok) return;
    await _endSessionAndExit();
  }

  Future<void> _sendMessage() async {
    final user = FirebaseAuth.instance.currentUser;
    final thread = _thread;
    if (user == null || thread == null) return;
    if (!_isActiveSession) return;

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
          'characterId': 'guider',
          'sessionId': thread.sessionId,
        },
      );

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

      final assistantMessage = await _guiderAiDataSource.fetchGuiderResponse(
        uid: user.uid,
        sessionId: thread.sessionId,
        threadId: thread.id,
        messages: messagePayload,
      );

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

  void _scrollToBottom({bool animate = true}) {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    final target = position.maxScrollExtent;
    final distance = (target - position.pixels).abs();

    // Avoid tiny repeated animations that feel like jitter.
    if (distance < 8) return;

    if (animate) {
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(target);
    }
  }

  bool _isNearBottom({double threshold = 120}) {
    if (!_scrollController.hasClients) return true;
    final position = _scrollController.position;
    final distanceFromBottom = position.maxScrollExtent - position.pixels;
    return distanceFromBottom <= threshold;
  }

  void _autoScrollAfterBuildIfNeeded(List<ChatMessageModel> messages) {
    final currentCount = messages.length;

    // Initialize counter without scrolling on first paint.
    if (_lastRenderedMessageCount == 0) {
      _lastRenderedMessageCount = currentCount;
      return;
    }

    final hasNewMessages = currentCount > _lastRenderedMessageCount;
    final userIsNearBottom = _isNearBottom();
    _lastRenderedMessageCount = currentCount;

    if (!hasNewMessages || !userIsNearBottom) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToBottom();
    });
  }

  void _handleFocusChange() {
    if (_inputFocusNode.hasFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _scrollToBottom(animate: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isActiveSession,
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
                      if (_isActiveSession)
                        _CircleIconButton(
                          icon: Icons.history_rounded,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => GuiderSessionHistoryScreen(
                                  currentlyOpenSessionId: widget.session.id,
                                ),
                              ),
                            );
                          },
                        )
                      else
                        const SizedBox(width: 44),
                    ],
                  ),
                ),
                if (widget.readOnly)
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
                          'This session has ended. You’re viewing it in read-only mode.',
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
                  child: _isInitializing
                      ? const Center(child: CircularProgressIndicator())
                      : _buildChatBody(context),
                ),
              ],
            ),
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
        Expanded(
          child: StreamBuilder<List<ChatMessageModel>>(
            stream: _chatRemoteDataSource.streamMessages(
              uid: user.uid,
              threadId: thread.id,
            ),
            builder: (context, snapshot) {
              final messages = snapshot.data ?? [];
              _autoScrollAfterBuildIfNeeded(messages);
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
                itemCount: messages.length + ((_isSending && _isActiveSession) ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && _isActiveSession && index == messages.length) {
                    return _TypingBubble(
                      label: tr(context, 'The Guider', 'المُرشد'),
                    );
                  }
                  final message = messages[index];
                  return _ChatBubble(
                    isUser: message.role == 'user',
                    text: message.content,
                    showGuiderAvatar: message.role == 'assistant',
                  );
                },
              );
            },
          ),
        ),
        if (_isActiveSession)
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
            const GuiderAvatar(
              size: 100,
              backgroundColor: Color(0xFFEDE7FF),
              fallbackIconSize: 40,
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
  final bool isUser;
  final String text;
  final bool showGuiderAvatar;

  const _ChatBubble({
    required this.isUser,
    required this.text,
    required this.showGuiderAvatar,
  });

  @override
  Widget build(BuildContext context) {
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;

    final bubble = Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF2A1E3B), height: 1.4),
      ),
    );

    if (!isUser && showGuiderAvatar) {
      return Align(
        alignment: alignment,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const GuiderAvatar(
              size: 40,
              backgroundColor: Color(0xFFEDE7FF),
              fallbackIconSize: 20,
            ),
            const SizedBox(width: 12),
            Flexible(child: bubble),
          ],
        ),
      );
    }

    return Align(alignment: alignment, child: bubble);
  }
}

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
