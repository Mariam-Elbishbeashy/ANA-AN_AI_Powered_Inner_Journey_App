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
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';

enum _ReframeMode { chat, voice, video }

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

  // Track character counts - ONLY based on currentState
  int _activeCharacterCount = 0;
  int _inactiveCharacterCount = 0;

  // Audio recording for video mode
  bool _videoAudioRecording = false;
  String? _videoAudioFilePath;
  final AudioRecorder _videoAudioRecorder = AudioRecorder();

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;
  String? _currentUserId;

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
      await _refreshCharacterData();
    });
  }

  // Refresh character data from database
  Future<void> _refreshCharacterData() async {
    await _checkForCharacters();
  }

  // Check if user has 3 or more ACTIVE characters
  bool _shouldRestrictAccess() {
    return _activeCharacterCount >= 3;
  }

  // Helper method to check if a character is active
  bool _isActiveCharacter(Map<String, dynamic> characterData) {
    final currentState = characterData['currentState'] ?? 'active';
    return currentState == 'active';
  }

  // Check character counts from database - only count ACTIVE characters
  Future<void> _checkForCharacters() async {
    try {
      if (_currentUserId == null) return;

      // Query for ALL user characters
      final querySnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      int activeCount = 0;
      int inactiveCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final currentState = data['currentState'] ?? 'active';

        if (currentState == 'active') {
          activeCount++;
        } else if (currentState == 'inactive') {
          inactiveCount++;
        }
      }

      setState(() {
        _activeCharacterCount = activeCount;
        _inactiveCharacterCount = inactiveCount;
      });

      print('📊 Character Stats: $activeCount active, $inactiveCount inactive');

    } catch (e) {
      print('❌ Error checking characters: $e');
      setState(() {
        _activeCharacterCount = 0;
        _inactiveCharacterCount = 0;
      });
    }
  }

  // Show restricted access dialog
  void _showRestrictedAccessDialog() {
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
            Text(
              tr(context, "Continue Your Healing Journey", "استمر في رحلة شفائك"),
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(context,
                  "You have $_activeCharacterCount active parts awaiting your attention. Please nurture them before discovering new insights. (Inactive parts can be reactivated)",
                  "لديك $_activeCharacterCount جزءًا نشطًا تنتظر اهتمامك. يرجى رعايتها قبل اكتشاف رؤى جديدة. (يمكن إعادة تفعيل الأجزاء غير النشطة)"),
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

  // Helper methods for Arabic translations
  String _getArabicDisplayName(String englishName) {
    final arabicNames = {
      'Inner Critic': 'الناقد الداخلي',
      'Perfectionist': 'الكمالي',
      'People Pleaser': 'المُرضي',
      'Controller': 'المتحكم',
      'Stoic Part': 'حمّال أسيّة',
      'Workaholic': 'مدمن العمل',
      'Confused Part': 'الجزء الحيران',
      'Procrastinator': 'المماطل',
      'Overeater': 'الآكل المفرط',
      'Binger': 'المفرط',
      'Overeater/Binger': 'الآكل المفرط',
      'Excessive Gamer': 'اللاعب المفرط',
      'Lonely Part': 'الجزء الوحيد',
      'Fearful Part': 'الجزء الخائف',
      'Neglected Part': 'الجزء المهمل',
      'Ashamed Part': 'الجزء الخجول',
      'Overwhelmed Part': 'الجزء المرهق',
      'Dependent Part': 'الجزء المعتمد',
      'Jealous Part': 'الجزء الغيور',
      'Wounded Child': 'الطفل الجريح',
    };

    return arabicNames[englishName] ?? englishName;
  }

  String _getArabicDescription(String englishName) {
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
      'هذا الجزء اليقظ يمسح باستمرار للبحث عن التهديدات والمخاطر المحتملة. يهدف إلى إبقائك آمناً من خلال توقع المشاكل ولكن يمكن أن يصبح مفرط اليقظة، مما يخلق قلقاً بشأن مواقف قد لا تحدث أبداً.',
      'Neglected Part':
      'هذا الجزء الجريح يحتفظ بذكريات الإهمال، أو عدم الاستماع، أو الهجر العاطفي. يحمل ألم الاحتياجات غير الملباة في الطفولة ويسعى للاعتراف والرعاية التي لم يتلقاها.',
      'Overeater/Binger':
      'هذا الجزء يستخدم الطعام لتهدئة الألم العاطفي، أو ملء الفراغ الداخلي، أو تخدير المشاعر الصعبة. يوفر راحة مؤقتة ولكن غالباً ما يؤدي إلى دورات من الذنب والمزيد من الأكل العاطفي.',
      'Overeater':
      'هذا الجزء يستخدم الطعام لتهدئة الألم العاطفي، أو ملء الفراغ الداخلي، أو تخدير المشاعر الصعبة. يوفر راحة مؤقتة ولكن غالباً ما يؤدي إلى دورات من الذنب والمزيد من الأكل العاطفي.',
      'Binger':
      'هذا الجزء يستخدم الطعام لتهدئة الألم العاطفي، أو ملء الفراغ الداخلي، أو تخدير المشاعر الصعبة. يوفر راحة مؤقتة ولكن غالباً ما يؤدي إلى دورات من الذنب والمزيد من الأكل العاطفي.',
      'Overwhelmed Part':
      'هذا الجزء يشعر بعدم القدرة على التعامل مع مطالب ومسؤوليات الحياة. يمثل إرهاق محاولة إدارة كل شيء ويحتاج إلى دعم في وضع الحدود وتحديد أولويات الرعاية الذاتية.',
      'Stoic Part':
      'هذا الجزء يكبت المشاعر ويحافظ على المسافة العاطفية كاستراتيجية بقاء. يعتقد أن إظهار الضعف خطير ويخلق مظهراً خارجياً متحكماً بينما تظل المشاعر الداخلية غير معالجة.',
      'Wounded Child':
      'هذا الجزء الضعيف يحمل ألم الطفولة، والصدمة، والاحتياجات العاطفية غير الملباة. يحتفظ بالبراءة التي أذيَت ويحتاج إلى اهتمام عطوف للشفاء والشعور بالأمان مرة أخرى.',
      'Controller':
      'هذا الجزء يحاول إدارة كل شيء وكل شخص لخلق إحساس بالأمان والقابلية للتنبؤ. يخاف من الفوضى وفقدان السيطرة، ويعمل بلا كلل للحفاظ على النظام ولكنه غالباً ما يخلق جموداً.',
      'Controller Part':
      'هذا الجزء يحاول إدارة كل شيء وكل شخص لخلق إحساس بالأمان والقابلية للتنبؤ. يخاف من الفوضى وفقدان السيطرة، ويعمل بلا كلل للحفاظ على النظام ولكنه غالباً ما يخلق جموداً.',
    };

    return arabicDescriptions[englishName] ??
        'تلعب هذه الشخصية الداخلية دوراً مهماً في مشهدك العاطفي. ظهرت كآلية وقائية خلال تجارب صعبة وتستمر في التأثير على كيفية تنقلك في العلاقات، والتحديات، وتصور الذات.';
  }

  String _getEnglishDescription(String englishName) {
    final englishDescriptions = {
      'Inner Critic': 'This part helps you stay safe by pointing out potential mistakes and keeping you from taking risks.',
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
      'Overeater/Binger': 'Uses food for comfort or distraction from emotional pain.',
      'Overwhelmed Part': 'Feels burdened by responsibilities and emotions, struggling to cope.',
      'Stoic Part': 'Suppresses emotions and maintains emotional distance as protection.',
      'Wounded Child': 'Carries childhood pain and trauma, often feeling vulnerable and hurt.',
      'Controller': 'Seeks to control situations and people to feel safe and secure.',
      'Controller Part': 'Seeks to control situations and people to feel safe and secure.',
    };

    return englishDescriptions[englishName] ??
        'An inner part that has been identified through reflection. This part holds emotions, beliefs, or patterns that influence your thoughts and behaviors.';
  }

  // Helper method to detect if text is Arabic
  bool _isArabicText(String text) {
    if (text.isEmpty) return false;
    final arabicPattern = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicPattern.hasMatch(text);
  }

  // Helper method to get English display name based on character name
  String _getEnglishDisplayName(String characterName) {
    final englishNames = {
      'Inner Critic': 'The Inner Critic',
      'People Pleaser': 'The People Pleaser',
      'Lonely Part': 'The Lonely Part',
      'Jealous Part': 'The Jealous Part',
      'Ashamed Part': 'The Ashamed Part',
      'Workaholic': 'The Workaholic',
      'Perfectionist': 'The Perfectionist',
      'Procrastinator': 'The Procrastinator',
      'Excessive Gamer': 'The Excessive Gamer',
      'Confused Part': 'The Confused Part',
      'Dependent Part': 'The Dependent Part',
      'Fearful Part': 'The Fearful Part',
      'Neglected Part': 'The Neglected Part',
      'Overeater': 'The Overeater',
      'Binger': 'The Binger',
      'Overeater/Binger': 'The Overeater',
      'Overwhelmed Part': 'The Overwhelmed Part',
      'Stoic Part': 'The Stoic Part',
      'Wounded Child': 'The Wounded Child',
      'Controller': 'The Controller',
      'Controller Part': 'The Controller',
    };

    return englishNames[characterName] ?? characterName;
  }

  // Helper method to verify media files
  Future<bool> _verifyMediaFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) {
      return false;
    }

    try {
      final file = File(filePath);
      if (!await file.exists()) {
        print('❌ File does not exist: $filePath');
        return false;
      }

      final fileSize = await file.length();
      if (fileSize == 0) {
        print('❌ File is empty: $filePath');
        return false;
      }

      print('✅ File verified: $filePath (${fileSize} bytes)');
      return true;
    } catch (e) {
      print('❌ Error verifying file: $e');
      return false;
    }
  }

  // Upload media file to Firebase Storage
  Future<String?> _uploadMediaFile(
      String filePath,
      String mediaType,
      String sessionId,
      ) async {
    try {
      // Verify file exists and has content
      if (!await _verifyMediaFile(filePath)) {
        return null;
      }

      final file = File(filePath);

      // Create a unique filename with timestamp to avoid collisions
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = filePath.split('.').last;
      final fileName = '${mediaType}_$timestamp.$fileExtension';
      final storagePath = 'users/$_currentUserId/characters/$mediaType/$sessionId/$fileName';

      print('📤 Uploading $mediaType to: $storagePath');

      // Upload to Firebase Storage with metadata
      final ref = _storage.ref().child(storagePath);

      // Add metadata
      final metadata = firebase_storage.SettableMetadata(
        contentType: mediaType == 'audio' ? 'audio/wav' : 'video/mp4',
        customMetadata: {
          'userId': _currentUserId ?? '',
          'sessionId': sessionId,
          'uploadedAt': DateTime.now().toIso8601String(),
        },
      );

      final uploadTask = await ref.putFile(file, metadata);

      // Verify upload was successful
      if (uploadTask.state == firebase_storage.TaskState.success) {
        // Get the download URL
        final downloadUrl = await ref.getDownloadURL();
        print('✅ Media uploaded successfully: $downloadUrl');
        return downloadUrl;
      } else {
        print('❌ Upload failed with state: ${uploadTask.state}');
        return null;
      }

    } catch (e) {
      print('❌ Error uploading media file: $e');
      return null;
    }
  }

  // Save high confidence characters to user collection
  Future<void> _saveHighConfidenceCharacters(
      Map<String, dynamic> analysisResult, {
        String? audioFilePath,
        String? videoFilePath,
        String? inputType,
      }) async {
    try {
      if (_currentUserId == null) {
        print('❌ No user ID available');
        return;
      }

      // FIRST CHECK: Verify user doesn't already have 3 or more active characters
      await _checkForCharacters(); // Get latest counts

      if (_shouldRestrictAccess()) {
        print('🚫 Cannot create or reactivate characters: User already has $_activeCharacterCount active characters');

        if (mounted) {
          // Show dialog explaining why they can't create/reactivate more characters
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
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.info_outline,
                      size: 40,
                      color: Color(0xFF8E7CFF),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    tr(context, "Cannot Create More Characters", "لا يمكن إنشاء المزيد من الشخصيات"),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr(context,
                        "You already have $_activeCharacterCount active parts. Please nurture them before discovering new insights or reactivating inactive parts.",
                        "لديك بالفعل $_activeCharacterCount جزء نشط. يرجى رعايتها قبل اكتشاف رؤى جديدة أو إعادة تفعيل الأجزاء غير النشطة."),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF8E7CFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr(context, "Got It", "حسناً"),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return; // Stop here - don't create or reactivate any characters
      }

      // Get inner_characters from analysis result
      List<dynamic> innerCharacters = [];

      if (analysisResult.containsKey('inner_characters')) {
        innerCharacters = analysisResult['inner_characters'] as List<dynamic>? ?? [];
      } else if (analysisResult.containsKey('analysisResult') &&
          analysisResult['analysisResult'] is Map) {
        final nested = analysisResult['analysisResult'] as Map;
        if (nested.containsKey('inner_characters')) {
          innerCharacters = nested['inner_characters'] as List<dynamic>? ?? [];
        }
      } else if (analysisResult.containsKey('primary_character') &&
          analysisResult['primary_character'] != 'Unknown') {
        final primaryChar = analysisResult['primary_character'];
        final confidence = analysisResult['confidence'] ?? 0.0;

        innerCharacters = [
          {
            'character': primaryChar,
            'character_name': analysisResult['character_name'] ?? primaryChar,
            'confidence': confidence,
          }
        ];
      }

      final String detectedLanguage = analysisResult['detected_language'] ?? 'english';

      // Filter characters with high confidence
      final highConfidenceCharacters = innerCharacters.where((character) {
        double confidence = 0.0;
        if (character is Map) {
          if (character.containsKey('confidence')) {
            confidence = (character['confidence'] as num?)?.toDouble() ?? 0.0;
          } else if (character.containsKey('score')) {
            confidence = (character['score'] as num?)?.toDouble() ?? 0.0;
          }
        }
        return confidence >= _highConfidenceThreshold;
      }).toList();

      if (highConfidenceCharacters.isEmpty) {
        print('ℹ️ No characters meet the high confidence threshold');
        return;
      }

      // Sort characters by confidence
      highConfidenceCharacters.sort((a, b) {
        final confA = (a['confidence'] as num?)?.toDouble() ?? 0.0;
        final confB = (b['confidence'] as num?)?.toDouble() ?? 0.0;
        return confB.compareTo(confA);
      });

      // Get ALL existing user characters
      final existingCharactersSnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      // Create maps for quick lookup by character name
      Map<String, Map<String, dynamic>> activeCharacters = {};
      Map<String, Map<String, dynamic>> inactiveCharacters = {};

      for (final doc in existingCharactersSnapshot.docs) {
        final data = doc.data();
        final characterName = data['characterName']?.toString().toLowerCase().trim() ?? '';
        final currentState = data['currentState'] ?? 'active';

        if (characterName.isNotEmpty) {
          if (currentState == 'inactive') {
            inactiveCharacters[characterName] = {
              ...data,
              'docId': doc.id,
            };
          } else {
            activeCharacters[characterName] = {
              ...data,
              'docId': doc.id,
            };
          }
        }
      }

      int maxRank = 0;
      for (final doc in existingCharactersSnapshot.docs) {
        final rank = (doc.data()['rank'] as num?)?.toInt() ?? 0;
        if (rank > maxRank) {
          maxRank = rank;
        }
      }

      int nextRank = maxRank + 1;
      int newCharactersCount = 0;
      int reactivatedCharactersCount = 0;

      final batch = _firestore.batch();
      final timestamp = DateTime.now();

      // Track how many active characters we'll have after all operations
      int totalActiveAfterOperations = _activeCharacterCount;

      // Process each high confidence character
      for (int i = 0; i < highConfidenceCharacters.length; i++) {
        final character = highConfidenceCharacters[i];

        // Get character name
        String characterName = 'Unknown';
        if (character is Map) {
          if (character.containsKey('character')) {
            characterName = character['character']?.toString() ?? 'Unknown';
          } else if (character.containsKey('character_name')) {
            characterName = character['character_name']?.toString() ?? 'Unknown';
          }
        }

        if (characterName == 'Unknown') {
          print('⚠️ Skipping character with unknown name');
          continue;
        }

        final characterNameLower = characterName.toLowerCase().trim();

        // Get confidence
        double confidence = 0.0;
        if (character is Map) {
          if (character.containsKey('confidence')) {
            confidence = (character['confidence'] as num?)?.toDouble() ?? 0.0;
          } else if (character.containsKey('score')) {
            confidence = (character['score'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // Check if character exists as INACTIVE
        if (inactiveCharacters.containsKey(characterNameLower)) {
          // Check if reactivating would exceed the limit
          if (totalActiveAfterOperations >= 3) {
            print('🚫 Cannot reactivate: Would exceed active character limit. Current: $_activeCharacterCount, After operations: $totalActiveAfterOperations');

            if (mounted && i == 0) {
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
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E7CFF).withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          size: 40,
                          color: Color(0xFF8E7CFF),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        tr(context, "Active Character Limit", "حد الشخصيات النشطة"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        tr(context,
                            "You can only have up to 3 active characters at a time. Cannot reactivate more characters at this time.",
                            "يمكنك الحصول على 3 شخصيات نشطة فقط في المرة الواحدة. لا يمكن إعادة تفعيل المزيد من الشخصيات في هذا الوقت."),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFF4B3A66),
                          fontSize: 15,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3EDFF),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tr(context,
                              "Current active: $_activeCharacterCount of 3",
                              "النشط حالياً: $_activeCharacterCount من 3"),
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF8E7CFF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            continue; // Skip this reactivation
          }

          // Reactivate the inactive character
          final inactiveData = inactiveCharacters[characterNameLower]!;
          final docId = inactiveData['docId'];

          print('🔄 Reactivating inactive character: $characterName');

          // Update the existing inactive character to active
          final docRef = _firestore.collection('user_characters').doc(docId);
          batch.update(docRef, {
            'currentState': 'active',
            'confidence': confidence, // Update with latest confidence
            'predictedAt': timestamp.toIso8601String(),
            'reactivatedAt': timestamp.toIso8601String(),
          });

          reactivatedCharactersCount++;
          totalActiveAfterOperations++; // Increment active count

          // Remove from inactive map so we don't process again
          inactiveCharacters.remove(characterNameLower);
          continue;
        }

        // Check if character exists as ACTIVE (skip if already active)
        if (activeCharacters.containsKey(characterNameLower)) {
          print('⏭️ Character already active: $characterName');
          continue;
        }

        // SECOND CHECK: Before adding a NEW character, verify again that we're not exceeding the limit
        if (totalActiveAfterOperations >= 3) {
          print('🚫 Cannot add new character: Would exceed active character limit. Current: $_activeCharacterCount, After operations: $totalActiveAfterOperations');

          if (mounted && i == 0) {
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
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: const Color(0xFF8E7CFF).withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.warning_amber_rounded,
                        size: 40,
                        color: Color(0xFF8E7CFF),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      tr(context, "Active Character Limit", "حد الشخصيات النشطة"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr(context,
                          "You can only have up to 3 active characters at a time. Some characters were not added.",
                          "يمكنك الحصول على 3 شخصيات نشطة فقط في المرة الواحدة. لم تتم إضافة بعض الشخصيات."),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF4B3A66),
                        fontSize: 15,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EDFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          Text(
                            tr(context,
                                "Current active: $_activeCharacterCount of 3",
                                "النشط حالياً: $_activeCharacterCount من 3"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B3A66),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tr(context,
                                "Remaining slots: ${2 - _activeCharacterCount}",
                                "المساحة المتبقية: ${2 - _activeCharacterCount}"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF8E7CFF),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          break; // Stop adding more new characters
        }

        // New character - add to database
        final rank = nextRank + newCharactersCount;
        newCharactersCount++;
        totalActiveAfterOperations++; // Increment active count

        // Get display names
        String displayNameEn = _getEnglishDisplayName(characterName);
        String displayNameAr = _getArabicDisplayName(characterName);

        // If character has a display name from API, use it
        if (character is Map) {
          if (character.containsKey('character_name_en')) {
            displayNameEn = character['character_name_en'].toString();
            displayNameAr = character['character_name_ar']?.toString() ?? displayNameAr;
          } else if (character.containsKey('character_name')) {
            String singleName = character['character_name'].toString();
            bool isArabic = _isArabicText(singleName);

            if (isArabic) {
              displayNameAr = singleName;
            } else {
              displayNameEn = singleName;
            }
          }
        }

        final archetype = _determineArchetype(characterName);
        final glbFileName = _getGLBFileName(characterName);

        // Get descriptions
        String descriptionEn = _getEnglishDescription(characterName);
        String descriptionAr = _getArabicDescription(characterName);

        // Create character document reference
        final characterDocRef = _firestore.collection('user_characters').doc();

        // Create data - NO isHealed field!
        final characterData = {
          'userId': _currentUserId!,
          'characterName': characterName,
          'displayNameEn': displayNameEn,
          'displayNameAr': displayNameAr,
          'archetype': archetype,
          'confidence': confidence,
          'rank': rank,
          'language': detectedLanguage,
          'glbFileName': glbFileName,
          'descriptionEn': descriptionEn,
          'descriptionAr': descriptionAr,
          'predictedAt': timestamp.toIso8601String(),
          'isHealed': false,
          'currentState': 'active', // Only 'active' or 'inactive' states
        };

        batch.set(characterDocRef, characterData);
        print('📝 Adding new character: $characterName (Rank: $rank)');
      }

      if (newCharactersCount > 0 || reactivatedCharactersCount > 0) {
        await batch.commit();

        if (newCharactersCount > 0) {
          print('✅ Added $newCharactersCount new characters');
        }
        if (reactivatedCharactersCount > 0) {
          print('🔄 Reactivated $reactivatedCharactersCount inactive characters');
        }

        await _checkForCharacters();

        if (mounted) {
          String message;
          if (newCharactersCount > 0 && reactivatedCharactersCount > 0) {
            message = tr(context,
                '$newCharactersCount new and $reactivatedCharactersCount reactivated inner characters added!',
                'تم إضافة $newCharactersCount شخصيات جديدة وإعادة تفعيل $reactivatedCharactersCount شخصيات!'
            );
          } else if (newCharactersCount > 0) {
            message = tr(context,
                '$newCharactersCount new inner ${newCharactersCount == 1 ? 'character' : 'characters'} added!',
                'تم إضافة $newCharactersCount من الشخصيات الداخلية الجديدة!'
            );
          } else if (reactivatedCharactersCount > 0) {
            message = tr(context,
                '$reactivatedCharactersCount inactive inner ${reactivatedCharactersCount == 1 ? 'character has' : 'characters have'} been reactivated!',
                'تم إعادة تفعيل $reactivatedCharactersCount من الشخصيات الداخلية غير النشطة!'
            );
          } else {
            return; // No changes to report
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: const Color(0xFF8E7CFF),
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
      } else if (mounted && newCharactersCount == 0 && reactivatedCharactersCount == 0) {
        // No changes made, but analysis completed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context,
                  'Analysis completed, but no new characters were added or reactivated',
                  'تم اكتمال التحليل، ولكن لم تتم إضافة أو إعادة تفعيل شخصيات جديدة'),
            ),
            backgroundColor: const Color(0xFF8E7CFF).withOpacity(0.8),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }

    } catch (e) {
      print('❌ Error saving characters: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(context, 'Error saving characters', 'حدث خطأ في حفظ الشخصيات'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Helper method to get existing user characters
  Future<List<UserCharacter>> _getUserCharacters() async {
    try {
      if (_currentUserId == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      return querySnapshot.docs.map((doc) {
        return UserCharacter.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      }).toList();

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
      'Overeater/Binger': 'overeater_binger.glb',
      'Overwhelmed Part': 'overwhelmed_part.glb',
      'Stoic Part': 'stoic_part.glb',
      'Wounded Child': 'wounded_child.glb',
      'Controller': 'controller.glb',
      'Controller Part': 'controller.glb',
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
    } catch (e) {
      print('❌ Error getting current user: $e');
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
        'primaryCharacter': analysisResult['primary_character'] ?? 'Unknown',
        'confidence': analysisResult['confidence'] ?? 0.0,
        'characterName': analysisResult['character_name'] ?? '',
      };

      await _firestore.collection('reframe_sessions').add(sessionData);

      print('✅ Reframe session saved to database');
    } catch (e) {
      print('❌ Error saving to database: $e');
    }
  }

  // Text Analysis
  Future<void> _analyzeText() async {
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
        print('📊 API Response: $result');

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

          // Save high confidence characters (text input has no media files)
          await _saveHighConfidenceCharacters(
            analysisData,
            inputType: 'text',
          );

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
        print('📊 API Response: $result');

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

          // Save high confidence characters with media
          await _saveHighConfidenceCharacters(
            analysisData,
            audioFilePath: _audioFilePath,
            inputType: 'voice',
          );

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
        print('📊 API Response: $result');

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

          // Save high confidence characters with media
          await _saveHighConfidenceCharacters(
            analysisData,
            videoFilePath: _videoFilePath,
            audioFilePath: _videoAudioFilePath,
            inputType: 'video',
          );

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

  Future<void> _switchToMode(_ReframeMode newMode) async {
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
                            "You have $_activeCharacterCount active parts that need attention. Care for them first, then you can continue to new insights. (Inactive parts can be reactivated)",
                            "لديك $_activeCharacterCount جزء نشط يحتاج إلى اهتمامك. اعتني بهم أولاً، ثم يمكنك المتابعة لرؤى جديدة. (يمكن إعادة تفعيل الأجزاء غير النشطة)"
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF4B3A66),
                          height: 1.6,
                        ),
                      ),
                      // if (_inactiveCharacterCount > 0) ...[
                      // const SizedBox(height: 12),
                      //   Container(
                      //     padding: const EdgeInsets.all(12),
                      //    decoration: BoxDecoration(
                      //       color: const Color(0xFFF3EDFF),
                      //        borderRadius: BorderRadius.circular(12),
                      //     ),
                      //     child: Text(
                      //       tr(
                      //           context,
                      //          "You have $_inactiveCharacterCount inactive parts that can be reactivated through new sessions",
                      //          "لديك $_inactiveCharacterCount جزء غير نشط يمكن إعادة تفعيلها من خلال جلسات جديدة"
                      ///      ),
                      ///       textAlign: TextAlign.center,
                      //       style: const TextStyle(
                      //         fontSize: 13,
                      //         color: Color(0xFF8E7CFF),
                      //         fontWeight: FontWeight.w600,
                      //       ),
                      //     ),
                      //   ),
                      //  ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Original UI for users with less than 3 active characters
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

                  // Character count info
                  if (_activeCharacterCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3EDFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.info_outline,
                            size: 18,
                            color: const Color(0xFF8E7CFF),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            tr(
                                context,
                                "You have $_activeCharacterCount active part${_activeCharacterCount == 1 ? '' : 's'} to nurture",
                                "لديك $_activeCharacterCount جزء نشط للعناية به"
                            ),
                            style: TextStyle(
                              color: const Color(0xFF8E7CFF),
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

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
        );
      case _ReframeMode.voice:
        return _VoiceInputCard(
          key: const ValueKey('voice'),
          recording: _voiceRecording,
          isAnalyzing: _isAnalyzing,
          onToggle: _toggleVoiceRecording,
        );
      case _ReframeMode.video:
        return _VideoInputCard(
          key: const ValueKey('video'),
          cameraController: _cameraController,
          isCameraInitialized: _isCameraInitialized,
          isRecording: _videoRecording,
          isAnalyzing: _isAnalyzing,
          onToggleRecording: _toggleVideoRecording,
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
                  const SizedBox(height: 16),
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

  const _ChatInputCard({
    super.key,
    required this.controller,
    required this.hint,
    required this.isAnalyzing,
    required this.onAnalyze,
  });

  @override
  Widget build(BuildContext context) {
    final hasText = controller.text.trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5DEFF),
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
            enabled: true,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: const Color(0xFF4B3A66).withOpacity(0.5),
              ),
            ),
            style: const TextStyle(
              color: Color(0xFF4B3A66),
            ),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasText && !isAnalyzing ? onAnalyze : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hasText ? const Color(0xFF8E7CFF) : const Color(0xFFCCCCCC),
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

  const _VoiceInputCard({
    super.key,
    required this.recording,
    required this.isAnalyzing,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final color = recording ? const Color(0xFF8E7CFF) : const Color(0xFFEDE7FF);
    final iconColor = recording ? Colors.white : const Color(0xFF8E7CFF);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5DEFF),
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
                onTap: !isAnalyzing ? onToggle : null,
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
                      recording
                          ? tr(context, "Recording...", "جارٍ التسجيل...")
                          : tr(context, "Tap to record", "اضغط للتسجيل"),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4B3A66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      recording
                          ? tr(context, "Tap stop when finished", "اضغط إيقاف عند الانتهاء")
                          : tr(context, "Speak clearly for best results", "تحدث بوضوح للحصول على أفضل النتائج"),
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF4B3A66).withOpacity(0.7),
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

  const _VideoInputCard({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.isRecording,
    required this.isAnalyzing,
    required this.onToggleRecording,
  });

  @override
  Widget build(BuildContext context) {
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
              color: const Color(0xFFE5DEFF),
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
              color: const Color(0xFFE5DEFF),
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
                onTap: isCameraInitialized && !isAnalyzing ? onToggleRecording : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isRecording
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
                      !isCameraInitialized
                          ? tr(context, "Camera initializing...", "جاري تهيئة الكاميرا...")
                          : isRecording
                          ? tr(context, "Recording...", "جارٍ التسجيل...")
                          : tr(context, "Ready to record video", "جاهز لتسجيل فيديو"),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF4B3A66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isRecording
                          ? tr(context, "Tap stop when finished", "اضغط إيقاف عند الانتهاء")
                          : tr(context, "Look at the camera and speak", "انظر إلى الكاميرا وتحدث"),
                      style: TextStyle(
                        fontSize: 12,
                        color: const Color(0xFF4B3A66).withOpacity(0.7),
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