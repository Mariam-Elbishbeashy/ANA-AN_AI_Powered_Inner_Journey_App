// lib/features/guider/presentation/screens/guider_chat_history_screen.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:http/http.dart' as http;
import '../../domain/entities/guider_session.dart';
import '../../domain/entities/guider_message.dart';
import '../../data/repositories/guider_session_repository.dart';

// Helper function to check if Arabic
bool _isArabic(BuildContext context) {
  return Localizations.localeOf(context).languageCode == 'ar';
}

class GuiderChatHistoryScreen extends StatefulWidget {
  final GuiderSession session;
  final String userName;

  const GuiderChatHistoryScreen({
    super.key,
    required this.session,
    required this.userName,
  });

  @override
  State<GuiderChatHistoryScreen> createState() => _GuiderChatHistoryScreenState();
}

class _GuiderChatHistoryScreenState extends State<GuiderChatHistoryScreen> {
  late final GuiderSessionRepository _repository;
  List<GuiderMessage> _messages = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = GuiderSessionRepository();
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

    print("🔍 Session ID: ${widget.session.id}");
    print("🔍 Thread ID from session: '${widget.session.threadId}'");

    String threadId = widget.session.threadId;

    try {
      print("📖 Loading messages from thread: $threadId");

      final messagesRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('chat_threads')
          .doc(threadId)
          .collection('messages');

      final snapshot = await messagesRef
          .orderBy('createdAt', descending: false)
          .get();

      print("📊 Found ${snapshot.docs.length} messages in thread");

      if (snapshot.docs.isEmpty) {
        setState(() {
          _messages = [];
          _isLoading = false;
        });
        return;
      }

      final messages = <GuiderMessage>[];

      // Decrypt each message
      for (final doc in snapshot.docs) {
        final data = doc.data();
        print("📄 Message doc: role=${data['role']}, hasCiphertext=${data['contentCiphertext'] != null}");

        String content = data['content'] ?? '';

        // If encrypted, decrypt via backend
        if (data['contentCiphertext'] != null) {
          try {
            // 🔥 CRITICAL FIX: Convert Timestamp to ISO string
            final cleanData = _cleanMessageData(data);

            final decryptResponse = await http.post(
              Uri.parse("http://192.168.100.7:5003/guider/decrypt_message"),
              headers: {'Content-Type': 'application/json'},
              body: json.encode({
                'uid': user.uid,
                'messageData': cleanData,
              }),
            ).timeout(const Duration(seconds: 5));

            if (decryptResponse.statusCode == 200) {
              final decryptData = json.decode(decryptResponse.body);
              if (decryptData['success'] == true) {
                content = decryptData['content'] ?? '';
                print("✅ Decrypted message: ${content.substring(0, content.length > 30 ? 30 : content.length)}...");
              }
            } else {
              print("⚠️ Decryption HTTP error: ${decryptResponse.statusCode}");
              content = '[Encrypted message]';
            }
          } catch (e) {
            print("⚠️ Decryption failed: $e");
            content = '[Encrypted message]';
          }
        }

        messages.add(GuiderMessage(
          id: doc.id,
          role: data['role'] ?? 'user',
          content: content,
          sender: data['sender'],
          createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
        ));
      }

      setState(() {
        _messages = messages;
        _isLoading = false;
      });

    } catch (e) {
      print("❌ Error loading messages: $e");
      setState(() {
        _error = 'Error loading messages: $e';
        _isLoading = false;
      });
    }
  }

// 🔥 Helper method to clean Timestamp objects
  Map<String, dynamic> _cleanMessageData(Map<String, dynamic> data) {
    final clean = <String, dynamic>{};

    for (final entry in data.entries) {
      final key = entry.key;
      final value = entry.value;

      if (value is Timestamp) {
        // Convert Timestamp to ISO string
        clean[key] = value.toDate().toIso8601String();
      } else if (value is Map) {
        // Recursively clean nested maps
        clean[key] = _cleanMessageData(Map<String, dynamic>.from(value));
      } else if (value is List) {
        // Clean lists if needed
        clean[key] = value;
      } else {
        clean[key] = value;
      }
    }

    return clean;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _isArabic(context);
    final title = tr(context, 'The Guider', 'المرشد');

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
              _buildAppBar(isArabic, title),
              _buildSessionBanner(isArabic),
              Expanded(
                child: _buildMessageList(isArabic),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isArabic, String title) {
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
                title,
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

  Widget _buildSessionBanner(bool isArabic) {
    return Padding(
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
    );
  }

  Widget _buildMessageList(bool isArabic) {
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
            ? widget.userName
            : (isGuider
            ? tr(context, 'The Guider', 'المرشد')
            : tr(context, 'Assistant', 'المساعد'));

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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Guider image for non-user messages
          if (!isUser)
            Container(
              width: 36,
              height: 36,
              margin: const EdgeInsets.only(right: 10),
              child: ClipOval(
                child: Image.asset(
                  'assets/images/guider.png',
                  width: 36,
                  height: 36,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback to icon if image fails to load
                    return Container(
                      width: 36,
                      height: 36,
                      color: isGuider
                          ? const Color(0xFFB79CFF).withValues(alpha: 0.15)
                          : const Color(0xFFEDE7FF),
                      child: Icon(
                        isGuider ? Icons.assistant_navigation : Icons.psychology_alt,
                        size: 20,
                        color: isGuider ? const Color(0xFFB79CFF) : const Color(0xFF8E7CFF),
                      ),
                    );
                  },
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

                // Message bubble - white with border
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