import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/models/chat_session_model.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/chat/presentation/widgets/chat_conversation.dart';

/// Read-only viewer for an ENDED session
/// - user can open a past session and see its messages
/// - user cannot send any messages
class ChatSessionViewerScreen extends StatelessWidget {
  final UserCharacter character;
  final InnerCharacterProfile? profile;
  final String assistantAvatarPath;
  final String characterId;
  final String characterType;
  final ChatSessionModel session;

  const ChatSessionViewerScreen({
    super.key,
    required this.character,
    required this.profile,
    required this.assistantAvatarPath,
    required this.characterId,
    required this.characterType,
    required this.session,
  });

  @override
  Widget build(BuildContext context) {
    final title = character.getDisplayName(isArabic(context) ? 'ar' : 'en');

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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Color(0xFFA790ED),
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
              Expanded(
                child: ChatConversation(
                  threadId: session.threadId,
                  readOnly: true,
                  characterId: characterId,
                  characterType: characterType,
                  // Keep display name in sync with Firebase + in-app language.
                  fallbackTitle: title,
                  fallbackSubtitle: tr(
                    context,
                    'A protective inner part.',
                    'جزء داخلي حامٍ.',
                  ),
                  fallbackRole: character.archetype,
                  assistantAvatarPath: assistantAvatarPath,
                  showHeader: false,
                  characterProfile: profile,
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

