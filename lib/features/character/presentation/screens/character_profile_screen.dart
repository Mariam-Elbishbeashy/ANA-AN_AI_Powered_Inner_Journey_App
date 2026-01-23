import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/character/presentation/screens/character_chat_screen.dart';
import 'package:ana_ifs_app/features/voice_analysis/presentation/screens/voice_analysis_screen.dart';

class CharacterProfileScreen extends StatefulWidget {
  final UserCharacter character;

  const CharacterProfileScreen({super.key, required this.character});

  @override
  State<CharacterProfileScreen> createState() => _CharacterProfileScreenState();
}

class _CharacterProfileScreenState extends State<CharacterProfileScreen> {
  late Future<_ProfileData> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileFuture = _loadProfileData();
  }

  Future<_ProfileData> _loadProfileData() async {
    try {
      final raw = await rootBundle
          .loadString('assets/data/inner_characters_data.json');
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        final targetNames = <String>{
          _normalize(widget.character.displayName),
          _normalize(widget.character.characterName),
          _compact(widget.character.displayName),
          _compact(widget.character.characterName),
        }..removeWhere((value) => value.isEmpty);
        for (final entry in decoded) {
          if (entry is Map<String, dynamic>) {
            final name = entry['displayName']?.toString() ?? '';
            final id = entry['id']?.toString() ?? '';
            final normalizedName = _normalize(name);
            final normalizedId = _normalize(id);
            final compactName = _compact(name);
            final compactId = _compact(id);
            final matches = targetNames.any(
              (target) =>
                  target == normalizedName ||
                  target == normalizedId ||
                  target == compactName ||
                  target == compactId ||
                  target.contains(normalizedName) ||
                  normalizedName.contains(target) ||
                  target.contains(compactName) ||
                  compactName.contains(target),
            );
            if (matches) {
              return _ProfileData.fromJson(entry);
            }
          }
        }
      }
    } catch (_) {}
    return _ProfileData.fallback(
      widget.character.displayName,
      widget.character.archetype,
    );
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\bthe\b'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _compact(String value) {
    return _normalize(value).replaceAll(' ', '');
  }

  String _getFullBodyImagePath(String characterName) {
    final imageMap = {
      'Inner Critic': 'inner_critic.png',
      'People Pleaser': 'people_pleaser.png',
      'Lonely Part': 'lonely.png',
      'Jealous Part': 'jealous.png',
      'Ashamed Part': 'ashamed.png',
      'Workaholic': 'workaholic.png',
      'Perfectionist': 'perfectionist.png',
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
      return 'assets/images/characters_full_body/${imageMap[characterName]}';
    }

    final lowerName = characterName.toLowerCase();
    for (final entry in imageMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return 'assets/images/characters_full_body/${entry.value}';
      }
    }

    return 'assets/images/characters_full_body/inner_critic.png';
  }

  Color _roleColor(String role) {
    switch (role.toLowerCase()) {
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

  @override
  Widget build(BuildContext context) {
    final imagePath = _getFullBodyImagePath(widget.character.characterName);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white,
              const Color(0xFFFBF8FF),
              const Color(0xFFF9F6FF),
            ],
          ),
        ),
        child: SafeArea(
          child: FutureBuilder<_ProfileData>(
            future: _profileFuture,
            builder: (context, snapshot) {
              final data = snapshot.data ??
                  _ProfileData.fallback(
                    widget.character.displayName,
                    widget.character.archetype,
                  );
              final roleColor = _roleColor(data.role);
              return CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
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
                                data.localizedDisplayName(context),
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
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: _HeroImageCard(
                        imagePath: imagePath,
                        tag: 'character-${widget.character.id}',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
                      child: LayoutBuilder(
                        builder: (context, _) {
                          const double cardHeight = 180;
                          const double footerHeight = 16;
                          final double totalHeight = cardHeight + footerHeight;
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: totalHeight,
                                  child: Column(
                                    children: [
                                      SizedBox(
                                        height: cardHeight,
                                        child: _IdentityCard(
                                          role: data.role,
                                          roleColor: roleColor,
                                          shortDescription: data
                                              .localizedShortDescription(context),
                                        ),
                                      ),
                                      const SizedBox(height: footerHeight),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: totalHeight,
                                  child: _InfoCarousel(
                                    cardHeight: cardHeight,
                                    footerHeight: footerHeight,
                                    items: [
                                      _CarouselItem(
                                        title: tr(
                                          context,
                                          'Why I Exist',
                                          'لماذا أوجد',
                                        ),
                                        icon: Icons.psychology_rounded,
                                        body: data.localizedWhyIExist(context),
                                      ),
                                      _CarouselItem(
                                        title: tr(context, 'Triggers', 'المحفزات'),
                                        icon: Icons.flash_on_rounded,
                                        items: data.localizedTriggers(context),
                                      ),
                                      _CarouselItem(
                                        title: tr(
                                          context,
                                          'Core Belief',
                                          'المعتقد الأساسي',
                                        ),
                                        icon: Icons.favorite_rounded,
                                        body: data.localizedCoreBelief(context),
                                      ),
                                      _CarouselItem(
                                        title: tr(context, 'Fear', 'الخوف'),
                                        icon: Icons.visibility_off_rounded,
                                        body: data.localizedFear(context),
                                      ),
                                      _CarouselItem(
                                        title: tr(context, 'Intention', 'النية'),
                                        icon: Icons.auto_awesome_rounded,
                                        body: data.localizedIntention(context),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: _TimelineSection(
                        title: tr(context, 'How I Show Up', 'كيف أظهر'),
                        icon: Icons.insights_rounded,
                        items: data.localizedHowIShowUp(context),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 0),
                      child: _InfoSection(
                        title: tr(context, 'What I Need From You', 'ماذا أحتاج منك'),
                        icon: Icons.volunteer_activism_rounded,
                        items: data.localizedWhatINeed(context),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
                      child: _CommunicationHub(
                        onChat: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => CharacterChatScreen(
                                character: widget.character,
                              ),
                            ),
                          );
                        },
                        onVoice: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VoiceAnalysisScreen(
                                character: widget.character,
                              ),
                            ),
                          );
                        },
                        onVideo: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                tr(
                                  context,
                                  'Video sessions are coming soon.',
                                  'جلسات الفيديو قادمة قريبًا.',
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileData {
  final String displayName;
  final String displayNameAr;
  final String role;
  final String shortDescription;
  final String shortDescriptionAr;
  final String whyIExist;
  final String whyIExistAr;
  final List<String> triggers;
  final List<String> triggersAr;
  final String coreBelief;
  final String coreBeliefAr;
  final String intention;
  final String intentionAr;
  final String fear;
  final String fearAr;
  final List<String> howIShowUp;
  final List<String> howIShowUpAr;
  final List<String> whatINeed;
  final List<String> whatINeedAr;

  const _ProfileData({
    required this.displayName,
    required this.displayNameAr,
    required this.role,
    required this.shortDescription,
    required this.shortDescriptionAr,
    required this.whyIExist,
    required this.whyIExistAr,
    required this.triggers,
    required this.triggersAr,
    required this.coreBelief,
    required this.coreBeliefAr,
    required this.intention,
    required this.intentionAr,
    required this.fear,
    required this.fearAr,
    required this.howIShowUp,
    required this.howIShowUpAr,
    required this.whatINeed,
    required this.whatINeedAr,
  });

  factory _ProfileData.fromJson(Map<String, dynamic> json) {
    return _ProfileData(
      displayName: json['displayName']?.toString() ?? 'Inner Part',
      displayNameAr: json['displayNameAr']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Manager',
      shortDescription: json['shortDescription']?.toString() ?? '',
      shortDescriptionAr: json['shortDescriptionAr']?.toString() ?? '',
      whyIExist: json['whyIExist']?.toString() ?? '',
      whyIExistAr: json['whyIExistAr']?.toString() ?? '',
      triggers: _listOfStrings(json['triggers']),
      triggersAr: _listOfStrings(json['triggersAr']),
      coreBelief: json['coreBelief']?.toString() ?? '',
      coreBeliefAr: json['coreBeliefAr']?.toString() ?? '',
      intention: json['intention']?.toString() ?? '',
      intentionAr: json['intentionAr']?.toString() ?? '',
      fear: json['fear']?.toString() ?? '',
      fearAr: json['fearAr']?.toString() ?? '',
      howIShowUp: _listOfStrings(json['howIShowUp']),
      howIShowUpAr: _listOfStrings(json['howIShowUpAr']),
      whatINeed: _listOfStrings(json['whatINeed']),
      whatINeedAr: _listOfStrings(json['whatINeedAr']),
    );
  }

  factory _ProfileData.fallback(String name, String role) {
    return _ProfileData(
      displayName: name,
      displayNameAr: '',
      role: role,
      shortDescription: '',
      shortDescriptionAr: '',
      whyIExist: '',
      whyIExistAr: '',
      triggers: const [],
      triggersAr: const [],
      coreBelief: '',
      coreBeliefAr: '',
      intention: '',
      intentionAr: '',
      fear: '',
      fearAr: '',
      howIShowUp: const [],
      howIShowUpAr: const [],
      whatINeed: const [],
      whatINeedAr: const [],
    );
  }

  static List<String> _listOfStrings(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  String localizedDisplayName(BuildContext context) {
    if (isArabic(context) && displayNameAr.isNotEmpty) {
      return displayNameAr;
    }
    return displayName;
  }

  String localizedShortDescription(BuildContext context) {
    if (isArabic(context) && shortDescriptionAr.isNotEmpty) {
      return shortDescriptionAr;
    }
    return shortDescription;
  }

  String localizedWhyIExist(BuildContext context) {
    if (isArabic(context) && whyIExistAr.isNotEmpty) {
      return whyIExistAr;
    }
    return whyIExist;
  }

  List<String> localizedTriggers(BuildContext context) {
    if (isArabic(context) && triggersAr.isNotEmpty) {
      return triggersAr;
    }
    return triggers;
  }

  String localizedCoreBelief(BuildContext context) {
    if (isArabic(context) && coreBeliefAr.isNotEmpty) {
      return coreBeliefAr;
    }
    return coreBelief;
  }

  String localizedIntention(BuildContext context) {
    if (isArabic(context) && intentionAr.isNotEmpty) {
      return intentionAr;
    }
    return intention;
  }

  String localizedFear(BuildContext context) {
    if (isArabic(context) && fearAr.isNotEmpty) {
      return fearAr;
    }
    return fear;
  }

  List<String> localizedHowIShowUp(BuildContext context) {
    if (isArabic(context) && howIShowUpAr.isNotEmpty) {
      return howIShowUpAr;
    }
    return howIShowUp;
  }

  List<String> localizedWhatINeed(BuildContext context) {
    if (isArabic(context) && whatINeedAr.isNotEmpty) {
      return whatINeedAr;
    }
    return whatINeed;
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accentColor;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 18,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white,
                Colors.white.withOpacity(0.98),
                const Color(0xFFFDFCFF).withOpacity(0.95),
              ],
            ),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(
              color: accentColor?.withOpacity(0.15) ?? Colors.white.withOpacity(0.95),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (accentColor ?? const Color(0xFF6A5CFF)).withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
                spreadRadius: -2,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _HeroImageCard extends StatelessWidget {
  final String imagePath;
  final String tag;

  const _HeroImageCard({required this.imagePath, required this.tag});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    const Color(0xFFF5F0FF),
                    const Color(0xFFEDE7FF).withOpacity(0.6),
                  ],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
            ),
          ),
          Center(
            child: Hero(
              tag: tag,
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  final String role;
  final Color roleColor;
  final String shortDescription;

  const _IdentityCard({
    required this.role,
    required this.roleColor,
    required this.shortDescription,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accentColor: roleColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  roleColor.withOpacity(0.15),
                  roleColor.withOpacity(0.08),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: roleColor.withOpacity(0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: roleColor.withOpacity(0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: roleColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: roleColor.withOpacity(0.5),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w900,
                    color: roleColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
          if (shortDescription.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6FF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFE8E1FF),
                  width: 1,
                ),
              ),
              child: Text(
                shortDescription,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.6,
                  color: Color(0xFF3D2D5A),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final String? body;
  final List<String>? items;

  const _InfoSection({
    required this.title,
    this.icon,
    this.body,
    this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accentColor: const Color(0xFF6A5CFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB4A3FF),
                        Color(0xFFA78BFA),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA78BFA).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              if (icon != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2A1E3B),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          if (body != null && body!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF9F6FF),
                    const Color(0xFFFBF8FF),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFE8E1FF),
                  width: 1,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF8E7CFF),
                          Color(0xFF6A5CFF),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      body!,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.6,
                        color: Color(0xFF3D2D5A),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (items != null && items!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: items!.asMap().entries.map(
                    (entry) {
                      final index = entry.key;
                      final item = entry.value;
                      final colors = [
                        [const Color(0xFF8E7CFF), const Color(0xFF6A5CFF)],
                        [const Color(0xFFA78BFA), const Color(0xFF9B7BFF)],
                        [const Color(0xFF6A5CFF), const Color(0xFF4A3F8F)],
                        [const Color(0xFF9B7BFF), const Color(0xFF7C6AFF)],
                      ];
                      final colorPair = colors[index % colors.length];
                      
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              colorPair[0].withOpacity(0.12),
                              colorPair[1].withOpacity(0.08),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: colorPair[0].withOpacity(0.25),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: colorPair[0],
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: colorPair[1].withOpacity(0.9),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _CarouselItem {
  final String title;
  final IconData icon;
  final String? body;
  final List<String>? items;

  const _CarouselItem({
    required this.title,
    required this.icon,
    this.body,
    this.items,
  });
}

class _InfoCarousel extends StatefulWidget {
  final List<_CarouselItem> items;
  final double cardHeight;
  final double footerHeight;

  const _InfoCarousel({
    required this.items,
    this.cardHeight = 180,
    this.footerHeight = 16,
  });

  @override
  State<_InfoCarousel> createState() => _InfoCarouselState();
}

class _InfoCarouselState extends State<_InfoCarousel> {
  late final PageController _controller;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.cardHeight + widget.footerHeight,
      child: Column(
        children: [
          SizedBox(
            height: widget.cardHeight,
            child: PageView.builder(
              controller: _controller,
              itemCount: widget.items.length,
              padEnds: false,
              onPageChanged: (value) => setState(() => _index = value),
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final hasBody = item.body != null && item.body!.isNotEmpty;
                final hasItems = item.items != null && item.items!.isNotEmpty;
                final colors = [
                  [const Color(0xFF8E7CFF), const Color(0xFF6A5CFF)],
                  [const Color(0xFFA78BFA), const Color(0xFF9B7BFF)],
                  [const Color(0xFF6A5CFF), const Color(0xFF4A3F8F)],
                  [const Color(0xFF9B7BFF), const Color(0xFF7C6AFF)],
                  [const Color(0xFF6A5CFF), const Color(0xFF8E7CFF)],
                ];
                final colorPair = colors[index % colors.length];
                
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _GlassCard(
                    padding: const EdgeInsets.all(14),
                    radius: 20,
                    accentColor: colorPair[0],
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    colorPair[0].withOpacity(0.75),
                                    colorPair[1].withOpacity(0.75),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: colorPair[0].withOpacity(0.25),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Icon(
                                item.icon,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                item.title,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF2A1E3B),
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (hasBody)
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          const Color(0xFFF9F6FF),
                                          const Color(0xFFFBF8FF),
                                        ],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: colorPair[0].withOpacity(0.15),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 3,
                                          height: 16,
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: colorPair,
                                              begin: Alignment.topCenter,
                                              end: Alignment.bottomCenter,
                                            ),
                                            borderRadius: BorderRadius.circular(2),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            item.body!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              height: 1.6,
                                              color: Color(0xFF3D2D5A),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (hasItems) ...[
                                  if (hasBody) const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: item.items!
                                        .map(
                                          (value) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 7,
                                            ),
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  colorPair[0].withOpacity(0.12),
                                                  colorPair[1].withOpacity(0.08),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(
                                                color: colorPair[0].withOpacity(0.25),
                                                width: 1,
                                              ),
                                            ),
                                            child: Text(
                                              value,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: colorPair[1].withOpacity(0.9),
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          SizedBox(
            height: widget.footerHeight,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _index == index ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: _index == index
                          ? const Color(0xFF6A5CFF)
                          : const Color(0xFFD6CEFF),
                      borderRadius: BorderRadius.circular(10),
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

class _TimelineSection extends StatelessWidget {
  final String title;
  final IconData? icon;
  final List<String> items;

  const _TimelineSection({
    required this.title,
    this.icon,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      accentColor: const Color(0xFF6A5CFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null)
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFFB4A3FF),
                        Color(0xFFA78BFA),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA78BFA).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              if (icon != null) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF2A1E3B),
                    letterSpacing: -0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Column(
            children: List.generate(items.length, (index) {
              final isLast = index == items.length - 1;
              final colors = [
                [const Color(0xFF8E7CFF), const Color(0xFF6A5CFF)],
                [const Color(0xFFA78BFA), const Color(0xFF9B7BFF)],
                [const Color(0xFF6A5CFF), const Color(0xFF4A3F8F)],
                [const Color(0xFF9B7BFF), const Color(0xFF7C6AFF)],
              ];
              final colorPair = colors[index % colors.length];
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Column(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                colorPair[0].withOpacity(0.7),
                                colorPair[1].withOpacity(0.7),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: colorPair[0].withOpacity(0.2),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ),
                        if (!isLast)
                          Container(
                            width: 3,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colorPair[0].withOpacity(0.3),
                                  colorPair[1].withOpacity(0.1),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFFFBF8FF),
                              const Color(0xFFF9F6FF),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorPair[0].withOpacity(0.2),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: colorPair[0].withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 4,
                              height: 20,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: colorPair,
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                items[index],
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.6,
                                  color: Color(0xFF3D2D5A),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String leftTitle;
  final IconData? leftIcon;
  final List<String>? leftItems;
  final String? leftBody;
  final String rightTitle;
  final IconData? rightIcon;
  final String rightBody;

  const _InfoRow({
    required this.leftTitle,
    this.leftIcon,
    this.leftItems,
    this.leftBody,
    required this.rightTitle,
    this.rightIcon,
    required this.rightBody,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _InfoSection(
            title: leftTitle,
            icon: leftIcon,
            body: leftBody,
            items: leftItems,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _InfoSection(
            title: rightTitle,
            icon: rightIcon,
            body: rightBody,
          ),
        ),
      ],
    );
  }
}

class _CommunicationHub extends StatelessWidget {
  final VoidCallback onChat;
  final VoidCallback onVoice;
  final VoidCallback onVideo;

  const _CommunicationHub({
    required this.onChat,
    required this.onVoice,
    required this.onVideo,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      radius: 22,
      accentColor: const Color(0xFF6A5CFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFB4A3FF),
                      Color(0xFFA78BFA),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFA78BFA).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                tr(context, 'Talk to Me', 'تحدث معي'),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF2A1E3B),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _HubButton(
                  icon: Icons.chat_bubble_rounded,
                  title: tr(context, 'Chat', 'دردشة'),
                  subtitle: tr(
                    context,
                    'Text conversation',
                    'محادثة نصية',
                  ),
                  gradientColors: const [Color(0xFF8E7CFF), Color(0xFF6A5CFF)],
                  onTap: onChat,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HubButton(
                  icon: Icons.mic_rounded,
                  title: tr(context, 'Voice', 'صوت'),
                  subtitle: tr(
                    context,
                    'Speak freely',
                    'تحدث بحرية',
                  ),
                  gradientColors: const [Color(0xFFA78BFA), Color(0xFF9B7BFF)],
                  onTap: onVoice,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _HubButton(
                  icon: Icons.videocam_rounded,
                  title: tr(context, 'Video', 'فيديو'),
                  subtitle: tr(
                    context,
                    'Guided sessions',
                    'جلسات موجهة',
                  ),
                  gradientColors: const [Color(0xFF6A5CFF), Color(0xFF4A3F8F)],
                  onTap: onVideo,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HubButton extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final List<Color> gradientColors;
  final VoidCallback onTap;

  const _HubButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradientColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              gradientColors[0].withOpacity(0.12),
              gradientColors[1].withOpacity(0.08),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: gradientColors[0].withOpacity(0.25),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: gradientColors[0].withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    gradientColors[0].withOpacity(0.75),
                    gradientColors[1].withOpacity(0.75),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: gradientColors[0].withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: Color(0xFF2A1E3B),
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: gradientColors[1].withOpacity(0.8),
                  height: 1.3,
                ),
              ),
            ),
          ],
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


