import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/guider_avatar.dart';
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

  // Guider state - whether the Guider is currently in the conversation
  bool _isGuiderInChat = false;

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
    final primaryName = widget.character.displayNameEn;
    final secondaryName = widget.character.characterName;
    return _characterDataSource
        .findCharacterByName(primaryName)
        .then((value) => value ?? _characterDataSource.findCharacterByName(
              secondaryName,
            ));
  }

  String _getTitle(BuildContext context) {
    // use the in-app language toggle (AppLanguageProvider), not the device locale
    final ar = isArabic(context);

    final displayName = widget.character.getDisplayName(ar ? 'ar' : 'en');

    if (ar) {
      return displayName;
    } else {
      final normalized = displayName.toLowerCase().startsWith('the ')
          ? displayName.substring(4)
          : displayName;
      return tr(context, 'Your $normalized', '$normalized الخاص بك');
    }
  }

  /// Show modal to invite or remove the Guider
  void _showGuiderModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _GuiderModal(
        isGuiderInChat: _isGuiderInChat,
        characterName: widget.character.displayNameEn,
        onInviteGuider: () {
          Navigator.pop(context);
          setState(() {
            _isGuiderInChat = true;
          });
        },
        onRemoveGuider: () {
          Navigator.pop(context);
          setState(() {
            _isGuiderInChat = false;
          });
        },
      ),
    );
  }

  /// Handle Guider state change from ChatConversation
  void _handleGuiderStateChanged(bool isGuiderIn) {
    setState(() {
      _isGuiderInChat = isGuiderIn;
    });
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
                    // Guider icon button (replaces menu)
                    _GuiderIconButton(
                      isGuiderInChat: _isGuiderInChat,
                      onTap: _showGuiderModal,
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
                      // IMPORTANT (requested): displayed names come from Firestore.
                      fallbackTitle: widget.character.getDisplayName(
                        isArabic(context) ? 'ar' : 'en',
                      ),
                      fallbackSubtitle: tr(
                        context,
                        'A protective inner part.',
                        'جزء داخلي حامٍ.',
                      ),
                      fallbackRole: widget.character.archetype,
                      assistantAvatarPath: _assistantAvatarPath,
                      showHeader: false,
                      characterProfile: profile,
                      isGuiderInChat: _isGuiderInChat,
                      onGuiderStateChanged: _handleGuiderStateChanged,
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
        : widget.character.displayNameEn;
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

/// Guider icon button that shows the Guider avatar
class _GuiderIconButton extends StatelessWidget {
  final bool isGuiderInChat;
  final VoidCallback onTap;

  const _GuiderIconButton({
    required this.isGuiderInChat,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: isGuiderInChat
              ? const Color(0xFFB79CFF)
              : Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: isGuiderInChat
                  ? const Color(0xFFB79CFF).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
          border: isGuiderInChat
              ? Border.all(color: const Color(0xFF9B7BFF), width: 2)
              : null,
        ),
        child: ClipOval(
          child: GuiderAvatar(
            size: 44,
            backgroundColor: Colors.transparent,
            fallbackIconColor:
                isGuiderInChat ? Colors.white : const Color(0xFF2A1E3B),
            fallbackIconSize: 22,
          ),
        ),
      ),
    );
  }
}

/// Modal for inviting or removing the Guider
class _GuiderModal extends StatelessWidget {
  final bool isGuiderInChat;
  final String characterName;
  final VoidCallback onInviteGuider;
  final VoidCallback onRemoveGuider;

  const _GuiderModal({
    required this.isGuiderInChat,
    required this.characterName,
    required this.onInviteGuider,
    required this.onRemoveGuider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFB79CFF).withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFE5DEFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Guider avatar
            const GuiderAvatar(
              size: 80,
              backgroundColor: Color(0xFFB79CFF),
              fallbackIconSize: 36,
            ),
            const SizedBox(height: 16),
            Text(
              tr(context, 'The Guider', 'المُرشد'),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isGuiderInChat
                  ? tr(
                      context,
                      'The Guider is currently in this conversation, helping you and your $characterName understand each other better.',
                      'المُرشد موجود حاليًا في هذه المحادثة، يساعدك أنت و$characterName على فهم بعضكم البعض بشكل أفضل.',
                    )
                  : tr(
                      context,
                      'Would you like The Guider to join this conversation? They can help you and your $characterName communicate with more clarity and compassion.',
                      'هل تريد أن ينضم المُرشد إلى هذه المحادثة؟ يمكنه مساعدتك أنت و$characterName على التواصل بوضوح وتعاطف أكبر.',
                    ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF6B5C82),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            if (isGuiderInChat)
              // Remove Guider button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: onRemoveGuider,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8B7EC8),
                    side: const BorderSide(color: Color(0xFFB79CFF)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(
                    tr(context, 'Continue without The Guider',
                        'استمر بدون المُرشد'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              )
            else
              // Invite Guider buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onInviteGuider,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB79CFF),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr(context, 'Yes, invite The Guider',
                            'نعم، ادعُ المُرشد'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF8B7EC8),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        tr(context, 'Not now', 'ليس الآن'),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}
