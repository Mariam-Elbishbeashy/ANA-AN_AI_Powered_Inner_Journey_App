// results_screen.dart - Updated with full Arabic support
import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';

import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/app/shell/ana_shell.dart';

class QuestionnaireResultsScreen extends StatefulWidget {
  const QuestionnaireResultsScreen({super.key});

  @override
  State<QuestionnaireResultsScreen> createState() =>
      _QuestionnaireResultsScreenState();
}

class _QuestionnaireResultsScreenState
    extends State<QuestionnaireResultsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  List<UserCharacter> _characters = [];
  bool _isLoading = true;
  List<bool> _modelsLoaded = []; // Track each model's loading state
  String _currentLanguage = 'en'; // Default language

  @override
  void initState() {
    super.initState();
    _loadResults();
    _loadUserLanguage();
  }

  Future<void> _loadUserLanguage() async {
    try {
      _currentLanguage = await _firestoreService.getUserLanguage();
      setState(() {});
    } catch (e) {
      print('Error loading user language: $e');
    }
  }

  Future<void> _loadResults() async {
    try {
      final characters = await _firestoreService.getUserCharacters();

      // Load user language preference
      _currentLanguage = await _firestoreService.getUserLanguage();

      if (characters.isNotEmpty) {
        // Initialize loading states
        _modelsLoaded = List.filled(characters.length, false);

        setState(() {
          _characters = characters;
        });

        // Load all models before showing anything
        await _loadAllModels(characters);

        setState(() {
          _isLoading = false;
        });
      } else {
        // If no characters found, show loading error
        setState(() {
          _isLoading = false;
          _characters = [];
        });
      }
    } catch (e) {
      print('Error loading results: $e');
      setState(() {
        _isLoading = false;
        _characters = [];
      });
    }
  }

  Future<void> _loadAllModels(List<UserCharacter> characters) async {
    // Load models sequentially to avoid overwhelming the system
    for (int i = 0; i < characters.length; i++) {
      try {
        // Get the correct GLB file name
        final glbFileName = _getGlbFileNameForCharacter(
          characters[i].characterName,
        );

        // Preload the asset
        await DefaultAssetBundle.of(context).load('assets/models/$glbFileName');

        setState(() {
          _modelsLoaded[i] = true;
        });

        // Small delay between loading each model
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        print('Failed to load model for ${characters[i].characterName}: $e');
        setState(() {
          _modelsLoaded[i] = false;
        });
      }
    }
  }

  void _goToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnaShell()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: SafeArea(
        child: _isLoading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: Color(0xFF8E7CFF)),
                    const SizedBox(height: 20),
                    Text(
                      _currentLanguage == 'ar'
                          ? 'جاري تحليل إجاباتك...'
                          : 'Analyzing your responses...',
                      style: const TextStyle(
                        color: Color(0xFF4B3A66),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              )
            : _characters.isEmpty
            ? _buildNoResultsScreen()
            : _buildContent(),
      ),
    );
  }

  Widget _buildNoResultsScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.psychology_outlined,
              size: 80,
              color: Color(0xFF8E7CFF),
            ),
            const SizedBox(height: 20),
            Text(
              _currentLanguage == 'ar' ? 'لا توجد نتائج بعد' : 'No Results Yet',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _currentLanguage == 'ar'
                  ? 'أكمل الاستبيان لرؤية شخصياتك الداخلية.'
                  : 'Complete the questionnaire to see your inner characters.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF4B3A66),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 58,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8E7CFF),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentLanguage == 'ar'
                      ? 'ابدأ الاستبيان'
                      : 'Take Questionnaire',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final isArabic = _currentLanguage == 'ar';

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              IconButton(
                icon: Icon(
                  isArabic
                      ? Icons.arrow_forward_rounded
                      : Icons.arrow_back_rounded,
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                color: const Color(0xFF6A5CFF),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isArabic ? 'شخصياتك الداخلية' : 'Your Inner Characters',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isArabic ? 'نتائج التحليل الذكي' : 'AI Analysis Results',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF6A5CFF),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Column(
              children: [
                // Introduction
                Container(
                  padding: const EdgeInsets.all(20),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8E7CFF).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF8E7CFF).withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.psychology_rounded,
                            color: Color(0xFF6A5CFF),
                            size: 24,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            isArabic
                                ? 'اكتمل التحليل الذكي'
                                : 'AI Analysis Complete',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isArabic
                            ? 'بناءً على إجاباتك في الاستبيان، إليك أهم ٣ شخصيات داخلية تم تحديدها بواسطة نموذجنا الذكي.'
                            : 'Based on your questionnaire responses, here are the 3 inner characters identified by our AI model.',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF4B3A66),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isArabic
                            ? 'عدد الأسئلة المحللة: ${_characters.isNotEmpty ? '١٣ سؤالاً' : '٠'}'
                            : 'Total answers analyzed: ${_characters.isNotEmpty ? '13 questions' : '0'}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6A5CFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

                // Characters list - all appear at once
                ..._characters.asMap().entries.map((entry) {
                  final index = entry.key;
                  final character = entry.value;
                  return _buildCharacterCard(character, index);
                }).toList(),

                const SizedBox(height: 20),

                // AI Insights Info
                Container(
                  padding: const EdgeInsets.all(16),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0ECF7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0C6E8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insights_rounded,
                        color: Color(0xFF6A5CFF),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isArabic ? 'كيف يعمل' : 'How It Works',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isArabic
                                  ? 'يقوم نموذجنا الذكي بتحليل إجاباتك لتحديد الأنماط والشخصيات الداخلية بناءً على نظرية أنظمة العائلة الداخلية.'
                                  : 'Our AI model analyzes your responses to identify patterns and inner characters based on Internal Family Systems theory.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF4B3A66),
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isArabic
                                  ? 'عدد الشخصيات المحددة: ${_characters.length}'
                                  : 'Characters identified: ${_characters.length}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6A5CFF),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // Continue button
                SizedBox(
                  width: double.infinity,
                  height: 58,
                  child: ElevatedButton(
                    onPressed: _goToHome,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E7CFF),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isArabic ? 'المتابعة إلى الرئيسية' : 'Continue to Home',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacterCard(UserCharacter character, int index) {
    final archetypeColor = _getArchetypeColor(character.archetype);
    final rankColor = _getRankColor(character.rank);
    final isArabic = _currentLanguage == 'ar';

    // Get the correct GLB file name
    final glbFileName = _getGlbFileNameForCharacter(character.characterName);

    // Get localized display name
    final displayName = _getLocalizedDisplayName(
      character.characterName,
      character.displayName,
    );

    // Get localized description
    final description = _getLocalizedDescription(
      character.characterName,
      character.description,
    );

    // Create updated character with localized data
    final updatedCharacter = UserCharacter(
      id: character.id,
      userId: character.userId,
      characterName: character.characterName,
      displayName: displayName,
      archetype: character.archetype,
      confidence: character.confidence,
      rank: character.rank,
      language: _currentLanguage,
      glbFileName: glbFileName,
      description: description,
      predictedAt: character.predictedAt,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Top row with rank and archetype badges
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Rank badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: rankColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '#${character.rank}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),

              // Archetype badge
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: archetypeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: archetypeColor),
                ),
                child: Text(
                  _getLocalizedArchetype(character.archetype),
                  style: TextStyle(
                    color: archetypeColor,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Character name
          Text(
            updatedCharacter.displayName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
            textAlign: TextAlign.center,
          ),

          const SizedBox(height: 8),

          // Confidence percentage
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.psychology_rounded,
                  size: 20,
                  color: Color(0xFF8E7CFF),
                ),
                const SizedBox(width: 8),
                Text(
                  isArabic
                      ? 'دقة الذكاء الاصطناعي: ${(character.confidence * 100).toStringAsFixed(1)}%'
                      : 'AI Confidence: ${(character.confidence * 100).toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF6A5CFF),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 3D Model Viewer
          Container(
            height: 250,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFF5F2FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: _build3DModelViewer(updatedCharacter, index),
          ),

          const SizedBox(height: 16),

          // Character description only (removed other sections)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF9F6FF),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Column(
              crossAxisAlignment: isArabic
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Text(
                  isArabic ? 'الوصف:' : 'Description:',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  updatedCharacter.description,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF4B3A66),
                    height: 1.6,
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Role explanation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5DEFF)),
            ),
            child: Column(
              crossAxisAlignment: isArabic
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: isArabic
                      ? MainAxisAlignment.end
                      : MainAxisAlignment.start,
                  children: [
                    if (!isArabic)
                      Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: archetypeColor,
                      ),
                    if (!isArabic) const SizedBox(width: 8),
                    Text(
                      isArabic ? 'دوره في حياتك:' : 'Role in Your Life:',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6A5CFF),
                      ),
                    ),
                    if (isArabic) const SizedBox(width: 8),
                    if (isArabic)
                      Icon(
                        Icons.shield_rounded,
                        size: 18,
                        color: archetypeColor,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  _getLocalizedRoleExplanation(character.archetype),
                  style: const TextStyle(
                    color: Color(0xFF7A6A5A),
                    fontSize: 15,
                    height: 1.5,
                  ),
                  textAlign: isArabic ? TextAlign.right : TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _build3DModelViewer(UserCharacter character, int index) {
    final isArabic = _currentLanguage == 'ar';

    // Check if model is loaded
    if (index >= _modelsLoaded.length || !_modelsLoaded[index]) {
      return _buildModelLoadingPlaceholder(character, isArabic);
    }

    try {
      // Get camera settings for specific character
      final cameraSettings = _getCameraSettingsForCharacter(
        character.characterName,
      );

      return ModelViewer(
        src: 'assets/models/${character.glbFileName}',
        alt: character.displayName,
        ar: false,
        autoRotate: false,
        cameraControls: true,
        backgroundColor: const Color(0xFFF5F2FF),
        loading: Loading.eager,
        reveal: Reveal.auto,
        // Disable zooming and panning, only allow rotation
        disableZoom: true,
        disablePan: true,
        touchAction: TouchAction.none,
        // Use character-specific camera settings
        cameraOrbit: cameraSettings['orbit'],
        fieldOfView: cameraSettings['fov'],
        // Lock vertical movement - only allow horizontal rotation
        minCameraOrbit: cameraSettings['minOrbit'],
        maxCameraOrbit: cameraSettings['maxOrbit'],
        minFieldOfView: cameraSettings['minFov'],
        maxFieldOfView: cameraSettings['maxFov'],
        // Fix camera target to center (adjust per model if needed)
        cameraTarget: cameraSettings['target'],
        // iOS specific
        iosSrc: 'assets/models/${character.glbFileName}',
      );
    } catch (e) {
      print('Model viewer error: $e');
      return _buildModelPlaceholder(character, isArabic);
    }
  }

  // Add this helper method to get camera settings per character
  Map<String, String> _getCameraSettingsForCharacter(String characterName) {
    // Default settings that work for most models
    final defaultSettings = {
      'orbit': '0deg 75deg 2.5m',
      'fov': '45deg',
      'minOrbit': '-Infinity 75deg 2m',
      'maxOrbit': 'Infinity 75deg 3m',
      'minFov': '35deg',
      'maxFov': '50deg',
      'target': '0m 0m 0m',
    };

    // Custom settings for specific models that need adjustment
    switch (characterName) {
      // Models that appear too high - adjust target Y downwards
      case 'People Pleaser':
      case 'Lonely Part':
      case 'Jealous Part':
      case 'Workaholic':
      case 'Perfectionist':
      case 'Procrastinator':
      case 'Excessive Gamer':
      case 'Confused Part':
      case 'Dependent Part':
      case 'Fearful Part':
      case 'Neglected Part':
      case 'Overeater':
      case 'Binger':
      case 'Overeater/Binger':
      case 'Overwhelmed Part':
      case 'Stoic Part':
      case 'Wounded Child':
      case 'Controller':
      case 'Controller Part':
        return {
          'orbit': '0deg 75deg 2m',
          'fov': '45deg',
          'minOrbit': '-Infinity 75deg 2.5m',
          'maxOrbit': 'Infinity 75deg 3m',
          'minFov': '35deg',
          'maxFov': '50deg',
          'target': '0m 1m 0m',
        };

      // Models that appear too low - adjust target Y upwards
      // (If you have any that appear too low)

      // Models that appear too far - adjust orbit distance
      case 'Inner Critic':
      case 'Ashamed Part':
        return {
          'orbit': '0deg 75deg 2m', // Closer distance
          'fov': '45deg',
          'minOrbit': '-Infinity 75deg 1.5m',
          'maxOrbit': 'Infinity 75deg 2.5m',
          'minFov': '35deg',
          'maxFov': '50deg',
          'target': '0m 0m 0m',
        };

      // Models that need wider field of view
      case 'Some Wide Model':
        return {
          'orbit': '0deg 75deg 3m',
          'fov': '60deg',
          'minOrbit': '-Infinity 75deg 2m',
          'maxOrbit': 'Infinity 75deg 4m',
          'minFov': '40deg',
          'maxFov': '70deg',
          'target': '0m 0m 0m',
        };

      default:
        return defaultSettings;
    }
  }

  Widget _buildModelLoadingPlaceholder(UserCharacter character, bool isArabic) {
    final archetypeColor = _getArchetypeColor(character.archetype);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            archetypeColor.withOpacity(0.05),
            archetypeColor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: Color(0xFF8E7CFF)),
            const SizedBox(height: 16),
            Text(
              isArabic
                  ? 'جاري تحميل ${character.displayName}...'
                  : 'Loading ${character.displayName}...',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: archetypeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModelPlaceholder(UserCharacter character, bool isArabic) {
    final archetypeColor = _getArchetypeColor(character.archetype);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            archetypeColor.withOpacity(0.05),
            archetypeColor.withOpacity(0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _getCharacterIcon(character.archetype),
              size: 60,
              color: archetypeColor.withOpacity(0.4),
            ),
            const SizedBox(height: 12),
            Text(
              character.displayName,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: archetypeColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isArabic ? 'نموذج شخصية ثلاثي الأبعاد' : '3D Character Model',
              style: TextStyle(fontSize: 14, color: const Color(0xFF7A6A5A)),
            ),
          ],
        ),
      ),
    );
  }

  // Localization Helper Methods

  String _getLocalizedDisplayName(
    String englishName,
    String currentDisplayName,
  ) {
    if (_currentLanguage != 'ar') return currentDisplayName;

    // Map English character names to Arabic
    final arabicNames = {
      'Inner Critic': 'الناقد',
      'Perfectionist': 'الكمالي',
      'People Pleaser': 'المرضي',
      'Controller': 'المتحكم',
      'Stoic Part': 'البارد',
      'Workaholic': 'مدمن الشغل',
      'Confused Part': 'الحيران',
      'Procrastinator': 'المؤجل',
      'Overeater': 'الآكل',
      'Binger': 'الآكل',
      'Overeater/Binger': 'الآكل',
      'Excessive Gamer': 'اللاعب',
      'Lonely Part': 'الوحيد',
      'Fearful Part': 'الخايف',
      'Neglected Part': 'المهمل',
      'Ashamed Part': 'الخجول',
      'Overwhelmed Part': 'المرهق',
      'Dependent Part': 'المعتمد',
      'Jealous Part': 'الغيور',
      'Wounded Child': 'الطفل الجريح',
    };

    return arabicNames[englishName] ?? currentDisplayName;
  }

  String _getLocalizedDescription(
    String characterName,
    String currentDescription,
  ) {
    if (_currentLanguage != 'ar') return currentDescription;

    // Arabic descriptions for characters
    final arabicDescriptions = {
      'Inner Critic':
          'هذا الصوت الداخلي يُقيّم أفعالك باستمرار، مشيراً إلى العيوب والأخطاء لمنع الفشل. بينما يهدف إلى حمايتك من خلال الحفاظ على معايير عالية، إلا أنه غالباً ما يظهر كحكم ذاتي قاسٍ يمكن أن يقوّض ثقتك بنفسك.',
      'People Pleaser':
          'هذا الجزء يُعطي أولوية لاحتياجات الآخرين فوق احتياجاتك الخاصة، يسعى للحصول على الموافقة وتجنب الصراع بأي ثمن. يعمل على الحفاظ على الانسجام في العلاقات ولكنه قد يؤدي إلى كبت مشاعرك الحقيقية وإهمال الحدود الشخصية.',
      'Lonely Part':
          'هذا الجزء يحمل مشاعر عميقة بالعزلة والشوق للتواصل العميق. يحتفظ بذكريات المسافة العاطفية ويتوق لرفقة مفهمة، وغالباً ما يظهر عندما تشعر بالانفصال عن الآخرين.',
      'Jealous Part':
          'هذا الجزء الواقي يظهر عندما ترى الآخرين كتهديد لعلاقاتك أو نجاحك. يشير إلى احتياجات غير مُلباة للأمان والتقدير، ويهدف لحماية ما تقدّره ولكنّه أحياناً يخلق مسافة.',
      'Ashamed Part':
          'هذا الجزء الجريح يحمل مشاعر عميقة بعدم الاستحقاق والوعي الذاتي من تجارب سابقة. يخفي جوانب من نفسك يراها غير مقبولة، ويعمل على حمايتك من الحكم مع تقييد التعبير الحقيقي.',
      'Workaholic':
          'هذا الجزء يُبقيك مشغولاً ومنتجاً باستمرار كوسيلة لتجنب مواجهة المشاعر الصعبة أو الفراغ الداخلي. يستخدم الإنجاز كدرع ضد الضعف، مما يؤدي غالباً إلى الإنهاك وإهمال الاحتياجات الشخصية.',
      'Perfectionist':
          'هذا الجزء يطالب بالكمال في كل ما تفعله، معتقداً أن الأداء المثالي سيمنع الانتقاد ويضمن القبول. بينما يهدف إلى التميز، إلا أنه غالباً ما يخلق معايير غير واقعية تسبب القلق والتسويف.',
      'Procrastinator':
          'هذا الجزء الواقي يُؤجل المهام المهمة لتجنب الفشل المحتمل أو الإرهاق أو مواجهة المشاعر الصعبة. يوفر راحة مؤقتة ولكنه يزيد الضغط في النهاية ويقوّض إحساسك بالقدرة.',
      'Excessive Gamer':
          'هذا الجزء يستخدم الألعاب كهروب من تحديات العالم الحقيقي، أو المشاعر غير المريحة، أو مشاعر النقص. يوفر إشباعاً فورياً وسيطرة في عالم افتراضي مع إهمال المسؤوليات الحياتية.',
      'Confused Part':
          'هذا الجزء يظهر عندما تشعر بالإرهاق من الخيارات، أو عدم اليقين بشأن القرارات، أو الانفصال عن حدسك. يمثل قلق عدم معرفة المسار "الصحيح" ويسعى للوضوح وسط عدم اليقين.',
      'Dependent Part':
          'هذا الجزء يخاف من الاستقلالية ويسعى باستمرار للتحقق الخارجي والدعم. يقلق بشأن اتخاذ القرارات بشكل مستقل ويعتمد بشدة على موافقة الآخرين، مما يحد من تطوير الثقة بالنفس.',
      'Fearful Part':
          'هذا الواقي اليقظ يمسح باستمرار للبحث عن التهديدات والمخاطر المحتملة. يهدف إلى إبقائك آمناً من خلال توقع المشاكل ولكن يمكن أن يصبح مفرط اليقظة، مما يخلق قلقاً بشأن مواقف قد لا تحدث أبداً.',
      'Neglected Part':
          'هذا الجزء الجريح يحتفظ بذكريات الإهمال، أو عدم الاستماع، أو الهجر العاطفي. يحمل ألم الاحتياجات غير الملباة في الطفولة ويسعى للاعتراف والرعاية التي لم يتلقاها.',
      'Overeater/Binger':
          'هذا الجزء يستخدم الطعام لتهدئة الألم العاطفي، أو ملء الفراغ الداخلي، أو تخدير المشاعر الصعبة. يوفر راحة مؤقتة ولكن غالباً ما يؤدي إلى دورات من الذنب والمزيد من الأكل العاطفي.',
      'Overwhelmed Part':
          'هذا الجزء يشعر بعدم القدرة على التعامل مع مطالب ومسؤوليات الحياة. يمثل إرهاق محاولة إدارة كل شيء ويحتاج إلى دعم في وضع الحدود وتحديد أولويات الرعاية الذاتية.',
      'Stoic Part':
          'هذا الواقي يكبت المشاعر ويحافظ على المسافة العاطفية كاستراتيجية بقاء. يعتقد أن إظهار الضعف خطير ويخلق مظهراً خارجياً متحكماً بينما تظل المشاعر الداخلية غير معالجة.',
      'Wounded Child':
          'هذا الجزء الضعيف يحمل ألم الطفولة، والصدمة، والاحتياجات العاطفية غير الملباة. يحتفظ بالبراءة التي أُذيَت ويحتاج إلى اهتمام عطوف للشفاء والشعور بالأمان مرة أخرى.',
      'Controller Part':
          'هذا الجزء يحاول إدارة كل شيء وكل شخص لخلق إحساس بالأمان والقابلية للتنبؤ. يخاف من الفوضى وفقدان السيطرة، ويعمل بلا كلل للحفاظ على النظام ولكنه غالباً ما يخلق جموداً.',
    };

    return arabicDescriptions[characterName] ??
        'تلعب هذه الشخصية الداخلية دوراً مهماً في مشهدك العاطفي. ظهرت كآلية وقائية خلال تجارب صعبة وتستمر في التأثير على كيفية تنقلك في العلاقات، والتحديات، وتصور الذات. فهم هذا الجزء بالتعاطف يمكن أن يساعدك في دمج نواياه الوقائية مع إيجاد طرق أكثر توازناً لتلبية احتياجاتك.';
  }

  String _getLocalizedArchetype(String archetype) {
    if (_currentLanguage != 'ar') return archetype.toUpperCase();

    switch (archetype.toLowerCase()) {
      case 'manager':
        return 'المدير';
      case 'firefighter':
        return 'المطفي';
      case 'exile':
        return 'المنفي';
      default:
        return archetype.toUpperCase();
    }
  }

  String _getLocalizedRoleExplanation(String archetype) {
    if (_currentLanguage != 'ar') {
      return _getRoleExplanation(archetype);
    }

    switch (archetype.toLowerCase()) {
      case 'manager':
        return 'هذا الواقي الاستباقي يحاول منع المشاعر المؤلمة من خلال السيطرة على المواقف، أو الأشخاص، أو نفسك. يعمل على إبقائك آمناً من خلال توقع المشاكل والحفاظ على السيطرة.';
      case 'firefighter':
        return 'هذا الواقي التفاعلي يقفز لإطفاء الحرائق العاطفية من خلال التشتيت أو التخدير. عندما تنشأ مشاعر شديدة، يتصرف بسرعة لتهدئة العاصفة العاطفية.';
      case 'exile':
        return 'هذا الجزء الجريح يحمل الألم، أو الخوف، أو الخجل من تجارب سابقة ويحتاج إلى تعاطف. يحمل أعباء عاطفية من أوقات سابقة في حياتك.';
      default:
        return 'يلعب هذا الجزء دوراً مهماً في نظامك الداخلي، ويعمل على حمايتك والحفاظ على التوازن في عالمك العاطفي.';
    }
  }

  // Helper Methods

  String _getGlbFileNameForCharacter(String characterName) {
    // Map character names to GLB files based on your assets
    final glbMap = {
      'Inner Critic': 'inner_critic.glb',
      'People Pleaser': 'people_pleaser.glb',
      'Lonely Part': 'lonely_part.glb',
      'Jealous Part': 'jealous_part.glb',
      'Ashamed Part': 'ashamed_part.glb',
      'Workaholic': 'workaholic.glb',
      'Perfectionist': 'perfectionist.glb',
      'Procrastinator': 'procastinator.glb',
      'Excessive Gamer': 'excessive_gamer.glb',
      'Confused Part': 'confused_part.glb',
      'Dependent Part': 'dependent_part.glb',
      'Fearful Part': 'fearful_part.glb',
      'Neglected Part': 'neglected_part.glb',
      'Overeater': 'overeater-binger.glb',
      'Binger': 'overeater-binger.glb',
      'Overeater/Binger': 'overeater-binger.glb',
      'Overwhelmed Part': 'overwhelmed_part.glb',
      'Stoic Part': 'stoic_part.glb',
      'Wounded Child': 'wounded_child.glb',
      'Controller': 'controller_part.glb',
      'Controller Part': 'controller_part.glb',
    };

    // Try to find the character in the map
    if (glbMap.containsKey(characterName)) {
      return glbMap[characterName]!;
    }

    // If character not found, try to find a close match
    final lowerName = characterName.toLowerCase();
    for (final entry in glbMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return entry.value;
      }
    }

    // Fallback to a default model
    print('⚠️ No GLB file found for character: $characterName');
    return 'inner_critic.glb'; // Default fallback
  }

  IconData _getCharacterIcon(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return Icons.gavel_rounded;
      case 'firefighter':
        return Icons.local_fire_department_rounded;
      case 'exile':
        return Icons.self_improvement_rounded;
      default:
        return Icons.psychology_rounded;
    }
  }

  Color _getArchetypeColor(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return const Color(0xFF4A6FA5);
      case 'firefighter':
        return const Color(0xFFD9534F);
      case 'exile':
        return const Color(0xFF5CB85C);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  String _getRoleExplanation(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return 'This proactive protector tries to prevent painful feelings by controlling situations, people, or yourself. It works to keep you safe by anticipating problems and maintaining control.';
      case 'firefighter':
        return 'This reactive protector jumps in to extinguish emotional fires through distraction or numbing. When intense feelings arise, it acts quickly to calm the emotional storm.';
      case 'exile':
        return 'This wounded part holds pain, fear, or shame from past experiences and needs compassion. It carries emotional burdens from earlier times in your life.';
      default:
        return 'This part plays an important role in your inner system, working to protect you and maintain balance in your emotional world.';
    }
  }
}
