import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'welcome_screen.dart';

class AnaShell extends StatefulWidget {
  const AnaShell({super.key});

  @override
  State<AnaShell> createState() => _AnaShellState();
}

class _AnaShellState extends State<AnaShell> {
  int _index = 0; // 0=Home, 1=Chat, 2=Progress
  bool _showChatBubbles = false;

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logout failed.")),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = _getFriendlyName(user);

    final pages = <Widget>[
      _HomePlaceholder(name: name, onLogout: _logout),
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

  const _TopHelloBar({required this.name, required this.onLogout});

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
                top: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
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
                        color: Colors.white.withValues(alpha: 0.92),
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
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
                          color: Colors.white.withValues(alpha: 0.9),
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 320));
    _scale = CurvedAnimation(parent: _c, curve: Curves.easeOutBack);
    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    _leftSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _topSlide = Tween<Offset>(begin: const Offset(0, 0.30), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
    _rightSlide = Tween<Offset>(begin: const Offset(0, 0.25), end: Offset.zero)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));

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
              color: const Color(0xFF8E7CFF).withValues(alpha: 0.14),
              border: Border.all(
                color: const Color(0xFF8E7CFF).withValues(alpha: 0.28),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
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

/// Placeholder pages (now with top hello bar + logout)
class _HomePlaceholder extends StatelessWidget {
  final String name;
  final VoidCallback onLogout;

  const _HomePlaceholder({required this.name, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TopHelloBar(name: name, onLogout: onLogout),
        const Expanded(
          child: Center(
            child: Text(
              "Home (to be designed)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ),
        ),
      ],
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
        const Expanded(
          child: Center(
            child: Text(
              "Chat (tap the center button)",
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF4B3A66),
              ),
            ),
          ),
        ),
      ],
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
        const Expanded(
          child: Center(
            child: Text(
              "Progress (to be designed)",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
