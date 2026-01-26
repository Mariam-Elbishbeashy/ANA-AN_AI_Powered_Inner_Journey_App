import 'package:flutter/material.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/map_3d/presentation/widgets/map_island.dart';
import 'package:ana_ifs_app/features/map_3d/presentation/widgets/path_painter.dart';
import 'package:ana_ifs_app/features/map_3d/presentation/widgets/wandering_blob.dart';
import 'package:ana_ifs_app/features/map_3d/presentation/widgets/character_detail_dialog.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';

class Map3DScreen extends StatefulWidget {
  final String name;
  final List<UserCharacter> userCharacters;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;

  const Map3DScreen({
    super.key,
    required this.name,
    required this.userCharacters,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
  });

  @override
  State<Map3DScreen> createState() => _Map3DScreenState();
}

class _Map3DScreenState extends State<Map3DScreen> {
  // Normal positions (NOT reversed) - bottom nodes have highest dy values
  final List<Offset> nodePositions = [
    const Offset(0.3, 820), // Bottom first (highest dy value)
    const Offset(0.65, 730), // Second bottom
    const Offset(0.2, 610), // Third from bottom
    const Offset(0.5, 500), // Fourth
    const Offset(0.75, 370), // Fifth
    const Offset(0.3, 270), // Sixth
    const Offset(0.6, 150), // Seventh
    const Offset(0.2, 30), // Top last (lowest dy value)
  ];

  late List<UserCharacter?> mapSlots;
  late ScrollController _scrollController;
  final FirestoreService _firestoreService = FirestoreService();
  List<UserCharacter> _healedCharacters = [];
  List<UserCharacter> _unhealedCharacters = [];
  bool _isLoading = true;
  late bool _isArabic; // Store language state locally

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    mapSlots = List<UserCharacter?>.filled(nodePositions.length, null);

    // Initialize with default value, will be updated in build
    _isArabic = false;

    // Load characters data
    _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      // Get both healed and unhealed characters
      final healed = await _firestoreService.getHealedCharacters();
      final unhealed = await _firestoreService.getUnhealedCharacters();

      // DEBUG LOGGING
      print('DEBUG: Loaded ${healed.length} healed characters');
      print('DEBUG: Loaded ${unhealed.length} unhealed characters');

      if (healed.isNotEmpty) {
        print('DEBUG: Healed character names: ${healed.map((c) => c.displayName).toList()}');
        for (var char in healed) {
          print('DEBUG: ${char.displayName} - isHealed: ${char.isHealed}, predictedAt: ${char.predictedAt}');
        }
      }

      setState(() {
        _healedCharacters = healed;
        _unhealedCharacters = unhealed;
      });

      // Clear mapSlots first
      for (int i = 0; i < mapSlots.length; i++) {
        mapSlots[i] = null;
      }

      // DEBUG: Show what we have
      print('DEBUG: Total characters: ${healed.length + unhealed.length}');
      print('DEBUG: Available slots: ${mapSlots.length}');

      // Combine characters - PUT HEALED CHARACTERS FIRST for visibility
      final allCharacters = [...healed, ...unhealed];

      // Assign characters to slots
      int assignedCount = 0;
      for (int i = 0; i < allCharacters.length && i < mapSlots.length; i++) {
        mapSlots[i] = allCharacters[i];
        assignedCount++;
        print('DEBUG: Slot $i assigned: ${allCharacters[i].displayName} '
            '(Healed: ${allCharacters[i].isHealed}, '
            'Archetype: ${allCharacters[i].archetype})');
      }

      print('DEBUG: Total assigned to map: $assignedCount');

      // Auto-scroll to BOTTOM when page loads (to show first nodes)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          // Scroll to the maximum extent (bottom) to show bottom nodes first
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOut,
          );
        }
      });

      setState(() {
        _isLoading = false;
      });

    } catch (e) {
      print('Error loading characters: $e');
      // Even if there's an error, try to use the initial characters passed to widget
      _useInitialCharacters();
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _useInitialCharacters() {
    print('DEBUG: Using initial characters from widget');
    print('DEBUG: Initial characters count: ${widget.userCharacters.length}');

    // Clear mapSlots first
    for (int i = 0; i < mapSlots.length; i++) {
      mapSlots[i] = null;
    }

    // Separate healed and unhealed from initial characters
    final healed = widget.userCharacters.where((c) => c.isHealed).toList();
    final unhealed = widget.userCharacters.where((c) => !c.isHealed).toList();

    setState(() {
      _healedCharacters = healed;
      _unhealedCharacters = unhealed;
    });

    print('DEBUG: Found ${healed.length} healed in initial data');
    print('DEBUG: Found ${unhealed.length} unhealed in initial data');

    // Combine and assign
    final allCharacters = [...healed, ...unhealed];

    for (int i = 0; i < allCharacters.length && i < mapSlots.length; i++) {
      mapSlots[i] = allCharacters[i];
      print('DEBUG: Slot $i assigned from initial: ${allCharacters[i].displayName} '
          '(Healed: ${allCharacters[i].isHealed})');
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showCharacterDetail(BuildContext context, UserCharacter character) {
    // Get current language state
    final currentIsArabic = _isArabic;

    // Get IFS relationships using current language state
    final ifsRelationships = _getIFSRelationships(character, currentIsArabic);
    final archetypeRelationships = _getArchetypeRelationships(character.archetype, currentIsArabic);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CharacterDetailDialog(
        character: character,
        ifsRelationships: ifsRelationships,
        archetypeRelationships: archetypeRelationships,
        allCharacters: [..._unhealedCharacters, ..._healedCharacters],
        isArabic: currentIsArabic, // Pass language state to dialog
      ),
    );
  }

  List<String> _getIFSRelationships(UserCharacter character, bool isArabic) {
    final otherCharacters = [..._unhealedCharacters, ..._healedCharacters]
        .where((c) => c.id != character.id)
        .toList();

    if (otherCharacters.isEmpty) {
      return [isArabic ? "لم يتم تحديد أجزاء أخرى بعد" : "No other parts identified yet"];
    }

    final List<String> relationships = [];

    // Get archetype-based relationships
    for (final otherChar in otherCharacters) {
      final relation = _getArchetypeRelation(character.archetype, otherChar.archetype, isArabic);
      if (relation.isNotEmpty) {
        relationships.add("${otherChar.displayName} ($relation)");
      }
    }

    // If no specific relationships found, show all other parts
    if (relationships.isEmpty) {
      return otherCharacters.map((c) => c.displayName).toList();
    }

    return relationships;
  }

  String _getArchetypeRelation(String archetype1, String archetype2, bool isArabic) {
    final archetype1Lower = archetype1.toLowerCase();
    final archetype2Lower = archetype2.toLowerCase();

    if (archetype1Lower == 'manager') {
      if (archetype2Lower == 'firefighter') {
        return isArabic ? 'يتم تنشيطه عند الشعور بالإرهاق' : 'triggers when overwhelmed';
      } else if (archetype2Lower == 'exile') {
        return isArabic ? 'يحمي من الألم' : 'protects from pain';
      }
    }

    if (archetype1Lower == 'firefighter') {
      if (archetype2Lower == 'manager') {
        return isArabic ? 'يتفاعل مع السيطرة' : 'reacts to control';
      } else if (archetype2Lower == 'exile') {
        return isArabic ? 'يصرف الانتباه عن الألم' : 'distracts from pain';
      }
    }

    if (archetype1Lower == 'exile') {
      if (archetype2Lower == 'manager') {
        return isArabic ? 'بحاجة إلى الحماية' : 'needs protection';
      } else if (archetype2Lower == 'firefighter') {
        return isArabic ? 'بحاجة إلى الراحة' : 'needs comfort';
      }
    }

    return '';
  }

  List<String> _getArchetypeRelationships(String archetype, bool isArabic) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return isArabic
            ? [
          "المديرون يحافظون على النظام والتحكم في النظام",
          "يحمون المنفيين من الشعور بالضعف",
          "ينشطون رجال الإطفاء عند الشعور بالإرهاق",
          "الهدف هو منع الألم والحفاظ على الاستقرار"
        ]
            : [
          "Managers maintain order and control in the system",
          "They protect exiles from feeling vulnerable",
          "They activate firefighters when feeling overwhelmed",
          "Goal is to prevent pain and maintain stability"
        ];
      case 'firefighter':
        return isArabic
            ? [
          "رجال الإطفاء يستجيبون لحالات الطوارئ العاطفية",
          "يصرفون الانتباه عن ألم المنفيين من خلال السلوكيات",
          "غالبًا ما يعارضون جهود المديرين للسيطرة",
          "الهدف هو توفير راحة فورية من الضيق"
        ]
            : [
          "Firefighters respond to emotional emergencies",
          "They distract from exile pain through behaviors",
          "Often oppose managers' control efforts",
          "Goal is to provide immediate relief from distress"
        ];
      case 'exile':
        return isArabic
            ? [
          "المنفيون يحملون المشاعر والذكريات الضعيفة",
          "يتم حمايتهم من قبل المديرين",
          "ينشطون رجال الإطفاء عند تنشيطهم",
          "الهدف هو أن يتم مشاهدتهم ودمجهم"
        ]
            : [
          "Exiles carry vulnerable emotions and memories",
          "They are protected by managers",
          "They trigger firefighters when activated",
          "Goal is to be witnessed and integrated"
        ];
      default:
        return isArabic
            ? [
          "هذا الجزء يلعب دورًا في نظامك الداخلي",
          "جميع الأجزاء تحاول المساعدة بطريقتها الخاصة",
          "الفهم يؤدي إلى التكامل"
        ]
            : [
          "This part plays a role in your internal system",
          "All parts are trying to help in their own way",
          "Understanding leads to integration"
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update language state in build method where it's safe to access context
    _isArabic = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF3E5F5),
      body: Column(
        children: [
          // Top Bar
          TopHelloBar(
            name: widget.name,
            onLogout: widget.onLogout,
            onSettings: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SettingsBottomSheet(
                  onRetakeQuestionnaire: widget.onRetakeQuestionnaire,
                  onSwitchLanguage: widget.onSwitchLanguage,
                ),
              );
            },
          ),

          // REMOVED: Healing Stats Bar - Now showing visually on each character

          // 3D Map Visualization
          Expanded(
            child: _isLoading
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(
                    color: Color(0xFF8E7CFF),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isArabic ? 'جاري تحميل الخريطة...' : 'Loading map...',
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                    ),
                  ),
                ],
              ),
            )
                : SingleChildScrollView(
              controller: _scrollController,
              physics: const BouncingScrollPhysics(),
              child: SizedBox(
                height: 1150,
                width: MediaQuery.of(context).size.width,
                child: Stack(
                  children: [
                    // Background Wandering Blobs
                    Positioned(
                      top: 50,
                      right: -50,
                      child: WanderingBlob(
                        color: const Color(0xFFE1BEE7).withOpacity(0.3),
                        size: 300,
                        wanderRange: 50.0,
                      ),
                    ),
                    Positioned(
                      top: 400,
                      left: -50,
                      child: WanderingBlob(
                        color: const Color(0xFFC8E6C9).withOpacity(0.3),
                        size: 400,
                        wanderRange: 80.0,
                      ),
                    ),
                    Positioned(
                      bottom: 100,
                      right: -20,
                      child: WanderingBlob(
                        color: const Color(0xFFE1BEE7).withOpacity(0.3),
                        size: 250,
                        wanderRange: 40.0,
                      ),
                    ),

                    // Path & Nodes
                    CustomPaint(
                      size: Size(MediaQuery.of(context).size.width, 1150),
                      painter: PathPainter(positions: nodePositions),
                    ),

                    // Floating scroll indicator
                    Positioned(
                      top: 20,
                      right: 20,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.arrow_upward,
                              size: 16,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isArabic ? "اسحب للاستكشاف" : "Scroll to explore",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.purple,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Character Islands - ADD DEBUGGING
                    ...List.generate(nodePositions.length, (index) {
                      final pos = nodePositions[index];
                      final double leftPos =
                          (pos.dx * MediaQuery.of(context).size.width) - 60;

                      final character = mapSlots[index];
                      IslandTheme theme;

                      if (character == null) {
                        // Empty slot - default to purple
                        theme = IslandTheme.purple;
                      } else if (character.isHealed) {
                        // Healed character - GREEN theme
                        theme = IslandTheme.green;
                      } else {
                        // Unhealed character - PURPLE theme
                        theme = IslandTheme.purple;
                      }

                      return Positioned(
                        top: pos.dy,
                        left: leftPos,
                        child: MapIsland(
                          userCharacter: character,
                          colorTheme: theme,
                          onTap: character != null
                              ? () => _showCharacterDetail(
                            context,
                            character,
                          )
                              : null,
                          isArabic: _isArabic, // Pass the language state
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}