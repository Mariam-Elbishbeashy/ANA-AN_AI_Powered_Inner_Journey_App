import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/home/presentation/screens/home_screen.dart';

import '../../../character/domain/entities/user_character.dart';

enum _ReframeMode { chat, voice, video }
enum _UsedInputType { none, text, voice, video }

class ReframeScreen extends StatefulWidget {
  final String name;
  final VoidCallback onLogout;
  final VoidCallback onRetakeQuestionnaire;
  final VoidCallback? onSwitchLanguage;
  final String serverUrl;
  final VoidCallback? onNavigateToHome;

  const ReframeScreen({
    super.key,
    required this.name,
    required this.onLogout,
    required this.onRetakeQuestionnaire,
    this.onSwitchLanguage,
    this.serverUrl = 'http://10.0.2.2:5000',
    this.onNavigateToHome,
  });

  @override
  State<ReframeScreen> createState() => _ReframeScreenState();
}

class _ReframeScreenState extends State<ReframeScreen> with WidgetsBindingObserver {
  _ReframeMode _mode = _ReframeMode.chat;
  final TextEditingController _chatController = TextEditingController();
  bool _voiceRecording = false;
  bool _isAnalyzing = false;
  Map<String, dynamic> _analysisResult = {};
  String? _audioFilePath;
  String? _videoFilePath;
  final AudioRecorder _audioRecorder = AudioRecorder();
  List<CameraDescription>? _cameras;
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _videoRecording = false;
  final ScrollController _scrollController = ScrollController();

  // Track character counts
  int _healedCharacterCount = 0;
  int _unhealedCharacterCount = 0;

  // Track which input type has been used
  _UsedInputType _usedInputType = _UsedInputType.none;

  // Audio recording for video mode
  bool _videoAudioRecording = false;
  String? _videoAudioFilePath;
  final AudioRecorder _videoAudioRecorder = AudioRecorder();

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String? _currentUserId;
  bool _hasActiveSession = false;
  DateTime? _sessionStartTime;

  // High confidence threshold
  final double _highConfidenceThreshold = 0.75;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentUser();
    _testServerConnection();
    _chatController.addListener(_handleTextChange);

    // Check for characters after getting current user
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future.delayed(const Duration(milliseconds: 500));
      await _checkForHealedCharacters();

      // // Check if user should be restricted from accessing this screen
      // if (_shouldRestrictAccess() && mounted) {
      //   _showRestrictedAccessDialog();
      // }
    });
  }

  // Check if user has 3 or more unhealed characters
  bool _shouldRestrictAccess() {
    return _unhealedCharacterCount >= 3;
  }

  // Check character counts from database
  Future<void> _checkForHealedCharacters() async {
    try {
      if (_currentUserId == null) return;

      // Query for ALL user characters
      final querySnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      int healedCount = 0;
      int unhealedCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final isHealed = data['isHealed'] == true;
        if (isHealed) {
          healedCount++;
        } else {
          unhealedCount++;
        }
      }

      setState(() {
        _healedCharacterCount = healedCount;
        _unhealedCharacterCount = unhealedCount;
      });

      print('📊 Character Stats: $healedCount healed, $unhealedCount unhealed');

      if (unhealedCount >= 3) {
        print('⚠️ User has 3+ unhealed characters - restricting access to Reframe');
      }

    } catch (e) {
      print('❌ Error checking characters: $e');
      setState(() {
        _healedCharacterCount = 0;
        _unhealedCharacterCount = 0;
      });
    }
  }

  // Show restricted access dialog
  void _showRestrictedAccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: true, // Allow tapping outside to close
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button at top right
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            const SizedBox(height: 8),

            // Lock icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF8E7CFF).withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lock_outline,
                size: 40,
                color: Color(0xFF8E7CFF),
              ),
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              tr(context,  "Continue Your Healing Journey",  // English version
                "استمر في رحلة شفائك"),
                textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),

            const SizedBox(height: 16),

            // Message
            Text(
              tr(context,
                  "To ensure each inner part receives the care it deserves, we gently pause new discoveries. You have $_unhealedCharacterCount parts awaiting your attention - nurturing them will renew your capacity for insight.",
                  "لضمان حصول كل جزء داخلي على الرعاية التي يستحقها، نتوقف بلطف عن الاكتشافات الجديدة. لديك $_unhealedCharacterCount جزءًا تنتظر اهتمامك - رعايتها ستعيد تجديد قدرتك على البصيرة."    ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4B3A66),
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Save high confidence characters to user collection
  Future<void> _saveHighConfidenceCharacters(Map<String, dynamic> analysisResult) async {
    try {
      if (_currentUserId == null) {
        print('❌ No user ID available');
        return;
      }

      final List<dynamic> innerCharacters = analysisResult['inner_characters'] ?? [];
      final String detectedLanguage = analysisResult['detected_language'] ?? 'english';

      // Filter characters with high confidence
      final highConfidenceCharacters = innerCharacters.where((character) {
        final confidence = (character['confidence'] ?? 0.0) as double;
        return confidence >= _highConfidenceThreshold;
      }).toList();

      if (highConfidenceCharacters.isEmpty) {
        print('ℹ️ No characters meet the high confidence threshold');
        return;
      }

      print('✅ Found ${highConfidenceCharacters.length} high confidence characters to save');

      // Sort characters by confidence in descending order
      highConfidenceCharacters.sort((a, b) {
        final confA = (a['confidence'] ?? 0.0) as double;
        final confB = (b['confidence'] ?? 0.0) as double;
        return confB.compareTo(confA);
      });

      // Get existing user characters to determine the next rank
      final existingCharacters = await _getUserCharacters();
      int maxRank = 0;
      for (final character in existingCharacters) {
        if (character.rank > maxRank) {
          maxRank = character.rank;
        }
      }
      int nextRank = maxRank + 1;

      print('📊 Existing characters: ${existingCharacters.length}, Max rank: $maxRank, Next rank: $nextRank');

      final batch = _firestore.batch();
      final timestamp = DateTime.now();

      // Save each high confidence character with sequential ranks
      for (int i = 0; i < highConfidenceCharacters.length; i++) {
        final character = highConfidenceCharacters[i];
        final characterName = character['character']?.toString() ?? 'Unknown';
        final displayName = character['character_name']?.toString() ?? characterName;
        final confidence = (character['confidence'] ?? 0.0) as double;
        final rank = nextRank + i;

        final archetype = _determineArchetype(characterName);
        final characterDocRef = _firestore.collection('user_characters').doc();
        final characterId = characterDocRef.id;
        final description = _getCharacterDescription(characterName, detectedLanguage);
        final glbFileName = _getGLBFileName(characterName);

        final userCharacter = UserCharacter(
          id: characterId,
          userId: _currentUserId!,
          characterName: characterName,
          displayNameEn: displayName,
          displayNameAr: displayName,
          archetype: archetype,
          confidence: confidence,
          rank: rank,
          language: detectedLanguage,
          glbFileName: glbFileName,
          descriptionEn: description,
          descriptionAr: description,
          predictedAt: timestamp,
          isHealed: false,
          healedAt: null,
        );

        batch.set(characterDocRef, userCharacter.toMap());

        print('📝 Saving character: $characterName (Rank: $rank, ${(confidence * 100).toStringAsFixed(1)}%)');
      }

      await batch.commit();

      print('✅ Successfully saved ${highConfidenceCharacters.length} high confidence characters');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context,
                  '${highConfidenceCharacters.length} inner characters added to your collection!',
                  'تم إضافة ${highConfidenceCharacters.length} من الشخصيات الداخلية إلى مجموعتك!'
              ),
            ),
            backgroundColor: const Color(0xFF8E7CFF),
            duration: const Duration(seconds: 3),
          ),
        );
      }

    } catch (e) {
      print('❌ Error saving high confidence characters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context,
                  'Error saving characters to collection',
                  'حدث خطأ في حفظ الشخصيات إلى المجموعة'
              ),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper method to get existing user characters
  Future<List<UserCharacter>> _getUserCharacters() async {
    try {
      if (_currentUserId == null) return [];

      final querySnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      final characters = querySnapshot.docs.map((doc) {
        return UserCharacter.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

      print('🔍 Found ${characters.length} existing characters for user:');
      for (final character in characters) {
        print('   - ${character.displayNameEn} (Rank: ${character.rank}, ID: ${character.id})');
      }

      return characters;
    } catch (e) {
      print('❌ Error getting user characters: $e');
      return [];
    }
  }

  // Helper method to determine archetype
  String _determineArchetype(String characterName) {
    final lowerName = characterName.toLowerCase();

    if (lowerName.contains('critic') ||
        lowerName.contains('perfectionist') ||
        lowerName.contains('workaholic') ||
        lowerName.contains('controller')) {
      return 'manager';
    } else if (lowerName.contains('procrastinator') ||
        lowerName.contains('gamer') ||
        lowerName.contains('overeater') ||
        lowerName.contains('binger')) {
      return 'firefighter';
    } else if (lowerName.contains('lonely') ||
        lowerName.contains('jealous') ||
        lowerName.contains('ashamed') ||
        lowerName.contains('wounded') ||
        lowerName.contains('fearful') ||
        lowerName.contains('neglected') ||
        lowerName.contains('overwhelmed') ||
        lowerName.contains('confused')) {
      return 'exile';
    }

    return 'exile';
  }

  // Helper method to get character description
  String _getCharacterDescription(String characterName, String language) {
    final descriptions = {
      'english': {
        'Inner Critic': 'The voice of self-judgment and high standards. Often pushes for perfection but can be harsh.',
        'People Pleaser': 'Seeks approval and validation from others, often at the expense of personal needs.',
        'Lonely Part': 'Feels isolated and disconnected, longing for connection and belonging.',
        'Jealous Part': 'Experiences envy and comparison, often feeling inadequate next to others.',
        'Ashamed Part': 'Carries feelings of shame and unworthiness, often hiding from others.',
        'Workaholic': 'Uses work to avoid feelings, often leading to burnout and imbalance.',
        'Perfectionist': 'Driven by fear of failure, seeks flawlessness in all endeavors.',
        'Procrastinator': 'Avoids tasks and decisions, often due to fear or overwhelm.',
        'Excessive Gamer': 'Escapes reality through gaming, often to avoid emotional discomfort.',
        'Confused Part': 'Feels uncertain and indecisive, struggling with clarity and direction.',
        'Dependent Part': 'Relies heavily on others for validation, decisions, and emotional support.',
        'Fearful Part': 'Experiences anxiety and worry, often anticipating negative outcomes.',
        'Neglected Part': 'Feels unseen and unheard, craving attention and care.',
        'Overeater': 'Uses food for comfort or distraction from emotional pain.',
        'Binger': 'Engages in compulsive behaviors to numb or escape feelings.',
        'Overwhelmed Part': 'Feels burdened by responsibilities and emotions, struggling to cope.',
        'Stoic Part': 'Suppresses emotions and maintains emotional distance as protection.',
        'Wounded Child': 'Carries childhood pain and trauma, often feeling vulnerable and hurt.',
        'Controller': 'Seeks to control situations and people to feel safe and secure.',
      },
      'arabic': {
        'Inner Critic': 'صوت الحكم الذاتي والمعايير العالية. غالبًا ما يدفع نحو الكمال ولكن يمكن أن يكون قاسيًا.',
        'People Pleaser': 'يسعى للحصول على الموافقة والتصديق من الآخرين، غالبًا على حساب الاحتياجات الشخصية.',
        'Lonely Part': 'يشعر بالعزلة والانفصال، يتوق للاتصال والانتماء.',
        'Jealous Part': 'يشعر بالحسد والمقارنة، غالبًا ما يشعر بعدم الكفاءة بجانب الآخرين.',
        'Ashamed Part': 'يحمل مشاعر الخزي وعدم الاستحقاق، غالبًا ما يختبئ من الآخرين.',
        'Workaholic': 'يستخدم العمل لتجنب المشاعر، مما يؤدي غالبًا إلى الإرهاق وعدم التوازن.',
        'Perfectionist': 'مدفوع بخشية الفشل، يسعى للكمال في جميع المساعي.',
        'Procrastinator': 'يتجنب المهام والقرارات، غالبًا بسبب الخوف أو الإرهاق.',
        'Excessive Gamer': 'يهرب من الواقع عبر الألعاب، غالبًا لتجنب الانزعاج العاطفي.',
        'Confused Part': 'يشعر بعدم اليقين والتردد، يكافح من أجل الوضوح والاتجاه.',
        'Dependent Part': 'يعتمد بشدة على الآخرين للتصديق، القرارات، والدعم العاطفي.',
        'Fearful Part': 'يشعر بالقلق والخوف، غالبًا يتوقع النتائج السلبية.',
        'Neglected Part': 'يشعر بأنه غير مرئي وغير مسموع، يتوق للاهتمام والرعاية.',
        'Overeater': 'يستخدم الطعام للراحة أو التشتيت من الألم العاطفي.',
        'Binger': 'ينخرط في سلوكيات قهرية لتخدير أو الهروب من المشاعر.',
        'Overwhelmed Part': 'يشعر بالإرهاق من المسؤوليات والمشاعر، يكافح للتكيف.',
        'Stoic Part': 'يكبح المشاعر ويحافظ على المسافة العاطفية كحماية.',
        'Wounded Child': 'يحمل ألم وصدمة الطفولة، غالبًا ما يشعر بالضعف والأذى.',
        'Controller': 'يسعى للتحكم في المواقف والأشخاص ليشعر بالأمان والأمن.',
      }
    };

    final lang = language.toLowerCase().contains('arabic') ? 'arabic' : 'english';
    final langDescriptions = descriptions[lang] ?? descriptions['english']!;

    return langDescriptions[characterName] ??
        'An inner part that has been identified through reflection. This part holds emotions, beliefs, or patterns that influence your thoughts and behaviors.';
  }

  // Helper method to get GLB file name
  String _getGLBFileName(String characterName) {
    final fileMap = {
      'Inner Critic': 'inner_critic.glb',
      'People Pleaser': 'people_pleaser.glb',
      'Lonely Part': 'lonely_part.glb',
      'Jealous Part': 'jealous_part.glb',
      'Ashamed Part': 'ashamed_part.glb',
      'Workaholic': 'workaholic.glb',
      'Perfectionist': 'perfectionist.glb',
      'Procrastinator': 'procrastinator.glb',
      'Excessive Gamer': 'excessive_gamer.glb',
      'Confused Part': 'confused_part.glb',
      'Dependent Part': 'dependent_part.glb',
      'Fearful Part': 'fearful_part.glb',
      'Neglected Part': 'neglected_part.glb',
      'Overeater': 'overeater.glb',
      'Binger': 'binger.glb',
      'Overwhelmed Part': 'overwhelmed_part.glb',
      'Stoic Part': 'stoic_part.glb',
      'Wounded Child': 'wounded_child.glb',
      'Controller': 'controller.glb',
    };

    return fileMap[characterName] ?? 'default_character.glb';
  }

  Future<void> _getCurrentUser() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      setState(() {
        _currentUserId = user?.uid;
      });
      print('👤 Current user ID: $_currentUserId');

      if (_currentUserId != null) {
        await _checkForActiveSession();
      }
    } catch (e) {
      print('❌ Error getting current user: $e');
    }
  }

  Future<void> _checkForActiveSession() async {
    try {
      final querySnapshot = await _firestore
          .collection('reframe_sessions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final doc = querySnapshot.docs.first;
        final data = doc.data();
        final timestamp = data['timestamp'] as Timestamp?;
        final createdAt = data['createdAt'] as String?;

        if (timestamp != null) {
          _sessionStartTime = timestamp.toDate();
        } else if (createdAt != null) {
          _sessionStartTime = DateTime.parse(createdAt);
        }

        setState(() {
          _hasActiveSession = true;
        });

        if (_sessionStartTime != null) {
          final now = DateTime.now();
          final difference = now.difference(_sessionStartTime!);
          if (difference.inHours >= 24) {
            await _deactivateSession(doc.id);
            setState(() {
              _hasActiveSession = false;
              _sessionStartTime = null;
            });
            return;
          }
        }

        _showActiveSessionDialog();
      } else {
        setState(() {
          _hasActiveSession = false;
          _sessionStartTime = null;
        });
      }
    } catch (e) {
      print('❌ Error checking active session: $e');
    }
  }

  Future<void> _deactivateSession(String sessionId) async {
    try {
      await _firestore
          .collection('reframe_sessions')
          .doc(sessionId)
          .update({'isActive': false});
      print('✅ Session deactivated after 24 hours');
    } catch (e) {
      print('❌ Error deactivating session: $e');
    }
  }

  void _handleTextChange() {
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _recheckPermissions();
    }
  }

  void _recheckPermissions() async {
    try {
      if (_mode == _ReframeMode.video) {
        final cameraStatus = await Permission.camera.status;
        if (cameraStatus.isGranted && !_isCameraInitialized) {
          await _initializeCamera();
        }
      }
    } catch (e) {
      print('Error rechecking permissions: $e');
    }
  }

  void _testServerConnection() async {
    try {
      final response = await http.get(
        Uri.parse('${widget.serverUrl}/api/health'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print('✅ Server connection successful');
      } else {
        print('⚠ Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Server connection failed: $e');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameraStatus = await Permission.camera.status;
      if (!cameraStatus.isGranted) {
        final newStatus = await Permission.camera.request();
        if (!newStatus.isGranted) {
          return;
        }
      }

      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
            (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
      }
    } catch (e) {
      print('Camera initialization error: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    if (_cameraController != null) {
      await _cameraController!.dispose();
      _cameraController = null;
    }
    setState(() {
      _isCameraInitialized = false;
    });
  }

  // Helper function to detect language from text
  String _detectLanguage(String text) {
    if (text.isEmpty) return 'english';

    final arabicPattern = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    if (arabicPattern.hasMatch(text)) {
      final egyPatterns = ['ده', 'دي', 'اللي', 'عشان', 'ايه', 'ماشي', 'احنا'];
      for (final pattern in egyPatterns) {
        if (text.contains(pattern)) {
          return 'egyptian';
        }
      }
      return 'arabic';
    }
    return 'english';
  }

  // Save to database
  Future<void> _saveToDatabase({
    required String inputType,
    required String transcript,
    required String language,
    required Map<String, dynamic> analysisResult,
    String? audioFilePath,
    String? videoFilePath,
  }) async {
    try {
      if (_currentUserId == null) return;

      final activeSessions = await _firestore
          .collection('reframe_sessions')
          .where('userId', isEqualTo: _currentUserId)
          .where('isActive', isEqualTo: true)
          .get();

      final batch = _firestore.batch();
      for (final doc in activeSessions.docs) {
        batch.update(doc.reference, {'isActive': false});
      }
      await batch.commit();

      final sessionData = {
        'userId': _currentUserId!,
        'inputType': inputType,
        'transcript': transcript,
        'language': language,
        'analysisResult': analysisResult,
        'audioFilePath': audioFilePath,
        'videoFilePath': videoFilePath,
        'timestamp': FieldValue.serverTimestamp(),
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'primaryCharacter': analysisResult['primary_character'] ?? 'Unknown',
        'confidence': analysisResult['confidence'] ?? 0.0,
        'characterName': analysisResult['character_name'] ?? '',
      };

      await _firestore.collection('reframe_sessions').add(sessionData);

      setState(() {
        _hasActiveSession = true;
        _sessionStartTime = DateTime.now();
      });

      print('✅ Reframe session saved to database');
    } catch (e) {
      print('❌ Error saving to database: $e');
    }
  }

  // Text Analysis
  Future<void> _analyzeText() async {
    // Check if user already has active session
    if (_hasActiveSession && _usedInputType == _UsedInputType.none) {
      _showActiveSessionDialog();
      return;
    }

    if (_chatController.text.trim().isEmpty) {
      return;
    }

    final text = _chatController.text.trim();
    final language = _detectLanguage(text);

    setState(() {
      _isAnalyzing = true;
      _analysisResult = {
        'type': 'text',
        'isLoading': true,
        'input': text,
        'language': language,
      };
      if (_usedInputType == _UsedInputType.none) {
        _usedInputType = _UsedInputType.text;
      }
    });

    try {
      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/analyze/text'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'text': text,
          'language': language,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final analysisData = {
            'type': 'text',
            'isLoading': false,
            'input': text,
            'primary_character': result['primary_character'] ?? 'Unknown',
            'character_name': result['character_name'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'inner_characters': result['inner_characters'] ?? [],
            'transcribed_text': null,
            'voice_emotions': [],
            'face_emotion': null,
            'face_confidence': null,
            'hand_gesture': null,
            'hand_gesture_emotion': null,
            'timestamp': DateTime.now().toIso8601String(),
            'detected_language': result['detected_language'] ?? language,
            'is_translated': result['is_translated'] ?? false,
          };

          setState(() {
            _analysisResult = analysisData;
          });

          await _saveToDatabase(
            inputType: 'text',
            transcript: text,
            language: result['detected_language'] ?? language,
            analysisResult: analysisData,
          );
          await _saveHighConfidenceCharacters(analysisData);

          _scrollToResults();
        }
      }
    } catch (e) {
      print('Text analysis error: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  // Voice Recording & Analysis
  Future<void> _startVoiceRecording() async {
    // Check if user already has active session
    if (_hasActiveSession && _usedInputType == _UsedInputType.none) {
      _showActiveSessionDialog();
      return;
    }

    try {
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) {
          return;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _audioFilePath = '${dir.path}/audio_$timestamp.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: _audioFilePath!,
      );

      setState(() {
        _voiceRecording = true;
        if (_usedInputType == _UsedInputType.none) {
          _usedInputType = _UsedInputType.voice;
        }
      });

      print('🎤 Started voice recording');
    } catch (e) {
      print('Error starting voice recording: $e');
      setState(() {
        _voiceRecording = false;
      });
    }
  }

  Future<void> _stopVoiceRecording() async {
    try {
      if (!_voiceRecording) return;

      await _audioRecorder.stop();
      await Future.delayed(const Duration(milliseconds: 500));

      if (_audioFilePath != null) {
        final file = File(_audioFilePath!);
        if (await file.exists()) {
          await _sendAudioToServer();
        }
      }

      setState(() {
        _voiceRecording = false;
      });
    } catch (e) {
      print('Error stopping voice recording: $e');
      setState(() {
        _voiceRecording = false;
      });
    }
  }

  Future<void> _sendAudioToServer() async {
    setState(() {
      _isAnalyzing = true;
      _analysisResult = {
        'type': 'audio',
        'isLoading': true,
        'input': 'Voice recording',
      };
    });

    try {
      if (_audioFilePath == null) {
        return;
      }

      final audioFile = File(_audioFilePath!);
      final bytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(bytes);

      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/analyze/audio'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'audio': base64Audio,
        }),
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final voiceEmotions = result['voice_emotions'] ?? [];
          final primaryVoiceEmotion = result['primary_voice_emotion'] ?? 'Unknown';
          final primaryVoiceConfidence = result['primary_voice_confidence'] ?? 0.0;
          final transcribedText = result['transcribed_text'] ?? 'No speech detected';
          final detectedLanguage = result['detected_language'] ?? 'english';
          final isTranslated = result['is_translated'] ?? false;

          final analysisData = {
            'type': 'audio',
            'isLoading': false,
            'input': 'Voice recording',
            'primary_character': result['primary_character'],
            'character_name': result['character_name'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'inner_characters': result['inner_characters'] ?? [],
            'transcribed_text': transcribedText,
            'voice_emotions': voiceEmotions,
            'primary_voice_emotion': primaryVoiceEmotion,
            'primary_voice_confidence': primaryVoiceConfidence,
            'face_emotion': null,
            'face_confidence': null,
            'hand_gesture': null,
            'hand_gesture_emotion': null,
            'timestamp': DateTime.now().toIso8601String(),
            'detected_language': detectedLanguage,
            'is_translated': isTranslated,
          };

          setState(() {
            _analysisResult = analysisData;
          });

          await _saveToDatabase(
            inputType: 'voice',
            transcript: transcribedText,
            language: detectedLanguage,
            analysisResult: analysisData,
            audioFilePath: _audioFilePath,
          );
          await _saveHighConfidenceCharacters(analysisData);

          _scrollToResults();
        }
      }
    } catch (e) {
      print('Audio send error: $e');
    } finally {
      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  void _toggleVoiceRecording() {
    if (_voiceRecording) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  }

  // Video Recording & Analysis
  Future<void> _startVideoRecording() async {
    // Check if user already has active session
    if (_hasActiveSession && _usedInputType == _UsedInputType.none) {
      _showActiveSessionDialog();
      return;
    }

    if (!_isCameraInitialized || _cameraController == null) {
      return;
    }

    try {
      await _startHiddenAudioRecording();
      await Future.delayed(const Duration(milliseconds: 200));

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _videoFilePath = '${dir.path}/video_$timestamp.mp4';

      await _cameraController!.startVideoRecording();

      setState(() {
        _videoRecording = true;
        if (_usedInputType == _UsedInputType.none) {
          _usedInputType = _UsedInputType.video;
        }
      });

      print('✅ Video recording started');
    } catch (e) {
      print('❌ Error starting video recording: $e');
      await _stopHiddenAudioRecording();
    }
  }

  Future<void> _startHiddenAudioRecording() async {
    try {
      final micStatus = await Permission.microphone.status;
      if (!micStatus.isGranted) {
        final newStatus = await Permission.microphone.request();
        if (!newStatus.isGranted) {
          _videoAudioFilePath = null;
          return;
        }
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _videoAudioFilePath = '${dir.path}/video_audio_$timestamp.wav';

      await _videoAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
          bitRate: 256000,
        ),
        path: _videoAudioFilePath!,
      );

      _videoAudioRecording = true;

    } catch (e) {
      print('❌ Error starting hidden audio recording: $e');
      _videoAudioRecording = false;
      _videoAudioFilePath = null;
    }
  }

  Future<void> _stopHiddenAudioRecording() async {
    if (!_videoAudioRecording) return;

    try {
      await _videoAudioRecorder.stop();
      await Future.delayed(const Duration(milliseconds: 300));

      _videoAudioRecording = false;

    } catch (e) {
      print('❌ Error stopping hidden audio recording: $e');
      _videoAudioRecording = false;
    }
  }

  Future<void> _stopVideoRecording() async {
    if (!_videoRecording) return;

    try {
      final file = await _cameraController!.stopVideoRecording();

      await Future.delayed(const Duration(milliseconds: 100));
      await _stopHiddenAudioRecording();

      await Future.delayed(const Duration(milliseconds: 200));

      if (file != null && _videoFilePath != null) {
        await file.saveTo(_videoFilePath!);
        await _sendVideoWithAudioToServer();
      }

      setState(() {
        _videoRecording = false;
      });
    } catch (e) {
      print('❌ Error stopping video recording: $e');
      setState(() {
        _videoRecording = false;
      });

      await _stopHiddenAudioRecording();
    }
  }

  Future<void> _sendVideoWithAudioToServer() async {
    setState(() {
      _isAnalyzing = true;
      _analysisResult = {
        'type': 'video',
        'isLoading': true,
        'input': 'Video recording',
      };
    });

    try {
      bool hasVideo = _videoFilePath != null && await File(_videoFilePath!).exists();
      if (!hasVideo) {
        return;
      }

      final videoFile = File(_videoFilePath!);
      final videoBytes = await videoFile.readAsBytes();
      final base64Video = base64Encode(videoBytes);

      String? base64Audio;
      if (_videoAudioFilePath != null) {
        final audioFile = File(_videoAudioFilePath!);
        bool hasAudio = await audioFile.exists();

        if (hasAudio) {
          final audioBytes = await audioFile.readAsBytes();
          if (audioBytes.length > 5000) {
            base64Audio = base64Encode(audioBytes);
          }
        }
      }

      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/analyze/video'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'video': base64Video,
          'audio': base64Audio,
          'text': _chatController.text.isNotEmpty ? _chatController.text : '',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        if (result['success'] == true) {
          final voiceEmotions = result['voice_emotions'] ?? [];
          final primaryVoiceEmotion = result['primary_voice_emotion'] ?? 'Unknown';
          final primaryVoiceConfidence = result['primary_voice_confidence'] ?? 0.0;
          final transcribedText = result['transcribed_text'] ?? '';
          final detectedLanguage = result['detected_language'] ?? 'english';
          final isTranslated = result['is_translated'] ?? false;

          final analysisData = {
            'type': 'video',
            'isLoading': false,
            'input': 'Video recording',
            'primary_character': result['primary_character'] ?? 'Unknown',
            'character_name': result['character_name'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'inner_characters': result['inner_characters'] ?? [],
            'transcribed_text': transcribedText,
            'voice_emotions': voiceEmotions,
            'primary_voice_emotion': primaryVoiceEmotion,
            'primary_voice_confidence': primaryVoiceConfidence,
            'face_emotion': result['face_emotion'] ?? 'Unknown',
            'face_confidence': result['face_confidence'] ?? 0.0,
            'hand_gesture': result['hand_gesture'] ?? 'None',
            'hand_gesture_emotion': result['hand_gesture_emotion'] ?? 'Neutral',
            'timestamp': DateTime.now().toIso8601String(),
            'detected_language': detectedLanguage,
            'is_translated': isTranslated,
          };

          setState(() {
            _analysisResult = analysisData;
          });

          await _saveToDatabase(
            inputType: 'video',
            transcript: transcribedText,
            language: detectedLanguage,
            analysisResult: analysisData,
            videoFilePath: _videoFilePath,
            audioFilePath: _videoAudioFilePath,
          );
          await _saveHighConfidenceCharacters(analysisData);

          _scrollToResults();
        }
      }
    } catch (e) {
      print('❌ Video send error: $e');
    } finally {
      await _cleanupTempFiles();

      setState(() {
        _isAnalyzing = false;
      });
    }
  }

  Future<void> _cleanupTempFiles() async {
    try {
      if (_videoFilePath != null && await File(_videoFilePath!).exists()) {
        await File(_videoFilePath!).delete();
      }

      if (_videoAudioFilePath != null && await File(_videoAudioFilePath!).exists()) {
        await File(_videoAudioFilePath!).delete();
      }

      if (_audioFilePath != null && await File(_audioFilePath!).exists()) {
        await File(_audioFilePath!).delete();
      }
    } catch (e) {
      print('⚠️ Error cleaning up files: $e');
    }
  }

  void _toggleVideoRecording() {
    if (_videoRecording) {
      _stopVideoRecording();
    } else {
      _startVideoRecording();
    }
  }

  // UI Helpers
  void _scrollToResults() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  bool _canSwitchToMode(_ReframeMode newMode) {
    if (_usedInputType == _UsedInputType.none) {
      return true;
    }

    switch (_usedInputType) {
      case _UsedInputType.text:
        if (newMode != _ReframeMode.chat) {
          return false;
        }
        break;
      case _UsedInputType.voice:
        if (newMode != _ReframeMode.voice) {
          return false;
        }
        break;
      case _UsedInputType.video:
        if (newMode != _ReframeMode.video) {
          return false;
        }
        break;
      case _UsedInputType.none:
        break;
    }

    return true;
  }

  Future<void> _switchToMode(_ReframeMode newMode) async {
    // Check if trying to enter new data with active session
    if (_hasActiveSession && _usedInputType == _UsedInputType.none) {
      _showActiveSessionDialog();
      return;
    }

    if (!_canSwitchToMode(newMode)) {
      return;
    }

    if (newMode == _ReframeMode.video && _mode != _ReframeMode.video) {
      setState(() {
        _isCameraInitialized = false;
      });
      await _initializeCamera();
    } else if (_mode == _ReframeMode.video && newMode != _ReframeMode.video) {
      await _disposeCamera();
    }

    setState(() {
      _mode = newMode;
    });
  }

  void _showActiveSessionDialog() {
    if (_sessionStartTime != null) {
      final now = DateTime.now();
      final difference = now.difference(_sessionStartTime!);
      if (difference.inHours >= 24) {
        setState(() {
          _hasActiveSession = false;
          _sessionStartTime = null;
        });
        return;
      }
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: const EdgeInsets.all(24),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Close button at top right
            Align(
              alignment: Alignment.topRight,
              child: IconButton(
                icon: const Icon(Icons.close, size: 24),
                onPressed: () => Navigator.of(context).pop(),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ),

            const SizedBox(height: 8),

            // Icon
            const Icon(
              Icons.emoji_objects_outlined,
              color: Color(0xFF8E7CFF),
              size: 48,
            ),

            const SizedBox(height: 20),

            // Title
            Text(
              tr(context, "Continue Your Journey", "استمر في رحلتك"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),

            const SizedBox(height: 16),

            // Message
            Text(
              tr(context,
                  "You've already begun something meaningful. We'll return home so you can move forward with it.",
                  "لقد بدأت بالفعل شيئًا ذا معنى. سنعود إلى الصفحة الرئيسية حتى تتمكن من المضي قدمًا فيه."
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF4B3A66),
                fontSize: 15,
                height: 1.5,
              ),
            ),

            if (_sessionStartTime != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3EDFF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF8E7CFF),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getTimeRemainingText(),
                      style: const TextStyle(
                        color: Color(0xFF4B3A66),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getTimeRemainingText() {
    if (_sessionStartTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(_sessionStartTime!);
    final hoursRemaining = 24 - difference.inHours;

    if (hoursRemaining <= 0) {
      return 'Session expired';
    } else if (hoursRemaining == 1) {
      return 'Available for 1 more hour';
    } else {
      return 'Available for $hoursRemaining more hours';
    }
  }

  void _navigateToHomeScreen() {
    if (widget.onNavigateToHome != null) {
      widget.onNavigateToHome!();
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _audioRecorder.dispose();
    _videoAudioRecorder.dispose();
    _cameraController?.dispose();
    _chatController.dispose();
    _scrollController.dispose();
    _chatController.removeListener(_handleTextChange);
    super.dispose();
  }

  // Build Method
  @override
  Widget build(BuildContext context) {
    // Check if user should be restricted from accessing this screen
    if (_shouldRestrictAccess()) {
      return Scaffold(
        body: Column(
          children: [
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
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E7CFF).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.lock_outline,
                          size: 54,
                          color: Color(0xFF8E7CFF),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        tr(context, "Access Restricted", "الوصول مقيد"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(
                            context,
                            "Some parts of your inner world are still in progress. Let’s care for them first, then you can continue to a new insight.",
                            "بعض الأجزاء في عالمك الداخلي ما زالت قيد التكوّن. دعنا نعتني بها أولًا، ثم يمكنك المتابعة لاكتشاف فهم جديد.من الأجزاء الداخلية التي تحتاج إلى اهتمامك. يرجى الاعتناء بها في مجموعتك قبل اكتشاف أجزاء جديدة."
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4B3A66),
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Original UI for users with less than 3 unhealed characters
    return Scaffold(
      body: Column(
        children: [
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
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.category_rounded,
                      size: 54,
                      color: Color(0xFF8E7CFF),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(context, "Reframe", "إعادة الإطار"),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(
                      context,
                      "This space is for reflection. Speak freely, and let ANA gently reframe your inner parts based on what you share.",
                      "هذه المساحة للتأمل. تحدث بحرية، ودع آنا تعيد صياغة أجزائك الداخلية برفق بناءً على ما تشاركه.",
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF4B3A66),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Mode selection cards
                  Row(
                    children: [
                      Expanded(
                        child: _ModeCard(
                          title: tr(context, "Chat", "دردشة"),
                          icon: Icons.chat_bubble_rounded,
                          selected: _mode == _ReframeMode.chat,
                          enabled: true,
                          onTap: () => _switchToMode(_ReframeMode.chat),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModeCard(
                          title: tr(context, "Voice", "صوت"),
                          icon: Icons.mic_rounded,
                          selected: _mode == _ReframeMode.voice,
                          enabled: true,
                          onTap: () => _switchToMode(_ReframeMode.voice),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModeCard(
                          title: tr(context, "Video", "فيديو"),
                          icon: Icons.videocam_rounded,
                          selected: _mode == _ReframeMode.video,
                          enabled: true,
                          onTap: () => _switchToMode(_ReframeMode.video),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Mode content
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildModeContent(context),
                  ),

                  // Analysis result
                  if (_analysisResult.isNotEmpty && _analysisResult['type'] != null) ...[
                    const SizedBox(height: 20),
                    _buildAnalysisResultCard(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeContent(BuildContext context) {
    switch (_mode) {
      case _ReframeMode.chat:
        return _ChatInputCard(
          key: const ValueKey('chat'),
          controller: _chatController,
          hint: tr(context, "Write what you're feeling...", "اكتب ما تشعر به..."),
          isAnalyzing: _isAnalyzing,
          onAnalyze: _analyzeText,
          usedInputType: _usedInputType,
          hasActiveSession: _hasActiveSession,
        );
      case _ReframeMode.voice:
        return _VoiceInputCard(
          key: const ValueKey('voice'),
          recording: _voiceRecording,
          isAnalyzing: _isAnalyzing,
          onToggle: _toggleVoiceRecording,
          usedInputType: _usedInputType,
          hasActiveSession: _hasActiveSession,
        );
      case _ReframeMode.video:
        return _VideoInputCard(
          key: const ValueKey('video'),
          cameraController: _cameraController,
          isCameraInitialized: _isCameraInitialized,
          isRecording: _videoRecording,
          isAnalyzing: _isAnalyzing,
          onToggleRecording: _toggleVideoRecording,
          usedInputType: _usedInputType,
          hasActiveSession: _hasActiveSession,
        );
    }
  }

  Widget _buildAnalysisResultCard() {
    final isLoading = _analysisResult['isLoading'] == true;
    final hasError = _analysisResult['error'] != null;
    final analysisType = _analysisResult['type'] ?? 'unknown';
    final innerCharacters = _analysisResult['inner_characters'] ?? [];
    final primaryCharacter = _analysisResult['primary_character'] ?? 'Unknown';
    final characterName = _analysisResult['character_name'] ?? '';
    final confidence = (_analysisResult['confidence'] ?? 0.0) * 100;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8E7CFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.analytics_rounded,
                color: const Color(0xFF8E7CFF),
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                tr(context, "Analysis Results", "نتائج التحليل"),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF2A1E3B),
                ),
              ),
              const Spacer(),
              Chip(
                label: Text(
                  analysisType.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                backgroundColor: const Color(0xFF8E7CFF),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (isLoading) ...[
            const Center(
              child: Column(
                children: [
                  CircularProgressIndicator(
                    color: Color(0xFF8E7CFF),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Analyzing...',
                    style: TextStyle(
                      color: Color(0xFF4B3A66),
                    ),
                  ),
                ],
              ),
            ),
          ] else if (hasError) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3F3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: const Color(0xFFD32F2F),
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Analysis Error',
                    style: const TextStyle(
                      color: Color(0xFFD32F2F),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _analysisResult['error']?.toString() ?? 'Unknown error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Input Preview
            if (_analysisResult['input'] != null) ...[
              _buildSectionTitle('Input'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _analysisResult['input']?.toString() ?? '',
                  style: const TextStyle(
                    color: Color(0xFF4B3A66),
                    fontSize: 14,
                  ),
                ),
              ),
            ],

            // Transcribed Text
            if (_analysisResult['transcribed_text'] != null &&
                _analysisResult['transcribed_text'].toString().isNotEmpty) ...[
              _buildSectionTitle('Transcribed Speech'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _analysisResult['transcribed_text'].toString(),
                  style: const TextStyle(
                    color: Color(0xFF4B3A66),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],

            // Primary Character
            _buildSectionTitle('Primary Inner Character'),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EDFF),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF8E7CFF)),
              ),
              child: Column(
                children: [
                  // Primary character image
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Image.asset(
                        _getImagePathForCharacter(primaryCharacter),
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.psychology_rounded,
                            color: const Color(0xFF8E7CFF),
                            size: 40,
                          );
                        },
                      ),
                    ),
                  ),
                  Text(
                    primaryCharacter,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (characterName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      characterName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E7CFF),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: confidence / 100,
                    backgroundColor: const Color(0xFFE5DEFF),
                    color: const Color(0xFF8E7CFF),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${confidence.toStringAsFixed(1)}% confidence',
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            // Top Inner Characters
            if (innerCharacters.isNotEmpty) ...[
              _buildSectionTitle('Top Inner Characters'),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: innerCharacters.length.clamp(0, 5),
                  itemBuilder: (context, index) {
                    final character = innerCharacters[index];
                    final charDisplayName = character['character']?.toString() ?? 'Unknown';
                    final charName = character['character_name']?.toString() ?? '';
                    final charConfidence = (character['confidence'] ?? 0.0) * 100;
                    final isPrimary = charDisplayName == primaryCharacter;

                    final cardWidth = 150.0;

                    return Container(
                      width: cardWidth,
                      margin: EdgeInsets.only(
                        right: index < innerCharacters.length.clamp(0, 5) - 1 ? 12 : 0,
                      ),
                      child: _buildCharacterCard(
                        displayName: charDisplayName,
                        characterName: charName,
                        charConfidence: charConfidence,
                        isPrimary: isPrimary,
                        index: index,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Emotions Section
            _buildEmotionsSection(),

            // Analysis Info
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F7FF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: const Color(0xFF8E7CFF),
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Analysis completed at ${_analysisResult['timestamp'] != null ? DateTime.parse(_analysisResult['timestamp']).toString().substring(0, 16) : 'unknown time'}',
                      style: const TextStyle(
                        color: Color(0xFF4B3A66),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCharacterCard({
    required String displayName,
    required String characterName,
    required double charConfidence,
    required bool isPrimary,
    required int index,
  }) {
    return GestureDetector(
      onTap: () {},
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPrimary ? const Color(0xFF8E7CFF) : const Color(0xFFE5DEFF),
            width: isPrimary ? 2.0 : 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isPrimary ? 0.1 : 0.05),
              blurRadius: isPrimary ? 12 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Character Image Area
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: isPrimary
                    ? Border.all(color: const Color(0xFF8E7CFF).withOpacity(0.3))
                    : null,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.asset(
                  _getImagePathForCharacter(displayName),
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Center(
                        child: Icon(
                          Icons.psychology_rounded,
                          color: const Color(0xFF8E7CFF),
                          size: 48,
                        )
                    );
                  },
                ),
              ),
            ),

            // Character Info Area
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    if (characterName.isNotEmpty) ...[
                      Text(
                        characterName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E7CFF),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: charConfidence / 100,
                      backgroundColor: const Color(0xFFE5DEFF),
                      color: const Color(0xFF8E7CFF).withOpacity(0.7),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),

                    Text(
                      '${charConfidence.toStringAsFixed(1)}% confidence',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF4B3A66),
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

  String _getImagePathForCharacter(String characterName) {
    final imageMap = {
      'Inner Critic': 'assets/images/inner_critic.png',
      'People Pleaser': 'assets/images/people_pleaser.png',
      'Lonely Part': 'assets/images/lonely.png',
      'Jealous Part': 'assets/images/jealous.png',
      'Ashamed Part': 'assets/images/ashamed.png',
      'Workaholic': 'assets/images/workaholic.png',
      'Perfectionist': 'assets/images/perfectionist.png',
      'Procrastinator': 'assets/images/procrastinator.png',
      'Excessive Gamer': 'assets/images/excessive_gamer.png',
      'Confused Part': 'assets/images/confused.png',
      'Dependent Part': 'assets/images/dependant.png',
      'Fearful Part': 'assets/images/fearful.png',
      'Neglected Part': 'assets/images/neglected.png',
      'Overeater': 'assets/images/overeater_binger.png',
      'Binger': 'assets/images/overeater_binger.png',
      'Overeater/Binger': 'assets/images/overeater_binger.png',
      'Overwhelmed Part': 'assets/images/overwhelmed.png',
      'Stoic Part': 'assets/images/stoic.png',
      'Wounded Child': 'assets/images/wounded_child.png',
      'Controller': 'assets/images/controller.png',
      'Controller Part': 'assets/images/controller.png',
    };

    if (imageMap.containsKey(characterName)) {
      return imageMap[characterName]!;
    }

    final lowerName = characterName.toLowerCase();
    for (final entry in imageMap.entries) {
      final keyLower = entry.key.toLowerCase();
      if (lowerName.contains(keyLower) || keyLower.contains(lowerName)) {
        return entry.value;
      }
    }

    return 'assets/images/inner_critic.png';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: Color(0xFF2A1E3B),
        ),
      ),
    );
  }

  Widget _buildEmotionsSection() {
    final emotions = <Map<String, dynamic>>[];

    final voiceEmotions = _analysisResult['voice_emotions'] ?? [];

    if (_analysisResult['face_emotion'] != null &&
        _analysisResult['face_emotion'] != 'Unknown') {
      emotions.add({
        'type': 'Face Emotion',
        'emotion': _analysisResult['face_emotion'],
        'confidence': _analysisResult['face_confidence'] ?? 0.0,
        'icon': Icons.face,
        'color': const Color(0xFF2196F3),
      });
    }

    if (_analysisResult['hand_gesture_emotion'] != null &&
        _analysisResult['hand_gesture_emotion'] != 'Neutral' &&
        _analysisResult['hand_gesture_emotion'] != 'Unknown') {
      emotions.add({
        'type': 'Gesture Emotion',
        'emotion': _analysisResult['hand_gesture_emotion'],
        'confidence': _analysisResult['hand_gesture_confidence'] ?? 0.0,
        'icon': Icons.gesture,
        'color': const Color(0xFFFF9800),
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (emotions.isNotEmpty) ...[
          _buildSectionTitle('Detected Emotions'),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: emotions.length <= 2 ? emotions.length : 3,
            childAspectRatio: 1.2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: emotions.map((emotion) {
              final confidence = emotion['confidence'] as double;
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: (emotion['color'] as Color).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: emotion['color'] as Color),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      emotion['icon'] as IconData,
                      color: emotion['color'] as Color,
                      size: 24,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      emotion['type'].toString(),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF4B3A66),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      emotion['emotion'].toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: emotion['color'] as Color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: LinearProgressIndicator(
                            value: confidence,
                            backgroundColor: (emotion['color'] as Color).withOpacity(0.2),
                            color: emotion['color'] as Color,
                            minHeight: 4,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${(confidence * 100).toStringAsFixed(1)}%',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF4B3A66),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
        ],

        if (voiceEmotions is List && voiceEmotions.isNotEmpty) ...[
          _buildSectionTitle('Voice Tone Emotions'),
          const SizedBox(height: 8),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F7FF),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8E7CFF).withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.volume_up_rounded,
                      color: const Color(0xFF8E7CFF),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Voice Tone Analysis',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                Column(
                  children: voiceEmotions.map((emotion) {
                    final emotionName = emotion['emotion']?.toString() ?? 'Unknown';
                    final confidence = (emotion['confidence'] ?? 0.0) as double;
                    final percentage = (confidence * 100);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              emotionName,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${percentage.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: percentage > 50
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF757575),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 120,
                            child: LinearProgressIndicator(
                              value: confidence,
                              backgroundColor: const Color(0xFFE0E0E0),
                              color: percentage > 50
                                  ? const Color(0xFF4CAF50)
                                  : const Color(0xFF8E7CFF),
                              minHeight: 8,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.icon,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = enabled
        ? (selected ? const Color(0xFF8E7CFF) : const Color(0xFF9B92B3))
        : const Color(0xFFCCCCCC);

    final backgroundColor = enabled
        ? (selected ? const Color(0xFFF3EDFF) : Colors.white)
        : const Color(0xFFF5F5F5);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: enabled
                ? (selected ? const Color(0xFF8E7CFF) : const Color(0xFFE5DEFF))
                : const Color(0xFFEEEEEE),
          ),
          boxShadow: enabled
              ? [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 6),
            ),
          ]
              : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatInputCard extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;
  final _UsedInputType usedInputType;
  final bool hasActiveSession;

  const _ChatInputCard({
    super.key,
    required this.controller,
    required this.hint,
    required this.isAnalyzing,
    required this.onAnalyze,
    required this.usedInputType,
    required this.hasActiveSession,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;
    final canUseChat = (usedInputType == _UsedInputType.none || usedInputType == _UsedInputType.text) && !hasActiveSession;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: canUseChat ? const Color(0xFFE5DEFF) : const Color(0xFFE5DEFF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            maxLines: 4,
            enabled: canUseChat,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: canUseChat ? const Color(0xFF4B3A66).withOpacity(0.5) : const Color(0xFFCCCCCC),
              ),
            ),
            style: TextStyle(
              color: canUseChat ? const Color(0xFF4B3A66) : const Color(0xFFCCCCCC),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canUseChat && hasText && !isAnalyzing ? onAnalyze : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canUseChat && hasText ? const Color(0xFF8E7CFF) : const Color(0xFFCCCCCC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: isAnalyzing
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
                  : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.analytics_rounded, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    tr(context, "Analyze", "تحليل"),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VoiceInputCard extends StatelessWidget {
  final bool recording;
  final bool isAnalyzing;
  final VoidCallback onToggle;
  final _UsedInputType usedInputType;
  final bool hasActiveSession;

  const _VoiceInputCard({
    super.key,
    required this.recording,
    required this.isAnalyzing,
    required this.onToggle,
    required this.usedInputType,
    required this.hasActiveSession,
  });

  @override
  Widget build(BuildContext context) {
    final canUseVoice = (usedInputType == _UsedInputType.none || usedInputType == _UsedInputType.voice) && !hasActiveSession;
    final color = canUseVoice
        ? (recording ? const Color(0xFF8E7CFF) : const Color(0xFFEDE7FF))
        : const Color(0xFFCCCCCC);
    final iconColor = canUseVoice
        ? (recording ? Colors.white : const Color(0xFF8E7CFF))
        : Colors.white;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: canUseVoice ? const Color(0xFFE5DEFF) : const Color(0xFFE5DEFF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: canUseVoice && !isAnalyzing ? onToggle : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: iconColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveSession
                          ? tr(context, "Session Active", "جلسة نشطة")
                          : !canUseVoice
                          ? tr(context, "Input method locked", "طريقة الإدخال مقفلة")
                          : recording
                          ? tr(context, "Recording...", "جارٍ التسجيل...")
                          : tr(context, "Tap to record", "اضغط للتسجيل"),
                      style: TextStyle(
                        fontSize: 16,
                        color: canUseVoice ? const Color(0xFF4B3A66) : const Color(0xFFCCCCCC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasActiveSession
                          ? tr(context, "Return to home to continue", "ارجع للصفحة الرئيسية للمتابعة")
                          : !canUseVoice
                          ? tr(context, "Cannot start new session", "لا يمكن بدء جلسة جديدة")
                          : recording
                          ? tr(context, "Tap stop when finished", "اضغط إيقاف عند الانتهاء")
                          : tr(context, "Speak clearly for best results", "تحدث بوضوح للحصول على أفضل النتائج"),
                      style: TextStyle(
                        fontSize: 12,
                        color: canUseVoice ? const Color(0xFF4B3A66).withOpacity(0.7) : const Color(0xFFCCCCCC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (isAnalyzing) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8E7CFF)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E7CFF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(context, "Analyzing audio...", "جارٍ تحليل الصوت..."),
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _VideoInputCard extends StatelessWidget {
  final CameraController? cameraController;
  final bool isCameraInitialized;
  final bool isRecording;
  final bool isAnalyzing;
  final VoidCallback onToggleRecording;
  final _UsedInputType usedInputType;
  final bool hasActiveSession;

  const _VideoInputCard({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.isRecording,
    required this.isAnalyzing,
    required this.onToggleRecording,
    required this.usedInputType,
    required this.hasActiveSession,
  });

  @override
  Widget build(BuildContext context) {
    final canUseVideo = (usedInputType == _UsedInputType.none || usedInputType == _UsedInputType.video) && !hasActiveSession;
    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 20.0;
    final videoWidth = screenWidth - (2 * padding);

    return Column(
      children: [
        Container(
          width: videoWidth,
          height: 200,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: canUseVideo ? const Color(0xFFE5DEFF) : const Color(0xFFE5DEFF),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: isCameraInitialized && cameraController != null
                ? _buildCameraPreview(context)
                : _buildCameraPlaceholder(context),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          width: videoWidth,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: canUseVideo ? const Color(0xFFE5DEFF) : const Color(0xFFE5DEFF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: canUseVideo && isCameraInitialized && !isAnalyzing ? onToggleRecording : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: !canUseVideo
                        ? const Color(0xFFCCCCCC)
                        : isRecording
                        ? const Color(0xFFFF6B6B)
                        : isCameraInitialized
                        ? const Color(0xFF8E7CFF)
                        : const Color(0xFFCCCCCC),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isRecording ? Icons.stop_rounded : Icons.videocam_rounded,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      hasActiveSession
                          ? tr(context, "Session Active", "جلسة نشطة")
                          : !canUseVideo
                          ? tr(context, "Input method locked", "طريقة الإدخال مقفلة")
                          : !isCameraInitialized
                          ? tr(context, "Camera initializing...", "جاري تهيئة الكاميرا...")
                          : isRecording
                          ? tr(context, "Recording...", "جارٍ التسجيل...")
                          : tr(context, "Ready to record video", "جاهز لتسجيل فيديو"),
                      style: TextStyle(
                        fontSize: 16,
                        color: canUseVideo ? const Color(0xFF4B3A66) : const Color(0xFFCCCCCC),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      hasActiveSession
                          ? tr(context, "Return to home to continue", "ارجع للصفحة الرئيسية للمتابعة")
                          : !canUseVideo
                          ? tr(context, "Cannot start new session", "لا يمكن بدء جلسة جديدة")
                          : isRecording
                          ? tr(context, "Tap stop when finished", "اضغط إيقاف عند الانتهاء")
                          : tr(context, "Look at the camera and speak", "انظر إلى الكاميرا وتحدث"),
                      style: TextStyle(
                        fontSize: 12,
                        color: canUseVideo ? const Color(0xFF4B3A66).withOpacity(0.7) : const Color(0xFFCCCCCC),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        if (isAnalyzing) ...[
          const SizedBox(height: 16),
          Container(
            width: videoWidth,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF3EDFF),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF8E7CFF)),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8E7CFF)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr(context, "Analyzing video...", "جارٍ تحليل الفيديو..."),
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraPreview(BuildContext context) {
    final cameraController = this.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return _buildCameraPlaceholder(context);
    }

    return Stack(
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: cameraController.value.aspectRatio,
            child: CameraPreview(cameraController),
          ),
        ),
        if (isRecording) ...[
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    tr(context, "REC", "تسجيل"),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCameraPlaceholder(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            color: Color(0xFF8E7CFF),
          ),
          const SizedBox(height: 12),
          Text(
            tr(context, "Initializing camera...", "جاري تهيئة الكاميرا..."),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}