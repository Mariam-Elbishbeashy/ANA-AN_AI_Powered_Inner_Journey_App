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
    this.serverUrl = 'http://10.0.2.2:5005',
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
  int _stableCharacterCount = 0;
  // Add these variables at the top with your other variables
  bool _hasCheckedRestriction = false;
  bool _isRestricted = false;

  // Add this with your other variables at the top
  bool _shouldShowFullRestrictionPage = false;

  // Audio recording for video mode
  bool _videoAudioRecording = false;
  String? _videoAudioFilePath;
  final AudioRecorder _videoAudioRecorder = AudioRecorder();

  // Firebase
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final firebase_storage.FirebaseStorage _storage = firebase_storage.FirebaseStorage.instance;
  String? _currentUserId;

  // High confidence threshold
  final double _highConfidenceThreshold = 0.40;

  // Add cache for Arabic names
  final Map<String, String> _arabicNameCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _getCurrentUser();
    _testServerConnection();
    _chatController.addListener(_handleTextChange);
    // Don't show full restriction page on initial load
    _checkRestrictionForInputDisabling();
  }

  // New method - only checks restriction for disabling inputs, NOT for showing full page
  Future<void> _checkRestrictionForInputDisabling() async {
    await _refreshCharacterData();
    if (mounted) {
      setState(() {
        if (!_hasCheckedRestriction) {
          _hasCheckedRestriction = true;
        }
        _isRestricted = _shouldRestrictAccess();
        // IMPORTANT: DO NOT set _shouldShowFullRestrictionPage here
      });
    }
  }
  // Add a method to explicitly show restriction page when needed
  void _showFullRestrictionPageIfNeeded() {
    if (_shouldRestrictAccess() && !_hasCheckedRestriction) {
      setState(() {
        _shouldShowFullRestrictionPage = true;
      });
    }
  }
  // Add method to check restriction
  Future<void> _checkRestrictionOnReturn() async {
    await _refreshCharacterData();
    if (mounted) {
      setState(() {
        if (!_hasCheckedRestriction) {
          _hasCheckedRestriction = true;
        }
        _isRestricted = _shouldRestrictAccess();
      });
    }
  }

  // Refresh character data from database (only reads, no writes)
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

  Future<void> _checkForCharacters() async {
    try {
      if (_currentUserId == null) return;

      final querySnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .get();

      int activeCount = 0;
      int inactiveCount = 0;
      int stableCount = 0;

      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final currentState = data['currentState'] ?? 'active';

        if (currentState == 'active') {
          activeCount++;
        } else if (currentState == 'inactive') {
          inactiveCount++;
        } else if (currentState == 'stable') {
          stableCount++;
        }
      }

      if (mounted) {
        setState(() {
          _activeCharacterCount = activeCount;
          _inactiveCharacterCount = inactiveCount;
          _stableCharacterCount = stableCount;
          _isRestricted = _shouldRestrictAccess();
          // IMPORTANT: Do NOT change _shouldShowFullRestrictionPage here
        });
      }

      print('📊 Character Stats: $activeCount active, $inactiveCount inactive, $stableCount stable');

    } catch (e) {
      print('❌ Error checking characters: $e');
      if (mounted) {
        setState(() {
          _activeCharacterCount = 0;
          _inactiveCharacterCount = 0;
          _stableCharacterCount = 0;
          _isRestricted = false;
          // Do NOT change _shouldShowFullRestrictionPage here
        });
      }
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
                color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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
                  "You have $_activeCharacterCount active parts awaiting your attention. Please nurture them before discovering new insights. (Inactive and stable parts can be reactivated)",
                  "لديك $_activeCharacterCount جزءًا نشطًا تنتظر اهتمامك. يرجى رعايتها قبل اكتشاف رؤى جديدة. (يمكن إعادة تفعيل الأجزاء غير النشطة والمستقرة)"),
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

  // ===================== FIXED LOCALIZATION METHODS =====================

  // Helper method to detect if text is Arabic
  bool _isArabicText(String text) {
    if (text.isEmpty) return false;
    final arabicPattern = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    return arabicPattern.hasMatch(text);
  }

  // Helper method to get English display name (without "The" prefix)
  String _getEnglishDisplayName(String characterName) {
    // Remove "The " prefix if it exists
    String displayName = characterName;
    if (displayName.toLowerCase().startsWith('the ')) {
      displayName = displayName.substring(4);
    }
    // Capitalize first letter
    if (displayName.isNotEmpty) {
      displayName = displayName[0].toUpperCase() + displayName.substring(1);
    }
    return displayName;
  }

  // ✅ FIXED: Respect app language setting
  String _getLocalizedDisplayName(String characterName) {
    // Check if the app is in Arabic mode
    final isAppArabic = Localizations.localeOf(context).languageCode == 'ar';

    // If app is NOT Arabic, always return English
    if (!isAppArabic) {
      return _getEnglishDisplayName(characterName);
    }

    // App IS Arabic - translate to Arabic
    // First check if the character name itself is already in Arabic
    if (_isArabicText(characterName)) {
      return characterName;
    }

    // Check cache
    if (_arabicNameCache.containsKey(characterName)) {
      return _arabicNameCache[characterName]!;
    }

    // Translate to Arabic
    final result = _getArabicDisplayName(characterName);
    _arabicNameCache[characterName] = result;
    return result;
  }

  // ✅ FIXED: Respect app language setting for descriptions
  String _getLocalizedDescription(String englishName) {
    final isAppArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (isAppArabic) {
      return _getArabicDescription(englishName);
    } else {
      return _getEnglishDescription(englishName);
    }
  }

  // ✅ FIXED: Respect app language setting for emotions
  String _getLocalizedEmotionName(String englishEmotion) {
    final isAppArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (!isAppArabic) return englishEmotion;

    final arabicEmotions = {
      'Happy': 'سعيد',
      'Sad': 'حزين',
      'Angry': 'غاضب',
      'Fearful': 'خائف',
      'Surprised': 'مندهش',
      'Disgusted': 'مشمئز',
      'Neutral': 'محايد',
      'Joy': 'فرح',
      'Anxious': 'قلق',
      'Calm': 'هادئ',
      'Excited': 'متحمس',
      'Frustrated': 'محبط',
      'Guilty': 'مذنب',
      'Hopeful': 'متفائل',
      'Peaceful': 'مسالم',
      'Grateful': 'ممتن',
      'Lonely': 'وحيد',
      'Overwhelmed': 'مرهق',
    };

    return arabicEmotions[englishEmotion] ?? englishEmotion;
  }

  String _getArabicDisplayName(String englishName) {
    print('🔍 Translating: "$englishName"');

    // If the name is empty or null, return it
    if (englishName.isEmpty) return englishName;

    // Normalize the name: remove "The " prefix and trim
    String lookupName = englishName.trim();
    if (lookupName.toLowerCase().startsWith('the ')) {
      lookupName = lookupName.substring(4).trim();
    }

    // Also try with "Part" removed if present
    String lookupNameWithoutPart = lookupName;
    if (lookupName.toLowerCase().endsWith(' part')) {
      lookupNameWithoutPart = lookupName.substring(0, lookupName.length - 5).trim();
    }

    final arabicNames = {
      // With "The " prefix versions
      'The Inner Critic': 'الناقد الداخلي',
      'The Perfectionist': 'الكمالي',
      'The People Pleaser': 'المُرضي',
      'The Controller': 'المتحكم',
      'The Stoic Part': 'حمّال أسيّة',
      'The Workaholic': 'مدمن العمل',
      'The Confused Part': 'الجزء الحيران',
      'The Procrastinator': 'المماطل',
      'The Overeater': 'الآكل المفرط',
      'The Binger': 'المفرط',
      'The Overeater/Binger': 'الآكل المفرط',
      'The Excessive Gamer': 'اللاعب المفرط',
      'The Lonely Part': 'الجزء الوحيد',
      'The Fearful Part': 'الجزء الخائف',
      'The Neglected Part': 'الجزء المهمل',
      'The Ashamed Part': 'الجزء الخجول',
      'The Overwhelmed Part': 'الجزء المرهق',
      'The Dependent Part': 'الجزء المعتمد',
      'The Jealous Part': 'الجزء الغيور',
      'The Wounded Child': 'الطفل الجريح',

      // Without "The " prefix versions
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

      // ADD THESE VARIATIONS - exact matches from your data
      'InnerCritic': 'الناقد الداخلي',
      'PeoplePleaser': 'المُرضي',
      'LonelyPart': 'الجزء الوحيد',
      'JealousPart': 'الجزء الغيور',
      'AshamedPart': 'الجزء الخجول',
      'Workaholic': 'مدمن العمل',
      'Perfectionist': 'الكمالي',
      'Procrastinator': 'المماطل',
      'ExcessiveGamer': 'اللاعب المفرط',
      'ConfusedPart': 'الجزء الحيران',
      'DependentPart': 'الجزء المعتمد',
      'FearfulPart': 'الجزء الخائف',
      'NeglectedPart': 'الجزء المهمل',
      'Overeater': 'الآكل المفرط',
      'Binger': 'المفرط',
      'OvereaterBinger': 'الآكل المفرط',
      'OverwhelmedPart': 'الجزء المرهق',
      'StoicPart': 'حمّال أسيّة',
      'WoundedChild': 'الطفل الجريح',
      'Controller': 'المتحكم',
      'ControllerPart': 'المتحكم',

      // Add lowercase variations
      'inner critic': 'الناقد الداخلي',
      'people pleaser': 'المُرضي',
      'lonely part': 'الجزء الوحيد',
      'jealous part': 'الجزء الغيور',
      'ashamed part': 'الجزء الخجول',
      'workaholic': 'مدمن العمل',
      'perfectionist': 'الكمالي',
      'procrastinator': 'المماطل',
      'excessive gamer': 'اللاعب المفرط',
      'confused part': 'الجزء الحيران',
      'dependent part': 'الجزء المعتمد',
      'fearful part': 'الجزء الخائف',
      'neglected part': 'الجزء المهمل',
      'overeater': 'الآكل المفرط',
      'binger': 'المفرط',
      'overeater/binger': 'الآكل المفرط',
      'overwhelmed part': 'الجزء المرهق',
      'stoic part': 'حمّال أسيّة',
      'wounded child': 'الطفل الجريح',
      'controller': 'المتحكم',
      'controller part': 'المتحكم',
    };

    // Try exact match with original name first (includes "The ")
    if (arabicNames.containsKey(englishName)) {
      print('✅ Found exact match: "$englishName" -> "${arabicNames[englishName]}"');
      return arabicNames[englishName]!;
    }

    // Try exact match with lookup name (without "The ")
    if (arabicNames.containsKey(lookupName)) {
      print('✅ Found match: "$lookupName" -> "${arabicNames[lookupName]}"');
      return arabicNames[lookupName]!;
    }

    // Try with "Part" removed
    if (arabicNames.containsKey(lookupNameWithoutPart)) {
      print('✅ Found match without "Part": "$lookupNameWithoutPart" -> "${arabicNames[lookupNameWithoutPart]}"');
      return arabicNames[lookupNameWithoutPart]!;
    }

    // Try case-insensitive match
    final lowerLookupName = lookupName.toLowerCase();
    for (final entry in arabicNames.entries) {
      if (entry.key.toLowerCase() == lowerLookupName ||
          entry.key.toLowerCase() == englishName.toLowerCase()) {
        print('✅ Found case-insensitive match: "${entry.key}" -> "${entry.value}"');
        return entry.value;
      }
    }

    // Try partial match
    for (final entry in arabicNames.entries) {
      final keyLower = entry.key.toLowerCase();
      if (lowerLookupName.contains(keyLower) || keyLower.contains(lowerLookupName)) {
        print('✅ Found partial match: "${entry.key}" -> "${entry.value}"');
        return entry.value;
      }
    }

    // If no translation found, try to return a default translation
    print('❌ No translation found for: "$englishName" (lookup: "$lookupName")');

    // Return a generic translation based on the original name
    if (englishName.toLowerCase().contains('critic')) {
      return 'الناقد الداخلي';
    } else if (englishName.toLowerCase().contains('pleaser')) {
      return 'المُرضي';
    } else if (englishName.toLowerCase().contains('lonely')) {
      return 'الجزء الوحيد';
    } else if (englishName.toLowerCase().contains('jealous')) {
      return 'الجزء الغيور';
    } else if (englishName.toLowerCase().contains('ashamed')) {
      return 'الجزء الخجول';
    } else if (englishName.toLowerCase().contains('workaholic')) {
      return 'مدمن العمل';
    } else if (englishName.toLowerCase().contains('perfectionist')) {
      return 'الكمالي';
    } else if (englishName.toLowerCase().contains('procrastinator')) {
      return 'المماطل';
    } else if (englishName.toLowerCase().contains('gamer')) {
      return 'اللاعب المفرط';
    } else if (englishName.toLowerCase().contains('confused')) {
      return 'الجزء الحيران';
    } else if (englishName.toLowerCase().contains('dependent')) {
      return 'الجزء المعتمد';
    } else if (englishName.toLowerCase().contains('fearful')) {
      return 'الجزء الخائف';
    } else if (englishName.toLowerCase().contains('neglected')) {
      return 'الجزء المهمل';
    } else if (englishName.toLowerCase().contains('overeater') || englishName.toLowerCase().contains('binger')) {
      return 'الآكل المفرط';
    } else if (englishName.toLowerCase().contains('overwhelmed')) {
      return 'الجزء المرهق';
    } else if (englishName.toLowerCase().contains('stoic')) {
      return 'حمّال أسيّة';
    } else if (englishName.toLowerCase().contains('wounded')) {
      return 'الطفل الجريح';
    } else if (englishName.toLowerCase().contains('controller')) {
      return 'المتحكم';
    }

    return englishName;
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

  // Add this as a class method (outside any other method)
  String _safeTr(BuildContext context, String en, String ar) {
    try {
      return tr(context, en, ar);
    } catch (e) {
      // Fallback to English if translation fails
      return en;
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
                      color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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
                    _safeTr(context, "Cannot Create More Characters", "لا يمكن إنشاء المزيد من الشخصيات"),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _safeTr(context,
                        "You already have $_activeCharacterCount active parts. Please nurture them before discovering new insights or reactivating inactive/stable parts.",
                        "لديك بالفعل $_activeCharacterCount جزء نشط. يرجى رعايتها قبل اكتشاف رؤى جديدة أو إعادة تفعيل الأجزاء غير النشطة/المستقرة."),
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
                        _safeTr(context, "Got It", "حسناً"),
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

      print('📊 High confidence characters to process:');
      for (var char in highConfidenceCharacters) {
        print('   - ${char['character']} (${char['confidence']})');
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

      print('📚 Existing characters in database: ${existingCharactersSnapshot.docs.length}');
      for (final doc in existingCharactersSnapshot.docs) {
        final data = doc.data();
        print('   - "${data['characterName']}" (state: ${data['currentState'] ?? 'active'})');
      }

      // Create maps for quick lookup by character name (using normalized keys)
      Map<String, Map<String, dynamic>> activeCharacters = {};
      Map<String, Map<String, dynamic>> inactiveCharacters = {};
      Map<String, Map<String, dynamic>> stableCharacters = {};

      // Helper function to normalize a character name for matching
      String normalizeName(String name) {
        if (name.isEmpty) return '';
        // Remove "The " prefix if it exists
        String normalized = name.trim();
        if (normalized.toLowerCase().startsWith('the ')) {
          normalized = normalized.substring(4).trim();
        }
        // Convert to lowercase for case-insensitive matching
        return normalized.toLowerCase();
      }

      for (final doc in existingCharactersSnapshot.docs) {
        final data = doc.data();
        final characterName = data['characterName']?.toString().trim() ?? '';
        final normalizedKey = normalizeName(characterName);
        final currentState = data['currentState'] ?? 'active';

        if (characterName.isNotEmpty) {
          if (currentState == 'inactive') {
            inactiveCharacters[normalizedKey] = {
              ...data,
              'docId': doc.id,
              'originalName': characterName,
            };
            print('   📌 Found INACTIVE: "$characterName" (normalized: "$normalizedKey")');
          } else if (currentState == 'stable') {
            stableCharacters[normalizedKey] = {
              ...data,
              'docId': doc.id,
              'originalName': characterName,
            };
            print('   📌 Found STABLE: "$characterName" (normalized: "$normalizedKey")');
          } else if (currentState == 'active') {
            activeCharacters[normalizedKey] = {
              ...data,
              'docId': doc.id,
              'originalName': characterName,
            };
            print('   📌 Found ACTIVE: "$characterName" (normalized: "$normalizedKey")');
          }
        }
      }

      print('📊 Summary - Active: ${activeCharacters.length}, Inactive: ${inactiveCharacters.length}, Stable: ${stableCharacters.length}');

      int maxRank = 0;
      for (final doc in existingCharactersSnapshot.docs) {
        final rank = (doc.data()['rank'] as num?)?.toInt() ?? 0;
        if (rank > maxRank) {
          maxRank = rank;
        }
      }

      int nextRank = maxRank + 1;
      int newCharactersCount = 0;
      int reactivatedFromInactiveCount = 0;
      int reactivatedFromStableCount = 0;

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

        // Normalize the character name for lookup
        final normalizedKey = normalizeName(characterName);
        print('\n🔍 Processing character: "$characterName" (normalized: "$normalizedKey")');

        // Get confidence
        double confidence = 0.0;
        if (character is Map) {
          if (character.containsKey('confidence')) {
            confidence = (character['confidence'] as num?)?.toDouble() ?? 0.0;
          } else if (character.containsKey('score')) {
            confidence = (character['score'] as num?)?.toDouble() ?? 0.0;
          }
        }

        // FIRST: Check if character exists in ANY state (active, inactive, or stable)
        // using the normalized key

        // CASE 1: Character is already ACTIVE - skip
        if (activeCharacters.containsKey(normalizedKey)) {
          final activeData = activeCharacters[normalizedKey]!;
          print('⏭️ Character already active: "${activeData['originalName']}"');
          continue;
        }

        // CASE 2: Character is STABLE - reactivate it (preserve all original data)
        if (stableCharacters.containsKey(normalizedKey)) {
          final stableData = stableCharacters[normalizedKey]!;
          final originalName = stableData['originalName'] ?? characterName;
          print('   ✅ Found STABLE character: "$originalName"');

          // Check if reactivating would exceed the limit
          if (totalActiveAfterOperations >= 3) {
            print('🚫 Cannot reactivate stable character: Would exceed active character limit. Current active: $_activeCharacterCount, After operations: $totalActiveAfterOperations');

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
                          color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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
                        _safeTr(context, "Active Character Limit", "حد الشخصيات النشطة"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _safeTr(context,
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
                          _safeTr(context,
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

          // Reactivate the stable character WITHOUT changing other fields
          final docId = stableData['docId'];

          print('🔄 Reactivating stable character: "$originalName"');
          print('   Document ID: $docId');
          print('   Current state before: ${stableData['currentState']}');

          // ONLY update currentState to 'active' - preserve all other fields (confidence, description, etc.)
          final docRef = _firestore.collection('user_characters').doc(docId);
          batch.update(docRef, {
            'currentState': 'active',
            'reactivatedAt': timestamp.toIso8601String(),
            // DO NOT update confidence, predictedAt, or any other fields
          });

          print('   ✅ Reactivated stable character (preserved original data)');

          reactivatedFromStableCount++;
          totalActiveAfterOperations++;

          // Remove from stable map so we don't process again
          stableCharacters.remove(normalizedKey);
          continue;
        }

        // CASE 3: Character is INACTIVE - reactivate it (update with new data)
        if (inactiveCharacters.containsKey(normalizedKey)) {
          final inactiveData = inactiveCharacters[normalizedKey]!;
          final originalName = inactiveData['originalName'] ?? characterName;
          print('   ✅ Found INACTIVE character: "$originalName"');

          // Check if reactivating would exceed the limit
          if (totalActiveAfterOperations >= 3) {
            print('🚫 Cannot reactivate inactive character: Would exceed active character limit. Current active: $_activeCharacterCount, After operations: $totalActiveAfterOperations');

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
                          color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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
                        _safeTr(context, "Active Character Limit", "حد الشخصيات النشطة"),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _safeTr(context,
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
                          _safeTr(context,
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
          final docId = inactiveData['docId'];

          print('🔄 Reactivating inactive character: "$originalName"');
          print('   Document ID: $docId');

          // Update the existing inactive character to active
          final docRef = _firestore.collection('user_characters').doc(docId);
          batch.update(docRef, {
            'currentState': 'active',
            'confidence': confidence,
            'predictedAt': timestamp.toIso8601String(),
            'reactivatedAt': timestamp.toIso8601String(),
          });

          reactivatedFromInactiveCount++;
          totalActiveAfterOperations++;

          // Remove from inactive map so we don't process again
          inactiveCharacters.remove(normalizedKey);
          continue;
        }

        // CASE 4: Character doesn't exist - add as NEW (if under limit)
        print('   Character not found, attempting to add as NEW');

        if (totalActiveAfterOperations >= 3) {
          print('🚫 Cannot add new character: Would exceed active character limit. Current active: $_activeCharacterCount, After operations: $totalActiveAfterOperations');

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
                        color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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
                      _safeTr(context, "Active Character Limit", "حد الشخصيات النشطة"),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _safeTr(context,
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
                            _safeTr(context,
                                "Current active: $_activeCharacterCount of 3",
                                "النشط حالياً: $_activeCharacterCount من 3"),
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF4B3A66),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _safeTr(context,
                                "Remaining slots: ${3 - _activeCharacterCount}",
                                "المساحة المتبقية: ${3 - _activeCharacterCount}"),
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
        totalActiveAfterOperations++;

        print('📝 Adding NEW character: "$characterName" (Rank: $rank)');

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

        // Create data
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
          'currentState': 'active', // Only 'active', 'inactive', or 'stable' states
        };

        batch.set(characterDocRef, characterData);
      }

      print('\n📊 Summary before commit:');
      print('   New characters: $newCharactersCount');
      print('   Reactivated from INACTIVE: $reactivatedFromInactiveCount');
      print('   Reactivated from STABLE: $reactivatedFromStableCount');

      if (newCharactersCount > 0 || reactivatedFromInactiveCount > 0 || reactivatedFromStableCount > 0) {
        await batch.commit();
        print('✅ Batch commit successful');

        if (newCharactersCount > 0) {
          print('✅ Added $newCharactersCount new characters');
        }
        if (reactivatedFromInactiveCount > 0) {
          print('🔄 Reactivated $reactivatedFromInactiveCount characters from INACTIVE state');
        }
        if (reactivatedFromStableCount > 0) {
          print('🔄 Reactivated $reactivatedFromStableCount characters from STABLE state (preserved original data)');
        }

        await _checkForCharacters();

        if (mounted) {
          String message;
          if (newCharactersCount > 0 && (reactivatedFromInactiveCount > 0 || reactivatedFromStableCount > 0)) {
            message = _safeTr(context,
                '$newCharactersCount new and ${reactivatedFromInactiveCount + reactivatedFromStableCount} reactivated inner characters added!',
                'تم إضافة $newCharactersCount شخصيات جديدة وإعادة تفعيل ${reactivatedFromInactiveCount + reactivatedFromStableCount} شخصيات!'
            );
          } else if (newCharactersCount > 0) {
            message = _safeTr(context,
                '$newCharactersCount new inner ${newCharactersCount == 1 ? 'character' : 'characters'} added!',
                'تم إضافة $newCharactersCount من الشخصيات الداخلية الجديدة!'
            );
          } else if (reactivatedFromInactiveCount > 0 || reactivatedFromStableCount > 0) {
            int totalReactivated = reactivatedFromInactiveCount + reactivatedFromStableCount;
            message = _safeTr(context,
                '$totalReactivated inner ${totalReactivated == 1 ? 'character has' : 'characters have'} been reactivated!',
                'تم إعادة تفعيل $totalReactivated من الشخصيات الداخلية!'
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
      } else if (mounted && newCharactersCount == 0 && reactivatedFromInactiveCount == 0 && reactivatedFromStableCount == 0) {
        // No changes made, but analysis completed
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _safeTr(context,
                  'Analysis completed, but no new characters were added or reactivated',
                  'تم اكتمال التحليل، ولكن لم تتم إضافة أو إعادة تفعيل شخصيات جديدة'),
            ),
            backgroundColor: const Color(0xFF8E7CFF).withValues(alpha: 0.8),
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
              _safeTr(context, 'Error saving characters', 'حدث خطأ في حفظ الشخصيات'),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
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
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // This runs when returning to the screen (including after hot reload)
    _checkRestrictionForFullPageOnReload();
  }

// New method - checks and shows full restriction page ONLY on reload
  Future<void> _checkRestrictionForFullPageOnReload() async {
    await _refreshCharacterData();
    if (mounted) {
      final isCurrentlyRestricted = _shouldRestrictAccess();

      setState(() {
        _isRestricted = isCurrentlyRestricted;
        _hasCheckedRestriction = true;

        // Only show full restriction page if:
        // 1. User is restricted (has 3+ active characters)
        // 2. AND this is a reload (we can detect this by checking if inputs were previously enabled)
        // For simplicity, we'll show full page on reload if restricted
        // You can add more sophisticated detection if needed
        _shouldShowFullRestrictionPage = isCurrentlyRestricted;
      });
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

      // Get inner characters as array
      final innerCharacters = analysisResult['inner_characters'] ?? [];

      // Get emotions as array
      final List<Map<String, dynamic>> emotions = [];

      // Add face emotion if available
      if (analysisResult['face_emotion'] != null &&
          analysisResult['face_emotion'] != 'Unknown' &&
          analysisResult['face_emotion'] != 'Not Analyzed') {
        emotions.add({
          'type': 'face',
          'emotion': analysisResult['face_emotion'].toString(),
          'confidence': (analysisResult['face_confidence'] ?? 0.0).toDouble(),
        });
      }

      // Add hand gesture emotion if available
      if (analysisResult['hand_gesture_emotion'] != null &&
          analysisResult['hand_gesture_emotion'] != 'Neutral' &&
          analysisResult['hand_gesture_emotion'] != 'Unknown') {
        emotions.add({
          'type': 'gesture',
          'emotion': analysisResult['hand_gesture_emotion'].toString(),
          'confidence': (analysisResult['hand_gesture_confidence'] ?? 0.0).toDouble(),
          'gesture': analysisResult['hand_gesture']?.toString() ?? '',
        });
      }

      // Add voice emotions (all of them)
      final voiceEmotions = analysisResult['voice_emotions'] ?? [];
      for (var ve in voiceEmotions) {
        emotions.add({
          'type': 'voice',
          'emotion': ve['emotion']?.toString() ?? 'Unknown',
          'confidence': (ve['confidence'] ?? 0.0).toDouble(),
        });
      }

      // Add primary voice emotion if exists and not already added
      if (analysisResult['primary_voice_emotion'] != null &&
          analysisResult['primary_voice_emotion'] != 'Unknown') {
        // Check if already added to avoid duplicates
        bool alreadyAdded = emotions.any((e) =>
        e['type'] == 'voice' && e['emotion'] == analysisResult['primary_voice_emotion']);

        if (!alreadyAdded) {
          emotions.add({
            'type': 'voice',
            'emotion': analysisResult['primary_voice_emotion'].toString(),
            'confidence': (analysisResult['primary_voice_confidence'] ?? 0.0).toDouble(),
          });
        }
      }

      final sessionData = {
        // Required fields
        'userId': _currentUserId!,
        'inputType': inputType,
        'createdAt': FieldValue.serverTimestamp(),

        // Transcript (limited length)
        'transcript': transcript.length > 500 ? transcript.substring(0, 500) : transcript,

        // ALL classified characters as array
        'innerCharacters': innerCharacters.map((char) {
          return {
            'character': char['character']?.toString() ?? 'Unknown',
            'characterName': char['character_name']?.toString() ?? '',
            'confidence': (char['confidence'] ?? 0.0).toDouble(),
          };
        }).toList(),

        // ALL emotions as array
        'emotions': emotions,

        // Language info
        'language': language,

        // Keep these for backward compatibility (optional, can be removed later)
        'primaryCharacter': analysisResult['primary_character'] ?? 'Unknown',
        'confidence': analysisResult['confidence'] ?? 0.0,
        'characterName': analysisResult['character_name'] ?? '',
      };

      // Add optional fields only if they exist
      if (analysisResult['detected_language'] != null) {
        sessionData['detectedLanguage'] = analysisResult['detected_language'];
      }

      if (analysisResult['is_translated'] != null) {
        sessionData['isTranslated'] = analysisResult['is_translated'];
      }

      // Save to database
      await _firestore.collection('reframe_sessions').add(sessionData);

      print('✅ Reframe session saved with ${innerCharacters.length} characters and ${emotions.length} emotions');
      if (emotions.isNotEmpty) {
        print('   Emotions: ${emotions.map((e) => '${e['emotion']} (${e['type']})').join(', ')}');
      }

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

  // ===================== FIXED VOICE RECORDING METHODS =====================

  Future<void> _startVoiceRecording() async {
    try {
      if (!await Permission.microphone.isGranted) {
        final status = await Permission.microphone.request();
        if (!status.isGranted) return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _audioFilePath = '${dir.path}/audio_$timestamp.wav';

      // ✅ FIXED: Use 16000Hz for speech recognition
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // ✅ 16kHz for speech recognition
          numChannels: 1,      // Mono
          bitRate: 128000,     // 128kbps is sufficient for speech
        ),
        path: _audioFilePath!,
      );

      setState(() {
        _voiceRecording = true;
      });

      print('🎤 Started voice recording at 16kHz mono');

      // Auto-stop after 30 seconds to prevent long recordings
      Future.delayed(const Duration(seconds: 30), () {
        if (_voiceRecording) {
          _stopVoiceRecording();
          print('⏱️ Auto-stopped recording after 30 seconds');
        }
      });
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
          // Verify audio file before sending
          final size = await file.length();
          print('📊 Audio file size: $size bytes');

          if (size > 1000) { // At least 1KB
            await _sendAudioToServer();
          } else {
            print('❌ Audio file too small: $size bytes');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Recording too short. Please speak longer and try again.'),
                backgroundColor: Colors.orange,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
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
        print('❌ No audio file path');
        return;
      }

      final audioFile = File(_audioFilePath!);

      // Check file exists and has content
      if (!await audioFile.exists()) {
        print('❌ Audio file does not exist');
        return;
      }

      final fileSize = await audioFile.length();
      print('📊 Audio file size: $fileSize bytes');

      if (fileSize < 1000) {
        print('❌ Audio file too small: $fileSize bytes');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Recording too short or silent. Please speak louder and try again.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final bytes = await audioFile.readAsBytes();
      final base64Audio = base64Encode(bytes);

      print('📤 Sending audio (${bytes.length} bytes) to server...');

      final response = await http.post(
        Uri.parse('${widget.serverUrl}/api/analyze/audio'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'audio': base64Audio,
        }),
      ).timeout(const Duration(seconds: 15));

      print('📡 Server response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        print('📊 API Response: ${result.containsKey('success') ? result['success'] : 'unknown'}');

        if (result['success'] == true) {
          // ✅ Get both original and translated text
          final transcribedText = result['transcribed_text'] ?? '';
          final translatedText = result['translated_text'] ?? '';
          final isTranslated = result['is_translated'] ?? false;
          final detectedLanguage = result['detected_language'] ?? 'english';

          // ✅ For display: show the original transcribed text (Arabic if spoken in Arabic)
          final displayText = transcribedText;

          // ✅ For analysis: use translated text if available, otherwise use original
          final analysisText = isTranslated && translatedText.isNotEmpty ? translatedText : transcribedText;

          print('🔄 Original transcribed text: "$transcribedText"');
          print('🔄 Translated text: "$translatedText"');
          print('🔄 Using for analysis: "$analysisText"');
          print('🔄 Is translated: $isTranslated');
          print('🔄 Detected language: $detectedLanguage');

          if (transcribedText.isEmpty || transcribedText == 'No speech detected') {
            print('⚠️ No speech detected in recording');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('No speech detected. Please speak clearly and try again.'),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
                behavior: SnackBarBehavior.floating,
              ),
            );
          } else {
            print('✅ Transcribed: "$transcribedText"');
            if (isTranslated) {
              print('✅ Translated: "$translatedText"');
            }
          }

          // Rest of your response handling...
          final voiceEmotions = result['voice_emotions'] ?? [];
          final primaryVoiceEmotion = result['primary_voice_emotion'] ?? 'Unknown';
          final primaryVoiceConfidence = result['primary_voice_confidence'] ?? 0.0;

          final analysisData = {
            'type': 'audio',
            'isLoading': false,
            'input': 'Voice recording',
            // ✅ Store BOTH original and translated
            'transcribed_text': transcribedText,  // Original Arabic speech
            'translated_text': translatedText,    // English translation (if applicable)
            'display_text': displayText,          // What to display
            'primary_character': result['primary_character'],
            'character_name': result['character_name'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'inner_characters': result['inner_characters'] ?? [],
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
            transcript: analysisText, // Use translated text for analysis
            language: detectedLanguage,
            analysisResult: analysisData,
            audioFilePath: _audioFilePath,
          );

          await _saveHighConfidenceCharacters(
            analysisData,
            audioFilePath: _audioFilePath,
            inputType: 'voice',
          );

          _scrollToResults();
        } else {
          print('❌ Server returned error: ${result['error'] ?? 'Unknown error'}');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Analysis failed: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Server error: ${response.statusCode}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      print('❌ Audio send error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  // ===================== FIXED VIDEO RECORDING METHODS =====================

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

      // ✅ FIXED: Use 16000Hz for speech recognition
      await _videoAudioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,  // ✅ 16kHz for speech recognition
          numChannels: 1,     // Mono
          bitRate: 128000,
        ),
        path: _videoAudioFilePath!,
      );

      _videoAudioRecording = true;
      print('🎤 Hidden audio recording started at 16kHz mono');
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
          if (audioBytes.isNotEmpty) {
            base64Audio = base64Encode(audioBytes);
            print('✅ Audio included: ${audioBytes.length} bytes');
          } else {
            print('⚠️ Audio file is empty');
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
        print('📊 Full API Response: $result');

        if (result['success'] == true) {
          // ✅ Get both original and translated text
          final transcribedText = result['transcribed_text'] ?? '';
          final translatedText = result['translated_text'] ?? '';
          final isTranslated = result['is_translated'] ?? false;
          final detectedLanguage = result['detected_language'] ?? 'english';

          print('🔄 Original transcribed text: "$transcribedText"');
          print('🔄 Translated text: "$translatedText"');
          print('🔄 Is translated: $isTranslated');

          List innerCharacters = [];

          if (result.containsKey('inner_characters') && result['inner_characters'] != null) {
            innerCharacters = result['inner_characters'] as List;
            print('✅ Found inner_characters: $innerCharacters');
          } else if (result.containsKey('inner_characters_list') && result['inner_characters_list'] != null) {
            innerCharacters = result['inner_characters_list'] as List;
            print('✅ Found inner_characters_list: $innerCharacters');
          } else if (result.containsKey('predictions') && result['predictions'] != null) {
            innerCharacters = result['predictions'] as List;
            print('✅ Found predictions: $innerCharacters');
          } else if (result.containsKey('text_predictions') && result['text_predictions'] != null) {
            final textPredictions = result['text_predictions'].toString();
            innerCharacters = _parseTextPredictions(textPredictions);
            print('✅ Parsed text_predictions: $innerCharacters');
          } else if (result.containsKey('analysisResult') && result['analysisResult'] is Map) {
            final nested = result['analysisResult'] as Map;
            if (nested.containsKey('inner_characters')) {
              innerCharacters = nested['inner_characters'] as List;
              print('✅ Found nested inner_characters: $innerCharacters');
            }
          }

          if (innerCharacters.isEmpty) {
            if (result.containsKey('primary_character') &&
                result['primary_character'] != null &&
                result['primary_character'] != 'Unknown') {
              innerCharacters = [
                {
                  'character': result['primary_character'],
                  'character_name': result['character_name'] ?? result['primary_character'],
                  'confidence': result['confidence'] ?? 0.5,
                }
              ];
              print('✅ Created character from primary_character: $innerCharacters');
            }
          }

          final voiceEmotions = result['voice_emotions'] ?? [];
          final primaryVoiceEmotion = result['primary_voice_emotion'] ?? 'Unknown';
          final primaryVoiceConfidence = result['primary_voice_confidence'] ?? 0.0;

          final analysisData = {
            'type': 'video',
            'isLoading': false,
            'input': 'Video recording',
            // ✅ Store BOTH original and translated
            'transcribed_text': transcribedText,  // Original Arabic speech
            'translated_text': translatedText,    // English translation (if applicable)
            'display_text': transcribedText,      // What to display
            'primary_character': result['primary_character'] ?? 'Unknown',
            'character_name': result['character_name'] ?? '',
            'confidence': result['confidence'] ?? 0.0,
            'inner_characters': innerCharacters,
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

          print('📊 Final analysisData inner_characters: ${analysisData['inner_characters']}');

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

          await _saveHighConfidenceCharacters(
            analysisData,
            videoFilePath: _videoFilePath,
            audioFilePath: _videoAudioFilePath,
            inputType: 'video',
          );

          _scrollToResults();
        } else {
          print('❌ Server returned success=false');
          print('   Error: ${result['error'] ?? 'Unknown error'}');
        }
      } else {
        print('❌ HTTP error: ${response.statusCode}');
        print('   Response body: ${response.body}');
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

  List<Map<String, dynamic>> _parseTextPredictions(String predictionsText) {
    final List<Map<String, dynamic>> result = [];

    final pattern = RegExp(r'([^(]+)\(([0-9.]+)\)');
    final matches = pattern.allMatches(predictionsText);

    for (final match in matches) {
      if (match.groupCount >= 2) {
        final characterName = match.group(1)?.trim() ?? '';
        final confidence = double.tryParse(match.group(2) ?? '0') ?? 0.0;

        if (characterName.isNotEmpty) {
          result.add({
            'character': characterName,
            'character_name': characterName,
            'confidence': confidence,
          });
        }
      }
    }

    return result;
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

  // Add this method to get character data from database
  Future<Map<String, dynamic>?> _getCharacterFromDatabase(String characterName) async {
    try {
      if (_currentUserId == null) return null;

      final querySnapshot = await _firestore
          .collection('user_characters')
          .where('userId', isEqualTo: _currentUserId)
          .where('characterName', isEqualTo: characterName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      }
      return null;
    } catch (e) {
      print('❌ Error getting character from database: $e');
      return null;
    }
  }

  void _toggleVoiceRecording() {
    if (_voiceRecording) {
      _stopVoiceRecording();
    } else {
      _startVoiceRecording();
    }
  }

  Future<void> _testAudioRecording() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final testPath = '${dir.path}/test_audio_$timestamp.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: testPath,
      );

      await Future.delayed(const Duration(seconds: 2));
      await _audioRecorder.stop();

      final file = File(testPath);
      if (await file.exists()) {
        final size = await file.length();
        print('✅ Test audio recorded: $size bytes');

        final bytes = await file.readAsBytes();
        print('   Audio bytes length: ${bytes.length}');

        final base64Audio = base64Encode(bytes);
        final response = await http.post(
          Uri.parse('${widget.serverUrl}/api/debug/test-audio'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'audio': base64Audio}),
        );

        if (response.statusCode == 200) {
          print('✅ Server audio test response: ${response.body}');
        }
      } else {
        print('❌ Test audio file not created');
      }
    } catch (e) {
      print('❌ Test audio error: $e');
    }
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
    if (_shouldShowFullRestrictionPage && _hasCheckedRestriction && _isRestricted) {
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
                          color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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
                            "You have $_activeCharacterCount active parts that need attention. Care for them first, then you can continue to new insights.",
                            "لديك $_activeCharacterCount جزء نشط يحتاج إلى اهتمامك. اعتني بهم أولاً، ثم يمكنك المتابعة لرؤى جديدة."
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
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
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

                  if (_activeCharacterCount > 0) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isRestricted
                            ? const Color(0xFFFFF3E0)
                            : const Color(0xFFF3EDFF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isRestricted ? Icons.warning_amber_rounded : Icons.info_outline,
                            size: 18,
                            color: _isRestricted
                                ? const Color(0xFFFF9800)
                                : const Color(0xFF8E7CFF),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _isRestricted
                                  ? tr(
                                  context,
                                  "Maximum active parts reached ($_activeCharacterCount/3). Please nurture existing parts first.",
                                  "تم الوصول إلى الحد الأقصى للأجزاء النشطة ($_activeCharacterCount/3). يرجى رعاية الأجزاء الموجودة أولاً."
                              )
                                  : tr(
                                  context,
                                  "You have $_activeCharacterCount active part${_activeCharacterCount == 1 ? '' : 's'} to nurture",
                                  "لديك $_activeCharacterCount جزء نشط للعناية به"
                              ),
                              style: TextStyle(
                                color: _isRestricted
                                    ? const Color(0xFFFF9800)
                                    : const Color(0xFF8E7CFF),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],

                  Row(
                    children: [
                      Expanded(
                        child: _ModeCard(
                          title: tr(context, "Chat", "دردشة"),
                          icon: Icons.chat_bubble_rounded,
                          selected: _mode == _ReframeMode.chat,
                          enabled: !_isRestricted,
                          onTap: () => _switchToMode(_ReframeMode.chat),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModeCard(
                          title: tr(context, "Voice", "صوت"),
                          icon: Icons.mic_rounded,
                          selected: _mode == _ReframeMode.voice,
                          enabled: !_isRestricted,
                          onTap: () => _switchToMode(_ReframeMode.voice),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ModeCard(
                          title: tr(context, "Video", "فيديو"),
                          icon: Icons.videocam_rounded,
                          selected: _mode == _ReframeMode.video,
                          enabled: !_isRestricted,
                          onTap: () => _switchToMode(_ReframeMode.video),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: _buildModeContent(context),
                  ),

                  if (_analysisResult.isNotEmpty && _analysisResult['type'] != null) ...[
                    const SizedBox(height: 20),
                    _buildAnalysisResultCard(),
                  ],

                  // ✅ Extra bottom padding for better scrolling
                  const SizedBox(height: 30),
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
          isDisabled: _isRestricted,
        );
      case _ReframeMode.voice:
        return _VoiceInputCard(
          key: const ValueKey('voice'),
          recording: _voiceRecording,
          isAnalyzing: _isAnalyzing,
          onToggle: _toggleVoiceRecording,
          isDisabled: _isRestricted,
        );
      case _ReframeMode.video:
        return _VideoInputCard(
          key: const ValueKey('video'),
          cameraController: _cameraController,
          isCameraInitialized: _isCameraInitialized,
          isRecording: _videoRecording,
          isAnalyzing: _isAnalyzing,
          onToggleRecording: _toggleVideoRecording,
          isDisabled: _isRestricted,
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

    // ✅ FIXED: Always respect app language
    final isAppArabic = Localizations.localeOf(context).languageCode == 'ar';

    String displayName;

    if (isAppArabic) {
      // App is Arabic - use Arabic name
      if (characterName.isNotEmpty && _isArabicText(characterName)) {
        displayName = characterName;
      } else if (characterName.isNotEmpty) {
        displayName = _getLocalizedDisplayName(characterName);
      } else {
        displayName = _getLocalizedDisplayName(primaryCharacter);
      }
    } else {
      // App is English - always show English
      if (characterName.isNotEmpty) {
        displayName = _getEnglishDisplayName(characterName);
      } else {
        displayName = _getEnglishDisplayName(primaryCharacter);
      }
    }

    // Also handle the localized character name (the second line)
    String localizedCharacterName = '';
    if (characterName.isNotEmpty && characterName != primaryCharacter) {
      if (isAppArabic) {
        if (_isArabicText(characterName)) {
          localizedCharacterName = characterName;
        } else {
          localizedCharacterName = _getLocalizedDisplayName(characterName);
        }
      } else {
        localizedCharacterName = _getEnglishDisplayName(characterName);
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF8E7CFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            if (_analysisResult['input'] != null) ...[
              _buildSectionTitle(tr(context, "Input", "النص المدخل")),
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
                  textDirection: _isArabicText(_analysisResult['input']?.toString() ?? '')
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  textAlign: _isArabicText(_analysisResult['input']?.toString() ?? '')
                      ? TextAlign.right
                      : TextAlign.left,
                ),
              ),
            ],

            if (_analysisResult['transcribed_text'] != null &&
                _analysisResult['transcribed_text'].toString().isNotEmpty) ...[
              _buildSectionTitle(tr(context, "Transcribed Speech", "النص المحوّل")),
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
                  style: TextStyle(
                    color: const Color(0xFF4B3A66),
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    // Add Arabic font support
                    fontFamily: _isArabicText(_analysisResult['transcribed_text']?.toString() ?? '')
                        ? 'Cairo'
                        : null,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  textDirection: _isArabicText(_analysisResult['transcribed_text']?.toString() ?? '')
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  textAlign: _isArabicText(_analysisResult['transcribed_text']?.toString() ?? '')
                      ? TextAlign.right
                      : TextAlign.left,
                ),
              ),
            ],
            _buildSectionTitle(tr(context, "Primary Inner Character", "الشخصية الداخلية الأساسية")),
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
                  Container(
                    width: 80,
                    height: 80,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
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
                  // ✅ FIXED: Use localized name based on app language
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                    textAlign: TextAlign.center,
                    textDirection: _isArabicText(displayName)
                        ? TextDirection.rtl
                        : TextDirection.ltr,
                  ),
                  if (localizedCharacterName.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      localizedCharacterName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF8E7CFF),
                      ),
                      textAlign: TextAlign.center,
                      textDirection: _isArabicText(localizedCharacterName)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
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
                    tr(context,
                        '${confidence.toStringAsFixed(1)}% confidence',
                        '${confidence.toStringAsFixed(1)}% ثقة'
                    ),
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),

            if (innerCharacters.isNotEmpty) ...[
              _buildSectionTitle(tr(context, "Top Inner Characters", "أفضل الشخصيات الداخلية")),
              const SizedBox(height: 12),

              SizedBox(
                height: 220,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: innerCharacters.length.clamp(0, 5),
                  itemBuilder: (context, index) {
                    final character = innerCharacters[index];
                    String charDisplayName = character['character']?.toString() ?? 'Unknown';
                    String charName = character['character_name']?.toString() ?? '';
                    final charConfidence = (character['confidence'] ?? 0.0) * 100;
                    final isPrimary = charDisplayName == primaryCharacter;

                    // ✅ FIXED: Respect app language for inner characters
                    String localizedCharName;
                    if (isAppArabic) {
                      if (charName.isNotEmpty && _isArabicText(charName)) {
                        localizedCharName = charName;
                      } else if (charName.isNotEmpty) {
                        localizedCharName = _getLocalizedDisplayName(charName);
                      } else {
                        localizedCharName = _getLocalizedDisplayName(charDisplayName);
                      }
                    } else {
                      // English mode
                      if (charName.isNotEmpty) {
                        localizedCharName = _getEnglishDisplayName(charName);
                      } else {
                        localizedCharName = _getEnglishDisplayName(charDisplayName);
                      }
                    }

                    final cardWidth = 157.0;

                    return Container(
                      width: cardWidth,
                      margin: EdgeInsets.only(
                        right: index < innerCharacters.length.clamp(0, 5) - 1 ? 12 : 0,
                      ),
                      child: _buildCharacterCard(
                        displayName: localizedCharName,
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

            _buildEmotionsSection(),

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
                      tr(context,
                          'Analysis completed at ${_analysisResult['timestamp'] != null ? DateTime.parse(_analysisResult['timestamp']).toString().substring(0, 16) : 'unknown time'}',
                          'تم التحليل في ${_analysisResult['timestamp'] != null ? DateTime.parse(_analysisResult['timestamp']).toString().substring(0, 16) : 'وقت غير معروف'}'
                      ),
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
    // ✅ Get localized display name - this will now respect app language
    final localizedName = _getLocalizedDisplayName(displayName);
    final localizedCharacterName = characterName.isNotEmpty
        ? _getLocalizedDisplayName(characterName)
        : '';

    // ✅ Use the original English name for image lookup, not the localized one
    // The displayName parameter might be Arabic, but we need the English name for the image
    String imageLookupName = displayName;

    // If displayName is Arabic, find its English equivalent
    if (_isArabicText(displayName)) {
      final arabicToEnglish = {
        'الناقد الداخلي': 'Inner Critic',
        'الكمالي': 'Perfectionist',
        'المُرضي': 'People Pleaser',
        'المتحكم': 'Controller',
        'حمّال أسيّة': 'Stoic Part',
        'مدمن العمل': 'Workaholic',
        'الجزء الحيران': 'Confused Part',
        'المماطل': 'Procrastinator',
        'الآكل المفرط': 'Overeater',
        'المفرط': 'Binger',
        'اللاعب المفرط': 'Excessive Gamer',
        'الجزء الوحيد': 'Lonely Part',
        'الجزء الخائف': 'Fearful Part',
        'الجزء المهمل': 'Neglected Part',
        'الجزء الخجول': 'Ashamed Part',
        'الجزء المرهق': 'Overwhelmed Part',
        'الجزء المعتمد': 'Dependent Part',
        'الجزء الغيور': 'Jealous Part',
        'الطفل الجريح': 'Wounded Child',
      };

      if (arabicToEnglish.containsKey(displayName)) {
        imageLookupName = arabicToEnglish[displayName]!;
      } else {
        // Try partial match
        for (final entry in arabicToEnglish.entries) {
          if (displayName.contains(entry.key) || entry.key.contains(displayName)) {
            imageLookupName = entry.value;
            break;
          }
        }
      }
    }

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
              color: Colors.black.withValues(alpha: isPrimary ? 0.1 : 0.05),
              blurRadius: isPrimary ? 12 : 8,
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
              decoration: BoxDecoration(
                color: const Color(0xFFF9F6FF),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                border: isPrimary
                    ? Border.all(color: const Color(0xFF8E7CFF).withValues(alpha: 0.3))
                    : null,
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                child: Image.asset(
                  _getImagePathForCharacter(imageLookupName),
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
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ✅ UPDATED: Use localized name with proper RTL support
                    Text(
                      localizedName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                        height: 1.2,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: _isArabicText(localizedName)
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                    ),
                    if (localizedCharacterName.isNotEmpty) ...[
                      Text(
                        localizedCharacterName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF8E7CFF),
                          height: 1.2,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: _isArabicText(localizedCharacterName)
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                      ),
                    ],
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: charConfidence / 100,
                      backgroundColor: const Color(0xFFE5DEFF),
                      color: const Color(0xFF8E7CFF).withValues(alpha: 0.7),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    Text(
                      tr(context,
                          '${charConfidence.toStringAsFixed(1)}% confidence',
                          '${charConfidence.toStringAsFixed(1)}% ثقة'
                      ),
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
    // If the name is Arabic, translate it back to English for image lookup
    String lookupName = characterName;

    // Check if the name is Arabic and translate it to English
    if (_isArabicText(characterName)) {
      // Find the English name by searching the Arabic translation map
      final arabicNames = {
        'الناقد الداخلي': 'Inner Critic',
        'الكمالي': 'Perfectionist',
        'المُرضي': 'People Pleaser',
        'المتحكم': 'Controller',
        'حمّال أسيّة': 'Stoic Part',
        'مدمن العمل': 'Workaholic',
        'الجزء الحيران': 'Confused Part',
        'المماطل': 'Procrastinator',
        'الآكل المفرط': 'Overeater',
        'المفرط': 'Binger',
        'اللاعب المفرط': 'Excessive Gamer',
        'الجزء الوحيد': 'Lonely Part',
        'الجزء الخائف': 'Fearful Part',
        'الجزء المهمل': 'Neglected Part',
        'الجزء الخجول': 'Ashamed Part',
        'الجزء المرهق': 'Overwhelmed Part',
        'الجزء المعتمد': 'Dependent Part',
        'الجزء الغيور': 'Jealous Part',
        'الطفل الجريح': 'Wounded Child',
      };

      if (arabicNames.containsKey(characterName)) {
        lookupName = arabicNames[characterName]!;
        print('🖼️ Translated Arabic name "$characterName" to English "$lookupName" for image lookup');
      } else {
        // Try partial match for Arabic names
        for (final entry in arabicNames.entries) {
          if (characterName.contains(entry.key) || entry.key.contains(characterName)) {
            lookupName = entry.value;
            print('🖼️ Partial match: "$characterName" -> "$lookupName" for image lookup');
            break;
          }
        }
      }
    }

    // Remove "The " prefix if it exists for lookup
    if (lookupName.startsWith('The ')) {
      lookupName = lookupName.substring(4);
    }

    final imageMap = {
      'Inner Critic': 'assets/images/inner_critic.png',
      'People Pleaser': 'assets/images/people_pleaser.png',
      'Lonely Part': 'assets/images/lonely.png',
      'Jealous Part': 'assets/images/jealous.png',
      'Ashamed Part': 'assets/images/ashamed.png',
      'Workaholic': 'assets/images/workaholic.png',
      'Perfectionist': 'assets/images/perfictionist.png',
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

    if (imageMap.containsKey(lookupName)) {
      return imageMap[lookupName]!;
    }

    if (imageMap.containsKey(characterName)) {
      return imageMap[characterName]!;
    }

    final lowerName = lookupName.toLowerCase();
    for (final entry in imageMap.entries) {
      final keyLower = entry.key.toLowerCase();
      if (lowerName.contains(keyLower) || keyLower.contains(lowerName)) {
        return entry.value;
      }
    }

    // Default fallback
    return 'assets/images/inner_critic.png';
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title, // Pass the already localized title
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
    final isAppArabic = Localizations.localeOf(context).languageCode == 'ar';

    // ✅ Get detected language to show proper labels
    final detectedLanguage = _analysisResult['detected_language'] ?? 'english';
    final isInputArabic = detectedLanguage == 'arabic' ||
        detectedLanguage == 'egyptian' ||
        detectedLanguage == 'egyptian-transliterated';

    // ✅ Use Arabic labels if app is Arabic
    final useArabicLabels = isAppArabic;

    if (_analysisResult['face_emotion'] != null &&
        _analysisResult['face_emotion'] != 'Unknown') {
      emotions.add({
        'type': useArabicLabels ? 'انطباع الوجه' : 'Face Emotion',
        'emotion': useArabicLabels
            ? _getLocalizedEmotionName(_analysisResult['face_emotion'])
            : _analysisResult['face_emotion'],
        'confidence': _analysisResult['face_confidence'] ?? 0.0,
        'icon': Icons.face,
        'color': const Color(0xFF2196F3),
      });
    }

    if (_analysisResult['hand_gesture_emotion'] != null &&
        _analysisResult['hand_gesture_emotion'] != 'Neutral' &&
        _analysisResult['hand_gesture_emotion'] != 'Unknown') {
      emotions.add({
        'type': useArabicLabels ? 'انطباع الإيماءة' : 'Gesture Emotion',
        'emotion': useArabicLabels
            ? _getLocalizedEmotionName(_analysisResult['hand_gesture_emotion'])
            : _analysisResult['hand_gesture_emotion'],
        'confidence': _analysisResult['hand_gesture_confidence'] ?? 0.0,
        'icon': Icons.gesture,
        'color': const Color(0xFFFF9800),
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (emotions.isNotEmpty) ...[
          _buildSectionTitle(
              tr(context, "Detected Emotions", useArabicLabels ? "المشاعر المكتشفة" : "Detected Emotions")
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final int crossAxisCount = emotions.length <= 2 ? emotions.length :
              availableWidth < 300 ? 2 : 3;
              final double itemWidth = (availableWidth - (crossAxisCount - 1) * 8) / crossAxisCount;

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: emotions.map((emotion) {
                  final confidence = emotion['confidence'] as double;
                  return Container(
                    width: itemWidth,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (emotion['color'] as Color).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: emotion['color'] as Color),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          emotion['icon'] as IconData,
                          color: emotion['color'] as Color,
                          size: availableWidth < 350 ? 18 : 22,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          emotion['type'].toString(),
                          style: TextStyle(
                            fontSize: availableWidth < 350 ? 10 : 12,
                            color: const Color(0xFF4B3A66),
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          emotion['emotion'].toString(),
                          style: TextStyle(
                            fontSize: availableWidth < 350 ? 11 : 13,
                            fontWeight: FontWeight.w700,
                            color: emotion['color'] as Color,
                          ),
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Expanded(
                              child: LinearProgressIndicator(
                                value: confidence.clamp(0.0, 1.0),
                                backgroundColor: (emotion['color'] as Color).withValues(alpha: 0.2),
                                color: emotion['color'] as Color,
                                minHeight: 4,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${(confidence * 100).toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: availableWidth < 350 ? 9 : 11,
                                color: const Color(0xFF4B3A66),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 12),
        ],

        if (voiceEmotions is List && voiceEmotions.isNotEmpty) ...[
          _buildSectionTitle(
              tr(context, "Voice Tone Emotions", useArabicLabels ? "مشاعر نبرة الصوت" : "Voice Tone Emotions")
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final availableWidth = constraints.maxWidth;
              final isSmallScreen = availableWidth < 350;

              return Container(
                width: double.infinity,
                padding: EdgeInsets.all(isSmallScreen ? 10 : 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F7FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF8E7CFF).withValues(alpha: 0.3)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.volume_up_rounded,
                          color: const Color(0xFF8E7CFF),
                          size: isSmallScreen ? 18 : 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr(context, "Voice Tone Analysis", useArabicLabels ? "تحليل نبرة الصوت" : "Voice Tone Analysis"),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF2A1E3B),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...voiceEmotions.map((emotion) {
                      final emotionName = emotion['emotion']?.toString() ?? 'Unknown';
                      // ✅ Use localized emotion name based on app language
                      final localizedEmotionName = useArabicLabels
                          ? _getLocalizedEmotionName(emotionName)
                          : emotionName;
                      final confidence = (emotion['confidence'] ?? 0.0) as double;
                      final percentage = (confidence * 100);

                      return Padding(
                        padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 10),
                        child: isSmallScreen
                            ? _buildSmallVoiceEmotionRow(localizedEmotionName, confidence, percentage)
                            : _buildVoiceEmotionRow(localizedEmotionName, confidence, percentage),
                      );
                    }).toList(),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }

// Helper method for voice emotion row (large screens)
  Widget _buildVoiceEmotionRow(String emotionName, double confidence, double percentage) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(
            emotionName,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2A1E3B),
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${percentage.toStringAsFixed(0)}%',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: percentage > 50
                ? const Color(0xFF4CAF50)
                : const Color(0xFF757575),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 3,
          child: LinearProgressIndicator(
            value: confidence.clamp(0.0, 1.0),
            backgroundColor: const Color(0xFFE0E0E0),
            color: percentage > 50
                ? const Color(0xFF4CAF50)
                : const Color(0xFF8E7CFF),
            minHeight: 6,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ],
    );
  }

// Helper method for voice emotion row (small screens)
  Widget _buildSmallVoiceEmotionRow(String emotionName, double confidence, double percentage) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                emotionName,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${percentage.toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: percentage > 50
                    ? const Color(0xFF4CAF50)
                    : const Color(0xFF757575),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: confidence.clamp(0.0, 1.0),
          backgroundColor: const Color(0xFFE0E0E0),
          color: percentage > 50
              ? const Color(0xFF4CAF50)
              : const Color(0xFF8E7CFF),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
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
              color: Colors.black.withValues(alpha: 0.05),
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

class _ChatInputCard extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final bool isAnalyzing;
  final VoidCallback onAnalyze;
  final bool isDisabled;

  const _ChatInputCard({
    super.key,
    required this.controller,
    required this.hint,
    required this.isAnalyzing,
    required this.onAnalyze,
    this.isDisabled = false,
  });

  @override
  State<_ChatInputCard> createState() => _ChatInputCardState();
}

class _ChatInputCardState extends State<_ChatInputCard> {
  bool _isRTL = false;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _checkTextDirection(widget.controller.text);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    _checkTextDirection(widget.controller.text);
  }

  void _checkTextDirection(String text) {
    if (text.isEmpty) {
      if (_isRTL != false) {
        setState(() {
          _isRTL = false;
        });
      }
      return;
    }

    final arabicPattern = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final hasArabic = arabicPattern.hasMatch(text);
    final arabicNumbers = RegExp(r'[\u0660-\u0669]');
    final hasArabicNumbers = arabicNumbers.hasMatch(text);

    final isRTL = hasArabic || hasArabicNumbers;

    if (isRTL != _isRTL) {
      setState(() {
        _isRTL = isRTL;
      });

      if (isRTL) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final textLength = widget.controller.text.length;
          widget.controller.selection = TextSelection.collapsed(offset: textLength);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasText = widget.controller.text.trim().isNotEmpty;
    final canAnalyze = hasText && !widget.isAnalyzing && !widget.isDisabled;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: widget.isDisabled ? const Color(0xFFF5F5F5) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE5DEFF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: 200,
              minHeight: 80,
            ),
            child: Directionality(
              textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
              child: TextField(
                controller: widget.controller,
                focusNode: _focusNode,
                maxLines: null,
                minLines: 3,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
                enabled: !widget.isDisabled,
                textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
                textAlign: _isRTL ? TextAlign.right : TextAlign.left,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: widget.hint,
                  border: InputBorder.none,
                  hintStyle: TextStyle(
                    color: const Color(0xFF4B3A66).withValues(alpha: 0.5),
                  ),
                  hintTextDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 12,
                  ),
                ),
                style: TextStyle(
                  color: const Color(0xFF4B3A66),
                  fontSize: 16,
                  height: 1.5,
                  fontFamily: _isRTL ? 'Cairo' : null,
                ),
                onChanged: (text) {},
                scrollPhysics: const ClampingScrollPhysics(),
                scrollPadding: const EdgeInsets.all(20),
              ),
            ),
          ),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canAnalyze ? widget.onAnalyze : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: canAnalyze ? const Color(0xFF8E7CFF) : const Color(0xFFCCCCCC),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: widget.isAnalyzing
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

          if (_isRTL && !widget.isDisabled) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3EDFF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.text_format,
                        size: 12,
                        color: Color(0xFF8E7CFF),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'RTL',
                        style: TextStyle(
                          fontSize: 10,
                          color: const Color(0xFF8E7CFF),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],

          if (widget.isDisabled) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 16,
                    color: const Color(0xFFFF9800),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(context,
                          "You have 3 active parts. Please nurture them before adding more.",
                          "لديك 3 أجزاء نشطة. يرجى رعايتها قبل إضافة المزيد."),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFFF9800),
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
}

class _VoiceInputCard extends StatelessWidget {
  final bool recording;
  final bool isAnalyzing;
  final VoidCallback onToggle;
  final bool isDisabled;

  const _VoiceInputCard({
    super.key,
    required this.recording,
    required this.isAnalyzing,
    required this.onToggle,
    this.isDisabled = false,
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
            color: isDisabled ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5DEFF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: (!isAnalyzing && !isDisabled) ? onToggle : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDisabled ? const Color(0xFFCCCCCC) : color,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: isDisabled ? Colors.grey : iconColor,
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
                      isDisabled
                          ? tr(context, "Access Restricted", "الوصول مقيد")
                          : recording
                          ? tr(context, "Recording...", "جارٍ التسجيل...")
                          : tr(context, "Tap to record", "اضغط للتسجيل"),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDisabled ? Colors.grey : const Color(0xFF4B3A66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDisabled
                          ? tr(context, "You have 3 active parts", "لديك 3 أجزاء نشطة")
                          : recording
                          ? tr(context, "Tap stop when finished", "اضغط إيقاف عند الانتهاء")
                          : tr(context, "Speak clearly for best results", "تحدث بوضوح للحصول على أفضل النتائج"),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisabled ? Colors.grey : const Color(0xFF4B3A66).withValues(alpha: 0.7),
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
  final bool isDisabled;

  const _VideoInputCard({
    super.key,
    required this.cameraController,
    required this.isCameraInitialized,
    required this.isRecording,
    required this.isAnalyzing,
    required this.onToggleRecording,
    this.isDisabled = false,
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
            color: isDisabled ? const Color(0xFFEEEEEE) : Colors.black,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5DEFF),
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: isDisabled
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, "Access Restricted", "الوصول مقيد"),
                    style: TextStyle(
                      color: Colors.grey[400],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            )
                : (isCameraInitialized && cameraController != null
                ? _buildCameraPreview(context)
                : _buildCameraPlaceholder(context)),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          width: videoWidth,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDisabled ? const Color(0xFFF5F5F5) : Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFE5DEFF),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: (isCameraInitialized && !isAnalyzing && !isDisabled)
                    ? onToggleRecording
                    : null,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isDisabled
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
                    color: isDisabled ? Colors.grey : Colors.white,
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
                      isDisabled
                          ? tr(context, "Access Restricted", "الوصول مقيد")
                          : !isCameraInitialized
                          ? tr(context, "Camera initializing...",
                          "جاري تهيئة الكاميرا...")
                          : isRecording
                          ? tr(context, "Recording...",
                          "جارٍ التسجيل...")
                          : tr(context, "Ready to record video",
                          "جاهز لتسجيل فيديو"),
                      style: TextStyle(
                        fontSize: 16,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF4B3A66),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isDisabled
                          ? tr(context, "You have 3 active parts",
                          "لديك 3 أجزاء نشطة")
                          : isRecording
                          ? tr(context, "Tap stop when finished",
                          "اضغط إيقاف عند الانتهاء")
                          : tr(context, "Look at the camera and speak",
                          "انظر إلى الكاميرا وتحدث"),
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisabled
                            ? Colors.grey
                            : const Color(0xFF4B3A66).withValues(alpha: 0.7),
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

  // ✅ UPDATED: Shows camera without zoom/crop/filters
  Widget _buildCameraPreview(BuildContext context) {
    final cameraController = this.cameraController;
    if (cameraController == null || !cameraController.value.isInitialized) {
      return _buildCameraPlaceholder(context);
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final padding = 20.0;
    final videoWidth = screenWidth - (2 * padding);
    final containerHeight = 200.0;

    return Container(
      width: videoWidth,
      height: containerHeight,
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CameraPreview(cameraController),
        ),
      ),
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