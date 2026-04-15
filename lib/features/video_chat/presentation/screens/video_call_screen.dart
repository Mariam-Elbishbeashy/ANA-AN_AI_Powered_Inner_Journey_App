import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:o3d/o3d.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/models/inner_character_profile.dart';
import 'package:ana_ifs_app/features/video_chat/data/models/guider_intervention_model.dart';
import '../../data/repositories/video_session_repository.dart';
import '../../domain/entities/video_session.dart';

class VideoCallScreen extends StatefulWidget {
  final UserCharacter character;
  final String? existingSessionId;

  const VideoCallScreen({
    super.key,
    required this.character,
    this.existingSessionId,
  });

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  late final VideoSessionRepository _sessionRepository;
  VideoSession? _currentVideoSession;
  Timer? _durationTimer;
  int _callDurationSeconds = 0;
  String? _currentSessionId;
  String? _currentThreadId;

  bool _isMuted = false;
  bool _isVideoEnabled = true;
  late final String _characterModelPath;
  final O3DController _o3dController = O3DController();

  // Guider participation
  bool _guiderActive = false;
  bool _guiderSpeaking = false;
  String _guiderMessage = "";
  GuiderInterventionModel _intervention = GuiderInterventionModel.none;
  bool _showingIntervention = false;

  // Guider GIF animation
  static const String _guiderGifPath = 'assets/animations/guider.gif';

  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraDisposed = false;

  // Emotion detection variables
  String _emotionSessionId = "";
  static const String _emotionServerUrl = "http://192.168.100.7:5002";
  Timer? _emotionFrameTimer;
  bool _emotionActive = false;
  int _frameSkip = 0;
  String _lastFaceEmotion = "neutral";
  double _lastFaceConfidence = 0.0;
  String _lastVoiceEmotion = "neutral";
  double _lastVoiceConfidence = 0.0;
  Timer? _emotionSendTimer;
  bool _hasPendingEmotionUpdate = false;

  // Emotion detection keywords for local intervention
  final List<String> _harshEmotionKeywords = [
    'hate', 'hate it', 'i hate', 'fucking', 'shit', 'damn',
    'angry', 'mad', 'furious', 'rage', 'annoying', 'stressed',
    'overwhelmed', 'too much', 'can\'t handle', 'i can\'t', 'i cant',
    'depressed', 'hopeless', 'worthless', 'useless', 'stupid',
    'sick of', 'tired of', 'done with', 'give up', 'giving up',
    'scared', 'terrified', 'anxious', 'panic',
  ];

  final List<String> _crisisKeywords = [
    'suicidal', 'suicide', 'kill myself', 'hurt myself', 'self-harm',
    'end my life', 'don\'t want to live', 'better off dead',
  ];

  // Voice & agent variables
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _tts = FlutterTts();

  final _chatRemoteDataSource = ChatRemoteDataSource();
  final _localDataSource = InnerCharacterLocalDataSource();

  bool _audioReady = false;
  InnerCharacterProfile? _characterProfile;
  bool _voiceLoopActive = false;
  bool _isRecording = false;
  bool _isBusy = false;
  bool _isSpeaking = false;

  // Store current TTS settings
  double _currentSpeechRate = 0.5;
  double _currentPitch = 1.0;

  late String _characterIdForBackend;
  String _detectedLanguage = 'en';
  bool _languageDetected = false;

  String _status = "LIVE";
  String _lastUserText = "";
  String _lastAiText = "";
  final List<String> _textBuffer = [];
  String _visibleAiText = "";
  String _error = "";
  List<Map<String, String>> _conversationHistory = [];

  Timer? _maxTimer;
  Timer? _silenceTimer;
  Timer? _typingTimer;
  Timer? _restartTimer;
  StreamSubscription? _recorderSubscription;

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const Duration _maxRecord = Duration(seconds: 15);
  static const Duration _silenceThreshold = Duration(seconds: 2);
  static const double _silenceDbThreshold = -45.0;

  DateTime? _recordStartAt;
  String? _wavPath;
  bool _hasDetectedSpeech = false;
  double _currentDbLevel = -100.0;
  bool _stopping = false;

  // Backend endpoints - CORRECT for agents.py (port 5001)
  static const String _agentServerUrl = "http://192.168.100.7:5001";
  static const String _videoServerUrl = "http://192.168.100.7:5003";
  static const String _guiderUpdateEmotionsEndpoint = "/guider/update_emotions";
  static const String _chatEndpoint = "/chat";                    // ← CHANGE: remove /video/
  static const String _chatGuidedEndpoint = "/chat_guided";       // ← CHANGE: remove /video/
  static const String _transcribeEndpoint = "/video/transcribe";
  static const String _sessionSummaryEndpoint = "/video/session_summary";
  static const String _endSessionEndpoint = "/video/end_session";
  // ==========================
  // LOCALIZATION HELPERS
  // ==========================
  String _getStatusText() {
    if (_detectedLanguage == 'ar') {
      switch (_status) {
        case "LIVE": return "مباشر";
        case "GUIDED": return "موجّه";
        case "LISTENING": return "بيسمع";
        case "THINKING": return "مفكّر";
        case "SPEAKING": return "بيتكلم";
        case "PROCESSING": return "بيجهّز";
        case "TRANSCRIBING": return "بيعمل نسخ";
        case "MUTED": return "كتم الصوت";
        case "INVITING_GUIDER": return "دعوة المرشد";
        default: return _status;
      }
    } else {
      switch (_status) {
        case "LIVE": return "LIVE";
        case "GUIDED": return "GUIDED";
        case "LISTENING": return "LISTENING";
        case "THINKING": return "THINKING";
        case "SPEAKING": return "SPEAKING";
        case "PROCESSING": return "PROCESSING";
        case "TRANSCRIBING": return "TRANSCRIBING";
        case "MUTED": return "MUTED";
        case "INVITING_GUIDER": return "INVITING GUIDER";
        default: return _status;
      }
    }
  }

  String _getGuiderActiveText() {
    return _detectedLanguage == 'ar' ? "المرشد معاك" : "Guider Active";
  }

  String _getInviteGuiderText() {
    return _detectedLanguage == 'ar' ? "اطلب المرشد" : "Invite Guider";
  }

  String _getGuiderName() {
    return _detectedLanguage == 'ar' ? "المرشد" : "The Guider";
  }

  String _getContinueAloneText() {
    return _detectedLanguage == 'ar' ? "كمل لوحدي" : "Continue Alone";
  }

  String _getInviteGuiderButtonText() {
    return _detectedLanguage == 'ar' ? "اطلب المرشد" : "Invite Guider";
  }

  String _getGuiderSupportText() {
    return _detectedLanguage == 'ar'
        ? "المرشد هيظهر على الشاشة عشان يدعمك"
        : "Guider will join to provide support";
  }

  String _getEndGuiderTitle() {
    return _detectedLanguage == 'ar' ? "إنهاء جلسة المرشد" : "End Guider Session";
  }

  String _getEndGuiderContent() {
    return _detectedLanguage == 'ar'
        ? 'عايز المرشد يسيّب المحادثة؟'
        : 'Do you want The Guider to leave the conversation?';
  }

  String _getCancelText() {
    return _detectedLanguage == 'ar' ? 'إلغاء' : 'Cancel';
  }

  String _getEndText() {
    return _detectedLanguage == 'ar' ? 'إنهاء' : 'End';
  }

  String _getGuiderWelcomeMessage() {
    return _detectedLanguage == 'ar'
        ? "مرحباً، أنا هنا عشان أساعد. هانضم لمكالمتك مع ${widget.character.getDisplayName('ar')}."
        : "Hello, I'm here to help. I'll be joining your conversation with ${widget.character.displayNameEn}.";
  }

  String _getGuiderSupportMessage() {
    return _detectedLanguage == 'ar' ? "أنا هنا لدعمك" : "I'm here to support you.";
  }

  String _getGuiderExitMessage() {
    return _detectedLanguage == 'ar'
        ? "هانسحب دلوقتي. تقدر تكمل محادثتك."
        : "I'll step back now. You can continue your conversation.";
  }

  String _getManualInterventionMessage() {
    return _detectedLanguage == 'ar'
        ? 'عايز المرشد ينضم ويساعدك في توجيه المحادثة؟'
        : 'Would you like The Guider to join and help guide your conversation?';
  }

  String _getYouText() {
    return _detectedLanguage == 'ar' ? 'أنت' : 'You';
  }

  String _getOffText() {
    return _detectedLanguage == 'ar' ? 'مطفية' : 'OFF';
  }

  @override
  void initState() {
    super.initState();
    _sessionRepository = VideoSessionRepository();
    _characterIdForBackend = _getCharacterIdForBackend(widget.character.characterName);
    print("🎯 Character ID for backend: $_characterIdForBackend");
    _characterModelPath = _getModelPathForCharacter(widget.character.characterName);
    _initializeCamera();
    _initAudio();
    _loadCharacterProfile();
    _initializeSession();
    _initTts();
    _initializeEmotionSession();
    _startDurationTracking();
  }

  String _getCharacterIdForBackend(String characterName) {
    final idMap = {
      'Inner Critic': 'inner_critic', 'People Pleaser': 'people_pleaser',
      'Lonely Part': 'lonely', 'Jealous Part': 'jealous',
      'Ashamed Part': 'ashamed', 'Workaholic': 'workaholic',
      'Perfectionist': 'perfectionist', 'Procrastinator': 'procrastinator',
      'Excessive Gamer': 'excessive_gamer', 'Confused Part': 'confused',
      'Dependent Part': 'dependent', 'Fearful Part': 'fearful',
      'Neglected Part': 'neglected', 'Overeater': 'overater_binger',
      'Overeater/Binger': 'overater_binger', 'Overwhelmed Part': 'overwhelmed',
      'Stoic Part': 'stoic', 'Wounded Child': 'wounded_child',
      'Controller': 'controller', 'Controller Part': 'controller',
    };
    return idMap[characterName] ?? characterName.toLowerCase().replaceAll(' ', '_');
  }

  void _startDurationTracking() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_voiceLoopActive || _isBusy || _isSpeaking) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  Future<void> _initializeSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _emotionSessionId = "emotion_${DateTime.now().millisecondsSinceEpoch}";

      if (widget.existingSessionId != null && widget.existingSessionId!.isNotEmpty) {
        final session = await _sessionRepository.getVideoSession(
          uid: user.uid,
          sessionId: widget.existingSessionId!,
        );
        if (session != null && session.isActive) {
          setState(() {
            _currentVideoSession = session;
            _currentSessionId = session.id;
            _currentThreadId = session.threadId;
          });
          print("✅ Resuming session: $_currentSessionId, Thread: $_currentThreadId");
          return;
        }
      }

      final active = await _sessionRepository.getActiveVideoSession(
        uid: user.uid,
        characterId: _characterIdForBackend,
      );

      if (active != null) {
        setState(() {
          _currentVideoSession = active;
          _currentSessionId = active.id;
          _currentThreadId = active.threadId;
        });
        print("✅ Found active session: $_currentSessionId, Thread: $_currentThreadId");
        return;
      }

      final newSession = await _sessionRepository.createVideoSession(
        uid: user.uid,
        characterId: _characterIdForBackend,
        title: 'Video call with ${widget.character.displayNameEn}',
      );

      setState(() {
        _currentVideoSession = newSession;
        _currentSessionId = newSession.id;
        _currentThreadId = newSession.threadId;
      });
      print("✅ New session created: $_currentSessionId, Thread: $_currentThreadId");
    } catch (e) {
      print("❌ Session initialization error: $e");
    }
  }

  Future<void> _saveMessage(String role, String content, {String? sender}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentThreadId == null) return;

    await _sessionRepository.saveMessage(
      uid: user.uid,
      threadId: _currentThreadId!,
      role: role,
      content: content,
      sender: sender,
      characterId: role == 'assistant' ? _characterIdForBackend : null,
      sessionId: _currentSessionId,
    );
  }

  // ==========================
  // EMOTION DETECTION & INTERVENTION (FROM OLD CODE)
  // ==========================
  Future<void> _initializeEmotionSession() async {
    try {
      final response = await http.post(
        Uri.parse("$_emotionServerUrl/emotion/start_session"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': _emotionSessionId,
          'user_name': widget.character.displayNameEn,
          'character_id': _characterIdForBackend,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          print("✅ Emotion session started on $_emotionServerUrl");
          _emotionActive = true;
          _startEmotionFrameCapture();

          _emotionSendTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
            _sendPendingEmotions();
          });
        }
      }
    } catch (e) {
      print("⚠️ Emotion server not available: $e");
    }
  }

  void _startEmotionFrameCapture() {
    _emotionFrameTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_emotionActive && _isVideoEnabled && _isCameraInitialized && _cameraController != null) {
        _captureAndAnalyzeFrame();
      }
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    _frameSkip++;
    if (_frameSkip % 3 != 0) return;

    try {
      final XFile? imageFile = await _cameraController?.takePicture();
      if (imageFile == null) return;

      final bytes = await imageFile.readAsBytes();
      final base64Image = base64.encode(bytes);

      final response = await http.post(
        Uri.parse("$_emotionServerUrl/emotion/analyze_face"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': _emotionSessionId,
          'frame': 'data:image/jpeg;base64,$base64Image',
        }),
      ).timeout(const Duration(milliseconds: 2000));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['emotions'] != null && data['emotions'].isNotEmpty) {
          final faceEmotion = data['emotions'][0]['emotion'];
          final faceConfidence = data['emotions'][0]['confidence'];

          if (faceEmotion != null && faceConfidence != null) {
            _lastFaceEmotion = faceEmotion;
            _lastFaceConfidence = faceConfidence;
            _hasPendingEmotionUpdate = true;
            print("🎭 Face: $faceEmotion (${(faceConfidence * 100).toStringAsFixed(1)}%)");
          }
        }
      }
    } catch (e) {
    }
  }

  Future<void> _analyzeAudioEmotion(String audioPath) async {
    try {
      final bytes = await File(audioPath).readAsBytes();
      final base64Audio = base64.encode(bytes);

      final response = await http.post(
        Uri.parse("$_emotionServerUrl/emotion/analyze_audio"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'session_id': _emotionSessionId,
          'audio': 'data:audio/wav;base64,$base64Audio',
        }),
      ).timeout(const Duration(milliseconds: 3000));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['voice_emotion'] != null) {
          final voiceEmotion = data['voice_emotion']['emotion'];
          final voiceConfidence = data['voice_emotion']['confidence'];

          if (voiceEmotion != null && voiceConfidence != null) {
            _lastVoiceEmotion = voiceEmotion;
            _lastVoiceConfidence = voiceConfidence;
            _hasPendingEmotionUpdate = true;
            print("🎭 Voice: $voiceEmotion (${(voiceConfidence * 100).toStringAsFixed(1)}%)");

            if (_currentSessionId != null) {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                await _sessionRepository.addEmotion(
                  uid: user.uid,
                  sessionId: _currentSessionId!,
                  emotion: voiceEmotion,
                );
              }
            }
          }
        }
      }
    } catch (e) {
      print("⚠️ Voice emotion analysis error: $e");
    }
  }

  Future<void> _sendPendingEmotions() async {
    if (!_hasPendingEmotionUpdate) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.post(
        Uri.parse("$_videoServerUrl$_guiderUpdateEmotionsEndpoint"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': user.uid,
          'sessionId': _currentSessionId,
          'faceEmotion': _lastFaceEmotion,
          'faceConfidence': _lastFaceConfidence,
          'voiceEmotion': _lastVoiceEmotion,
          'voiceConfidence': _lastVoiceConfidence,
        }),
      ).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        _hasPendingEmotionUpdate = false;
        print("✅ Emotions saved to Firestore: Face=$_lastFaceEmotion, Voice=$_lastVoiceEmotion");
      } else {
        print("⚠️ Failed to save emotions: ${response.statusCode}");
      }
    } catch (e) {
      print("⚠️ Failed to send emotions: $e");
    }
  }

  Future<void> _endEmotionSession() async {
    _emotionActive = false;
    _emotionFrameTimer?.cancel();
    _emotionSendTimer?.cancel();

    await _sendPendingEmotions();

    try {
      await http.post(
        Uri.parse("$_emotionServerUrl/emotion/end_session"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'session_id': _emotionSessionId}),
      ).timeout(const Duration(seconds: 3));
      print("✅ Emotion session ended");
    } catch (e) {
      print("⚠️ Could not end emotion session: $e");
    }
  }

  // ==========================
  // LOCAL EMOTION DETECTION & INTERVENTION (FROM OLD CODE)
  // ==========================
  void _checkEmotionAndIntervene(String transcript) {
    if (_guiderActive || _showingIntervention) return;

    final lowerText = transcript.toLowerCase();

    // Check for crisis keywords
    for (final keyword in _crisisKeywords) {
      if (lowerText.contains(keyword)) {
        _showGuiderInvitation('crisis', 'high',
            "I notice you're expressing very difficult feelings. Would you like The Guider to join and help you through this?");
        return;
      }
    }

    // Count harsh emotion keywords
    int harshCount = 0;
    for (final keyword in _harshEmotionKeywords) {
      if (lowerText.contains(keyword)) {
        harshCount++;
      }
    }

    // Trigger based on intensity
    if (harshCount >= 3) {
      _showGuiderInvitation('high_emotion', 'high',
          "I can hear you're going through something intense. Would you like The Guider to join and provide support?");
    } else if (harshCount >= 2) {
      _showGuiderInvitation('emotional', 'medium',
          "It sounds like you're feeling strong emotions. The Guider is here if you'd like someone to talk to.");
    } else if (harshCount >= 1) {
      _showGuiderInvitation('mild_emotion', 'low',
          "I'm here for you. Would you like The Guider to join our conversation?");
    }
  }

  void _showGuiderInvitation(String reason, String severity, String message) {
    if (_showingIntervention || _guiderActive) return;

    setState(() {
      _intervention = GuiderInterventionModel(
        shouldIntervene: true,
        reason: reason,
        severity: severity,
        guiderMessage: message,
      );
      _showingIntervention = true;
      _status = "INVITING_GUIDER";
      _stopAll();
    });
  }

  Future<void> _handleGuiderInvitation(bool accept) async {
    if (!mounted) return;

    setState(() {
      _showingIntervention = false;
    });

    if (accept) {
      setState(() {
        _guiderActive = true;
        _status = "GUIDED";
        _intervention = GuiderInterventionModel.none;
      });

      if (_currentSessionId != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await _sessionRepository.setGuiderJoined(
            uid: user.uid,
            sessionId: _currentSessionId!,
            guiderJoined: true,
          );
        }
      }

      final message = _getGuiderWelcomeMessage();
      await _speakText(message, isGuider: true);
      _guiderMessage = _getGuiderSupportMessage();

      await Future.delayed(const Duration(milliseconds: 500));
      _startVoiceLoop();
    } else {
      setState(() {
        _status = "LIVE";
        _intervention = GuiderInterventionModel.none;
      });
      _startVoiceLoop();
    }
  }

  Future<void> _toggleGuider() async {
    if (_guiderActive) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(_getEndGuiderTitle()),
          content: Text(_getEndGuiderContent()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(_getCancelText()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(_getEndText()),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        setState(() {
          _guiderActive = false;
          _guiderMessage = "";
          _status = "LIVE";
        });

        if (_currentSessionId != null) {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null) {
            await _sessionRepository.setGuiderJoined(
              uid: user.uid,
              sessionId: _currentSessionId!,
              guiderJoined: false,
            );
          }
        }

        final message = _getGuiderExitMessage();
        await _speakText(message, isGuider: true);
      }
    } else {
      _showGuiderInvitation('manual', 'low', _getManualInterventionMessage());
    }
  }

  // ==========================
  // LANGUAGE DETECTION
  // ==========================
  String _detectLanguageFromText(String text) {
    if (text.isEmpty) return _detectedLanguage;

    final arabicRegex = RegExp(r'[\u0600-\u06FF\u0750-\u077F\u08A0-\u08FF\uFB50-\uFDFF\uFE70-\uFEFF]');
    final hasArabic = arabicRegex.hasMatch(text);
    final arabicCount = arabicRegex.allMatches(text).length;
    final englishCount = RegExp(r'[a-zA-Z]').allMatches(text).length;

    final egyptianWords = ['ايه', 'ازيك', 'عايز', 'عاوز', 'بتاع', 'دي', 'ده', 'دول', 'احنا', 'انتي', 'انتا', 'بتعمل', 'عشان', 'لأ', 'ايوه', 'اه'];
    bool hasEgyptianArabic = false;
    for (var word in egyptianWords) {
      if (text.contains(word)) {
        hasEgyptianArabic = true;
        break;
      }
    }

    if ((hasArabic && arabicCount > englishCount) || hasEgyptianArabic) {
      return 'ar';
    } else {
      return 'en';
    }
  }

  Future<void> _updateTtsLanguage(String language) async {
    try {
      if (language == 'ar') {
        await _tts.setLanguage("ar-EG");
        await _tts.setSpeechRate(0.45);
      } else {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.5);
      }
      print("🎤 TTS language updated to: ${language == 'ar' ? 'Egyptian Arabic' : 'English'}");
    } catch (e) {
      print("❌ Error updating TTS language: $e");
      if (language == 'ar') {
        try {
          await _tts.setLanguage("ar-SA");
          print("🎤 Fallback to Standard Arabic");
        } catch (e2) {
          print("❌ Fallback also failed: $e2");
        }
      }
    }
  }

  // ==========================
  // CHARACTER-SPECIFIC VOICE SETTINGS (FROM OLD CODE)
  // ==========================
  Map<String, dynamic> _getCharacterVoiceSettings(String characterName) {
    final Map<String, dynamic> settings = {
      'rate': 0.45,
      'pitch': 1.0,
      'volume': 1.0,
    };

    final List<String> maleCharacters = [
      'Dependent Part', 'Lonely Part', 'Excessive Gamer', 'Inner Critic',
      'Workaholic', 'Controller', 'Controller Part',
    ];

    final List<String> femaleCharacters = [
      'Jealous Part', 'Neglected Part', 'Stoic Part', 'Overeater',
      'Binger', 'Overeater/Binger', 'Wounded Child', 'People Pleaser',
      'Ashamed Part', 'Fearful Part', 'Overwhelmed Part', 'Perfectionist',
      'Procrastinator', 'Confused Part',
    ];

    if (maleCharacters.contains(characterName)) {
      settings['pitch'] = 0.85;
      settings['rate'] = 0.48;
    } else if (femaleCharacters.contains(characterName)) {
      settings['pitch'] = 1.25;
      settings['rate'] = 0.52;
    }

    switch (characterName) {
      case 'Inner Critic':
        settings['rate'] = 0.50;
        settings['pitch'] = 0.75;
        settings['volume'] = 1.1;
        break;
      case 'Wounded Child':
        settings['rate'] = 0.32;
        settings['pitch'] = 1.65;
        settings['volume'] = 0.55;
        break;
      case 'Workaholic':
        settings['rate'] = 0.65;
        settings['pitch'] = 0.88;
        settings['volume'] = 0.95;
        break;
      case 'People Pleaser':
        settings['rate'] = 0.58;
        settings['pitch'] = 1.35;
        settings['volume'] = 1.0;
        break;
    }

    return settings;
  }

  // ==========================
  // AGENT METHODS
  // ==========================
  Future<Map<String, dynamic>> _sendToAgent({
    required String uid,
    required String transcript,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final uri = Uri.parse("$_agentServerUrl$_chatEndpoint");

    final Map<String, dynamic> characterProfile;
    if (_characterProfile != null) {
      characterProfile = _characterProfile!.toPromptMap(
        useArabic: _detectedLanguage == 'ar',
      );
    } else {
      characterProfile = {
        'displayName': _detectedLanguage == 'ar'
            ? widget.character.getDisplayName('ar')
            : widget.character.displayNameEn,
        'id': _characterIdForBackend,
        'characterName': widget.character.characterName,
      };
    }

    final List<Map<String, String>> messages = [
      ...conversationHistory,
      {'role': 'user', 'content': transcript}
    ];

    final requestBody = {
      'uid': uid,
      'characterId': _characterIdForBackend,
      'characterProfile': characterProfile,
      'messages': messages,
      'sessionId': _currentSessionId,
      'threadId': _currentThreadId,
      'checkIntervention': false, // We handle emotion detection locally
      'language': _detectedLanguage,
    };

    print("📤 Sending to agent at ${uri.toString()}");
    print("📤 Language: ${_detectedLanguage == 'ar' ? 'Egyptian Arabic' : 'English'}");
    print("📤 CharacterId: $_characterIdForBackend");

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("✅ Agent response received");
      return data;
    }
    print("❌ Agent error: ${response.statusCode} - ${response.body}");
    throw Exception("HTTP ${response.statusCode}");
  }

  Future<Map<String, dynamic>> _sendToGuidedAgent({
    required String uid,
    required String transcript,
    required List<Map<String, String>> conversationHistory,
  }) async {
    final uri = Uri.parse("$_agentServerUrl$_chatGuidedEndpoint");

    final Map<String, dynamic> characterProfile;
    if (_characterProfile != null) {
      characterProfile = _characterProfile!.toPromptMap(
        useArabic: _detectedLanguage == 'ar',
      );
    } else {
      characterProfile = {
        'displayName': _detectedLanguage == 'ar'
            ? widget.character.getDisplayName('ar')
            : widget.character.displayNameEn,
        'id': _characterIdForBackend,
        'characterName': widget.character.characterName,
      };
    }

    final List<Map<String, dynamic>> guidedMessages = [];
    for (final msg in conversationHistory) {
      guidedMessages.add({
        'sender': msg['role'] == 'user' ? 'user' : widget.character.displayNameEn,
        'content': msg['content'],
      });
    }
    guidedMessages.add({
      'sender': 'user',
      'content': transcript,
    });

    final requestBody = {
      'uid': uid,
      'characterId': _characterIdForBackend,
      'characterProfile': characterProfile,
      'messages': guidedMessages,
      'sessionId': _currentSessionId,
      'threadId': _currentThreadId,
      'language': _detectedLanguage,
    };

    print("📤 Sending to guided agent at ${uri.toString()}");
    print("📤 Language: ${_detectedLanguage == 'ar' ? 'Egyptian Arabic' : 'English'}");
    print("📤 CharacterId: $_characterIdForBackend");
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("✅ Guided agent response received");
      return data;
    }
    print("❌ Guided agent error: ${response.statusCode} - ${response.body}");
    throw Exception("HTTP ${response.statusCode}");
  }

  Future<void> _processUserMessage(String transcript) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw Exception("User not logged in");

    print("📝 Processing user message: '$transcript'");

    final detectedLang = _detectLanguageFromText(transcript);
    if (detectedLang != _detectedLanguage) {
      print("🌐 Language changed: ${_detectedLanguage} -> $detectedLang");
      setState(() {
        _detectedLanguage = detectedLang;
        _languageDetected = true;
      });
      await _updateTtsLanguage(detectedLang);
    }

    setState(() {
      _lastUserText = transcript;
      _status = "THINKING";
    });

    await _saveMessage('user', transcript, sender: 'user');

    // Check emotion and trigger intervention if needed (FROM OLD CODE)
    if (!_guiderActive && !_showingIntervention) {
      _checkEmotionAndIntervene(transcript);
      if (_showingIntervention) {
        setState(() => _isBusy = false);
        return;
      }
    }

    // Send to appropriate endpoint
    Map<String, dynamic> response;
    if (_guiderActive) {
      response = await _sendToGuidedAgent(
        uid: user.uid,
        transcript: transcript,
        conversationHistory: _conversationHistory,
      );
    } else {
      response = await _sendToAgent(
        uid: user.uid,
        transcript: transcript,
        conversationHistory: _conversationHistory,
      );
    }

    if (response['success'] == true) {
      String characterMessage = '';
      String guiderMessage = '';

      if (_guiderActive) {
        characterMessage = response['characterMessage'] ?? '';
        guiderMessage = response['guiderMessage'] ?? '';

        if (characterMessage.isNotEmpty) {
          print("🤖 Character response: $characterMessage");
          await _saveMessage('assistant', characterMessage, sender: _characterIdForBackend);
          _startTypingAnimation(characterMessage);
          await _speakText(characterMessage);
          await Future.delayed(const Duration(milliseconds: 500));
        }

        if (guiderMessage.isNotEmpty) {
          print("👤 Guider response: $guiderMessage");
          await _saveMessage('assistant', guiderMessage, sender: 'guider');
          await _speakText(guiderMessage, isGuider: true);
        }
      } else {
        characterMessage = response['assistantMessage'] ?? '';
        print("🤖 Character response: $characterMessage");
        await _saveMessage('assistant', characterMessage, sender: _characterIdForBackend);
        _startTypingAnimation(characterMessage);
        await _speakText(characterMessage);
      }

      _conversationHistory.add({'role': 'user', 'content': transcript});
      if (characterMessage.isNotEmpty) {
        _conversationHistory.add({'role': 'assistant', 'content': characterMessage});
      }

      if (_conversationHistory.length > 20) {
        _conversationHistory = _conversationHistory.sublist(_conversationHistory.length - 20);
      }

      setState(() {
        _lastAiText = characterMessage;
        _textBuffer.clear();
        _visibleAiText = "";
        _isBusy = false;
        _status = _guiderActive ? "GUIDED" : "LIVE";
      });
    } else {
      throw Exception(response['error'] ?? 'Unknown error');
    }
  }

  // ==========================
  // AUDIO & VOICE METHODS
  // ==========================
  Future<void> _initAudio() async {
    try {
      print("🎤 Initializing audio...");
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        setState(() {
          _error = "Microphone permission denied";
        });
        return;
      }
      await _recorder.openRecorder();
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      setState(() {
        _audioReady = true;
      });
      print("✅ Audio initialized successfully");
      _startVoiceLoop();
    } catch (e) {
      print("❌ Audio init error: $e");
      setState(() {
        _error = "Audio init error: $e";
      });
    }
  }

  Future<String> _makeWavPath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "${dir.path}/video_user_$timestamp.wav";
  }

  void _setupVoiceDetection() {
    _recorderSubscription?.cancel();
    _recorderSubscription = _recorder.onProgress!.listen((event) {
      if (!_isRecording || _stopping) return;
      final dbLevel = event.decibels ?? -100.0;
      _currentDbLevel = dbLevel;
      if (dbLevel > _silenceDbThreshold) {
        if (!_hasDetectedSpeech) {
          _hasDetectedSpeech = true;
          print("🎤 Speech detected");
        }
        _silenceTimer?.cancel();
        _silenceTimer = Timer(_silenceThreshold, () {
          if (_hasDetectedSpeech && _isRecording && !_stopping) {
            print("🔇 Silence threshold reached - processing");
            _stopRecordingAndSend();
          }
        });
      }
    });
  }

  Future<void> _startRecordingWithAutoStop() async {
    if (!_voiceLoopActive || _isMuted) return;
    if (_isSpeaking || _isBusy || _isRecording || _guiderSpeaking) return;

    _stopping = false;
    _hasDetectedSpeech = false;

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      setState(() {
        _isRecording = true;
        _status = "LISTENING";
      });

      _wavPath = await _makeWavPath();
      final file = File(_wavPath!);
      if (await file.exists()) {
        await file.delete();
      }

      _recordStartAt = DateTime.now();
      await _recorder.startRecorder(
        toFile: _wavPath!,
        codec: Codec.pcm16WAV,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
      );
      _setupVoiceDetection();
      _maxTimer?.cancel();
      _maxTimer = Timer(_maxRecord, () async {
        if (!_voiceLoopActive || !_isRecording) return;
        print("⏰ Max recording time reached");
        await _stopRecordingAndSend();
      });
      print("✅ Recording started successfully");
    } catch (e) {
      print("❌ START RECORD ERROR: $e");
      setState(() {
        _isRecording = false;
        _status = _guiderActive ? "GUIDED" : "LIVE";
      });
    }
  }

  Future<void> _stopRecordingAndSend() async {
    if (_stopping || !_isRecording) return;
    _stopping = true;

    try {
      print("⏹️ Stopping recording...");
      setState(() {
        _isBusy = true;
        _status = "PROCESSING";
        _isRecording = false;
      });

      _maxTimer?.cancel();
      _silenceTimer?.cancel();
      _recorderSubscription?.cancel();

      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      final path = _wavPath;
      if (path == null || !(await File(path).exists())) {
        throw Exception("Audio file missing");
      }

      final len = await File(path).length();
      if (len < 5000 || !_hasDetectedSpeech) {
        print("⚠️ Audio too short or no speech");
        setState(() {
          _isBusy = false;
        });
        if (_voiceLoopActive && !_isMuted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_voiceLoopActive && !_isMuted && mounted) {
              _startRecordingWithAutoStop();
            }
          });
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      await _analyzeAudioEmotion(path);

      setState(() => _status = "TRANSCRIBING");
      final transcript = await _transcribeAudio(path);
      if (transcript.isEmpty) {
        throw Exception("Empty transcription");
      }

      print("📝 Transcription: '$transcript'");

      await _processUserMessage(transcript);

    } catch (e) {
      print("❌ Error in voice processing: $e");
      setState(() {
        _status = _guiderActive ? "GUIDED" : "LIVE";
        _isBusy = false;
        _isSpeaking = false;
        _error = "Error: $e";
      });
      if (_voiceLoopActive && !_isMuted) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_voiceLoopActive && !_isMuted && mounted) {
            _startRecordingWithAutoStop();
          }
        });
      }
    } finally {
      _stopping = false;
    }
  }

  Future<String> _transcribeAudio(String wavPath) async {
    try {
      print("🎤 Transcribing audio: $wavPath");
      final uri = Uri.parse("$_videoServerUrl$_transcribeEndpoint");
      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', wavPath),
      );
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );
      final responseBody = await streamedResponse.stream.bytesToString();
      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final transcript = data['transcript'] ?? '';
        print("📝 Transcription result: '$transcript'");
        return transcript;
      }
      print("❌ Transcription failed: ${streamedResponse.statusCode}");
      return '';
    } catch (e) {
      print("❌ Transcription error: $e");
      return '';
    }
  }

  void _startVoiceLoop() async {
    if (!_audioReady) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_audioReady) return;
    }
    setState(() {
      _voiceLoopActive = true;
    });
    await Future.delayed(const Duration(milliseconds: 300));
    await _startRecordingWithAutoStop();
  }

  void _stopAll() async {
    print("🛑 Stopping all audio activities");
    _voiceLoopActive = false;
    _restartTimer?.cancel();
    _maxTimer?.cancel();
    _silenceTimer?.cancel();
    _typingTimer?.cancel();
    _recorderSubscription?.cancel();

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _tts.stop();
    } catch (e) {
      print("Error stopping: $e");
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isBusy = false;
      _isSpeaking = false;
      _guiderSpeaking = false;
      _textBuffer.clear();
      _visibleAiText = "";
    });
    _stopping = false;
  }

  // ==========================
  // TTS METHODS (FROM OLD CODE)
  // ==========================
  Future<void> _initTts() async {
    try {
      final settings = _getCharacterVoiceSettings(widget.character.characterName);
      _currentSpeechRate = settings['rate'];
      _currentPitch = settings['pitch'];

      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(_currentSpeechRate);
      await _tts.setPitch(_currentPitch);
      try {
        await _tts.setVolume(settings['volume']);
      } catch (e) {
        print("Volume control not supported");
      }

      _tts.setCompletionHandler(() {
        setState(() {
          _isSpeaking = false;
          _isBusy = false;
          _textBuffer.clear();
          _visibleAiText = "";
          _status = _guiderActive ? "GUIDED" : "LIVE";
        });

        if (_voiceLoopActive && mounted && !_isMuted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_voiceLoopActive && !_isMuted && mounted) {
              _startRecordingWithAutoStop();
            }
          });
        }
      });

      _tts.setErrorHandler((msg) {
        print("❌ TTS Error: $msg");
        setState(() {
          _error = "TTS error: $msg";
          _isSpeaking = false;
        });
      });
    } catch (e) {
      print("❌ TTS init error: $e");
    }
  }

  Future<void> _speakText(String text, {bool isGuider = false}) async {
    if (text.isEmpty) return;

    // Save current settings
    final previousRate = _currentSpeechRate;
    final previousPitch = _currentPitch;

    if (isGuider) {
      // Guider voice settings
      _currentSpeechRate = 0.52;
      _currentPitch = 1.2;
      await _tts.setSpeechRate(_currentSpeechRate);
      await _tts.setPitch(_currentPitch);
    } else {
      // Character voice settings
      final settings = _getCharacterVoiceSettings(widget.character.characterName);
      _currentSpeechRate = settings['rate'];
      _currentPitch = settings['pitch'];
      await _tts.setSpeechRate(_currentSpeechRate);
      await _tts.setPitch(_currentPitch);
    }

    try {
      setState(() {
        if (isGuider) {
          _guiderSpeaking = true;
          _guiderMessage = text;
        } else {
          _isSpeaking = true;
          _isBusy = false;
          _status = "SPEAKING";
        }
      });

      await _tts.speak(text);

      setState(() {
        if (isGuider) {
          _guiderSpeaking = false;
          _guiderMessage = "";
        } else {
          _isSpeaking = false;
        }
      });
    } catch (e) {
      print("❌ TTS Error: $e");
      setState(() {
        _isSpeaking = false;
        _guiderSpeaking = false;
        _error = "TTS error: $e";
      });
    } finally {
      // Restore previous settings
      _currentSpeechRate = previousRate;
      _currentPitch = previousPitch;
      await _tts.setSpeechRate(previousRate);
      await _tts.setPitch(previousPitch);
    }
  }

  void _startTypingAnimation(String fullText) {
    _typingTimer?.cancel();
    setState(() {
      _textBuffer.clear();
      _visibleAiText = "";
    });

    final words = fullText.split(' ');
    int index = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (index >= words.length) {
        timer.cancel();
        return;
      }
      if (!mounted) return;
      setState(() {
        _textBuffer.add(words[index]);
        if (_textBuffer.length > 15) {
          _textBuffer.removeAt(0);
        }
        _visibleAiText = _textBuffer.join(' ');
      });
      index++;
    });
  }

  // ==========================
  // CAMERA METHODS
  // ==========================
  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras != null && _cameras!.isNotEmpty) {
        final frontCamera = _cameras!.firstWhere(
              (camera) => camera.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras!.first,
        );

        _cameraController = CameraController(
          frontCamera,
          ResolutionPreset.low,
          enableAudio: false,
        );

        await _cameraController!.initialize();
        if (mounted && !_isCameraDisposed) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted && !_isCameraDisposed) {
        setState(() {
          _isVideoEnabled = false;
        });
      }
    }
  }

  Future<void> _disposeCamera() async {
    _isCameraDisposed = true;
    if (_cameraController != null) {
      try {
        await _cameraController!.dispose();
      } catch (e) {
        print("Error disposing camera: $e");
      }
      _cameraController = null;
    }
    _isCameraInitialized = false;
  }

  // ==========================
  // CHARACTER METHODS
  // ==========================
  Future<void> _loadCharacterProfile() async {
    try {
      final profile = await _localDataSource.findCharacterByName(
        widget.character.characterName,
      );
      if (profile != null) {
        setState(() {
          _characterProfile = profile;
        });
        print("✅ Character profile loaded: ${profile.displayName}");
      }
    } catch (e) {
      print("❌ Error loading character profile: $e");
    }
  }

  String _getModelPathForCharacter(String characterName) {
    final modelMap = {
      'Inner Critic': 'assets/models/inner_critic.glb',
      'People Pleaser': 'assets/models/people_pleaser.glb',
      'Lonely Part': 'assets/models/lonely_part.glb',
      'Jealous Part': 'assets/models/jealous_part.glb',
      'Ashamed Part': 'assets/models/ashamed_part.glb',
      'Workaholic': 'assets/models/workaholic.glb',
      'Perfectionist': 'assets/models/perfectionist.glb',
      'Procrastinator': 'assets/models/procastinator.glb',
      'Excessive Gamer': 'assets/models/excessive_gamer.glb',
      'Confused Part': 'assets/models/confused_part.glb',
      'Dependent Part': 'assets/models/dependent_part.glb',
      'Fearful Part': 'assets/models/fearful_part.glb',
      'Neglected Part': 'assets/models/neglected_part.glb',
      'Overeater': 'assets/models/overeater-binger.glb',
      'Binger': 'assets/models/overeater-binger.glb',
      'Overeater/Binger': 'assets/models/overeater-binger.glb',
      'Overwhelmed Part': 'assets/models/overwhelmed_part.glb',
      'Stoic Part': 'assets/models/stoic_part.glb',
      'Wounded Child': 'assets/models/wounded_child.glb',
      'Controller': 'assets/models/controller_part.glb',
      'Controller Part': 'assets/models/controller_part.glb',
    };
    return modelMap[characterName] ?? 'assets/models/inner_critic.glb';
  }

  String _getCharacterQuote(String characterName) {
    if (_detectedLanguage == 'ar') {
      final quotesAr = {
        'Inner Critic': "أنا هنا عشان أحميك من الأخطاء.",
        'People Pleaser': "أنا بس عايز الكل يكون سعيد.",
        'Lonely Part': "بحس بالوحدة حتى لو كنت وسط ناس كتير.",
        'Jealous Part': "ليه هما عندهم حاجات أنا معنديش؟",
        'Ashamed Part': "أنا مش كويس كفاية.",
        'Workaholic': "دايماً فيه حاجات تتعمل.",
        'Perfectionist': "لازم يكون كامل.",
        'Procrastinator': "هعملها بعدين.",
        'Excessive Gamer': "وليفل واحدة بس.",
        'Confused Part': "أنا مش فاهم.",
        'Dependent Part': "مش عارف أعمل ده لوحدي.",
        'Fearful Part': "لو حاجة وحشة حصلت؟",
        'Neglected Part': "في حد شايفني؟",
        'Overeater': "الأكل بيخليني أحسن.",
        'Overwhelmed Part': "ده كتير أوي.",
        'Stoic Part': "أنا مش محتاج مساعدة.",
        'Wounded Child': "أنا بس عايز أبقى في أمان.",
        'Controller': "أنا لازم أبقى متحكم.",
      };
      return quotesAr[characterName] ?? "أنا هنا عشان أساعدك.";
    } else {
      final quotes = {
        'Inner Critic': "I'm here to protect you from mistakes.",
        'People Pleaser': "I just want everyone to be happy.",
        'Lonely Part': "I feel so alone, even in a crowd.",
        'Jealous Part': "Why do they have what I don't?",
        'Ashamed Part': "I'm not good enough.",
        'Workaholic': "There's always more to do.",
        'Perfectionist': "It has to be perfect.",
        'Procrastinator': "I'll do it later.",
        'Excessive Gamer': "Just one more level.",
        'Confused Part': "I don't understand.",
        'Dependent Part': "I can't do this alone.",
        'Fearful Part': "What if something goes wrong?",
        'Neglected Part': "Does anyone see me?",
        'Overeater': "Food makes me feel better.",
        'Overwhelmed Part': "It's too much.",
        'Stoic Part': "I don't need help.",
        'Wounded Child': "I just want to be safe.",
        'Controller': "I need to be in control.",
      };
      return quotes[characterName] ?? "I'm here to help you.";
    }
  }

  // ==========================
  // UI ACTION METHODS
  // ==========================
  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });

    if (_isMuted) {
      _stopAll();
      setState(() {
        _status = "MUTED";
        _textBuffer.clear();
        _visibleAiText = "";
      });
    } else {
      _startVoiceLoop();
      setState(() {
        _status = _guiderActive ? "GUIDED" : "LIVE";
      });
    }
  }

  void _toggleVideo() async {
    if (_isVideoEnabled) {
      await _disposeCamera();
      setState(() {
        _isVideoEnabled = false;
        _isCameraInitialized = false;
      });
    } else {
      setState(() {
        _isVideoEnabled = true;
      });
      await _initializeCamera();
    }
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();
    _endEmotionSession();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentSessionId != null && _currentThreadId != null) {
      _sendSessionSummary(user).catchError((e) => print("Error sending session summary: $e"));
      _sessionRepository.endVideoSession(
        uid: user.uid,
        sessionId: _currentSessionId!,
        duration: _callDurationSeconds,
      ).catchError((e) => print("Error ending session: $e"));
    }

    _stopAll();
    _disposeCamera();

    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _sendSessionSummary(User user) async {
    try {
      final messagesForSummary = _conversationHistory.map((msg) {
        return {
          'role': msg['role'],
          'content': msg['content'],
        };
      }).toList();

      final response = await http.post(
        Uri.parse("$_videoServerUrl$_sessionSummaryEndpoint"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'sessionId': _currentSessionId,
          'threadId': _currentThreadId,
          'characterId': _characterIdForBackend,
          'duration': _callDurationSeconds,
          'messages': messagesForSummary,
          'language': _detectedLanguage,
        }),
      ).timeout(const Duration(seconds: 10));

      print("✅ Session summary sent: ${response.statusCode}");
    } catch (e) {
      print("Error sending session summary: $e");
    }
  }

  // ==========================
  // UI BUILDERS (FROM OLD CODE)
  // ==========================
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _endCall),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleGuider,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _guiderActive ? const Color(0xFFB79CFF).withOpacity(0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _guiderActive ? const Color(0xFFB79CFF) : Colors.grey.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        child: ClipOval(
                          child: Image.asset(_guiderGifPath, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.assistant_navigation, size: 18, color: _guiderActive ? const Color(0xFFB79CFF) : Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _guiderActive ? _getGuiderActiveText() : _getInviteGuiderText(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _guiderActive ? const Color(0xFFB79CFF) : const Color(0xFF4B3A66)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    CircleAvatar(radius: 4,
                        backgroundColor: _isRecording ? Colors.green : _isBusy ? Colors.orange : _isSpeaking ? Colors.purple : _guiderSpeaking ? const Color(0xFFB79CFF) : Colors.red),
                    const SizedBox(width: 6),
                    Text(_getStatusText(), style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGuiderIndicator() {
    if (!_guiderActive) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    return Positioned(
      top: 80,
      left: 16,
      child: GestureDetector(
        onTap: _toggleGuider,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFB79CFF), width: 2),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFB79CFF).withOpacity(0.5), blurRadius: 8)]),
                child: ClipOval(
                  child: Image.asset(_guiderGifPath, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)]), shape: BoxShape.circle),
                        child: const Icon(Icons.assistant_navigation, color: Colors.white, size: 18),
                      )),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_getGuiderName(), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF2A1E3B))),
                  if (_guiderMessage.isNotEmpty)
                    Container(
                      constraints: BoxConstraints(maxWidth: screenWidth * 0.5),
                      child: Text(_guiderMessage,
                          style: TextStyle(fontSize: 10, color: _guiderSpeaking ? const Color(0xFFB79CFF) : const Color(0xFF4B3A66), fontStyle: FontStyle.italic),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                ],
              ),
              const SizedBox(width: 4),
              if (_guiderSpeaking) Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFB79CFF))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInterventionOverlay() {
    if (!_showingIntervention) return const SizedBox.shrink();
    final screenWidth = MediaQuery.of(context).size.width;
    final guiderMessage = _intervention.guiderMessage ?? '';
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.85),
        child: Center(
          child: Container(
            width: screenWidth * 0.85,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))]),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFB79CFF).withOpacity(0.6), blurRadius: 20)]),
                  child: ClipOval(
                    child: Image.asset(_guiderGifPath, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)]), shape: BoxShape.circle),
                          child: const Icon(Icons.assistant_navigation, color: Colors.white, size: 40),
                        )),
                  ),
                ),
                const SizedBox(height: 20),
                Text(_getGuiderName(), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF2A1E3B))),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: const Color(0xFFF5F0FF), borderRadius: BorderRadius.circular(20)),
                  child: Text(guiderMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Color(0xFF4B3A66), height: 1.5)),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleGuiderInvitation(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6A5CFF),
                          side: const BorderSide(color: Color(0xFFB79CFF), width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(_getContinueAloneText(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleGuiderInvitation(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB79CFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: Text(_getInviteGuiderButtonText(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(_getGuiderSupportText(), style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, {bool isActive = true, bool isEndCall = false}) {
    if (isEndCall) {
      return Container(
        width: 70, height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)]), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
        child: Icon(icon, color: Colors.white, size: 30),
      );
    }
    if (!isActive) {
      return Container(
        width: 70, height: 70,
        decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF4A2B7A), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
        child: Icon(icon, color: Colors.white, size: 30),
      );
    }
    return Container(
      width: 70, height: 70,
      decoration: BoxDecoration(shape: BoxShape.circle, gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)]), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8)]),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _emotionFrameTimer?.cancel();
    _emotionSendTimer?.cancel();
    _restartTimer?.cancel();
    _maxTimer?.cancel();
    _silenceTimer?.cancel();
    _typingTimer?.cancel();
    _recorderSubscription?.cancel();
    _stopAll();
    _disposeCamera();
    try {
      _recorder.closeRecorder();
      _tts.stop();
    } catch (e) {
      print("Error disposing: $e");
    }
    _textBuffer.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              "assets/images/call_background.jpeg",
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                Expanded(
                  flex: 3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: screenWidth * 0.6,
                        height: screenWidth * 0.6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE6DBFF).withOpacity(0.5),
                        ),
                      ),
                      Positioned(
                        top: screenHeight * 0.14,
                        child: SizedBox(
                          height: screenHeight * 0.45,
                          width: screenWidth * 0.65,
                          child: O3D(
                            controller: _o3dController,
                            src: _characterModelPath,
                            autoPlay: true,
                            cameraControls: false,
                            backgroundColor: Colors.transparent,
                            autoRotate: false,
                            loading: Loading.eager,
                          ),
                        ),
                      ),
                      if (_guiderActive)
                        Positioned(
                          top: 10,
                          left: 10,
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFFB79CFF),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFB79CFF).withOpacity(0.3),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                _guiderGifPath,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: const Color(0xFFB79CFF),
                                    child: const Icon(
                                      Icons.assistant_navigation,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        top: 5,
                        right: -75,
                        child: GestureDetector(
                          onTap: _toggleVideo,
                          child: Container(
                            width: 120,
                            height: 160,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isVideoEnabled ? Colors.purple : const Color(0xFF4A2B7A),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: _isVideoEnabled && _isCameraInitialized && _cameraController != null
                                  ? CameraPreview(_cameraController!)
                                  : Container(
                                color: _isVideoEnabled
                                    ? Colors.purple.withOpacity(0.3)
                                    : const Color(0xFF4A2B7A).withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isVideoEnabled
                                            ? Icons.videocam
                                            : Icons.videocam_off,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        _getYouText(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (!_isVideoEnabled)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A2B7A).withOpacity(0.8),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _getOffText(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -6),
                  child: Column(
                    children: [
                      Container(
                        width: screenWidth * 0.9,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.character.getDisplayName(_detectedLanguage == 'ar' ? 'ar' : 'en'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (_lastUserText.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '"$_lastUserText"',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: Colors.purple,
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            Text(
                              _visibleAiText.isNotEmpty
                                  ? _visibleAiText
                                  : _getCharacterQuote(widget.character.characterName),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                            if (_isBusy && _visibleAiText.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.purple),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          GestureDetector(
                            onTap: _toggleMute,
                            child: _circleButton(
                              _isMuted ? Icons.mic_off : Icons.mic,
                              isActive: !_isMuted,
                            ),
                          ),
                          const SizedBox(width: 30),
                          GestureDetector(
                            onTap: _endCall,
                            child: _circleButton(
                              Icons.call_end,
                              isEndCall: true,
                            ),
                          ),
                          const SizedBox(width: 30),
                          GestureDetector(
                            onTap: _toggleVideo,
                            child: _circleButton(
                              _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                              isActive: _isVideoEnabled,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildGuiderIndicator(),
          _buildInterventionOverlay(),
        ],
      ),
    );
  }
}