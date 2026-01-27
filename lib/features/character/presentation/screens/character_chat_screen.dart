import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/chat_conversation.dart';

class CharacterChatScreen extends StatefulWidget {
  final UserCharacter character;

  const CharacterChatScreen({super.key, required this.character});

  @override
  State<CharacterChatScreen> createState() => _CharacterChatScreenState();
}

class _CharacterChatScreenState extends State<CharacterChatScreen> {
  late Future<InnerCharacterProfile?> _characterFuture;
  final _characterDataSource = InnerCharacterLocalDataSource();
  late final String _assistantAvatarPath;

  @override
  void initState() {
    super.initState();
    _characterFuture = _loadCharacterProfile();
    _assistantAvatarPath =
        _getImagePathForCharacter(widget.character.characterName);
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


  Future<InnerCharacterProfile?> _loadCharacterProfile() {
    final primaryName = widget.character.displayName;
    final secondaryName = widget.character.characterName;
    return _characterDataSource
        .findCharacterByName(primaryName)
        .then((value) => value ?? _characterDataSource.findCharacterByName(
              secondaryName,
            ));
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
                child: FutureBuilder<InnerCharacterProfile?>(
                  future: _characterFuture,
                  builder: (context, snapshot) {
                    final profile = snapshot.data;
                    final characterId =
                        profile?.id ?? _fallbackCharacterId();
                    return ChatConversation(
                      characterId: characterId,
                      characterType: 'inner_character',
                      fallbackTitle: widget.character.displayName,
                      fallbackSubtitle: tr(
                        context,
                        'A protective inner part.',
                        'جزء داخلي حامٍ.',
                      ),
                      fallbackRole: widget.character.archetype,
                      assistantAvatarPath: _assistantAvatarPath,
                      showHeader: false,
                      characterProfile: profile,
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _fallbackCharacterId() {
    final raw = widget.character.characterName.isNotEmpty
        ? widget.character.characterName
        : widget.character.displayName;
    final normalized = raw
        .toLowerCase()
        .replaceAll('the ', '')
        .replaceAll(RegExp(r'[^a-z0-9\s_]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');
    return normalized.isEmpty ? 'inner_critic' : normalized;
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
