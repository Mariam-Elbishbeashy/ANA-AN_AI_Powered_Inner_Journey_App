import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/cached_o3d_widget.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

enum IslandTheme { green, purple }

class MapIsland extends StatelessWidget {
  final UserCharacter? userCharacter;
  final IslandTheme colorTheme;
  final VoidCallback? onTap;
  final bool isArabic;

  const MapIsland({
    super.key,
    this.userCharacter,
    required this.colorTheme,
    this.onTap,
    required this.isArabic,
  });

  @override
  Widget build(BuildContext context) {
    // DEBUG LOGGING
    print('DEBUG MapIsland: Building for ${userCharacter?.displayName ?? "empty"}, '
        'colorTheme: ${colorTheme.name}, isHealed: ${userCharacter?.isHealed ?? false}');

    Color mainColor;
    Color sideColor;
    Color glowColor;

    if (colorTheme == IslandTheme.green) {
      // Healed character - Green theme
      mainColor = const Color(0xFFA5D6A7);
      sideColor = const Color(0xFF66BB6A);
      glowColor = const Color(0xFF5CB85C).withOpacity(0.3);
      print('DEBUG MapIsland: Using GREEN theme for ${userCharacter?.displayName ?? "empty"}');
    } else {
      // Unhealed character - Purple theme
      mainColor = const Color(0xFFCE93D8);
      sideColor = const Color(0xFFAB47BC);
      glowColor = const Color(0xFFAB47BC).withOpacity(0.3);
      print('DEBUG MapIsland: Using PURPLE theme for ${userCharacter?.displayName ?? "empty"}');
    }

    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Island Platform
          SizedBox(
            height: 150,
            width: 120,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Glow effect for healed characters
                if (colorTheme == IslandTheme.green)
                  Container(
                    height: 70,
                    width: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 20,
                          spreadRadius: 5,
                        ),
                      ],
                    ),
                  ),

                // Base
                Container(
                  height: 60,
                  width: 100,
                  decoration: BoxDecoration(
                    color: sideColor,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: sideColor.withOpacity(0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 5),
                      ),
                      if (colorTheme == IslandTheme.green)
                        BoxShadow(
                          color: glowColor,
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: mainColor,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: userCharacter == null
                          ? Icon(
                        Icons.spa,
                        color: Colors.white.withOpacity(0.6),
                        size: 24,
                      )
                          : null,
                    ),
                  ),
                ),
                // 3D Model
                if (userCharacter != null)
                  Positioned(
                    bottom: 20,
                    child: SizedBox(
                      height: 130,
                      width: 110,
                      child: Stack(
                        children: [
                          if (userCharacter!.isHealed)
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                child: const Icon(
                                  Icons.check,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          userCharacter!.glbFileName.isNotEmpty
                              ? CachedO3D(
                            glbPath: "assets/models/${userCharacter!.glbFileName}",
                            autoPlay: true,
                            cameraControls: false,
                          )
                              : Container(
                            decoration: BoxDecoration(
                              color: _getArchetypeColor(
                                userCharacter!.archetype,
                              ).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _getArchetypeIcon(userCharacter!.archetype),
                              size: 50,
                              color: _getArchetypeColor(
                                userCharacter!.archetype,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Glass Effect Label
          if (userCharacter != null) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5.0, sigmaY: 5.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.6),
                      width: 1.5,
                    ),
                    boxShadow: [
                      if (colorTheme == IslandTheme.green)
                        BoxShadow(
                          color: const Color(0xFF5CB85C).withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        userCharacter!.displayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorTheme == IslandTheme.green
                              ? const Color(0xFF2E7D32) // Dark green for healed
                              : const Color(0xFF4A148C), // Purple for unhealed
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _getTranslatedArchetype(context, userCharacter!.archetype),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: _getArchetypeColor(userCharacter!.archetype),
                            ),
                          ),
                          if (userCharacter!.isHealed)
                            Row(
                              children: [
                                const SizedBox(width: 4),
                                Container(
                                  width: 4,
                                  height: 4,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF5CB85C),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isArabic ? 'تم الشفاء' : 'HEALED',
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.w800,
                                    color: const Color(0xFF5CB85C),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getArchetypeColor(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return const Color(0xFF6A5CFF);
      case 'firefighter':
        return const Color(0xFFFF6B6B);
      case 'exile':
        return const Color(0xFFFFB84D);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  IconData _getArchetypeIcon(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return Icons.business_center;
      case 'firefighter':
        return Icons.local_fire_department;
      case 'exile':
        return Icons.people_alt;
      default:
        return Icons.person;
    }
  }

  String _getTranslatedArchetype(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'MANAGER', 'مدير');
      case 'firefighter':
        return tr(context, 'FIREFIGHTER', 'رجل إطفاء');
      case 'exile':
        return tr(context, 'EXILE', 'منفي');
      default:
        return archetype.toUpperCase();
    }
  }
}

// Extension to get enum name
extension IslandThemeExtension on IslandTheme {
  String get name => toString().split('.').last;
}