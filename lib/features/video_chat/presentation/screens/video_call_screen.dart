import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:o3d/o3d.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter/services.dart';

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

  // Background video player for full-screen animation
  VideoPlayerController? _backgroundVideoController;
  bool _isBackgroundVideoInitialized = false;
  bool _useVideoFallback = false;

  // Legacy video player for circle display (kept for compatibility)
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool _isPlayingVideo = false;

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
  Timer? _continuousTranscribeTimer;
  String _partialTranscript = "";
  bool _isTranscribingPartial = false;
  String? _preloadedResponse;
  bool _isPreloading = false;

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
  List<Map<String, dynamic>> _conversationHistory = [];

  Timer? _maxTimer;
  Timer? _silenceTimer;
  Timer? _typingTimer;
  Timer? _restartTimer;
  StreamSubscription? _recorderSubscription;

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const Duration _maxRecord = Duration(seconds: 10); // REDUCED from 15
  static const Duration _silenceThreshold = Duration(milliseconds: 250); // REDUCED from 500
  static const double _silenceDbThreshold = -30.0; // INCREASED sensitivity

  DateTime? _recordStartAt;
  String? _wavPath;
  bool _hasDetectedSpeech = false;
  double _currentDbLevel = -100.0;
  bool _stopping = false;

  // OPTIMIZATION: Pre-warmed connection and response caching
  http.Client? _httpClient;
  bool _isProcessingMessage = false;
  String _lastProcessedTranscript = "";
  DateTime? _lastProcessTime;
  static const Duration _minProcessInterval = Duration(milliseconds: 300); // REDUCED from 500
  final Map<String, String> _cachedResponses = {};

  // OPTIMIZATION: Parallel processing
  bool _isTranscribing = false;
  String _pendingTranscript = "";
  Completer<void>? _currentSpeechCompleter;

  // OPTIMIZATION: Faster recording start
  bool _isRecorderReady = false;
  Timer? _readyCheckTimer;

  // OPTIMIZATION: TTS pre-warming
  bool _ttsWarmedUp = false;

  // OPTIMIZATION: Background operations queue
  final List<Future<void> Function()> _backgroundTasks = [];
  bool _isProcessingBackground = false;

  // Backend endpoints
  static const String _agentServerUrl = "http://192.168.100.7:5001";
  static const String _videoServerUrl = "http://192.168.100.7:5003";
  static const String _guiderUpdateEmotionsEndpoint = "/guider/update_emotions";
  static const String _chatEndpoint = "/chat";
  static const String _chatGuidedEndpoint = "/chat_guided";
  static const String _transcribeEndpoint = "/video/transcribe";
  static const String _sessionSummaryEndpoint = "/video/session_summary";

  // Queue for sequential speaking (prevents overlap)
  final List<Map<String, dynamic>> _speakingQueue = [];
  bool _isProcessingQueue = false;

  // Guider waiting mechanism
  bool _isGuiderWaiting = false;
  Timer? _guiderWaitTimer;

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

  int min(int a, int b) => a < b ? a : b;

  bool _usesVideo() {
    return !_useVideoFallback &&
        (_characterModelPath.endsWith('.mp4') || _characterModelPath.endsWith('.webm'));
  }

  @override
  void initState() {
    super.initState();
    _sessionRepository = VideoSessionRepository();
    _characterIdForBackend = _getCharacterIdForBackend(widget.character.characterName);
    print("🎯 Character ID for backend: $_characterIdForBackend");
    _characterModelPath = _getModelPathForCharacter(widget.character.characterName);

    _httpClient = http.Client();

    _initializeCamera();
    _initAudio();
    _loadCharacterProfile();
    _initializeSession();
    _initTts();
    _initializeEmotionSession();
    _startDurationTracking();
    _initializeBackgroundVideo();
    _warmupTts(); // NEW: Pre-warm TTS engine
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

      print("🎯 Creating BRAND NEW session for ${widget.character.characterName}");

      final newSession = await _sessionRepository.createVideoSession(
        uid: user.uid,
        characterId: _characterIdForBackend,
        title: 'Video call with ${widget.character.displayNameEn} - ${DateTime.now().toIso8601String()}',
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

  // OPTIMIZATION: Background task queue
  void _addBackgroundTask(Future<void> Function() task) {
    _backgroundTasks.add(task);
    if (!_isProcessingBackground) {
      _processBackgroundTasks();
    }
  }

  Future<void> _processBackgroundTasks() async {
    if (_isProcessingBackground) return;
    _isProcessingBackground = true;

    while (_backgroundTasks.isNotEmpty) {
      final task = _backgroundTasks.removeAt(0);
      try {
        await task();
      } catch (e) {
        print("Background task error: $e");
      }
      await Future.delayed(const Duration(milliseconds: 50));
    }

    _isProcessingBackground = false;
  }

  Future<void> _saveMessage(String role, String content, {String? sender}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentThreadId == null) return;

    // OPTIMIZATION: Save in background
    _addBackgroundTask(() async {
      await _sessionRepository.saveMessage(
        uid: user.uid,
        threadId: _currentThreadId!,
        role: role,
        content: content,
        sender: sender,
        characterId: role == 'assistant' ? _characterIdForBackend : null,
        sessionId: _currentSessionId,
      );
    });
  }

  String _getModelPathForCharacter(String characterName) {
    final modelMap = {
      'Inner Critic': 'assets/animations/innner.mp4',
      'Lonely Part': 'assets/animations/lonly.mp4',
      'People Pleaser': 'assets/models/people_pleaser.glb',
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
      'Overwhelmed Part': 'assets/animations/overwhelmed.mp4',
      'Stoic Part': 'assets/models/stoic_part.glb',
      'Wounded Child': 'assets/models/wounded_child.glb',
      'Controller': 'assets/models/controller_part.glb',
      'Controller Part': 'assets/models/controller_part.glb',
    };
    return modelMap[characterName] ?? 'assets/models/inner_critic.glb';
  }

  Future<void> _initializeBackgroundVideo() async {
    if (!_characterModelPath.endsWith('.mp4') && !_characterModelPath.endsWith('.webm')) {
      print("📹 Character uses 3D model, not video");
      return;
    }

    try {
      try {
        await rootBundle.load(_characterModelPath);
      } catch (e) {
        print("❌ Video asset not found: $_characterModelPath");
        _useVideoFallback = true;
        if (mounted) setState(() {});
        return;
      }

      _backgroundVideoController = VideoPlayerController.asset(_characterModelPath);
      await _backgroundVideoController!.initialize();

      _backgroundVideoController!.setLooping(true);
      _backgroundVideoController!.setVolume(0);

      await _backgroundVideoController!.pause();

      if (mounted) {
        setState(() {
          _isBackgroundVideoInitialized = true;
        });
      }

      print("✅ Background video initialized for character: ${widget.character.characterName}");
    } catch (e) {
      print("❌ Error initializing background video: $e");
      _useVideoFallback = true;
      if (mounted) setState(() {});
    }
  }

  void _startContinuousTranscription() {
    _continuousTranscribeTimer?.cancel();

    _continuousTranscribeTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) { // REDUCED from 1200
      if (_isRecording && _recorder.isRecording && !_isTranscribingPartial && _wavPath != null) {
        final recordDuration = DateTime.now().difference(_recordStartAt!);
        if (recordDuration > const Duration(seconds: 1)) {
          _transcribePartialIncremental();
        }
      }
    });
  }

  Future<void> _transcribePartialIncremental() async {
    if (_isTranscribingPartial) return;

    _isTranscribingPartial = true;

    try {
      final path = _wavPath;
      if (path == null || !(await File(path).exists())) {
        _isTranscribingPartial = false;
        return;
      }

      final file = File(path);
      final size = await file.length();

      if (size < 25000) {
        _isTranscribingPartial = false;
        return;
      }

      if (_preloadedResponse != null && _partialTranscript.isNotEmpty) {
        _isTranscribingPartial = false;
        return;
      }

      final uri = Uri.parse("$_videoServerUrl/video/transcribe");
      var request = http.MultipartRequest('POST', uri);
      request.files.add(
        await http.MultipartFile.fromPath('file', path),
      );

      final response = await request.send().timeout(const Duration(milliseconds: 1000));
      final responseBody = await response.stream.bytesToString();

      if (response.statusCode == 200) {
        final data = jsonDecode(responseBody);
        final transcript = data['transcript'] ?? '';

        if (transcript.isNotEmpty &&
            transcript.length > _partialTranscript.length + 10 &&
            transcript != _partialTranscript) {
          _partialTranscript = transcript;
          print("📝 Partial: ${_partialTranscript.substring(0, min(50, _partialTranscript.length))}...");

          if (_partialTranscript.length > 15) {
            _preloadAgentResponse(transcript);
          }
        }
      }
    } catch (e) {
      // Silent fail
    }

    _isTranscribingPartial = false;
  }

  Future<void> _preloadAgentResponse(String partialText) async {
    if (_isPreloading || partialText.length < 15) return;
    if (_preloadedResponse != null) return;

    _isPreloading = true;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

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
        };
      }

      final response = await _httpClient!.post(
        Uri.parse("$_agentServerUrl$_chatEndpoint"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'uid': user.uid,
          'characterId': _characterIdForBackend,
          'characterProfile': characterProfile,
          'messages': [
            {'role': 'user', 'content': partialText}
          ],
          'sessionId': _currentSessionId,
          'threadId': _currentThreadId,
          'checkIntervention': false,
          'preload': true,
        }),
      ).timeout(const Duration(seconds: 2));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['assistantMessage'] != null) {
          _preloadedResponse = data['assistantMessage'];
          print("✅ Preloaded response ready (${_preloadedResponse!.length} chars)");
        }
      }
    } catch (e) {
      // Silent fail
    }

    _isPreloading = false;
  }

  void _startBackgroundVideo() {
    if (_backgroundVideoController != null &&
        _isBackgroundVideoInitialized &&
        mounted &&
        !_backgroundVideoController!.value.isPlaying) {
      _backgroundVideoController!.play();
      print("🎬 Background video started (character speaking)");
    }
  }

  void _pauseBackgroundVideo() {
    if (_backgroundVideoController != null &&
        _isBackgroundVideoInitialized &&
        mounted &&
        _backgroundVideoController!.value.isPlaying) {
      _backgroundVideoController!.pause();
      print("⏸️ Background video paused (character stopped speaking)");
    }
  }

  // OPTIMIZATION: TTS pre-warming
  Future<void> _warmupTts() async {
    try {
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.5);
      await _tts.setPitch(1.0);
      _ttsWarmedUp = true;
      print("🎤 TTS engine pre-warmed");
    } catch (e) {
      print("TTS warmup failed: $e");
    }
  }

  // ==========================
  // EMOTION DETECTION
  // ==========================
  Future<void> _initializeEmotionSession() async {
    try {
      final response = await _httpClient!.post(
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

      final response = await _httpClient!.post(
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

      final response = await _httpClient!.post(
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
                _addBackgroundTask(() async {
                  await _sessionRepository.addEmotion(
                    uid: user.uid,
                    sessionId: _currentSessionId!,
                    emotion: voiceEmotion,
                  );
                });
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

      final response = await _httpClient!.post(
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
      await _httpClient!.post(
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
  // SPEAKING QUEUE
  // ==========================
  Future<void> _speakWithQueue(String text, {bool isGuider = false}) async {
    if (text.isEmpty) return;

    if (isGuider && _isSpeaking) {
      print("🛡️ Guider message waiting - character is speaking");
      _isGuiderWaiting = true;

      _guiderWaitTimer?.cancel();
      _guiderWaitTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        if (!_isSpeaking && mounted && _isGuiderWaiting) {
          timer.cancel();
          _isGuiderWaiting = false;
          _speakingQueue.add({'text': text, 'isGuider': isGuider});
          if (!_isProcessingQueue) {
            _processQueue();
          }
        }
      });
      return;
    }

    _speakingQueue.add({'text': text, 'isGuider': isGuider});

    if (!_isProcessingQueue) {
      _processQueue();
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

  Map<String, dynamic> _getCharacterVoiceSettings(String characterName) {
    final Map<String, dynamic> settings = {
      'rate': 0.46,
      'pitch': 1.0,
      'volume': 1.0,
      'voiceName': 'echo',
    };

    const voiceMap = {
      'inner_critic': 'en-US-Neural2-D',
      'workaholic': 'en-US-Neural2-J',
      'controller': 'en-US-Neural2-I',
      'dependent': 'en-US-Wavenet-B',
      'excessive_gamer': 'en-US-Neural2-C',
      'stoic': 'en-US-Neural2-A',
      'people_pleaser': 'en-US-Neural2-F',
      'jealous': 'en-US-Standard-C',
      'wounded_child': 'en-US-Neural2-C',
      'ashamed': 'en-US-Standard-E',
      'fearful': 'en-US-Neural2-A',
      'overwhelmed': 'en-US-Neural2-F',
      'perfectionist': 'en-US-Neural2-F',
      'neglected': 'en-US-Wavenet-F',
      'overater_binger': 'en-US-Wavenet-F',
      'confused': 'en-US-Neural2-A',
      'procrastinator': 'en-US-Neural2-F',
      'lonely': 'en-US-Standard-C',
    };

    settings['voiceName'] = voiceMap[characterName] ?? 'en-US-Neural2-F';

    switch (characterName) {
      case 'inner_critic':
        settings['rate'] = 0.40;
        settings['pitch'] = 0.58;
        settings['volume'] = 1.10;
        break;

      case 'workaholic':
        settings['rate'] = 0.56;
        settings['pitch'] = 0.60;
        settings['volume'] = 1.05;
        break;

      case 'controller':
        settings['rate'] = 0.42;
        settings['pitch'] = 0.50;
        settings['volume'] = 1.00;
        break;

      case 'dependent':
        settings['rate'] = 0.46;
        settings['pitch'] = 0.65;
        settings['volume'] = 0.95;
        break;

      case 'excessive_gamer':
        settings['rate'] = 0.62;
        settings['pitch'] = 0.68;
        settings['volume'] = 1.10;
        break;

      case 'stoic':
        settings['rate'] = 0.36;
        settings['pitch'] = 0.68;
        settings['volume'] = 0.95;
        break;

      case 'wounded_child':
        settings['rate'] = 0.55;
        settings['pitch'] = 1.55;
        settings['volume'] = 0.82;
        break;

      case 'fearful':
        settings['rate'] = 0.62;
        settings['pitch'] = 1.45;
        break;

      case 'procrastinator':
        settings['rate'] = 0.36;
        settings['pitch'] = 0.96;
        break;

      case 'ashamed':
        settings['rate'] = 0.40;
        settings['volume'] = 0.85;
        break;

      case 'overwhelmed':
        settings['rate'] = 0.52;
        settings['volume'] = 0.88;
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
    required List<Map<String, dynamic>> conversationHistory,
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

    final List<Map<String, String>> messages = [];
    final recentHistory = conversationHistory.length > 6
        ? conversationHistory.sublist(conversationHistory.length - 8)
        : conversationHistory;

    for (final msg in recentHistory) {
      if (msg['role'] == 'user') {
        messages.add({'role': 'user', 'content': msg['content'] as String});
      } else if (msg['role'] == 'assistant' && msg['isGuider'] != true) {
        messages.add({'role': 'assistant', 'content': msg['content'] as String});
      }
    }
    messages.add({'role': 'user', 'content': transcript});

    final requestBody = {
      'uid': uid,
      'characterId': _characterIdForBackend,
      'characterProfile': characterProfile,
      'messages': messages,
      'sessionId': _currentSessionId,
      'threadId': _currentThreadId,
      'checkIntervention': true,
      'language': _detectedLanguage,
    };

    print("📤 Sending to agent...");
    final stopwatch = Stopwatch()..start();
    final response = await _httpClient!.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 15));

    stopwatch.stop();
    print("📥 Agent response in ${stopwatch.elapsedMilliseconds}ms");

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print("✅ Agent response received");
      return data;
    }
    print("❌ Agent error: ${response.statusCode}");
    throw Exception("HTTP ${response.statusCode}");
  }

  Future<Map<String, dynamic>> _sendToGuidedAgent({
    required String uid,
    required String transcript,
    required List<Map<String, dynamic>> conversationHistory,
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
    final recentHistory = conversationHistory.length > 8
        ? conversationHistory.sublist(conversationHistory.length - 8)
        : conversationHistory;

    for (final msg in recentHistory) {
      final isGuider = msg['isGuider'] == true;
      final role = msg['role'] as String? ?? '';
      final content = msg['content'] as String? ?? '';

      if (content.isEmpty) continue;

      if (role == 'user') {
        guidedMessages.add({'sender': 'user', 'content': content});
      } else if (role == 'assistant') {
        if (isGuider) {
          guidedMessages.add({'sender': 'guider', 'content': content});
        } else {
          guidedMessages.add({'sender': widget.character.displayNameEn, 'content': content});
        }
      }
    }

    guidedMessages.add({'sender': 'user', 'content': transcript});

    print("📤 Guided messages count: ${guidedMessages.length}");

    final requestBody = {
      'uid': uid,
      'characterId': _characterIdForBackend,
      'characterProfile': characterProfile,
      'messages': guidedMessages,
      'sessionId': _currentSessionId,
      'threadId': _currentThreadId,
      'language': _detectedLanguage,
    };

    print("📤 Sending to guided agent...");
    final stopwatch = Stopwatch()..start();

    try {
      final response = await _httpClient!.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 30));

      stopwatch.stop();
      print("📥 Guided agent response in ${stopwatch.elapsedMilliseconds}ms");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print("✅ Guided agent response received");
        return data;
      }
      print("❌ Guided agent error: ${response.statusCode}");
      throw Exception("HTTP ${response.statusCode}");
    } catch (e) {
      print("❌ Guided agent request failed: $e");
      rethrow;
    }
  }

  // ==========================
  // PROCESS USER MESSAGE (OPTIMIZED)
  // ==========================

  void _logTiming(String phase, Stopwatch stopwatch) {
    final elapsed = stopwatch.elapsedMilliseconds;
    print("⏱️ TIMING: $phase took ${elapsed}ms");
    stopwatch.reset();
  }

  // OPTIMIZATION: Stop recording without waiting
  Future<void> _stopRecordingAsync() async {
    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      _maxTimer?.cancel();
      _silenceTimer?.cancel();
      _recorderSubscription?.cancel();
      _continuousTranscribeTimer?.cancel();
    } catch (e) {
      print("Error stopping recording: $e");
    }
  }

  Future<void> _processUserMessage(String transcript) async {
    final totalStopwatch = Stopwatch()..start();
    print("🟢 PROCESSING START: $transcript");

    if (_isProcessingMessage) {
      print("⚠️ Already processing a message, queueing...");
      _pendingTranscript = transcript;
      return;
    }

    if (_lastProcessTime != null) {
      final elapsed = DateTime.now().difference(_lastProcessTime!);
      if (elapsed < _minProcessInterval && transcript == _lastProcessedTranscript) {
        print("⚠️ Skipping duplicate rapid message");
        return;
      }
    }

    _isProcessingMessage = true;
    _lastProcessedTranscript = transcript;
    _lastProcessTime = DateTime.now();

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      _isProcessingMessage = false;
      throw Exception("User not logged in");
    }

    // OPTIMIZATION: Stop recording in background without waiting
    unawaited(_stopRecordingAsync());

    setState(() {
      _isRecording = false;
      _isSpeaking = false;
      _guiderSpeaking = false;
      _isBusy = true;
      _status = "THINKING";
      _visibleAiText = "";
    });

    final detectLangStopwatch = Stopwatch()..start();
    final detectedLang = _detectLanguageFromText(transcript);
    if (detectedLang != _detectedLanguage) {
      setState(() => _detectedLanguage = detectedLang);
      unawaited(_updateTtsLanguage(detectedLang));
    }
    _logTiming("Language detection & update", detectLangStopwatch);

    setState(() {
      _lastUserText = transcript;
    });

    // OPTIMIZATION: Save message in background
    unawaited(_saveMessage('user', transcript, sender: 'user'));

    Map<String, dynamic> response;

    try {
      final agentStopwatch = Stopwatch()..start();

      // OPTIMIZATION: Use preloaded response if available
      if (_preloadedResponse != null && _preloadedResponse!.isNotEmpty) {
        print("🚀 USING PRELOADED RESPONSE");
        response = {
          'success': true,
          'assistantMessage': _preloadedResponse,
          'intervention': null
        };
        _preloadedResponse = null;
        _partialTranscript = "";
      }
      // OPTIMIZATION: Check cache
      else if (_cachedResponses.containsKey(transcript)) {
        print("🚀 USING CACHED RESPONSE");
        response = {
          'success': true,
          'assistantMessage': _cachedResponses[transcript],
          'intervention': null
        };
      }
      else {
        // OPTIMIZATION: Run emotion analysis in parallel with agent call
        final audioPath = _wavPath;
        if (audioPath != null) {
          unawaited(_analyzeAudioEmotion(audioPath));
        }

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
      }

      _logTiming("Agent API call (${_guiderActive ? 'GUIDED' : 'STANDARD'})", agentStopwatch);
    } catch (e) {
      print("❌ Agent error: $e");
      setState(() {
        _status = _guiderActive ? "GUIDED" : "LIVE";
        _isBusy = false;
      });
      _isProcessingMessage = false;

      _scheduleVoiceLoopRestart();

      if (_pendingTranscript.isNotEmpty) {
        final pending = _pendingTranscript;
        _pendingTranscript = "";
        _processUserMessage(pending);
      }
      return;
    }

    if (response['success'] == true) {
      // Check for intervention
      if (response['intervention'] != null && response['intervention']['shouldIntervene'] == true) {
        final intervention = GuiderInterventionModel.fromMap(response['intervention']);

        if (intervention.shouldIntervene && mounted && !_guiderActive && !_showingIntervention) {
          print("🎯 INTERVENTION FROM BACKEND: ${intervention.reason}");

          if (intervention.guiderMessage != null && intervention.guiderMessage!.isNotEmpty) {
            _intervention = GuiderInterventionModel(
              shouldIntervene: true,
              reason: intervention.reason,
              severity: intervention.severity,
              guiderMessage: intervention.guiderMessage,
            );
          } else {
            _intervention = intervention;
          }

          setState(() {
            _showingIntervention = true;
            _status = "INVITING_GUIDER";
            _isBusy = false;
          });

          _isProcessingMessage = false;
          return;
        }
      }

      String characterMessage = '';
      String guiderMessage = '';

      if (_guiderActive) {
        characterMessage = response['characterMessage'] ?? '';
        guiderMessage = response['guiderMessage'] ?? '';

        final String responseOrder = response['respondent'] ?? 'character_only';
        final bool suppressCharacter = response['suppressCharacter'] ?? false;

        print("📢 Response order: $responseOrder");

        // OPTIMIZATION: Save messages in background
        if (characterMessage.isNotEmpty && !suppressCharacter) {
          unawaited(_saveMessage('assistant', characterMessage, sender: _characterIdForBackend));
          _conversationHistory.add({
            'role': 'assistant',
            'content': characterMessage,
            'isGuider': false,
          });
        }

        if (guiderMessage.isNotEmpty) {
          unawaited(_saveMessage('assistant', guiderMessage, sender: 'guider'));
          _conversationHistory.add({
            'role': 'assistant',
            'content': guiderMessage,
            'isGuider': true,
          });
        }

        final List<Map<String, dynamic>> speechQueue = [];

        if (responseOrder == 'guider_only') {
          if (guiderMessage.isNotEmpty) {
            speechQueue.add({'text': guiderMessage, 'isGuider': true});
          }
        }
        else if (responseOrder == 'guider_first') {
          if (guiderMessage.isNotEmpty) {
            speechQueue.add({'text': guiderMessage, 'isGuider': true});
          }
          if (characterMessage.isNotEmpty && !suppressCharacter) {
            speechQueue.add({'text': characterMessage, 'isGuider': false});
          }
        }
        else {
          if (characterMessage.isNotEmpty && !suppressCharacter) {
            speechQueue.add({'text': characterMessage, 'isGuider': false});
          }
          if (guiderMessage.isNotEmpty) {
            speechQueue.add({'text': guiderMessage, 'isGuider': true});
          }
        }

        if (speechQueue.isNotEmpty) {
          _startTypingAnimation(speechQueue.first['text']);

          setState(() {
            _isBusy = false;
          });

          // OPTIMIZATION: Speak sequentially with minimal delays
          final ttsStopwatch = Stopwatch()..start();
          for (int i = 0; i < speechQueue.length; i++) {
            final speakStopwatch = Stopwatch()..start();
            await _speakTextFast(speechQueue[i]['text'], isGuider: speechQueue[i]['isGuider']);
            _logTiming("TTS - ${speechQueue[i]['isGuider'] ? 'Guider' : 'Character'} message ${i+1}/${speechQueue.length}", speakStopwatch);
            if (i < speechQueue.length - 1) {
              await Future.delayed(const Duration(milliseconds: 100)); // REDUCED from 200
            }
          }
          _logTiming("Total TTS for ${speechQueue.length} message(s)", ttsStopwatch);
        } else {
          setState(() {
            _isBusy = false;
            _status = _guiderActive ? "GUIDED" : "LIVE";
          });
          _scheduleVoiceLoopRestart();
        }

      } else {
        characterMessage = response['assistantMessage'] ?? '';
        if (characterMessage.isNotEmpty) {
          // OPTIMIZATION: Save message in background
          unawaited(_saveMessage('assistant', characterMessage, sender: _characterIdForBackend));
          _conversationHistory.add({
            'role': 'assistant',
            'content': characterMessage,
            'isGuider': false,
          });

          // OPTIMIZATION: Cache response
          if (transcript.length > 20 && transcript.length < 100 && characterMessage.length < 200) {
            _cachedResponses[transcript] = characterMessage;
            if (_cachedResponses.length > 50) {
              _cachedResponses.remove(_cachedResponses.keys.first);
            }
          }

          _startTypingAnimation(characterMessage);

          setState(() {
            _isBusy = false;
          });

          final ttsStopwatch = Stopwatch()..start();
          await _speakTextFast(characterMessage, isGuider: false);
          _logTiming("TTS - Character message", ttsStopwatch);
        } else {
          setState(() {
            _isBusy = false;
            _status = "LIVE";
          });
          _scheduleVoiceLoopRestart();
        }
      }

      _conversationHistory.add({
        'role': 'user',
        'content': transcript,
        'isGuider': false,
      });

      setState(() {
        _lastAiText = characterMessage;
        _textBuffer.clear();
        _visibleAiText = "";
      });

    } else {
      throw Exception(response['error'] ?? 'Unknown error');
    }

    _isProcessingMessage = false;
    _logTiming("TOTAL PROCESSING (from start to finish)", totalStopwatch);

    if (_pendingTranscript.isNotEmpty) {
      final pending = _pendingTranscript;
      _pendingTranscript = "";
      _processUserMessage(pending);
    }
  }

  void _scheduleVoiceLoopRestart() {
    if (!mounted) return;

    _restartTimer?.cancel();

    _restartTimer = Timer(const Duration(milliseconds: 200), () { // REDUCED from 400
      if (!mounted) return;

      print("🔄 Scheduled voice loop restart - checking conditions...");
      print("  voiceLoopActive: $_voiceLoopActive");
      print("  isMuted: $_isMuted");
      print("  isSpeaking: $_isSpeaking");
      print("  isProcessingMessage: $_isProcessingMessage");
      print("  isBusy: $_isBusy");
      print("  speakingQueue length: ${_speakingQueue.length}");
      print("  guiderActive: $_guiderActive");

      if (_voiceLoopActive &&
          !_isMuted &&
          !_isSpeaking &&
          !_isProcessingMessage &&
          !_isBusy &&
          _speakingQueue.isEmpty) {
        print("🎙️ Restarting voice loop now");
        _startRecordingWithAutoStop();
      } else {
        print("⏳ Conditions not met, will retry");
        if (_voiceLoopActive && !_isMuted && mounted) {
          _restartTimer = Timer(const Duration(milliseconds: 300), () {
            if (mounted && _voiceLoopActive && !_isMuted && !_isSpeaking && !_isProcessingMessage && !_isBusy && _speakingQueue.isEmpty) {
              _startRecordingWithAutoStop();
            }
          });
        }
      }
    });
  }

  // ==========================
  // SEQUENTIAL SPEAKER
  // ==========================

  Future<void> _speakSequentially(List<Map<String, dynamic>> messages) async {
    if (messages.isEmpty) return;

    print("📢 Starting sequential speech of ${messages.length} message(s)");

    for (int i = 0; i < messages.length; i++) {
      final item = messages[i];
      final text = item['text'] as String;
      final isGuider = item['isGuider'] as bool;

      if (text.isEmpty) continue;

      print("📢 Speaking [${i + 1}/${messages.length}]: ${isGuider ? 'Guider' : 'Character'}");

      final previousRate = _currentSpeechRate;
      final previousPitch = _currentPitch;

      if (isGuider) {
        _currentSpeechRate = 0.52;
        _currentPitch = 1.2;
        await _tts.setSpeechRate(_currentSpeechRate);
        await _tts.setPitch(_currentPitch);

        if (mounted) {
          setState(() {
            _guiderSpeaking = true;
            _guiderMessage = text;
          });
        }
      } else {
        final settings = _getCharacterVoiceSettings(widget.character.characterName);
        _currentSpeechRate = settings['rate'];
        _currentPitch = settings['pitch'];
        await _tts.setSpeechRate(_currentSpeechRate);
        await _tts.setPitch(_currentPitch);

        if (mounted) {
          setState(() {
            _isSpeaking = true;
            _isBusy = false;
            _status = "SPEAKING";
          });
          _startBackgroundVideo();
        }
      }

      final speechCompleter = Completer<void>();

      void onSpeechComplete() {
        print("✅ Speech finished");
        if (mounted) {
          setState(() {
            if (isGuider) {
              _guiderSpeaking = false;
              _guiderMessage = "";
            } else {
              _isSpeaking = false;
              _pauseBackgroundVideo();
            }
          });

          print("🎙️ Restarting voice loop after speech completion");
          Future.delayed(const Duration(milliseconds: 150), () { // REDUCED from 300
            if (mounted && _voiceLoopActive && !_isMuted) {
              print("🎙️ Actually starting recording now...");
              _startRecordingWithAutoStop();
            }
          });
        }
        if (!speechCompleter.isCompleted) {
          speechCompleter.complete();
        }
      }

      _tts.setCompletionHandler(onSpeechComplete);

      print("🗣️ Speaking text: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
      await _tts.speak(text);
      await speechCompleter.future;

      _currentSpeechRate = previousRate;
      _currentPitch = previousPitch;
      await _tts.setSpeechRate(previousRate);
      await _tts.setPitch(previousPitch);

      if (isGuider) {
        await Future.delayed(const Duration(milliseconds: 200)); // REDUCED from 400
      } else {
        await Future.delayed(const Duration(milliseconds: 100)); // REDUCED from 200
      }

      if (i + 1 < messages.length && mounted) {
        _startTypingAnimation(messages[i + 1]['text']);
      }
    }

    _tts.setCompletionHandler(() {
      print("🎯 TTS completion handler triggered");
      setState(() {
        _isSpeaking = false;
        _textBuffer.clear();
        _visibleAiText = "";
      });

      _pauseBackgroundVideo();

      if (_speakingQueue.isEmpty) {
        setState(() {
          _isBusy = false;
          _status = _guiderActive ? "GUIDED" : "LIVE";
        });

        if (_voiceLoopActive && mounted && !_isMuted) {
          print("🎙️ Default handler: Restarting voice loop");
          Future.delayed(const Duration(milliseconds: 100), () { // REDUCED from 200
            if (_voiceLoopActive && !_isMuted && mounted && !_isBusy && _speakingQueue.isEmpty && !_isProcessingMessage) {
              _startRecordingWithAutoStop();
            }
          });
        }
      }
    });

    print("✅ Sequential speech completed");
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

      _isRecorderReady = true;

      _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
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
        _silenceTimer = Timer(const Duration(milliseconds: 250), () { // REDUCED from 350
          if (_hasDetectedSpeech && _isRecording && !_stopping) {
            print("🔇 Silence threshold reached - processing");
            _stopRecordingAndSend();
          }
        });
      }
    });
  }

  Future<void> _startRecordingWithAutoStop() async {
    print("🎙️ _startRecordingWithAutoStop called - voiceLoopActive=$_voiceLoopActive, isMuted=$_isMuted");

    if (!_voiceLoopActive || _isMuted) return;
    if (_isSpeaking || _isBusy || _isRecording || _guiderSpeaking) return;
    if (_isProcessingMessage) return;

    _stopping = false;
    _hasDetectedSpeech = false;
    _partialTranscript = "";
    _preloadedResponse = null;

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        await Future.delayed(const Duration(milliseconds: 20)); // REDUCED from 30
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

      Future.delayed(const Duration(milliseconds: 500), () { // REDUCED from 800
        if (_isRecording) _startContinuousTranscription();
      });

      _maxTimer?.cancel();
      _maxTimer = Timer(_maxRecord, () async {
        if (!_voiceLoopActive || !_isRecording) return;
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
      _continuousTranscribeTimer?.cancel();

      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      final path = _wavPath;
      if (path == null || !(await File(path).exists())) {
        throw Exception("Audio file missing");
      }

      final len = await File(path).length();
      if (len < 3000 || !_hasDetectedSpeech) {
        print("⚠️ Audio too short or no speech");
        setState(() {
          _isBusy = false;
        });
        if (_voiceLoopActive && !_isMuted) {
          Future.delayed(const Duration(milliseconds: 100), () { // REDUCED from 200
            if (_voiceLoopActive && !_isMuted && mounted) {
              _startRecordingWithAutoStop();
            }
          });
        }
        _stopping = false;
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      unawaited(_analyzeAudioEmotion(path));

      setState(() => _status = "TRANSCRIBING");
      final transcript = await _fastTranscribe(path);
      if (transcript.isEmpty) {
        throw Exception("Empty transcription");
      }

      print("📝 Transcription: '$transcript'");

      // Check cache
      if (_cachedResponses.containsKey(transcript)) {
        final cachedResponse = _cachedResponses[transcript]!;
        print("🚀 USING CACHED RESPONSE - Skipped agent call!");

        unawaited(_saveMessage('user', transcript, sender: 'user'));
        _conversationHistory.add({
          'role': 'user',
          'content': transcript,
          'isGuider': false,
        });

        unawaited(_saveMessage('assistant', cachedResponse, sender: _characterIdForBackend));
        _conversationHistory.add({
          'role': 'assistant',
          'content': cachedResponse,
          'isGuider': false,
        });

        _startTypingAnimation(cachedResponse);

        setState(() {
          _isBusy = false;
        });

        await _speakTextFast(cachedResponse, isGuider: false);

        setState(() {
          _lastAiText = cachedResponse;
          _textBuffer.clear();
          _visibleAiText = "";
        });

        _preloadedResponse = null;
        _partialTranscript = "";
        _isProcessingMessage = false;
        _scheduleVoiceLoopRestart();
        _stopping = false;
        return;
      }

      // Check preload
      bool usePreload = false;
      String finalResponse = '';

      if (_preloadedResponse != null && _preloadedResponse!.isNotEmpty) {
        if (_partialTranscript.isNotEmpty) {
          final similarityCheck = transcript.contains(_partialTranscript) ||
              _partialTranscript.contains(transcript.substring(0, min(transcript.length, _partialTranscript.length)));

          if (similarityCheck) {
            usePreload = true;
            finalResponse = _preloadedResponse!;
            print("🚀 USING PRELOADED RESPONSE - Skipped agent call! (${finalResponse.length} chars)");
          } else {
            print("⚠️ Preload mismatch - using normal flow");
          }
        } else if (_partialTranscript.isEmpty && transcript.length > 15) {
          usePreload = true;
          finalResponse = _preloadedResponse!;
          print("🚀 USING PRELOADED RESPONSE (no partial) - Skipped agent call!");
        }
      }

      if (usePreload) {
        unawaited(_saveMessage('user', transcript, sender: 'user'));
        _conversationHistory.add({
          'role': 'user',
          'content': transcript,
          'isGuider': false,
        });

        unawaited(_saveMessage('assistant', finalResponse, sender: _characterIdForBackend));
        _conversationHistory.add({
          'role': 'assistant',
          'content': finalResponse,
          'isGuider': false,
        });

        _startTypingAnimation(finalResponse);

        setState(() {
          _isBusy = false;
        });

        await _speakTextFast(finalResponse, isGuider: false);

        setState(() {
          _lastAiText = finalResponse;
          _textBuffer.clear();
          _visibleAiText = "";
        });

        _preloadedResponse = null;
        _partialTranscript = "";
        _isProcessingMessage = false;
        _scheduleVoiceLoopRestart();
        _stopping = false;
        return;
      }

      // Normal flow
      await _processUserMessage(transcript);

      if (_lastAiText.isNotEmpty &&
          transcript.length > 20 &&
          transcript.length < 100 &&
          _lastAiText.length < 200) {
        _cachedResponses[transcript] = _lastAiText;
        if (_cachedResponses.length > 50) {
          _cachedResponses.remove(_cachedResponses.keys.first);
        }
      }

      _preloadedResponse = null;
      _partialTranscript = "";

    } catch (e) {
      print("❌ Error in voice processing: $e");
      setState(() {
        _status = _guiderActive ? "GUIDED" : "LIVE";
        _isBusy = false;
        _isSpeaking = false;
        _error = "Error: $e";
      });
      if (_voiceLoopActive && !_isMuted) {
        Future.delayed(const Duration(milliseconds: 200), () { // REDUCED from 300
          if (_voiceLoopActive && !_isMuted && mounted) {
            _startRecordingWithAutoStop();
          }
        });
      }
    } finally {
      _stopping = false;
    }
  }

  Future<String> _fastTranscribe(String wavPath) async {
    try {
      final file = File(wavPath);
      final fileSize = await file.length();

      if (fileSize < 3000) {
        print("⚠️ Audio too short (${fileSize} bytes)");
        return '';
      }
      if (fileSize > 5 * 1024 * 1024) {
        print("⚠️ Audio too large (${fileSize} bytes)");
        return '';
      }

      final uri = Uri.parse("$_videoServerUrl$_transcribeEndpoint");
      var request = http.MultipartRequest('POST', uri);
      request.headers['Accept'] = 'application/json';
      request.files.add(
        await http.MultipartFile.fromPath('file', wavPath),
      );

      final streamedResponse = await request.send().timeout(const Duration(seconds: 5)); // REDUCED from 8
      final responseBody = await streamedResponse.stream.bytesToString().timeout(
        const Duration(seconds: 3), // REDUCED from 5
      );

      if (streamedResponse.statusCode == 200) {
        final data = jsonDecode(responseBody);
        return data['transcript'] ?? '';
      }

      return '';
    } catch (e) {
      print("❌ Transcription error: $e");
      return '';
    }
  }

  Future<String> _fastTranscribeWithRetry(String wavPath, {int maxRetries = 1}) async { // REDUCED from 2
    for (int i = 0; i < maxRetries; i++) {
      try {
        final result = await _fastTranscribe(wavPath);
        if (result.isNotEmpty) return result;

        if (i < maxRetries - 1) {
          print("⚠️ Transcription failed, retrying (${i + 1}/$maxRetries)...");
          await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
        }
      } catch (e) {
        print("❌ Retry ${i + 1} failed: $e");
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }
    return '';
  }

  void _startVoiceLoop() async {
    if (!_audioReady) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_audioReady) return;
    }
    setState(() {
      _voiceLoopActive = true;
    });
    await Future.delayed(const Duration(milliseconds: 100)); // REDUCED from 200
    await _startRecordingWithAutoStop();
  }

  void _stopAll() async {
    print("🛑 Stopping all audio activities");
    _voiceLoopActive = false;
    _isProcessingMessage = false;
    _pendingTranscript = "";
    _restartTimer?.cancel();
    _maxTimer?.cancel();
    _silenceTimer?.cancel();
    _typingTimer?.cancel();
    _guiderWaitTimer?.cancel();
    _recorderSubscription?.cancel();

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _tts.stop();
      _pauseBackgroundVideo();
    } catch (e) {
      print("Error stopping: $e");
    }

    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isBusy = false;
      _isSpeaking = false;
      _guiderSpeaking = false;
      _isGuiderWaiting = false;
      _textBuffer.clear();
      _visibleAiText = "";
      _speakingQueue.clear();
      _isProcessingQueue = false;
    });
    _stopping = false;
  }

  // ==========================
  // TTS METHODS (OPTIMIZED)
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
        print("🎯 TTS completion handler triggered");
        setState(() {
          _isSpeaking = false;
          _textBuffer.clear();
          _visibleAiText = "";
        });

        _pauseBackgroundVideo();

        if (_speakingQueue.isEmpty) {
          setState(() {
            _isBusy = false;
            _status = _guiderActive ? "GUIDED" : "LIVE";
          });
        }

        if (_voiceLoopActive && mounted && !_isMuted && _speakingQueue.isEmpty && !_isProcessingMessage) {
          Future.delayed(const Duration(milliseconds: 100), () { // REDUCED from 200
            if (_voiceLoopActive && !_isMuted && mounted && !_isBusy && _speakingQueue.isEmpty && !_isProcessingMessage) {
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
        _pauseBackgroundVideo();
      });
    } catch (e) {
      print("❌ TTS init error: $e");
    }
  }

  // OPTIMIZED speak method
  Future<void> _speakTextFast(String text, {bool isGuider = false}) async {
    final ttsStopwatch = Stopwatch()..start();
    print("🔊 TTS START: ${isGuider ? 'Guider' : 'Character'} - ${text.substring(0, text.length > 50 ? 50 : text.length)}...");

    if (text.isEmpty) return;

    if (isGuider && _isSpeaking) {
      print("🛑 GUARD: Guider prevented from interrupting character speech");
      _speakingQueue.add({'text': text, 'isGuider': isGuider});
      return;
    }

    final previousRate = _currentSpeechRate;
    final previousPitch = _currentPitch;

    if (isGuider) {
      _currentSpeechRate = 0.52;
      _currentPitch = 1.2;
      await _tts.setSpeechRate(_currentSpeechRate);
      await _tts.setPitch(_currentPitch);
    } else {
      final settings = _getCharacterVoiceSettings(widget.character.characterName);
      _currentSpeechRate = settings['rate'];
      _currentPitch = settings['pitch'];
      await _tts.setSpeechRate(_currentSpeechRate);
      await _tts.setPitch(_currentPitch);
    }

    final speechCompleter = Completer<void>();

    void onSpeechComplete() {
      final elapsed = ttsStopwatch.elapsedMilliseconds;
      print("✅ TTS COMPLETE: ${isGuider ? 'Guider' : 'Character'} took ${elapsed}ms");

      if (mounted) {
        setState(() {
          if (isGuider) {
            _guiderSpeaking = false;
            _guiderMessage = "";
          } else {
            _isSpeaking = false;
            _pauseBackgroundVideo();
          }
        });

        print("🎙️ Restarting voice loop after speech completion");
        Future.delayed(const Duration(milliseconds: 150), () { // REDUCED from 300
          if (mounted && _voiceLoopActive && !_isMuted && !_isSpeaking && !_isProcessingMessage && !_isBusy && !_guiderSpeaking && _speakingQueue.isEmpty) {
            print("🎙️ Actually starting recording now...");
            _startRecordingWithAutoStop();
          }
        });
      }
      if (!speechCompleter.isCompleted) {
        speechCompleter.complete();
      }
    }

    _tts.setCompletionHandler(onSpeechComplete);

    try {
      setState(() {
        if (isGuider) {
          _guiderSpeaking = true;
          _guiderMessage = text;
        } else {
          _isSpeaking = true;
          _isBusy = false;
          _status = "SPEAKING";
          _startBackgroundVideo();
        }
      });

      print("🗣️ Speaking text in _speakTextFast: ${text.substring(0, text.length > 50 ? 50 : text.length)}...");
      await _tts.speak(text);
      await speechCompleter.future;

      print("✅ Speech completed for this message");

    } catch (e) {
      print("❌ TTS Error: $e");
      setState(() {
        _isSpeaking = false;
        _guiderSpeaking = false;
        _error = "TTS error: $e";
      });
      _pauseBackgroundVideo();
      if (!speechCompleter.isCompleted) {
        speechCompleter.complete();
      }

      if (_voiceLoopActive && !_isMuted && mounted) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _voiceLoopActive && !_isMuted && !_isSpeaking && !_isProcessingMessage) {
            _startRecordingWithAutoStop();
          }
        });
      }
    } finally {
      _currentSpeechRate = previousRate;
      _currentPitch = previousPitch;
      await _tts.setSpeechRate(previousRate);
      await _tts.setPitch(previousPitch);
    }
  }

  Future<void> _processQueue() async {
    if (_speakingQueue.isEmpty) {
      _isProcessingQueue = false;
      return;
    }

    _isProcessingQueue = true;
    final item = _speakingQueue.removeAt(0);
    final text = item['text'] as String;
    final isGuider = item['isGuider'] as bool;

    if (isGuider && _isSpeaking) {
      print("🛡️ Guider in queue waiting for character to finish...");
      _speakingQueue.insert(0, item);
      await Future.delayed(const Duration(milliseconds: 100)); // REDUCED from 150
      _processQueue();
      return;
    }

    final queueStopwatch = Stopwatch()..start();
    print("📋 QUEUE PROCESSING: ${isGuider ? 'Guider' : 'Character'} message");

    await _speakTextFast(text, isGuider: isGuider);

    _logTiming("Queue item (${isGuider ? 'Guider' : 'Character'})", queueStopwatch);

    if (isGuider) {
      await Future.delayed(const Duration(milliseconds: 200)); // REDUCED from 300
    } else {
      await Future.delayed(const Duration(milliseconds: 100)); // REDUCED from 150
    }

    _processQueue();
  }

  void _startTypingAnimation(String fullText) {
    _typingTimer?.cancel();
    setState(() {
      _textBuffer.clear();
      _visibleAiText = "";
    });

    final words = fullText.split(' ');
    int index = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 230), (timer) { // REDUCED from 280
      if (index >= words.length) {
        timer.cancel();
        return;
      }
      if (!mounted) return;
      setState(() {
        _textBuffer.add(words[index]);
        if (_textBuffer.length > 12) {
          _textBuffer.removeAt(0);
        }
        _visibleAiText = _textBuffer.join(' ');
      });
      index++;
    });
  }

  // ==========================
  // HANDLE GUIDER INVITATION / REMOVAL
  // ==========================

  Future<void> _handleGuiderInvitation(bool accept) async {
    if (!mounted) return;

    if (accept) {
      _stopAll();

      setState(() {
        _guiderActive = true;
        _status = "GUIDED";
        _intervention = GuiderInterventionModel.none;
        _showingIntervention = false;
        _guiderMessage = _getGuiderSupportMessage();
      });

      if (_currentSessionId != null) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          _addBackgroundTask(() async {
            await _sessionRepository.setGuiderJoined(
              uid: user.uid,
              sessionId: _currentSessionId!,
              guiderJoined: true,
            );
          });
        }
      }

      final welcomeMessage = _getGuiderWelcomeMessage();
      if (welcomeMessage.isNotEmpty) {
        unawaited(_saveMessage('assistant', welcomeMessage, sender: 'guider'));
        _conversationHistory.add({
          'role': 'assistant',
          'content': welcomeMessage,
          'isGuider': true,
        });
      }

      await _speakTextFast(welcomeMessage, isGuider: true);

      await Future.delayed(const Duration(milliseconds: 300)); // REDUCED from 500

      if (mounted) {
        setState(() {
          _isProcessingMessage = false;
          _isBusy = false;
          _isSpeaking = false;
          _guiderSpeaking = false;
          _isProcessingQueue = false;
          _stopping = false;
          _pendingTranscript = "";
        });

        _speakingQueue.clear();
        _voiceLoopActive = true;
        _startRecordingWithAutoStop();
      }
    } else {
      setState(() {
        _status = "LIVE";
        _intervention = GuiderInterventionModel.none;
        _showingIntervention = false;
        _guiderMessage = "";
      });
      _startVoiceLoop();
    }
  }

  Future<void> _handleGuiderRemoval() async {
    if (!mounted) return;

    setState(() {
      _guiderActive = false;
      _status = "LIVE";
      _guiderMessage = "";
    });

    final exitMessage = _getGuiderExitMessage();
    if (exitMessage.isNotEmpty) {
      unawaited(_saveMessage('assistant', exitMessage, sender: 'guider'));
      _conversationHistory.add({
        'role': 'assistant',
        'content': exitMessage,
        'isGuider': true,
      });
    }

    await _speakWithQueue(exitMessage, isGuider: true);

    if (_currentSessionId != null) {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        _addBackgroundTask(() async {
          await _sessionRepository.setGuiderJoined(
            uid: user.uid,
            sessionId: _currentSessionId!,
            guiderJoined: false,
          );
        });
      }
    }

    await Future.delayed(const Duration(milliseconds: 200)); // REDUCED from 300
    _startVoiceLoop();
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
    if (!_isCameraDisposed) {
      _isCameraDisposed = true;

      if (_cameraController != null) {
        try {
          await _cameraController?.stopImageStream();
          await _cameraController?.dispose();
          print("✅ Camera disposed successfully");
        } catch (e) {
          print("Error disposing camera: $e");
        } finally {
          _cameraController = null;
          _isCameraInitialized = false;
        }
      }
    }
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
      setState(() {
        _isVideoEnabled = false;
        _isCameraInitialized = false;
      });
      await _disposeCamera();
    } else {
      setState(() {
        _isVideoEnabled = true;
      });
      _isCameraDisposed = false;
      await _initializeCamera();
      if (mounted) {
        setState(() {
          _isCameraInitialized = _cameraController?.value.isInitialized ?? false;
        });
      }
    }
  }

  Future<void> _endCall() async {
    _durationTimer?.cancel();
    _voiceLoopActive = false;
    _isProcessingMessage = false;
    _stopAll();

    if (mounted) {
      setState(() {
        _isVideoEnabled = false;
        _isCameraInitialized = false;
      });
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController?.stopImageStream();
        await _cameraController?.dispose();
        print("✅ Camera explicitly closed and disposed");
      } catch (e) {
        print("Error closing camera: $e");
      } finally {
        _cameraController = null;
        _isCameraInitialized = false;
        _isCameraDisposed = true;
      }
    }

    await Future.delayed(const Duration(milliseconds: 100));
    await _endEmotionSession();

    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentSessionId != null && _currentThreadId != null) {
      _addBackgroundTask(() => _sendSessionSummary(user));
      _addBackgroundTask(() => _sessionRepository.endVideoSession(
        uid: user.uid,
        sessionId: _currentSessionId!,
        duration: _callDurationSeconds,
      ));
    }

    if (_backgroundVideoController != null) {
      await _backgroundVideoController!.dispose();
    }
    if (_videoController != null) {
      await _videoController!.dispose();
    }

    _httpClient?.close();

    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          Navigator.pop(context);
        }
      });
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

      final response = await _httpClient!.post(
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
      ).timeout(const Duration(seconds: 12));

      print("✅ Session summary sent: ${response.statusCode}");
    } catch (e) {
      print("Error sending session summary: $e");
    }
  }

  void _showGuiderModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GuiderModal(
        isGuiderInChat: _guiderActive,
        characterName: widget.character.displayNameEn,
        onInviteGuider: () {
          Navigator.pop(context);
          _handleGuiderInvitation(true);
        },
        onRemoveGuider: () {
          Navigator.pop(context);
          _handleGuiderRemoval();
        },
      ),
    );
  }

  void _toggleGuider() {
    _showGuiderModal();
  }

  // ==========================
  // RESPONSIVE UI BUILDERS
  // ==========================

  Widget _buildTopBar() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: 8,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 6 : 8,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: isSmallScreen ? 16 : 20,
                  color: Colors.purple,
                ),
                SizedBox(width: isSmallScreen ? 4 : 6),
                Text(
                  _formatDuration(_callDurationSeconds),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.purple,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: _toggleGuider,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: _guiderActive ? const Color(0xFFB79CFF).withValues(alpha: 0.2) : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _guiderActive ? const Color(0xFFB79CFF) : Colors.grey.withValues(alpha: 0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: isSmallScreen ? 20 : 24,
                        height: isSmallScreen ? 20 : 24,
                        child: ClipOval(
                          child: Image.asset(_guiderGifPath, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(Icons.assistant_navigation, size: isSmallScreen ? 14 : 18,
                                  color: _guiderActive ? const Color(0xFFB79CFF) : Colors.grey)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(width: isSmallScreen ? 8 : 12),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 10 : 14,
                  vertical: isSmallScreen ? 4 : 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: isSmallScreen ? 3 : 4,
                      backgroundColor: _isRecording ? Colors.green : _isBusy ? Colors.orange : _isSpeaking ? Colors.purple : _guiderSpeaking ? const Color(0xFFB79CFF) : Colors.red,
                    ),
                    SizedBox(width: isSmallScreen ? 4 : 6),
                    Text(
                      _getStatusText(),
                      style: TextStyle(
                        color: Colors.purple,
                        fontWeight: FontWeight.bold,
                        fontSize: isSmallScreen ? 12 : 16,
                      ),
                    ),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  Widget _buildGuiderIndicator() {
    if (!_guiderActive) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final gifSize = isSmallScreen ? 150.0 : 85.0;

    return Positioned(
      top: 100,
      left: 0,
      child: GestureDetector(
        onTap: _toggleGuider,
        child: Container(
          width: gifSize,
          height: gifSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: _guiderSpeaking
                ? [
              BoxShadow(
                color: const Color(0xFFB79CFF).withValues(alpha: 0.5),
                blurRadius: 15,
                spreadRadius: 2,
              ),
            ]
                : null,
          ),
          child: ClipOval(
            child: Image.asset(
              _guiderGifPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)]),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.assistant_navigation, color: Colors.white, size: gifSize * 0.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInterventionOverlay() {
    if (!_showingIntervention) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 400;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            width: screenWidth * 0.85,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: isSmallScreen ? 60 : 80,
                  height: isSmallScreen ? 60 : 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: const Color(0xFFB79CFF).withValues(alpha: 0.6), blurRadius: 20)],
                  ),
                  child: ClipOval(
                    child: Image.asset(_guiderGifPath, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)]), shape: BoxShape.circle),
                          child: Icon(Icons.assistant_navigation, color: Colors.white, size: isSmallScreen ? 30 : 40),
                        )),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                Text(
                  _getGuiderName(),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 20 : 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF2A1E3B),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _intervention.guiderMessage ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14 : 16,
                      color: const Color(0xFF4B3A66),
                      height: 1.5,
                    ),
                  ),
                ),
                SizedBox(height: isSmallScreen ? 20 : 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleGuiderInvitation(false),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF6A5CFF),
                          side: const BorderSide(color: Color(0xFFB79CFF), width: 1.5),
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          _getContinueAloneText(),
                          style: TextStyle(fontSize: isSmallScreen ? 13 : 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleGuiderInvitation(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB79CFF),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 4,
                        ),
                        child: Text(
                          _getInviteGuiderButtonText(),
                          style: TextStyle(fontSize: isSmallScreen ? 13 : 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                Text(
                  _getGuiderSupportText(),
                  style: TextStyle(fontSize: isSmallScreen ? 10 : 11, color: Colors.grey.shade500),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, {bool isActive = true, bool isEndCall = false}) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final buttonSize = isSmallScreen ? 55.0 : 70.0;
    final iconSize = isSmallScreen ? 24.0 : 30.0;

    if (isEndCall) {
      return Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)]),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    }
    if (!isActive) {
      return Container(
        width: buttonSize,
        height: buttonSize,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4A2B7A),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    }
    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)]),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)],
      ),
      child: Icon(icon, color: Colors.white, size: iconSize),
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
    _guiderWaitTimer?.cancel();
    _recorderSubscription?.cancel();
    _stopAll();
    _continuousTranscribeTimer?.cancel();

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      _cameraController?.stopImageStream();
      _cameraController?.dispose();
      _cameraController = null;
      print("✅ Camera closed in dispose");
    }

    if (_backgroundVideoController != null) {
      _backgroundVideoController!.dispose();
      print("✅ Background video player disposed");
    }

    if (_videoController != null) {
      _videoController!.dispose();
      print("✅ Legacy video player disposed");
    }

    _httpClient?.close();

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
    final isSmallScreen = screenWidth < 400;
    final isLandscape = screenWidth > screenHeight;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    final characterCircleSize = isTablet ? screenWidth * 0.45 : screenWidth * 0.6;
    final o3dHeight = isLandscape ? screenHeight * 0.15 : screenHeight * 0.3;
    final o3dWidth = isLandscape ? screenWidth * 0.25 : screenWidth * 0.15;
    final videoWidth = isSmallScreen ? 110.0 : 130.0;
    final videoHeight = isSmallScreen ? 150.0 : 170.0;
    final chatContainerWidth = isLandscape ? screenWidth * 0.7 : screenWidth * 0.9;
    final double characterNameFontSize = isSmallScreen ? 22.0 : 26.0;
    final double quoteFontSize = isSmallScreen ? 14.0 : 16.0;

    final bool usesVideo = _usesVideo();

    return Scaffold(
      body: Stack(
        children: [
          // Full screen background video or image
          if (usesVideo && _backgroundVideoController != null && _isBackgroundVideoInitialized)
            Positioned.fill(
              child: VideoPlayer(_backgroundVideoController!),
            )
          else
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
                  flex: isLandscape ? 6 : 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 5,
                        right: isSmallScreen ? 10: -35,
                        child: GestureDetector(
                          onTap: _toggleVideo,
                          child: Container(
                            width: videoWidth,
                            height: videoHeight,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isVideoEnabled ? Colors.purple : const Color(0xFF4A2B7A),
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 15, spreadRadius: 2),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: _isVideoEnabled && _isCameraInitialized && _cameraController != null && _cameraController!.value.isInitialized
                                  ? CameraPreview(_cameraController!)
                                  : Container(
                                color: _isVideoEnabled
                                    ? Colors.purple.withValues(alpha: 0.3)
                                    : const Color(0xFF4A2B7A).withValues(alpha: 0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                                        color: Colors.white,
                                        size: isSmallScreen ? 30 : 40,
                                      ),
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      Text(
                                        _getYouText(),
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 12 : 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (!_isVideoEnabled)
                                        Container(
                                          margin: const EdgeInsets.only(top: 5),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A2B7A).withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            _getOffText(),
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 10,
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
                  offset: Offset(0, isSmallScreen ? -4 : -6),
                  child: Column(
                    children: [
                      Container(
                        width: chatContainerWidth,
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 16 : 24,
                          vertical: isSmallScreen ? 16 : 20,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.95),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, -2)),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              widget.character.getDisplayName(_detectedLanguage == 'ar' ? 'ar' : 'en'),
                              style: TextStyle(
                                fontSize: characterNameFontSize,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2A1E3B),
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
                                  style: TextStyle(
                                    color: Colors.purple,
                                    fontSize: isSmallScreen ? 12 : 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            Text(
                              _visibleAiText.isNotEmpty
                                  ? _visibleAiText
                                  : _getCharacterQuote(widget.character.characterName),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: quoteFontSize,
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
                          SizedBox(width: isSmallScreen ? 20 : 30),
                          GestureDetector(
                            onTap: _endCall,
                            child: _circleButton(
                              Icons.call_end,
                              isEndCall: true,
                            ),
                          ),
                          SizedBox(width: isSmallScreen ? 20 : 30),
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

class _GuiderModal extends StatelessWidget {
  final bool isGuiderInChat;
  final String characterName;
  final VoidCallback onInviteGuider;
  final VoidCallback onRemoveGuider;

  const _GuiderModal({
    required this.isGuiderInChat,
    required this.characterName,
    required this.onInviteGuider,
    required this.onRemoveGuider,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final avatarSize = isSmallScreen ? 60.0 : 80.0;
    final titleFontSize = isSmallScreen ? 18.0 : 20.0;
    final textFontSize = isSmallScreen ? 13.0 : 15.0;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: const Color(0xFFB79CFF).withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, -4)),
          ],
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: const Color(0xFFE5DEFF), borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 20),
              Container(
                width: avatarSize,
                height: avatarSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: const Color(0xFFB79CFF).withValues(alpha: 0.6), blurRadius: 20)],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/animations/guider.gif',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.assistant_navigation, color: Colors.white, size: avatarSize * 0.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'The Guider',
                style: TextStyle(fontSize: titleFontSize, fontWeight: FontWeight.w800, color: const Color(0xFF2A1E3B)),
              ),
              const SizedBox(height: 12),
              Text(
                isGuiderInChat
                    ? 'The Guider is currently in this conversation, helping you and your $characterName understand each other better.'
                    : 'Would you like The Guider to join this conversation? They can help you and your $characterName communicate with more clarity and compassion.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: textFontSize, color: const Color(0xFF6B5C82), height: 1.5),
              ),
              const SizedBox(height: 24),
              if (isGuiderInChat)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: onRemoveGuider,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF8B7EC8),
                      side: const BorderSide(color: Color(0xFFB79CFF)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                    ),
                    child: Text(
                      'Continue without The Guider',
                      style: TextStyle(fontSize: textFontSize, fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              else
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onInviteGuider,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFB79CFF),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                        ),
                        child: Text(
                          'Yes, invite The Guider',
                          style: TextStyle(fontSize: textFontSize, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF8B7EC8),
                          padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 12 : 14),
                        ),
                        child: Text(
                          'Not now',
                          style: TextStyle(fontSize: textFontSize, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}