import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/guider_session_history_screen.dart';
import 'package:ana_ifs_app/features/video_chat/presentation/screens/guider_video_call_screen.dart'; // Add this import
import 'package:ana_ifs_app/features/voice_analysis/presentation/screens/voice_analysis_screen.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/voice_analysis/presentation/screens/guider_voice_sessions_screen.dart';
import '../../../video_chat/presentation/screens/guider_sessions_screen.dart';

import 'package:ana_ifs_app/features/voice_analysis/presentation/screens/voice_sessions_screen.dart';

class ChatScreen extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;
  final UserCharacter character;

  const ChatScreen({
    super.key,
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
    required this.character,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFFB79CFF);
    final isAr = isArabic(context);

    return Column(
      children: [
        TopHelloBar(
          name: name,
          onLogout: onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => SettingsBottomSheet(
                onRetakeQuestionnaire: onRetakeQuestionnaire,
                onSwitchLanguage: onSwitchLanguage,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              20 + 92 + MediaQuery.of(context).padding.bottom,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Align(
                  alignment: Alignment.center,
                  child: Transform.translate(
                    offset: const Offset(-40, 0),
                    child: SizedBox(
                      width: 250,
                      height: 250,
                      child: Image.asset(
                        'assets/animations/guider_chat.gif',
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.smart_toy_rounded,
                              size: 60,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  tr(context, "Chat with The Guider", "اتكلم مع المُرشد"),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  tr(
                    context,
                    "The Guider is your calm, supportive companion. It helps you slow down, notice your inner parts, and gently reframe what you share.",
                    "المُرشد هو صاحبك الهادي والداعم. بيساعدك تهدى، وتلاحظ الأجزاء اللي جواك، ويعيد صياغة اللي بتشاركه بلُطف.",
                  ),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF4B3A66),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Directionality(
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    child: Column(
                      crossAxisAlignment:
                      isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        Row(
                          textDirection:
                          isAr ? TextDirection.rtl : TextDirection.ltr,
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: accent,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr(context, "How it works:", "بيشتغل إزاي:"),
                                textAlign:
                                isAr ? TextAlign.right : TextAlign.left,
                                textDirection:
                                isAr ? TextDirection.rtl : TextDirection.ltr,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF2A1E3B),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 15),
                        _InstructionStep(
                          number: 1,
                          text: tr(
                            context,
                            "Say what's on your mind",
                            "قول اللي في بالك",
                          ),
                        ),
                        _InstructionStep(
                          number: 2,
                          text: tr(
                            context,
                            "Let The Guider reflect and reframe",
                            "سيب المُرشد يعكس ويعيد صياغه",
                          ),
                        ),
                        _InstructionStep(
                          number: 3,
                          text: tr(
                            context,
                            "Notice which inner part shows up",
                            "لاحظ أنهي جزء داخلي ظهر",
                          ),
                        ),
                        _InstructionStep(
                          number: 4,
                          text: tr(
                            context,
                            "Choose a next step with clarity",
                            "اختار الخطوة الجاية بوضوح",
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Talk to Me Hub
                _GuiderCommunicationHub(
                  userName: name, // Add this parameter
                  onChat: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const GuiderSessionHistoryScreen(),
                      ),
                    );
                  },
                  onVoice: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GuiderVoiceSessionsScreen(
                          userName: character.displayNameEn,
                          characterId: character.id,
                        ),
                      ),
                    );
                  },
                  onVideo: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => GuiderSessionsScreen(
                          userName: name,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InstructionStep extends StatelessWidget {
  final int number;
  final String text;

  const _InstructionStep({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    final isAr = isArabic(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFB79CFF).withValues(alpha: 0.18),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFB79CFF)),
            ),
            child: Center(
              child: Text(
                isAr ? _toArabicDigits(number) : '$number',
                textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFB79CFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              textAlign: isAr ? TextAlign.right : TextAlign.left,
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF4B3A66),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _toArabicDigits(Object value) {
    var text = value.toString();
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishDigits.length; i++) {
      text = text.replaceAll(englishDigits[i], arabicDigits[i]);
    }

    return text;
  }
}

// Glass Card widget for the communication hub
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accentColor;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withValues(alpha: 0.98),
                const Color(0xFFFDFCFF).withValues(alpha: 0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: accentColor?.withValues(alpha: 0.15) ??
                  Colors.white.withValues(alpha: 0.95),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color:
                (accentColor ?? const Color(0xFF6A5CFF)).withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// Guider Communication Hub - "Talk to Me" section
class _GuiderCommunicationHub extends StatelessWidget {
  final String userName; // Add this parameter
  final VoidCallback onChat;
  final VoidCallback onVoice;
  final VoidCallback onVideo;

  const _GuiderCommunicationHub({
    required this.userName, // Add this parameter
    required this.onChat,
    required this.onVoice,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    final isAr = isArabic(context);

    return Directionality(
      textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
      child: _GlassCard(
        padding: const EdgeInsets.all(20),
        radius: 22,
        accentColor: const Color(0xFF6A5CFF),
        child: Column(
          crossAxisAlignment:
          isAr ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB4A3FF),
                        Color(0xFFA78BFA),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA78BFA).withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.chat_bubble_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(context, 'Talk to Me', 'اتكلم معايا'),
                    textAlign: isAr ? TextAlign.right : TextAlign.left,
                    textDirection: isAr ? TextDirection.rtl : TextDirection.ltr,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2A1E3B),
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _HubButton(
                    icon: Icons.chat_bubble_rounded,
                    title: tr(context, 'Chat', 'شات'),
                    subtitle: tr(
                      context,
                      'Text conversation',
                      'محادثة كتابة',
                    ),
                    gradientColors: const [Color(0xFF8E7CFF), Color(0xFF6A5CFF)],
                    onTap: onChat,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HubButton(
                    icon: Icons.mic_rounded,
                    title: tr(context, 'Voice', 'صوت'),
                    subtitle: tr(
                      context,
                      'Speak freely',
                      'اتكلم براحتك',
                    ),
                    gradientColors: const [Color(0xFFA78BFA), Color(0xFF9B7BFF)],
                    onTap: onVoice,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _HubButton(
                    icon: Icons.videocam_rounded,
                    title: tr(context, 'Video', 'فيديو'),
                    subtitle: tr(
                      context,
                      'Video call',
                      'مكالمة فيديو',
                    ),
                    gradientColors: const [Color(0xFF6A5CFF), Color(0xFF4A3F8F)],
                    onTap: onVideo,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Hub Button for the communication options
class _HubButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _HubButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradientColors[0].withValues(alpha: 0.12),
              gradientColors[1].withValues(alpha: 0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: gradientColors[0].withValues(alpha: 0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors[0].withValues(alpha: 0.75),
                    gradientColors[1].withValues(alpha: 0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2A1E3B),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: gradientColors[1].withValues(alpha: 0.8),
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
