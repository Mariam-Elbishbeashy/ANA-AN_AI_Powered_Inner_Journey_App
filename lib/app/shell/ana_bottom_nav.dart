import 'package:flutter/material.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

/// Custom bottom nav bar (Home / 3D Map / Chat / Reframe / Progress)
class AnaBottomNav extends StatelessWidget {
  final int currentIndex;
  final VoidCallback onHome;
  final VoidCallback onMap3D;
  final VoidCallback onChat;
  final VoidCallback onReframe;
  final VoidCallback onProgress;

  const AnaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onHome,
    required this.onMap3D,
    required this.onChat,
    required this.onReframe,
    required this.onProgress,
  });

  @override
  Widget build(BuildContext context) {
    const bg = Color(0xFFFFFFFF);
    const selected = Color(0xFF8E7CFF);
    const unselected = Color(0xFF9B92B3);

    final isHome = currentIndex == 0;
    final isMap3D = currentIndex == 1;
    final isChat = currentIndex == 2;
    final isReframe = currentIndex == 3;
    final isProg = currentIndex == 4;

    return Container(
      height: 86 + MediaQuery.of(context).padding.bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            height: double.infinity,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 18,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              8 + MediaQuery.of(context).padding.bottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _NavItem(
                  label: tr(context, "Home", "الرئيسية"),
                  icon: Icons.home_rounded,
                  active: isHome,
                  activeColor: selected,
                  inactiveColor: unselected,
                  onTap: onHome,
                ),
                _NavItem(
                  label: tr(context, "3D Map", "خريطة ثلاثية الأبعاد"),
                  icon: Icons.map_rounded,
                  active: isMap3D,
                  activeColor: selected,
                  inactiveColor: unselected,
                  onTap: onMap3D,
                ),
                const SizedBox(width: 66), // Space for center chat button
                _NavItem(
                  label: tr(context, "Reframe", "إعادة الإطار"),
                  icon: Icons.category_rounded,
                  active: isReframe,
                  activeColor: selected,
                  inactiveColor: unselected,
                  onTap: onReframe,
                ),
                _NavItem(
                  label: tr(context, "Progress", "التقدم"),
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
            top: -6,
            child: Center(
              child: GestureDetector(
                onTap: onChat,
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 160),
                  scale: isChat ? 1.03 : 1.0,
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFB79CFF),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFB79CFF).withOpacity(0.45),
                          blurRadius: 24,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
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
        width: 64,
        height: 70,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
