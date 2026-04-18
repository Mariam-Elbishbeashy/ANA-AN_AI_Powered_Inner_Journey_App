import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/cached_o3d_widget.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

enum IslandTheme { green, purple, grey }

class MapIsland extends StatelessWidget {
  final UserCharacter? userCharacter;
  final IslandTheme colorTheme;
  final VoidCallback? onTap;
  final bool isArabic;
  final Key? refreshKey;

  const MapIsland({
    Key? key,
    this.userCharacter,
    required this.colorTheme,
    this.onTap,
    required this.isArabic,
    this.refreshKey,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // DEBUG LOGGING
    print('DEBUG MapIsland: Building for ${userCharacter?.displayNameEn ?? "empty"}, '
        'colorTheme: ${colorTheme.name}, currentState: ${userCharacter?.currentState ?? "none"}');

    Color mainColor;
    Color sideColor;
    Color glowColor;
    Color textColor;
    bool isInteractive = true;

    if (colorTheme == IslandTheme.green) {
      // Stable character - Green theme
      mainColor = const Color(0xFFA5D6A7);
      sideColor = const Color(0xFF66BB6A);
      glowColor = const Color(0xFF5CB85C).withValues(alpha: 0.3);
      textColor = const Color(0xFF2E7D32);
      print('DEBUG MapIsland: Using GREEN theme (stable) for ${userCharacter?.displayNameEn ?? "empty"}');
    } else if (colorTheme == IslandTheme.grey) {
      // Inactive character - Grey theme
      mainColor = const Color(0xFFE0E0E0);
      sideColor = const Color(0xFFBDBDBD);
      glowColor = Colors.transparent;
      textColor = const Color(0xFF616161);
      isInteractive = false; // Make inactive characters non-tappable
      print('DEBUG MapIsland: Using GREY theme (inactive) for ${userCharacter?.displayNameEn ?? "empty"}');
    } else {
      // Active character - Purple theme
      mainColor = const Color(0xFFCE93D8);
      sideColor = const Color(0xFFAB47BC);
      glowColor = const Color(0xFFAB47BC).withValues(alpha: 0.3);
      textColor = const Color(0xFF4A148C);
      print('DEBUG MapIsland: Using PURPLE theme (active) for ${userCharacter?.displayNameEn ?? "empty"}');
    }

    return GestureDetector(
      onTap: isInteractive ? onTap : null, // Disable taps for inactive
      child: Opacity(
        opacity: colorTheme == IslandTheme.grey ? 0.6 : 1.0, // Fade inactive characters
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
                  // Glow effect for stable characters
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

                  // Lock icon for inactive characters (only lock, no cancel sign)
                  if (colorTheme == IslandTheme.grey && userCharacter != null)
                    Positioned(
                      top: 30,
                      right: 10,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 14,
                          color: Color(0xFF757575),
                        ),
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
                          color: sideColor.withValues(alpha: 0.4),
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
                          color: Colors.white.withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: userCharacter == null
                            ? Icon(
                          Icons.spa,
                          color: Colors.white.withValues(alpha: 0.6),
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
                            // State indicator badge (only check for stable, no badge for inactive)
                            if (userCharacter!.currentState == 'stable')
                              Positioned(
                                top: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF5CB85C),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.check,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            userCharacter!.glbFileName.isNotEmpty
                                ? CachedO3D(
                              glbPath: "assets/models/${userCharacter!.glbFileName}",
                              autoPlay: true,
                              cameraControls: false,
                              key: refreshKey,
                              cacheKey: userCharacter!.id,
                            )
                                : Container(
                              decoration: BoxDecoration(
                                color: _getArchetypeColor(
                                  userCharacter!.archetype,
                                ).withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                _getArchetypeIcon(userCharacter!.archetype),
                                size: 50,
                                color: _getArchetypeColor(
                                  userCharacter!.archetype,
                                ).withValues(alpha:
                                  colorTheme == IslandTheme.grey ? 0.5 : 1.0,
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
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        if (colorTheme == IslandTheme.green)
                          BoxShadow(
                            color: const Color(0xFF5CB85C).withValues(alpha: 0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Text(
                          isArabic && userCharacter!.displayNameAr.isNotEmpty
                              ? userCharacter!.displayNameAr
                              : userCharacter!.displayNameEn,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: textColor,
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
                                color: _getArchetypeColor(userCharacter!.archetype).withValues(alpha:
                                colorTheme == IslandTheme.grey ? 0.5 : 1.0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: _getStateDotColor(userCharacter!.currentState),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _getStateLabel(userCharacter!.currentState, isArabic),
                              style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: _getStateLabelColor(userCharacter!.currentState),
                              ),
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

  Color _getStateDotColor(String state) {
    switch (state) {
      case 'stable':
        return const Color(0xFF5CB85C);
      case 'inactive':
        return const Color(0xFF9E9E9E);
      case 'active':
      default:
        return const Color(0xFFAB47BC);
    }
  }

  Color _getStateLabelColor(String state) {
    switch (state) {
      case 'stable':
        return const Color(0xFF5CB85C);
      case 'inactive':
        return const Color(0xFF757575);
      case 'active':
      default:
        return const Color(0xFFAB47BC);
    }
  }

  String _getStateLabel(String state, bool isArabic) {
    switch (state) {
      case 'stable':
        return isArabic ? 'مستقر' : 'STABLE';
      case 'inactive':
        return isArabic ? 'غير نشط' : 'INACTIVE';
      case 'active':
      default:
        return isArabic ? 'نشط' : 'ACTIVE';
    }
  }
}

// Extension to get enum name
extension IslandThemeExtension on IslandTheme {
  String get name => toString().split('.').last;
}