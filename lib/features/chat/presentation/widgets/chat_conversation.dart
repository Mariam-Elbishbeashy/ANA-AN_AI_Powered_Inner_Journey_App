import 'dart:async';

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
import 'package:ana_ifs_app/features/chat/presentation/widgets/guider_avatar.dart';

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

  /// when provided, the conversation will open an existing thread instead of
  /// auto-creating/finding the active thread.

  /// - start new session => create session+thread => open its `threadId`
  final String? threadId;

  /// when true, the user can *only view* messages (no sending).
  ///
  /// used for "ended" sessions: user can open a past session and read it,
  /// but cannot add messages to it.
  final bool readOnly;

  /// whether the guider is currently in the conversation
  final bool isGuiderInChat;

  /// callback when user wants to invite/remove the guider
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
    this.threadId,
    this.readOnly = false,
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

  // firestore calls can occasionally hang (connectivity / local cache sync)
  // enforcing a timeout so the UI never stays stuck in "sending" forever
  static const Duration _firestoreTimeout = Duration(seconds: 20);
  static const Duration _combineSpeakerWindow = Duration(seconds: 12);

  //Data for the chat conversation.
  ChatThreadModel? _thread;
  InnerCharacterProfile? _characterProfile;
  bool _isInitializing = true;
  bool _isSending = false;
  Object? _lastSendError;
  int _lastRenderedMessageCount = 0;

  // Guider intervention state
  GuiderInterventionModel? _pendingIntervention;
  bool _interventionDismissed = false;

  @override
  void initState() {
    super.initState();
    _initializeChat();
    _inputFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _inputFocusNode.removeListener(_handleFocusChange);
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

    // If the caller gave us a threadId, we open that thread directly.
    // Otherwise we fall back to the legacy behavior (ensure active thread).
    final existingThreadId = widget.threadId;
    final thread = (existingThreadId != null && existingThreadId.isNotEmpty)
        ? await _chatRemoteDataSource.getThreadById(
            uid: user.uid,
            threadId: existingThreadId,
          )
        : await _chatRemoteDataSource.ensureChatThread(
            uid: user.uid,
            characterId: widget.characterId,
            characterType: widget.characterType,
            title: character?.displayName ?? widget.fallbackTitle,
          );

    if (thread == null) {
      // Thread not found (deleted or permission issue). We keep UI stable.
      if (!mounted) return;
      setState(() {
        _isInitializing = false;
      });
      return;
    }

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

    // Hard stop for ended sessions / read-only viewers.
    if (widget.readOnly || thread.status != 'active') {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'This session has ended. You can view it, but you can’t send new messages.',
              'انتهت هذه الجلسة. يمكنك عرضها، لكن لا يمكنك إرسال رسائل جديدة.',
            ),
          ),
        ),
      );
      return;
    }

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
      ).timeout(_firestoreTimeout);

      // Get recent messages from the chat server
      final recentMessages = await _chatRemoteDataSource.getRecentMessages(
        uid: user.uid,
        threadId: thread.id,
        limit: 20,
      ).timeout(_firestoreTimeout);

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

      _lastSendError = null;
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _lastSendError = error;

      final isTimeout = error is TimeoutException;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isTimeout
                ? tr(
                    context,
                    'This is taking too long. Please try again.',
                    'الرد يستغرق وقتًا طويلًا. حاول مرة أخرى.',
                  )
                : 'Chat error: $error',
          ),
          action: SnackBarAction(
            label: tr(context, 'Retry', 'إعادة المحاولة'),
            onPressed: _retryLastTurn,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<void> _retryLastTurn() async {
    final user = FirebaseAuth.instance.currentUser;
    final thread = _thread;
    if (user == null || thread == null) return;
    if (_isSending) return;
    if (widget.readOnly || thread.status != 'active') return;

    setState(() {
      _isSending = true;
    });

    try {
      final recentMessages = await _chatRemoteDataSource.getRecentMessages(
        uid: user.uid,
        threadId: thread.id,
        limit: 20,
      ).timeout(_firestoreTimeout);

      final messagePayload = recentMessages.map((message) {
        final metadata = message.metadata ?? {};
        return {
          'role': message.role,
          'content': message.content,
          'sender': metadata['sender'] ??
              (message.role == 'user' ? 'user' : 'character'),
        };
      }).toList();

      if (widget.isGuiderInChat) {
        await _sendGuidedMessage(user.uid, thread, messagePayload);
      } else {
        await _sendRegularMessage(user.uid, thread, messagePayload);
      }

      _lastSendError = null;
      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;
      _lastSendError = error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Retry failed: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _senderOf(ChatMessageModel message) {
    final metadata = message.metadata ?? {};
    return (metadata['sender'] ??
            (message.role == 'user' ? 'user' : 'character'))
        .toString();
  }

  /// In Guider-in-chat (trio) mode, the backend can return both a character reply
  /// and a Guider reply for a single user turn. Persisting both is useful, but
  /// rendering them as two consecutive bubbles feels like "talking at the same time".
  ///
  /// We keep both messages in Firestore, but group the consecutive pair into one
  /// UI item: character bubble + collapsible Guider note.
  List<_ChatListItem> _groupMessagesForUi(List<ChatMessageModel> messages) {
    final items = <_ChatListItem>[];

    for (var i = 0; i < messages.length; i++) {
      final current = messages[i];
      final currentSender = _senderOf(current);

      final canStartCombined =
          current.role == 'assistant' && currentSender == 'character';
      if (canStartCombined && i + 1 < messages.length) {
        final next = messages[i + 1];
        final nextSender = _senderOf(next);
        final isGuiderNext =
            next.role == 'assistant' && nextSender == 'guider';

        if (isGuiderNext) {
          final a = current.createdAt;
          final b = next.createdAt;

          // If timestamps are missing, still combine (same logical turn).
          final withinWindow = (a == null || b == null)
              ? true
              : b.difference(a).abs() <= _combineSpeakerWindow;

          if (withinWindow) {
            items.add(_ChatListItem.combined(character: current, guider: next));
            i++; // consume next too
            continue;
          }
        }
      }

      items.add(_ChatListItem.single(current));
    }

    return items;
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
      ).timeout(_firestoreTimeout);
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
      ).timeout(_firestoreTimeout);
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
      ).timeout(_firestoreTimeout);
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


    // Use AppLanguageProvider for in-app language toggles.
    final useArabic = isArabic(context);

    // The character name shown in chat come from firestore (the caller
    // passes it through `fallbackTitle`)

    final headerTitle = widget.fallbackTitle;
    final headerSubtitle = useArabic
        ? (_characterProfile?.shortDescriptionAr.isNotEmpty == true
            ? _characterProfile!.shortDescriptionAr
            : widget.fallbackSubtitle)
        : (_characterProfile?.shortDescription ?? widget.fallbackSubtitle);

    return Column(
      children: [
        if (widget.showHeader)
          _ChatHeader(
            title: headerTitle,
            subtitle: headerSubtitle,
          ),
        // show Guider intervention card if pending
        if (_pendingIntervention != null)
          _GuiderInterventionCard(
            intervention: _pendingIntervention!,
            onContinueAlone: _dismissIntervention,
            onLetGuiderIn: _letGuiderIn,
          ),
        // show Guider joined banner
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
              _autoScrollAfterBuildIfNeeded(messages);
              if (messages.isEmpty) {
                return Center(
                  child: Text(
                    tr(context, 'Start the conversation when you are ready.',
                        'ابدأ المحادثة عندما تكون مستعدًا.'),
                  ),
                );
              }

              final items = _groupMessagesForUi(messages);

              return ListView.builder(
                controller: _scrollController,
                padding: EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                itemCount: items.length + (_isSending ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isSending && index == items.length) {
                    return _TypingBubble(
                      label: widget.isGuiderInChat
                          ? tr(context, 'Thinking', 'يفكرون')
                          : headerTitle,
                    );
                  }
                  final item = items[index];
                  if (item.isCombined) {
                    final characterMessage = item.character!;
                    final guiderMessage = item.guider!;
                    return _CombinedAssistantTurn(
                      characterText: characterMessage.content,
                      guiderText: guiderMessage.content,
                      characterAvatarPath: widget.showAssistantAvatar
                          ? widget.assistantAvatarPath
                          : null,
                    );
                  }

                  final message = item.message!;
                  final sender = _senderOf(message);

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
        if (!widget.readOnly)
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
        border: Border.all(color: const Color(0xFFB79CFF).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const GuiderAvatar(
            size: 28,
            backgroundColor: const Color(0xFFB79CFF),
            fallbackIconSize: 14,
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
            const GuiderAvatar(
              size: 40,
              backgroundColor: const Color(0xFFB79CFF),
              fallbackIconSize: 20,
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

class _ChatListItem {
  final ChatMessageModel? message;
  final ChatMessageModel? character;
  final ChatMessageModel? guider;

  _ChatListItem.single(this.message)
      : character = null,
        guider = null;

  _ChatListItem.combined({required this.character, required this.guider})
      : message = null;

  bool get isCombined => character != null && guider != null;
}

class _CombinedAssistantTurn extends StatelessWidget {
  final String characterText;
  final String guiderText;
  final String? characterAvatarPath;

  const _CombinedAssistantTurn({
    required this.characterText,
    required this.guiderText,
    this.characterAvatarPath,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ChatBubble(
          isUser: false,
          isGuider: false,
          text: characterText,
          characterAvatarPath: characterAvatarPath,
        ),
        _GuiderNoteBubble(text: guiderText),
      ],
    );
  }
}

class _GuiderNoteBubble extends StatefulWidget {
  final String text;

  const _GuiderNoteBubble({required this.text});

  @override
  State<_GuiderNoteBubble> createState() => _GuiderNoteBubbleState();
}

class _GuiderNoteBubbleState extends State<_GuiderNoteBubble> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(left: 52, top: 4, bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF8F6FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB79CFF)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  const Icon(
                    Icons.auto_awesome_rounded,
                    size: 16,
                    color: Color(0xFF6B5C82),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(context, 'Guider note', 'ملاحظة المُرشد'),
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6B5C82),
                      ),
                    ),
                  ),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    color: const Color(0xFF6B5C82),
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              Text(
                widget.text,
                style: const TextStyle(
                  color: Color(0xFF2A1E3B),
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
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
            color: borderColor.withValues(alpha: 0.2),
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
              GuiderAvatar(
                size: 36,
                backgroundColor: borderColor,
                fallbackIcon: isCrisis
                    ? Icons.favorite_rounded
                    : Icons.auto_awesome_rounded,
                fallbackIconSize: 18,
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
                  color: iconColor.withValues(alpha: 0.6),
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
