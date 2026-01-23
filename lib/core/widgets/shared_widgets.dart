import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/profile/presentation/screens/profile_screen.dart';

/// ✅ Small reusable header: "Hello, Name" + Logout button
class TopHelloBar extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback? onSettings;

  const TopHelloBar({
    super.key,
    required this.name,
    required this.onLogout,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    String initialsFromName(String value) {
      final parts = value.trim().split(RegExp(r'\s+'));
      if (parts.isEmpty) return '';
      if (parts.length == 1) {
        return parts.first.isNotEmpty ? parts.first[0].toUpperCase() : '';
      }
      return (parts[0].isNotEmpty ? parts[0][0] : '') +
          (parts[1].isNotEmpty ? parts[1][0] : '');
    }

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF8E7CFF), Color(0xFF6A5CFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  initialsFromName(name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, "Hello, $name", "مرحباً، $name"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tr(
                      context,
                      "Welcome back to your inner space",
                      "أهلاً بعودتك إلى مساحتك الداخلية",
                    ),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A6A5A),
                    ),
                  ),
                ],
              ),
            ),
            if (onSettings != null)
              _TopBarIconButton(
                icon: Icons.settings_rounded,
                onPressed: onSettings!,
                tooltip: 'Settings',
              ),
            _TopBarIconButton(
              icon: Icons.person_rounded,
              tooltip: 'Profile',
              onPressed: () {
                final user = FirebaseAuth.instance.currentUser;
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(
                      user: user,
                      onLogout: onLogout,
                      initialUserCharacters: <UserCharacter>[],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBarIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final String tooltip;

  const _TopBarIconButton({
    required this.icon,
    required this.onPressed,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3EDFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        color: const Color(0xFF6A5CFF),
        tooltip: tooltip,
      ),
    );
  }
}

/// The 3 character circles above Chat
class ChatBubblesArc extends StatefulWidget {
  final void Function(String characterName) onTapCharacter;

  const ChatBubblesArc({super.key, required this.onTapCharacter});

  @override
  State<ChatBubblesArc> createState() => _ChatBubblesArcState();
}

class _ChatBubblesArcState extends State<ChatBubblesArc>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  late final Animation<Offset> _leftSlide;
  late final Animation<Offset> _topSlide;
  late final Animation<Offset> _rightSlide;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    _leftSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _topSlide = Tween<Offset>(
      begin: const Offset(0, 0.30),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _rightSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: ScaleTransition(
        scale: _scale,
        child: Center(
          child: SizedBox(
            width: 280,
            height: 200,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                Positioned(
                  bottom: 20,
                  left: 14,
                  child: SlideTransition(
                    position: _leftSlide,
                    child: _CharacterBubble(
                      label: "Character 1",
                      icon: Icons.gavel_rounded,
                      onTap: () => widget.onTapCharacter("Inner Critic"),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  child: SlideTransition(
                    position: _topSlide,
                    child: _CharacterBubble(
                      label: "Character 2",
                      icon: Icons.emoji_emotions_rounded,
                      onTap: () => widget.onTapCharacter("Wounded Child"),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 20,
                  right: 14,
                  child: SlideTransition(
                    position: _rightSlide,
                    child: _CharacterBubble(
                      label: "Character 3",
                      icon: Icons.shield_rounded,
                      onTap: () => widget.onTapCharacter("Protector"),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CharacterBubble extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _CharacterBubble({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF8E7CFF).withOpacity(0.14),
              border: Border.all(
                color: const Color(0xFF8E7CFF).withOpacity(0.28),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Icon(icon, color: const Color(0xFF2A1E3B), size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ],
      ),
    );
  }
}

/// Settings Bottom Sheet
class SettingsBottomSheet extends StatelessWidget {
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const SettingsBottomSheet({
    super.key,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            tr(context, 'Settings', 'الإعدادات'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
          ),
          const SizedBox(height: 20),
          ListTile(
            leading: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF8E7CFF),
            ),
            title: Text(tr(context, 'Retake Questionnaire', 'إعادة الاستبيان')),
            subtitle: Text(
              tr(
                context,
                'Update your inner characters assessment',
                'تحديث تقييم شخصياتك الداخلية',
              ),
            ),
            onTap: () {
              Navigator.pop(context);
              onRetakeQuestionnaire();
            },
          ),
          if (onSwitchLanguage != null)
            ListTile(
              leading: const Icon(
                Icons.language_rounded,
                color: Color(0xFF8E7CFF),
              ),
              title: Text(tr(context, 'Change Language', 'تغيير اللغة')),
              subtitle: Text(
                tr(
                  context,
                  'Switch between English and Arabic',
                  'التبديل بين الإنجليزية والعربية',
                ),
              ),
              onTap: () {
                Navigator.pop(context);
                onSwitchLanguage!();
              },
            ),
          ListTile(
            leading: const Icon(
              Icons.privacy_tip_rounded,
              color: Color(0xFF8E7CFF),
            ),
            title: Text(tr(context, 'Privacy & Data', 'الخصوصية والبيانات')),
            onTap: () {
              // TODO: Implement privacy screen
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_rounded, color: Color(0xFF8E7CFF)),
            title: Text(tr(context, 'Help & Support', 'المساعدة والدعم')),
            onTap: () {
              // TODO: Implement help screen
              Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr(context, 'Close', 'إغلاق')),
            ),
          ),
        ],
      ),
    );
  }
}
