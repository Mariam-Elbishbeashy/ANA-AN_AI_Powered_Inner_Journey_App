import 'package:flutter/material.dart';
import '../models/user_character_model.dart';
import 'voice_analysis_screen.dart';
import '../l10n/app_strings.dart';

class CharacterChatScreen extends StatefulWidget {
  final UserCharacter character;

  const CharacterChatScreen({super.key, required this.character});

  @override
  State<CharacterChatScreen> createState() => _CharacterChatScreenState();
}

class _CharacterChatScreenState extends State<CharacterChatScreen> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  String _getImagePathForCharacter(String characterName) {
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

  String _getTitle(BuildContext context) {
    final name = widget.character.displayName.trim();
    final normalized = name.toLowerCase().startsWith('the ')
        ? name.substring(4)
        : name;
    return tr(context, 'Your $normalized', '$normalized الخاص بك');
  }

  @override
  Widget build(BuildContext context) {
    final imagePath = _getImagePathForCharacter(widget.character.characterName);

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
                          _getTitle(context),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                      ),
                    ),
                    _CircleIconButton(
                      icon: Icons.menu_rounded,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 18),
                  children: [
                    _AssistantBubble(
                      imagePath: imagePath,
                      text: tr(
                        context,
                        'Hi! How can I assist you today?',
                        'مرحباً! كيف يمكنني مساعدتك اليوم؟',
                      ),
                    ),
                    const SizedBox(height: 14),
                    _UserBubble(
                      text: tr(context, 'What is Web3?', 'ما هو الويب 3؟'),
                    ),
                    const SizedBox(height: 14),
                    _VoiceBubble(),
                    const SizedBox(height: 14),
                    _AssistantCard(
                      imagePath: imagePath,
                      title: tr(context, 'What is Web3?', 'ما هو الويب 3؟'),
                      body:
                          tr(
                            context,
                            'Web3 is a decentralized internet built on blockchain, giving users control over their data, identity, and digital assets.',
                            'الويب 3 هو إنترنت لامركزي مبني على البلوك تشين ويمنح المستخدمين التحكم في بياناتهم وهويتهم وأصولهم الرقمية.',
                          ),
                    ),
                    const SizedBox(height: 14),
                    _AssistantCard(
                      imagePath: imagePath,
                      title: tr(
                        context,
                        'Key Features of Web3:',
                        'الميزات الرئيسية للويب 3:',
                      ),
                      body: tr(
                        context,
                        '1. Decentralization\n2. User ownership\n3. Token-based incentives',
                        '1. اللامركزية\n2. ملكية المستخدم\n3. حوافز قائمة على الرموز',
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(26),
                          border: Border.all(color: const Color(0xFFE5DEFF)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Center(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: tr(
                                context,
                                'Type a message',
                                'اكتب رسالة',
                              ),
                              border: InputBorder.none,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    _RoundActionButton(
                      icon: Icons.send_rounded,
                      onTap: () {},
                      backgroundColor: const Color(0xFF8E7CFF),
                      iconColor: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    _RoundActionButton(
                      icon: Icons.mic_rounded,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                VoiceAnalysisScreen(character: widget.character),
                          ),
                        );
                      },
                      backgroundColor: const Color(0xFFEDE7FF),
                      iconColor: const Color(0xFF8E7CFF),
                    ),
                  ],
                ),
              ),
            ],
          ),
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

class _AssistantBubble extends StatelessWidget {
  final String imagePath;
  final String text;

  const _AssistantBubble({required this.imagePath, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFEDE7FF),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF2A1E3B),
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UserBubble extends StatelessWidget {
  final String text;

  const _UserBubble({required this.text});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5DEFF)),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Color(0xFF2A1E3B),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _VoiceBubble extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: const [
          SizedBox(width: 16),
          Icon(Icons.graphic_eq_rounded, color: Colors.white),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              '00:05',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Icon(Icons.play_arrow_rounded, color: Colors.white),
          SizedBox(width: 16),
        ],
      ),
    );
  }
}

class _AssistantCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String body;

  const _AssistantCard({
    required this.imagePath,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 20,
          backgroundColor: const Color(0xFFEDE7FF),
          child: ClipOval(
            child: Image.asset(
              imagePath,
              width: 40,
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Color(0xFF4B3A66),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _RoundActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;

  const _RoundActionButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}