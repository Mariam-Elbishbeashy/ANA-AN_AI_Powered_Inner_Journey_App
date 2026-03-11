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
  List<UserCharacter> _stableCharacters = [];
  List<UserCharacter> _activeCharacters = [];
  List<UserCharacter> _inactiveCharacters = [];
  bool _isLoading = true;
  late bool _isArabic; // Store language state locally
  DateTime? _lastUserActivity;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    mapSlots = List<UserCharacter?>.filled(nodePositions.length, null);

    // Initialize with default value, will be updated in build
    _isArabic = false;

    // Load characters data and check inactivity
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInactivityAndLoadCharacters();
    });
  }

  Future<void> _checkInactivityAndLoadCharacters() async {
    print('🗺️ Map3DScreen: Checking inactivity and loading characters');

    // First check if user has been inactive (this will update characters if needed)
    await _firestoreService.checkAndUpdateInactiveCharacters();

    // Then update last activity timestamp
    await _firestoreService.updateUserLastActivity();

    // Load characters with updated states
    await _loadCharacters();
  }

  Future<void> _loadCharacters() async {
    try {
      print('Map3DScreen: Loading characters');

      // Get all characters
      final allCharacters = await _firestoreService.getUserCharacters();
      print('Map3DScreen: Total characters: ${allCharacters.length}');

      // Log states for debugging
      for (var c in allCharacters) {
        print('   - ${c.displayNameEn}: state=${c.currentState}');
      }

      // Get user's last activity
      _lastUserActivity = await _getLastUserActivity();

      // Categorize characters based on currentState
      final stable = allCharacters.where((c) => c.currentState == 'stable').toList();
      final active = allCharacters.where((c) => c.currentState == 'active').toList();
      final inactive = allCharacters.where((c) => c.currentState == 'inactive').toList();

      // DEBUG LOGGING
      print('🗺️ Map3DScreen: Found ${stable.length} stable characters');
      print('🗺️ Map3DScreen: Found ${active.length} active characters');
      print('🗺️ Map3DScreen: Found ${inactive.length} inactive characters');

      // Check if widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _stableCharacters = stable;
          _activeCharacters = active;
          _inactiveCharacters = inactive;
        });

        // Clear mapSlots first
        for (int i = 0; i < mapSlots.length; i++) {
          mapSlots[i] = null;
        }

        // Combine characters - order: stable first, then active, then inactive
        final allCharactersSorted = [...stable, ...active, ...inactive];

        // Assign characters to slots
        int assignedCount = 0;
        for (int i = 0; i < allCharactersSorted.length && i < mapSlots.length; i++) {
          mapSlots[i] = allCharactersSorted[i];
          assignedCount++;
          print('Map3DScreen: Slot $i assigned: ${allCharactersSorted[i].displayNameEn} '
              '(State: ${allCharactersSorted[i].currentState})');
        }

        print('Map3DScreen: Total assigned to map: $assignedCount');

        // Auto-scroll to BOTTOM when page loads
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients && mounted) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 800),
              curve: Curves.easeOut,
            );
          }
        });

        // Update loading state
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }

    } catch (e) {
      print('🗺️ Map3DScreen: Error loading characters: $e');
      if (mounted) {
        _useInitialCharacters();
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _useInitialCharacters() {
    if (!mounted) return;

    print('DEBUG: Using initial characters from widget');
    print('DEBUG: Initial characters count: ${widget.userCharacters.length}');

    // Clear mapSlots first
    for (int i = 0; i < mapSlots.length; i++) {
      mapSlots[i] = null;
    }

    // Separate by state from initial characters
    final stable = widget.userCharacters.where((c) => c.currentState == 'stable').toList();
    final active = widget.userCharacters.where((c) => c.currentState == 'active').toList();
    final inactive = widget.userCharacters.where((c) => c.currentState == 'inactive').toList();

    if (mounted) {
      setState(() {
        _stableCharacters = stable;
        _activeCharacters = active;
        _inactiveCharacters = inactive;
      });
    }

    print('DEBUG: Found ${stable.length} stable in initial data');
    print('DEBUG: Found ${active.length} active in initial data');
    print('DEBUG: Found ${inactive.length} inactive in initial data');

    // Combine and assign
    final allCharactersSorted = [...stable, ...active, ...inactive];

    for (int i = 0; i < allCharactersSorted.length && i < mapSlots.length; i++) {
      mapSlots[i] = allCharactersSorted[i];
      print('DEBUG: Slot $i assigned from initial: ${allCharactersSorted[i].displayNameEn} '
          '(State: ${allCharactersSorted[i].currentState})');
    }
  }

  Future<DateTime?> _getLastUserActivity() async {
    try {
      final userDoc = await _firestoreService.usersCollection
          .doc(_firestoreService.currentUserId)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        if (data['lastActivityAt'] != null) {
          return DateTime.tryParse(data['lastActivityAt']);
        }
      }
    } catch (e) {
      print('Error getting last activity: $e');
    }
    return DateTime.now();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _showCharacterDetail(BuildContext context, UserCharacter character) {
    // Don't show details for inactive characters
    if (character.currentState == 'inactive') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isArabic
                ? 'هذا الجزء غير نشط حالياً. استمر في استخدام التطبيق لتفعيله.'
                : 'This part is currently inactive. Continue using the app to activate it.',
          ),
          backgroundColor: const Color(0xFF9E9E9E),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

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
        allCharacters: [..._activeCharacters, ..._stableCharacters, ..._inactiveCharacters],
        isArabic: currentIsArabic, // Pass language state to dialog
      ),
    );
  }

  List<String> _getIFSRelationships(UserCharacter character, bool isArabic) {
    final otherCharacters = [..._activeCharacters, ..._stableCharacters, ..._inactiveCharacters]
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
        relationships.add("${otherChar.displayNameEn} ($relation)");
      }
    }

    // If no specific relationships found, show all other parts
    if (relationships.isEmpty) {
      return otherCharacters.map((c) => c.displayNameEn).toList();
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

                    // Character Islands
                    ...List.generate(nodePositions.length, (index) {
                      final pos = nodePositions[index];
                      final double leftPos =
                          (pos.dx * MediaQuery.of(context).size.width) - 60;

                      final character = mapSlots[index];
                      IslandTheme theme;

                      if (character == null) {
                        // Empty slot - default to purple
                        theme = IslandTheme.purple;
                      } else if (character.currentState == 'stable') {
                        // Stable character - GREEN theme
                        theme = IslandTheme.green;
                      } else if (character.currentState == 'inactive') {
                        // Inactive character - GREY theme
                        theme = IslandTheme.grey;
                      } else {
                        // Active character - PURPLE theme
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