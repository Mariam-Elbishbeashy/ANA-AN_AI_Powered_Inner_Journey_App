import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/character/presentation/screens/character_profile_screen.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class AdminInnerCharactersScreen extends StatefulWidget {
  const AdminInnerCharactersScreen({super.key});

  @override
  State<AdminInnerCharactersScreen> createState() =>
      _AdminInnerCharactersScreenState();
}

class _AdminInnerCharactersScreenState extends State<AdminInnerCharactersScreen> {
  late Future<List<UserCharacter>> _charactersFuture;

  @override
  void initState() {
    super.initState();
    _charactersFuture = _loadCharacters();
  }

  Future<List<UserCharacter>> _loadCharacters() async {
    final raw =
        await rootBundle.loadString('assets/data/inner_characters_data.json');
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];

    final now = DateTime.now();
    final characters = <UserCharacter>[];
    final limit = decoded.length > 18 ? 18 : decoded.length;
    for (var i = 0; i < limit; i++) {
      final entry = decoded[i];
      if (entry is! Map<String, dynamic>) continue;
      final id = entry['id']?.toString() ?? 'character_$i';
      final displayName = entry['displayName']?.toString() ?? 'Inner Part';
      final role = entry['role']?.toString() ?? 'Manager';
      characters.add(
        UserCharacter(
          id: id,
          userId: 'inner_characters',
          characterName: displayName,
          displayName: displayName,
          archetype: role.toLowerCase(),
          confidence: 1.0,
          rank: i + 1,
          language: 'en',
          glbFileName: '',
          description: entry['shortDescription']?.toString() ?? '',
          predictedAt: now,
          isHealed: false,
          healedAt: null,
        ),
      );
    }
    return characters;
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

  String _localizedArchetype(BuildContext context, String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'MANAGER', 'مدير');
      case 'firefighter':
        return tr(context, 'FIREFIGHTER', 'إطفائي');
      case 'exile':
        return tr(context, 'EXILE', 'منفى');
      default:
        return archetype.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr(context, 'Inner Characters', 'الشخصيات الداخلية'),
          style: const TextStyle(
            color: Color(0xFF2A1E3B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: FutureBuilder<List<UserCharacter>>(
        future: _charactersFuture,
        builder: (context, snapshot) {
          final characters = snapshot.data ?? [];
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
            );
          }
          if (characters.isEmpty) {
            return Center(
              child: Text(
                tr(context, 'No characters found.', 'لا توجد شخصيات.'),
                style: const TextStyle(color: Color(0xFF7A6A5A)),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: characters.map((character) {
                final imagePath = _getImagePathForCharacter(
                  character.characterName,
                );
                final color = _getArchetypeColor(character.archetype);
                return SizedBox(
                  width: (MediaQuery.of(context).size.width - 52) / 2,
                  child: _InnerCharacterCard(
                    character: character,
                    imagePath: imagePath,
                    color: color,
                    archetypeLabel: _localizedArchetype(
                      context,
                      character.archetype,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => CharacterProfileScreen(
                            character: character,
                            hideCommunicationHub: true,
                          ),
                        ),
                      );
                    },
                  ),
                );
              }).toList(),
            ),
          );
        },
      ),
    );
  }
}

class _InnerCharacterCard extends StatelessWidget {
  final UserCharacter character;
  final String imagePath;
  final Color color;
  final String archetypeLabel;
  final VoidCallback onTap;

  const _InnerCharacterCard({
    required this.character,
    required this.imagePath,
    required this.color,
    required this.archetypeLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5DEFF),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 120,
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFFF9F6FF),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Hero(
                  tag: 'character-${character.id}',
                  child: Image.asset(
                    imagePath,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      character.displayName,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        archetypeLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: color,
                          letterSpacing: 0.8,
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
    );
  }
}
