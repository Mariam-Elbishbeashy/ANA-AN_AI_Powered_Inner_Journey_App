import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';
import 'questionnaire/initial_motivation_screen.dart';
import '../services/firestore_service.dart';
import 'profile_screen.dart';

class AnaShell extends StatefulWidget {
  const AnaShell({super.key});

  @override
  State<AnaShell> createState() => _AnaShellState();
}

class _AnaShellState extends State<AnaShell> {
  int _index = 0; // 0=Home, 1=Chat, 2=Progress
  bool _showChatBubbles = false;
  final FirestoreService _firestoreService = FirestoreService();

  void _selectTab(int i) {
    setState(() {
      _index = i;
      if (i != 1) _showChatBubbles = false;
    });
  }

  void _toggleChat() {
    setState(() {
      _index = 1;
      _showChatBubbles = !_showChatBubbles;
    });
  }

  String _getFriendlyName(User? user) {
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      final beforeAt = email.split('@').first;
      if (beforeAt.isNotEmpty) return beforeAt;
    }

    return "there";
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      if (!mounted) return;

      // ✅ Clear all routes and go to Welcome
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AnaWelcomeScreen()),
        (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logout failed.")));
    }
  }

  Future<void> _retakeQuestionnaire() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retake Questionnaire'),
        content: const Text(
          'This will clear your current character assessment and start a new questionnaire. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retake'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear existing data
        await _firestoreService.clearQuestionnaireData();

        // Navigate to motivation screen
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
          (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = _getFriendlyName(user);

    final pages = <Widget>[
      _HomePlaceholder(
        name: name,
        onLogout: _logout,
        onRetakeQuestionnaire: _retakeQuestionnaire,
      ),
      _ChatPlaceholder(name: name, onLogout: _logout),
      _ProgressPlaceholder(name: name, onLogout: _logout),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Stack(
        children: [
          // Current page
          Positioned.fill(child: pages[_index]),

          // Tap-outside-to-close overlay
          if (_showChatBubbles)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => setState(() => _showChatBubbles = false),
                behavior: HitTestBehavior.opaque,
                child: Container(color: Colors.transparent),
              ),
            ),

          // Chat bubbles popup
          Positioned(
            left: 0,
            right: 0,
            bottom: 92,
            child: IgnorePointer(
              ignoring: !_showChatBubbles,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 160),
                opacity: _showChatBubbles ? 1 : 0,
                child: AnimatedSlide(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  offset: _showChatBubbles
                      ? Offset.zero
                      : const Offset(0, 0.10),
                  child: _ChatBubblesArc(
                    onTapCharacter: (characterName) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Selected: $characterName")),
                      );
                      setState(() => _showChatBubbles = false);
                    },
                  ),
                ),
              ),
            ),
          ),

          // Bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _AnaBottomNav(
              currentIndex: _index,
              onHome: () => _selectTab(0),
              onChat: _toggleChat,
              onProgress: () => _selectTab(2),
            ),
          ),
        ],
      ),
    );
  }
}

/// ✅ Small reusable header: "Hello, Name" + Logout button
class _TopHelloBar extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback? onSettings;

  const _TopHelloBar({
    required this.name,
    required this.onLogout,
    this.onSettings,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                "Hello, $name 👋",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2A1E3B),
                ),
              ),
            ),
            if (onSettings != null)
              IconButton(
                onPressed: onSettings,
                icon: const Icon(Icons.settings_rounded, size: 22),
                color: const Color(0xFF6A5CFF),
              ),
            TextButton.icon(
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text("Logout"),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFF6A5CFF),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom bottom nav bar (Home / Chat / Progress)
class _AnaBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onChat;
  final VoidCallback onProgress;

  const _AnaBottomNav({
    required this.currentIndex,
    required this.onHome,
    required this.onChat,
    required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFF0ECF7);
    const selected = Color(0xFF8E7CFF);
    const unselected = Color(0xFF7A6A5A);

    final isHome = currentIndex == 0;
    final isChat = currentIndex == 1;
    final isProg = currentIndex == 2;

    return SizedBox(
      height: 92,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: 78,
            decoration: BoxDecoration(
              color: bg,
              border: Border(
                top: BorderSide(color: Colors.black.withOpacity(0.06)),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 26),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _NavItem(
                  label: "Home",
                  icon: Icons.grid_view_rounded,
                  active: isHome,
                  activeColor: selected,
                  inactiveColor: unselected,
                  onTap: onHome,
                ),
                const SizedBox(width: 96),
                _NavItem(
                  label: "Progress",
                  icon: Icons.insert_chart_outlined_rounded,
                  active: isProg,
                  activeColor: selected,
                  inactiveColor: unselected,
                  onTap: onProgress,
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: -22,
            child: Center(
              child: GestureDetector(
                onTap: onChat,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: isChat ? 1.03 : 1.0,
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFEEDFFB),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.92),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.9),
                        ),
                        child: Icon(
                          Icons.smart_toy_outlined,
                          color: isChat ? selected : unselected,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 12,
            child: Center(
              child: Text(
                "Chat",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: isChat ? selected : unselected,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool active;
  final Color activeColor;
  final Color inactiveColor;
  final VoidCallback onTap;

  const _NavItem({
    required this.label,
    required this.icon,
    required this.active,
    required this.activeColor,
    required this.inactiveColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? activeColor : inactiveColor;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 90,
        height: 78,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The 3 character circles above Chat
class _ChatBubblesArc extends StatefulWidget {
  final void Function(String characterName) onTapCharacter;

  const _ChatBubblesArc({required this.onTapCharacter});

  @override
  State<_ChatBubblesArc> createState() => _ChatBubblesArcState();
}

class _ChatBubblesArcState extends State<_ChatBubblesArc>
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
class _SettingsBottomSheet extends StatelessWidget {
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const _SettingsBottomSheet({
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
          const Text(
            'Settings',
            style: TextStyle(
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
            title: const Text('Retake Questionnaire'),
            subtitle: const Text('Update your inner characters assessment'),
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
              title: const Text('Change Language'),
              subtitle: const Text('Switch between English and Arabic'),
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
            title: const Text('Privacy & Data'),
            onTap: () {
              // TODO: Implement privacy screen
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.help_rounded, color: Color(0xFF8E7CFF)),
            title: const Text('Help & Support'),
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
              child: const Text('Close'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder pages (now with top hello bar + logout)
class _HomePlaceholder extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;

  const _HomePlaceholder({
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopHelloBar(
          name: name,
          onLogout: onLogout,
          onSettings: () {
            showModalBottomSheet(
              context: context,
              builder: (context) => _SettingsBottomSheet(
                onRetakeQuestionnaire: onRetakeQuestionnaire,
              ),
            );
          },
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Welcome card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8E7CFF), Color(0xFF6A5CFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8E7CFF).withOpacity(0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 5),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Welcome to Your Inner Sanctuary',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Hello $name, your inner characters are waiting to connect with you.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              '3 Characters Identified',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Daily check-in
                const Text(
                  'Daily Check-in',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.self_improvement_rounded,
                        color: Color(0xFF8E7CFF),
                        size: 30,
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'How are your inner parts feeling today?',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Take a moment to check in with yourself',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF7A6A5A).withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          // TODO: Implement daily check-in
                        },
                        icon: const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF8E7CFF),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Recent insights
                const Text(
                  'Recent Insights',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E7CFF).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.insights_rounded,
                              color: Color(0xFF8E7CFF),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 15),
                          const Expanded(
                            child: Text(
                              'Your Inner Critic has been active this week',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        'This might be a sign that you\'re facing new challenges or stepping out of your comfort zone. Remember, your inner critic is trying to protect you.',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF7A6A5A),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0ECF7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Weekly Pattern',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6A5CFF),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '2 days ago',
                            style: TextStyle(
                              fontSize: 12,
                              color: const Color(0xFF7A6A5A).withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Quick actions
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.chat_bubble_rounded,
                        label: 'Chat with\nCharacters',
                        color: const Color(0xFF8E7CFF),
                        onTap: () {
                          // TODO: Navigate to chat
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.track_changes_rounded,
                        label: 'Track\nProgress',
                        color: const Color(0xFF6A5CFF),
                        onTap: () {
                          // TODO: Navigate to progress
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _QuickActionButton(
                        icon: Icons.psychology_rounded,
                        label: 'Learn About\nCharacters',
                        color: const Color(0xFF4A3F6F),
                        onTap: () {
                          // TODO: Navigate to characters library
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5DEFF)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF2A1E3B),
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatPlaceholder extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;

  const _ChatPlaceholder({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopHelloBar(name: name, onLogout: onLogout),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.smart_toy_rounded,
                      size: 60,
                      color: Color(0xFF8E7CFF),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    "Chat with Your Inner Characters",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 15),
                  const Text(
                    "Tap the center button to select a character to chat with. "
                    "Each character represents a different part of your inner world.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
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
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.info_rounded,
                              color: Color(0xFF6A5CFF),
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                "How it works:",
                                style: TextStyle(
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
                          text: "Tap the center button below",
                        ),
                        _InstructionStep(
                          number: 2,
                          text: "Choose one of your 3 main characters",
                        ),
                        _InstructionStep(
                          number: 3,
                          text: "Start a conversation with that part of you",
                        ),
                        _InstructionStep(
                          number: 4,
                          text: "Listen to what it needs to tell you",
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF8E7CFF).withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF8E7CFF)),
            ),
            child: Center(
              child: Text(
                '$number',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF8E7CFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
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
}

class _ProgressPlaceholder extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;

  const _ProgressPlaceholder({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopHelloBar(name: name, onLogout: onLogout),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),
                // Progress overview
                const Text(
                  'Your Journey Progress',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Track your growth and insights over time',
                  style: TextStyle(
                    fontSize: 16,
                    color: const Color(0xFF4B3A66).withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 30),

                // Weekly activity
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFE5DEFF)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.timeline_rounded,
                            color: Color(0xFF8E7CFF),
                            size: 24,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'Weekly Activity',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      _ActivityItem(
                        day: 'Mon',
                        value: 0.8,
                        label: 'High self-awareness',
                      ),
                      _ActivityItem(
                        day: 'Tue',
                        value: 0.6,
                        label: 'Moderate activity',
                      ),
                      _ActivityItem(
                        day: 'Wed',
                        value: 0.9,
                        label: 'Deep reflection',
                      ),
                      _ActivityItem(day: 'Thu', value: 0.4, label: 'Quiet day'),
                      _ActivityItem(
                        day: 'Fri',
                        value: 0.7,
                        label: 'Good progress',
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // Character insights
                const Text(
                  'Character Insights',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 15),
                _CharacterInsightCard(
                  characterName: 'Inner Critic',
                  trend: 'Decreasing',
                  trendColor: Colors.green,
                  insight: 'You\'re becoming more compassionate with yourself',
                ),
                const SizedBox(height: 15),
                _CharacterInsightCard(
                  characterName: 'People Pleaser',
                  trend: 'Stable',
                  trendColor: Colors.orange,
                  insight: 'Boundary-setting practice is showing results',
                ),
                const SizedBox(height: 15),
                _CharacterInsightCard(
                  characterName: 'Wounded Child',
                  trend: 'Healing',
                  trendColor: Colors.blue,
                  insight: 'Increased moments of self-compassion noted',
                ),

                const SizedBox(height: 40),

                // Milestones
                const Text(
                  'Milestones',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 15),
                _MilestoneItem(
                  title: 'First Week Complete',
                  date: 'Completed 7 days ago',
                  achieved: true,
                ),
                _MilestoneItem(
                  title: '10 Self-Checkins',
                  date: '3 more to go',
                  achieved: false,
                ),
                _MilestoneItem(
                  title: 'Recognized 3 Patterns',
                  date: 'Completed today',
                  achieved: true,
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final String day;
  final double value;
  final String label;

  const _ActivityItem({
    required this.day,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              day,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ),
          Expanded(
            child: LinearProgressIndicator(
              value: value,
              backgroundColor: const Color(0xFFE5DEFF),
              valueColor: AlwaysStoppedAnimation<Color>(
                const Color(0xFF8E7CFF),
              ),
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 15),
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(color: const Color(0xFF7A6A5A), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _CharacterInsightCard extends StatelessWidget {
  final String characterName;
  final String trend;
  final Color trendColor;
  final String insight;

  const _CharacterInsightCard({
    required this.characterName,
    required this.trend,
    required this.trendColor,
    required this.insight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8E7CFF).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.psychology_rounded,
              color: Color(0xFF8E7CFF),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  characterName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  insight,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A6A5A),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: trendColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: trendColor),
            ),
            child: Text(
              trend,
              style: TextStyle(
                color: trendColor,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MilestoneItem extends StatelessWidget {
  final String title;
  final String date;
  final bool achieved;

  const _MilestoneItem({
    required this.title,
    required this.date,
    required this.achieved,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: achieved
                  ? const Color(0xFF8E7CFF).withOpacity(0.1)
                  : const Color(0xFFF0ECF7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              achieved ? Icons.check_circle_rounded : Icons.circle_outlined,
              color: achieved
                  ? const Color(0xFF8E7CFF)
                  : const Color(0xFF9C90B3),
              size: 24,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: achieved
                        ? const Color(0xFF2A1E3B)
                        : const Color(0xFF7A6A5A),
                  ),
                ),
                Text(
                  date,
                  style: TextStyle(
                    fontSize: 14,
                    color: achieved
                        ? const Color(0xFF6A5CFF)
                        : const Color(0xFF9C90B3),
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
