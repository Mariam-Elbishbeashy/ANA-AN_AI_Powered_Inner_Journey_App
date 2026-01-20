import 'package:flutter/material.dart';
import 'widgets/shared_widgets.dart';
import '../l10n/app_strings.dart';

enum _ReframeMode { chat, voice, video }

class ReframeScreen extends StatefulWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const ReframeScreen({
    super.key,
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  State<ReframeScreen> createState() => _ReframeScreenState();
}

class _ReframeScreenState extends State<ReframeScreen> {
  _ReframeMode _mode = _ReframeMode.chat;
  final TextEditingController _chatController = TextEditingController();
  bool _listening = false;

  @override
  void dispose() {
    _chatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopHelloBar(
          name: widget.name,
          onLogout: widget.onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SettingsBottomSheet(
                onRetakeQuestionnaire: widget.onRetakeQuestionnaire,
                onSwitchLanguage: widget.onSwitchLanguage,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E7CFF).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.category_rounded,
                    size: 54,
                    color: Color(0xFF8E7CFF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr(context, "Reframe", "إعادة الإطار"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  tr(
                    context,
                    "This space is for reflection. Speak freely, and let ANA gently reframe your inner parts based on what you share.",
                    "هذه المساحة للتأمل. تحدث بحرية، ودع آنا تعيد صياغة أجزائك الداخلية برفق بناءً على ما تشاركه.",
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4B3A66),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _ModeCard(
                        title: tr(context, "Chat", "دردشة"),
                        icon: Icons.chat_bubble_rounded,
                        selected: _mode == _ReframeMode.chat,
                        onTap: () => setState(() => _mode = _ReframeMode.chat),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        title: tr(context, "Voice", "صوت"),
                        icon: Icons.mic_rounded,
                        selected: _mode == _ReframeMode.voice,
                        onTap: () => setState(() => _mode = _ReframeMode.voice),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ModeCard(
                        title: tr(context, "Video", "فيديو"),
                        icon: Icons.videocam_rounded,
                        selected: _mode == _ReframeMode.video,
                        onTap: () => setState(() => _mode = _ReframeMode.video),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  child: _buildModeContent(context),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildModeContent(BuildContext context) {
    switch (_mode) {
      case _ReframeMode.chat:
        return _ChatInputCard(
          key: const ValueKey('chat'),
          controller: _chatController,
          hint: tr(context, "Write what you're feeling...", "اكتب ما تشعر به..."),
        );
      case _ReframeMode.voice:
        return _VoiceInputCard(
          key: const ValueKey('voice'),
          listening: _listening,
          onToggle: () => setState(() => _listening = !_listening),
        );
      case _ReframeMode.video:
        return _VideoInputCard(
          key: const ValueKey('video'),
        );
    }
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF8E7CFF) : const Color(0xFF9B92B3);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFF3EDFF) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? const Color(0xFF8E7CFF) : const Color(0xFFE5DEFF),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;

  const _ChatInputCard({
    super.key,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        maxLines: 4,
        decoration: InputDecoration(
          hintText: hint,
          border: InputBorder.none,
        ),
      ),
    );
  }
}

class _VoiceInputCard extends StatelessWidget {
  final bool listening;
  final VoidCallback onToggle;

  const _VoiceInputCard({
    super.key,
    required this.listening,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = listening ? const Color(0xFF8E7CFF) : const Color(0xFFEDE7FF);
    final iconColor =
        listening ? Colors.white : const Color(0xFF8E7CFF);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.mic_rounded, color: iconColor),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              listening
                  ? tr(context, "Listening...", "جارٍ الاستماع...")
                  : tr(context, "Tap to start speaking", "اضغط لبدء التحدث"),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B3A66),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VideoInputCard extends StatelessWidget {
  const _VideoInputCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE7FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.videocam_rounded,
              color: Color(0xFF8E7CFF),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              tr(
                context,
                "Tap to start video sharing",
                "اضغط لبدء مشاركة الفيديو",
              ),
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF4B3A66),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}