import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

// ==========================
// DEBUG TIMING HELPER
// ==========================
class DebugTimer {
  final String name;
  final Stopwatch _stopwatch = Stopwatch();
  DateTime? _startTime;
  bool _isRunning = false;
  static final Map<String, List<int>> _timings = {};
  static final Map<String, int> _counts = {};

  DebugTimer(this.name);

  void start() {
    _stopwatch.reset();
    _stopwatch.start();
    _startTime = DateTime.now();
    _isRunning = true;
    print('⏱️ [START] $name');
  }

  void stop() {
    if (!_isRunning) return;
    _stopwatch.stop();
    _isRunning = false;
    final elapsed = _stopwatch.elapsedMilliseconds;
    _timings.putIfAbsent(name, () => []).add(elapsed);
    _counts[name] = (_counts[name] ?? 0) + 1;
    print('⏱️ [END] $name: ${elapsed}ms');
  }

  void lap(String label) {
    if (!_isRunning) return;
    final elapsed = _stopwatch.elapsedMilliseconds;
    print('⏱️ [LAP] $name - $label: ${elapsed}ms');
  }

  static void printSummary() {
    print('\n' + '=' * 80);
    print('📊 TIMING SUMMARY REPORT');
    print('=' * 80);

    final sortedKeys = _timings.keys.toList()..sort();
    for (final key in sortedKeys) {
      final timings = _timings[key]!;
      final count = _counts[key] ?? 0;
      final total = timings.reduce((a, b) => a + b);
      final avg = total ~/ count;
      final min = timings.reduce((a, b) => a < b ? a : b);
      final max = timings.reduce((a, b) => a > b ? a : b);

      print('📌 $key');
      print('   Count: $count');
      print('   Total: ${total}ms (${(total / 1000).toStringAsFixed(2)}s)');
      print('   Avg:   ${avg}ms');
      print('   Min:   ${min}ms');
      print('   Max:   ${max}ms');
      print('');
    }

    // Calculate total time per category
    final categories = {
      'Session': ['_generateSessionAndThread', '_startVideoSession', '_startVideoSession_verify'],
      'Emotion': ['_initializeEmotionSession', '_captureAndAnalyzeFrame', '_analyzeAudioEmotion', '_sendPendingEmotions', '_endEmotionSession'],
      'Camera': ['_initializeCamera', '_disposeCamera'],
      'Audio': ['_initAudio', '_startRecordingWithAutoStop', '_stopRecordingAndSend'],
      'Transcription': ['_transcribeAudio', '_transcribePartialIncremental'],
      'AI Response': ['_getGuiderResponse', '_preloadGuiderResponse'],
      'TTS': ['_initTts', '_speakGuiderText', '_warmupTts'],
      'Message Save': ['_saveMessageEncrypted'],
      'Summary': ['_endCallAndSaveSummary'],
    };

    print('=' * 80);
    print('📊 CATEGORY SUMMARY');
    print('=' * 80);

    for (final entry in categories.entries) {
      final category = entry.key;
      final keys = entry.value;
      int totalTime = 0;
      int totalCalls = 0;

      for (final key in keys) {
        if (_timings.containsKey(key)) {
          final timings = _timings[key]!;
          totalTime += timings.reduce((a, b) => a + b);
          totalCalls += timings.length;
        }
      }

      if (totalCalls > 0) {
        print('📂 $category');
        print('   Total: ${totalTime}ms (${(totalTime / 1000).toStringAsFixed(2)}s)');
        print('   Calls: $totalCalls');
        print('   Avg:   ${totalTime ~/ totalCalls}ms');
        print('');
      }
    }

    print('=' * 80);
  }
}

// Extension method for easy timing
extension TimedAsync on Future {
  static Future<T> timed<T>(String name, Future<T> Function() action) async {
    final timer = DebugTimer(name);
    timer.start();
    try {
      final result = await action();
      timer.stop();
      return result;
    } catch (e) {
      timer.stop();
      rethrow;
    }
  }
}

class GuiderVideoCallScreen extends StatefulWidget {
  final String userName;
  final String? characterId;

  const GuiderVideoCallScreen({
    super.key,
    required this.userName,
    this.characterId,
  });

  @override
  State<GuiderVideoCallScreen> createState() => _GuiderVideoCallScreenState();
}

class _GuiderVideoCallScreenState extends State<GuiderVideoCallScreen> {
  // ==========================
  // UI VARIABLES
  // ==========================
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  bool _isProcessing = false;
  bool _isRecording = false;
  bool _isSpeaking = false;
  String _lastUserTranscript = "";
  String _status = "LIVE";
  double _currentDbLevel = -100.0;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;

  // Session and Thread IDs for database saving
  String _sessionId = "";
  String _threadId = "";
  bool _hasMessages = false; // Track if any messages were exchanged

  // Emotion tracking variables
  String _emotionSessionId = "";
  static const String _emotionServerUrl = "http://192.168.100.7:5002";
  Timer? _emotionFrameTimer;
  bool _emotionActive = false;
  int _frameSkip = 0;

  // Store last detected emotions to send to backend
  String _lastFaceEmotion = "neutral";
  double _lastFaceConfidence = 0.0;
  String _lastVoiceEmotion = "neutral";
  double _lastVoiceConfidence = 0.0;
  Timer? _emotionSendTimer;
  bool _hasPendingEmotionUpdate = false;

  static const String _guiderGifPath = 'assets/animations/guider.gif';

  // OPTIMIZATION: Pre-cached fallback responses
  static const List<String> _fallbackMessages = [
    "Take a deep breath. I'm here with you.",
    "Notice how you're feeling right now.",
    "There's no rush. We have all the time you need.",
    "Whatever you're experiencing is valid.",
    "You're doing important work by being here.",
    "Let's explore this together, gently.",
    "Your inner parts are welcome here.",
    "This is a safe space for all of you.",
    "Breathe. Feel. Be present.",
    "I'm listening - not just to your words, but to you.",
  ];

  // Text buffer for rolling text
  final List<String> _textBuffer = [];
  String _visibleGuiderText = "";
  Timer? _typingTimer;

  // Camera
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isCameraDisposed = false;

  // ==========================
  // VOICE VARIABLES (OPTIMIZED)
  // ==========================
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterTts _tts = FlutterTts();

  bool _audioReady = false;
  bool _voiceLoopActive = false;
  bool _hasDetectedSpeech = false;
  bool _stopping = false;

  List<Map<String, String>> _conversationHistory = [];

  Timer? _maxTimer;
  Timer? _silenceTimer;
  Timer? _restartTimer;
  Timer? _readyCheckTimer;
  StreamSubscription? _recorderSubscription;

  // OPTIMIZATION: Reduced timing for faster responses
  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const Duration _maxRecord = Duration(seconds: 10);
  static const Duration _silenceThreshold = Duration(milliseconds: 250);
  static const double _silenceDbThreshold = -30.0;

  String? _wavPath;

  // TTS Settings
  double _guiderSpeechRate = 0.55;
  double _guiderPitch = 1.2;

  // OPTIMIZATION: Caching
  final Map<String, String> _cachedResponses = {};
  String _pendingTranscript = "";
  bool _isProcessingMessage = false;
  bool _isTranscribing = false;
  String? _preloadedResponse;
  bool _isPreloading = false;
  Timer? _continuousTranscribeTimer;
  String _partialTranscript = "";
  bool _isTranscribingPartial = false;

  // Backend
  static const String _voiceAppBaseUrl = "http://192.168.100.7:5003";
  static const String _guiderRespondEndpoint = "/guider/respond";
  static const String _guiderUpdateEmotionsEndpoint = "/guider/update_emotions";
  static const String _guiderSessionSummaryEndpoint = "/guider/session_summary";
  static const String _guiderSaveMessageEndpoint = "/guider/save_message";
  static const String _transcribeEndpoint = "/video/transcribe";

  int _sessionStartTime = DateTime.now().millisecondsSinceEpoch;

  // HTTP Client for connection pooling
  http.Client? _httpClient;

  @override
  void initState() {
    super.initState();
    _httpClient = http.Client();
    _generateSessionAndThread();
    _startVideoSession();
    _initializeEmotionSession();
    _initializeCamera();
    _initAudio();
    _initTts();
    _startDurationTracking();
    _warmupTts();
  }

  void _startDurationTracking() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_voiceLoopActive || _isProcessing || _isSpeaking) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  void _generateSessionAndThread() {
    final timer = DebugTimer('_generateSessionAndThread');
    timer.start();

    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _threadId = DateTime.now().millisecondsSinceEpoch.toString();
    _emotionSessionId = "emotion_${DateTime.now().millisecondsSinceEpoch}";
    print("📱 Session ID: $_sessionId");
    print("📱 Thread ID: $_threadId");

    timer.stop();
  }

  // OPTIMIZATION: TTS pre-warming
  Future<void> _warmupTts() async {
    await TimedAsync.timed('_warmupTts', () async {
      try {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(_guiderSpeechRate);
        await _tts.setPitch(_guiderPitch);
        print("🎤 TTS engine pre-warmed");
      } catch (e) {
        print("TTS warmup failed: $e");
      }
    });
  }

  Future<void> _startVideoSession() async {
    await TimedAsync.timed('_startVideoSession', () async {
      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // 🔥 FIX: Create the session document FIRST with isActive: true
        final sessionRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(_sessionId);

        await sessionRef.set({
          'threadId': _threadId,
          'startedAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'duration': 0,
          'hasMessages': false,
          'showInHistory': false,
          'characterType': 'guider',
          'type': 'video',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true)).timeout(const Duration(seconds: 5));

        print("✅ Session created: $_sessionId");
        print("   ThreadId: $_threadId");
        print("   isActive: true");

        // Also try the backend endpoint
        try {
          final response = await _httpClient!.post(
            Uri.parse("$_voiceAppBaseUrl/guider/start_session"),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'uid': user.uid,
              'sessionId': _sessionId,
              'threadId': _threadId,
              'userName': widget.userName,
              'characterId': widget.characterId,
            }),
          ).timeout(const Duration(seconds: 3));

          if (response.statusCode == 200) {
            print("✅ Video session started on backend");
          }
        } catch (e) {
          print("⚠️ Backend session start failed: $e");
        }

      } catch (e) {
        print("⚠️ Could not start video session: $e");
      }
    });
  }

  // ==========================
  // SAVE MESSAGE WITH ENCRYPTION (OPTIMIZED - Background)
  // ==========================
  Future<void> _saveMessageEncrypted(String role, String content, {String? sender}) async {
    await TimedAsync.timed('_saveMessageEncrypted', () async {
      if (_threadId.isEmpty) {
        print('❌ Cannot save message: threadId is empty');
        return;
      }

      // Mark that we have messages
      if (content.isNotEmpty) {
        _hasMessages = true;
      }

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        // OPTIMIZATION: Fire and forget
        unawaited(_httpClient!.post(
          Uri.parse("$_voiceAppBaseUrl$_guiderSaveMessageEndpoint"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uid': user.uid,
            'threadId': _threadId,
            'sessionId': _sessionId,
            'role': role,
            'content': content,
            'sender': sender ?? (role == 'user' ? 'user' : 'guider'),
            'characterId': role == 'assistant' ? 'guider' : null,
          }),
        ).timeout(const Duration(seconds: 5)).then((response) {
          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            if (data['success'] == true) {
              print('✅ Message saved encrypted via backend: ${data['messageId']}');
            }
          }
        }).catchError((e) {
          print('⚠️ Failed to save encrypted message: $e');
        }));
      } catch (e) {
        print('⚠️ Failed to save encrypted message: $e');
      }
    });
  }

  // ==========================
  // EMOTION METHODS WITH BACKEND SYNC
  // ==========================

  Future<void> _initializeEmotionSession() async {
    await TimedAsync.timed('_initializeEmotionSession', () async {
      try {
        final response = await _httpClient!.post(
          Uri.parse("$_emotionServerUrl/emotion/start_session"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'session_id': _emotionSessionId,
            'user_name': widget.userName,
            'character_id': widget.characterId,
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
    });
  }

  void _startEmotionFrameCapture() {
    _emotionFrameTimer = Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (_emotionActive && _isVideoEnabled && _isCameraInitialized && _cameraController != null) {
        _captureAndAnalyzeFrame();
      }
    });
  }

  Future<void> _captureAndAnalyzeFrame() async {
    await TimedAsync.timed('_captureAndAnalyzeFrame', () async {
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
        // Silent fail
      }
    });
  }

  Future<void> _analyzeAudioEmotion(String audioPath) async {
    await TimedAsync.timed('_analyzeAudioEmotion', () async {
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
            }
          }
        }
      } catch (e) {
        print("⚠️ Voice emotion analysis error: $e");
      }
    });
  }

  Future<void> _sendPendingEmotions() async {
    await TimedAsync.timed('_sendPendingEmotions', () async {
      if (!_hasPendingEmotionUpdate) return;

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final response = await _httpClient!.post(
          Uri.parse("$_voiceAppBaseUrl$_guiderUpdateEmotionsEndpoint"),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'uid': user.uid,
            'sessionId': _sessionId,
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
    });
  }

  Future<void> _endEmotionSession() async {
    await TimedAsync.timed('_endEmotionSession', () async {
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
    });
  }

  // ==========================
  // CAMERA METHODS
  // ==========================
  Future<void> _initializeCamera() async {
    await TimedAsync.timed('_initializeCamera', () async {
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
    });
  }

  Future<void> _disposeCamera() async {
    await TimedAsync.timed('_disposeCamera', () async {
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
    });
  }

  // ==========================
  // TTS METHODS (OPTIMIZED)
  // ==========================
  Future<void> _initTts() async {
    await TimedAsync.timed('_initTts', () async {
      try {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(_guiderSpeechRate);
        await _tts.setPitch(_guiderPitch);
        await _tts.setVolume(1.0);

        _tts.setCompletionHandler(() {
          if (mounted) {
            setState(() {
              _isSpeaking = false;
              _isProcessing = false;
              _textBuffer.clear();
              _visibleGuiderText = "";
              _status = "LIVE";
            });
          }

          if (_voiceLoopActive && mounted && !_isMuted) {
            Future.delayed(const Duration(milliseconds: 150), () {
              if (_voiceLoopActive && !_isMuted && mounted && !_isProcessingMessage) {
                _startRecordingWithAutoStop();
              }
            });
          }
        });

        _tts.setErrorHandler((msg) {
          print("❌ TTS Error: $msg");
          if (mounted) {
            setState(() {
              _isSpeaking = false;
            });
          }
        });
        print("✅ TTS initialized");
      } catch (e) {
        print("❌ TTS init error: $e");
      }
    });
  }

  Future<void> _speakGuiderText(String text) async {
    await TimedAsync.timed('_speakGuiderText', () async {
      if (text.isEmpty) return;

      try {
        if (mounted) {
          setState(() {
            _isSpeaking = true;
            _status = "SPEAKING";
          });
        }

        await _tts.setSpeechRate(_guiderSpeechRate);
        await _tts.setPitch(_guiderPitch);
        await _tts.speak(text);
      } catch (e) {
        print("❌ TTS Error: $e");
        if (mounted) {
          setState(() {
            _isSpeaking = false;
          });
        }
      }
    });
  }

  // ==========================
  // AUDIO METHODS (OPTIMIZED)
  // ==========================
  Future<void> _initAudio() async {
    await TimedAsync.timed('_initAudio', () async {
      try {
        print("🎤 Initializing audio...");
        final mic = await Permission.microphone.request();
        if (!mic.isGranted) {
          if (mounted) {
            setState(() {
              _status = "NO_MIC";
            });
          }
          return;
        }
        await _recorder.openRecorder();
        _recorder.setSubscriptionDuration(const Duration(milliseconds: 50));
        if (mounted) {
          setState(() {
            _audioReady = true;
          });
        }
        print("✅ Audio initialized");
        _startVoiceLoop();
      } catch (e) {
        print("❌ Audio init error: $e");
        if (mounted) {
          setState(() {
            _status = "ERROR";
          });
        }
      }
    });
  }

  Future<String> _makeWavPath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "${dir.path}/guider_audio_$timestamp.wav";
  }

  void _setupVoiceDetection() {
    _recorderSubscription?.cancel();
    _recorderSubscription = _recorder.onProgress!.listen((event) {
      if (!_isRecording || _stopping) return;
      final dbLevel = event.decibels ?? -100.0;
      _currentDbLevel = dbLevel;

      if (mounted) {
        setState(() {});
      }

      if (dbLevel > _silenceDbThreshold) {
        if (!_hasDetectedSpeech) {
          _hasDetectedSpeech = true;
          print("🎤 Speech detected at ${dbLevel.toStringAsFixed(1)}dB");
        }
        _silenceTimer?.cancel();
        _silenceTimer = Timer(_silenceThreshold, () {
          if (_hasDetectedSpeech && _isRecording && !_stopping) {
            print("🔇 Silence reached - processing");
            _stopRecordingAndSend();
          }
        });
      }
    });
  }

  // OPTIMIZATION: Continuous transcription for preloading
  void _startContinuousTranscription() {
    _continuousTranscribeTimer?.cancel();

    _continuousTranscribeTimer = Timer.periodic(const Duration(milliseconds: 600), (timer) {
      if (_isRecording && _recorder.isRecording && !_isTranscribingPartial && _wavPath != null) {
        final recordDuration = DateTime.now().difference(_recordStartAt!);
        if (recordDuration > const Duration(seconds: 1)) {
          _transcribePartialIncremental();
        }
      }
    });
  }

  DateTime? _recordStartAt;

  Future<void> _transcribePartialIncremental() async {
    await TimedAsync.timed('_transcribePartialIncremental', () async {
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

        final uri = Uri.parse("$_voiceAppBaseUrl$_transcribeEndpoint");
        var request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath('file', path),
        );

        final response = await request.send().timeout(const Duration(milliseconds: 800));
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
              _preloadGuiderResponse(transcript);
            }
          }
        }
      } catch (e) {
        // Silent fail
      }

      _isTranscribingPartial = false;
    });
  }

  // OPTIMIZATION: Preload guider response
  Future<void> _preloadGuiderResponse(String partialText) async {
    await TimedAsync.timed('_preloadGuiderResponse', () async {
      if (_isPreloading || partialText.length < 15) return;
      if (_preloadedResponse != null) return;

      _isPreloading = true;

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) return;

        final url = Uri.parse("$_voiceAppBaseUrl$_guiderRespondEndpoint");
        final requestBody = {
          'uid': user.uid,
          'userMessage': partialText,
          'characterId': widget.characterId,
          'sessionId': _sessionId,
          'threadId': _threadId,
          'conversationHistory': _conversationHistory,
          'preload': true,
        };

        final response = await _httpClient!.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 2));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['guiderMessage'] != null && data['guiderMessage'].isNotEmpty) {
            _preloadedResponse = data['guiderMessage'];
            print("✅ Preloaded guider response ready (${_preloadedResponse!.length} chars)");
          }
        }
      } catch (e) {
        // Silent fail
      }

      _isPreloading = false;
    });
  }

  Future<void> _startRecordingWithAutoStop() async {
    await TimedAsync.timed('_startRecordingWithAutoStop', () async {
      if (!_voiceLoopActive || _isMuted) return;
      if (_isSpeaking || _isProcessing || _isRecording) return;
      if (_isProcessingMessage) return;

      _stopping = false;
      _hasDetectedSpeech = false;
      _partialTranscript = "";
      _preloadedResponse = null;

      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
          await Future.delayed(const Duration(milliseconds: 20));
        }

        if (mounted) {
          setState(() {
            _isRecording = true;
            _status = "LISTENING";
          });
        }

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

        Future.delayed(const Duration(milliseconds: 400), () {
          if (_isRecording) _startContinuousTranscription();
        });

        _maxTimer?.cancel();
        _maxTimer = Timer(_maxRecord, () async {
          if (!_voiceLoopActive || !_isRecording) return;
          print("⏰ Max recording time");
          await _stopRecordingAndSend();
        });
        print("✅ Recording started successfully");
      } catch (e) {
        print("❌ Record error: $e");
        if (mounted) {
          setState(() {
            _isRecording = false;
            _status = "LIVE";
          });
        }
      }
    });
  }

  Future<String> _transcribeAudio(String wavPath) async {
    return await TimedAsync.timed('_transcribeAudio', () async {
      try {
        final uri = Uri.parse("$_voiceAppBaseUrl$_transcribeEndpoint");
        var request = http.MultipartRequest('POST', uri);
        request.files.add(
          await http.MultipartFile.fromPath('file', wavPath),
        );
        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 5),
        );
        final responseBody = await streamedResponse.stream.bytesToString();
        if (streamedResponse.statusCode == 200) {
          final data = jsonDecode(responseBody);
          return data['transcript'] ?? '';
        }
        return '';
      } catch (e) {
        print("❌ Transcription error: $e");
        return '';
      }
    });
  }

  Future<String> _getGuiderResponse(String uid, String userMessage) async {
    return await TimedAsync.timed('_getGuiderResponse', () async {
      try {
        // Check cache first
        if (_cachedResponses.containsKey(userMessage)) {
          print("🚀 USING CACHED GUIDER RESPONSE");
          return _cachedResponses[userMessage]!;
        }

        // Check preload
        if (_preloadedResponse != null && _preloadedResponse!.isNotEmpty) {
          if (_partialTranscript.isNotEmpty) {
            final similarityCheck = userMessage.contains(_partialTranscript) ||
                _partialTranscript.contains(userMessage.substring(0, min(userMessage.length, _partialTranscript.length)));

            if (similarityCheck) {
              print("🚀 USING PRELOADED GUIDER RESPONSE");
              final response = _preloadedResponse!;
              _preloadedResponse = null;
              return response;
            }
          } else if (_partialTranscript.isEmpty && userMessage.length > 15) {
            print("🚀 USING PRELOADED GUIDER RESPONSE (no partial)");
            final response = _preloadedResponse!;
            _preloadedResponse = null;
            return response;
          }
        }

        final url = Uri.parse("$_voiceAppBaseUrl$_guiderRespondEndpoint");

        final requestBody = {
          'uid': uid,
          'userMessage': userMessage,
          'characterId': widget.characterId,
          'sessionId': _sessionId,
          'threadId': _threadId,
          'conversationHistory': _conversationHistory,
        };

        print("📤 Sending to Guider: $userMessage");
        print("📤 SessionId: $_sessionId, ThreadId: $_threadId");

        final httpResponse = await _httpClient!.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 15));

        if (httpResponse.statusCode == 200) {
          final data = json.decode(httpResponse.body);
          final response = data['guiderMessage'] ?? _getRandomFallbackMessage();

          // Cache response
          if (userMessage.length > 20 && userMessage.length < 100 && response.length < 200) {
            _cachedResponses[userMessage] = response;
            if (_cachedResponses.length > 50) {
              _cachedResponses.remove(_cachedResponses.keys.first);
            }
          }

          return response;
        }
        return _getRandomFallbackMessage();
      } catch (e) {
        print("Network error: $e");
        return _getRandomFallbackMessage();
      }
    });
  }

  String _getRandomFallbackMessage() {
    final random = DateTime.now().millisecondsSinceEpoch % _fallbackMessages.length;
    return _fallbackMessages[random];
  }

  void _startTypingAnimation(String fullText) {
    _typingTimer?.cancel();
    if (mounted) {
      setState(() {
        _textBuffer.clear();
        _visibleGuiderText = "";
      });
    }

    final words = fullText.split(' ');
    int index = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 230), (timer) {
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
        _visibleGuiderText = _textBuffer.join(' ');
      });
      index++;
    });
  }

  Future<void> _stopRecordingAndSend() async {
    await TimedAsync.timed('_stopRecordingAndSend', () async {
      if (_stopping || !_isRecording) return;
      _stopping = true;

      try {
        if (mounted) {
          setState(() {
            _isProcessing = true;
            _status = "PROCESSING";
            _isRecording = false;
          });
        }

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
        print("📁 Audio file size: $len bytes");

        if (len < 5000 || !_hasDetectedSpeech) {
          print("⚠️ Audio too short ($len bytes) or no speech");
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
          if (_voiceLoopActive && !_isMuted) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_voiceLoopActive && !_isMuted && mounted) {
                _startRecordingWithAutoStop();
              }
            });
          }
          _preloadedResponse = null;
          _partialTranscript = "";
          return;
        }

        // Analyze audio for emotion (background)
        unawaited(_analyzeAudioEmotion(path));

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) throw Exception("User not logged in");

        if (mounted) {
          setState(() => _status = "TRANSCRIBING");
        }

        final transcript = await _transcribeAudio(path);
        if (transcript.isEmpty) {
          print("⚠️ Empty transcription");
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
          if (_voiceLoopActive && !_isMuted) {
            Future.delayed(const Duration(milliseconds: 100), () {
              if (_voiceLoopActive && !_isMuted && mounted) {
                _startRecordingWithAutoStop();
              }
            });
          }
          _preloadedResponse = null;
          _partialTranscript = "";
          return;
        }

        print("✅ Transcription: $transcript");

        if (mounted) {
          setState(() {
            _lastUserTranscript = transcript;
          });
        }

        // ============================================================
        // CRITICAL: Save user message with encryption (background)
        // ============================================================
        unawaited(_saveMessageEncrypted('user', transcript, sender: 'user'));

        _conversationHistory.add({'role': 'user', 'content': transcript});

        if (mounted) {
          setState(() => _status = "THINKING");
        }

        final guiderResponse = await _getGuiderResponse(user.uid, transcript);

        // ============================================================
        // CRITICAL: Save assistant message with encryption (background)
        // ============================================================
        unawaited(_saveMessageEncrypted('assistant', guiderResponse, sender: 'guider'));

        _startTypingAnimation(guiderResponse);

        _conversationHistory.add({'role': 'assistant', 'content': guiderResponse});

        if (_conversationHistory.length > 20) {
          _conversationHistory = _conversationHistory.sublist(_conversationHistory.length - 20);
        }

        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }

        await _speakGuiderText(guiderResponse);

        if (mounted) {
          setState(() {
            _textBuffer.clear();
            _visibleGuiderText = "";
          });
        }

        _preloadedResponse = null;
        _partialTranscript = "";

      } catch (e) {
        print("❌ Error: $e");
        if (mounted) {
          setState(() {
            _status = "LIVE";
            _isProcessing = false;
          });
        }
        if (_voiceLoopActive && !_isMuted) {
          Future.delayed(const Duration(milliseconds: 200), () {
            if (_voiceLoopActive && !_isMuted && mounted) {
              _startRecordingWithAutoStop();
            }
          });
        }
      } finally {
        _stopping = false;
      }
    });
  }

  Future<void> _startVoiceLoop() async {
    await TimedAsync.timed('_startVoiceLoop', () async {
      if (!_audioReady) {
        await Future.delayed(const Duration(seconds: 1));
        if (!_audioReady) return;
      }
      if (mounted) {
        setState(() {
          _voiceLoopActive = true;
        });
      }
      await Future.delayed(const Duration(milliseconds: 100));
      await _startRecordingWithAutoStop();
    });
  }

  void _stopAll() async {
    await TimedAsync.timed('_stopAll', () async {
      print("🛑 Stopping all audio activities");
      _voiceLoopActive = false;
      _isProcessingMessage = false;
      _pendingTranscript = "";
      _restartTimer?.cancel();
      _maxTimer?.cancel();
      _silenceTimer?.cancel();
      _typingTimer?.cancel();
      _recorderSubscription?.cancel();
      _continuousTranscribeTimer?.cancel();

      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
        await _tts.stop();
      } catch (e) {
        print("Error stopping: $e");
      }

      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
          _isSpeaking = false;
          _textBuffer.clear();
          _visibleGuiderText = "";
        });
      }
      _stopping = false;
    });
  }

  // ==========================
  // END CALL - FIXED
  // ==========================
  Future<void> _endCallAndSaveSummary() async {
    await TimedAsync.timed('_endCallAndSaveSummary', () async {
      _durationTimer?.cancel();
      _stopAll();
      await _endEmotionSession();
      await _disposeCamera();

      try {
        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          print("❌ No user found when ending session");
          if (mounted) Navigator.pop(context);
          return;
        }

        // Ensure we have a session ID
        if (_sessionId.isEmpty) {
          _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
        }

        // Ensure we have a thread ID
        if (_threadId.isEmpty) {
          _threadId = DateTime.now().millisecondsSinceEpoch.toString();
        }

        // Determine if session should be shown in history
        final shouldShowInHistory = _hasMessages || _callDurationSeconds > 10;

        print("🔚 Ending session: $_sessionId");
        print("   ThreadId: $_threadId");
        print("   Duration: ${_callDurationSeconds}s");
        print("   Has messages: $_hasMessages");
        print("   Show in history: $shouldShowInHistory");

        // 🔥 FIX: ALWAYS set isActive: false when ending
        final sessionRef = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('sessions')
            .doc(_sessionId);

        final sessionData = {
          'threadId': _threadId,
          'startedAt': FieldValue.serverTimestamp(),
          'endedAt': FieldValue.serverTimestamp(),
          'isActive': false, // 🔥 CRITICAL: Always false when ending
          'duration': _callDurationSeconds,
          'hasMessages': _hasMessages,
          'showInHistory': shouldShowInHistory,
          'characterType': 'guider',
          'type': 'video',
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Use set with merge to ensure the document exists
        await sessionRef.set(sessionData, SetOptions(merge: true))
            .timeout(const Duration(seconds: 5));

        print("✅ Session ended successfully: $_sessionId");
        print("   isActive set to: false");

        // Also ensure the thread exists and has the session reference
        if (_threadId.isNotEmpty) {
          try {
            final threadRef = FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('chat_threads')
                .doc(_threadId);

            await threadRef.set({
              'sessionId': _sessionId,
              'createdAt': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true)).timeout(const Duration(seconds: 3));
            print("✅ Thread updated with session reference");
          } catch (e) {
            print("⚠️ Could not update thread: $e");
          }
        }

        // Send summary to backend
        if (_conversationHistory.isNotEmpty) {
          unawaited(_sendSessionSummary(user));
        }

      } catch (e) {
        print("❌ Error ending session: $e");

        // 🔥 FALLBACK: Try a direct update as last resort
        try {
          final user = FirebaseAuth.instance.currentUser;
          if (user != null && _sessionId.isNotEmpty) {
            print("🔄 Attempting fallback update...");

            await FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .collection('sessions')
                .doc(_sessionId)
                .set({
              'endedAt': DateTime.now(),
              'isActive': false, // 🔥 CRITICAL: Always false
              'duration': _callDurationSeconds,
              'hasMessages': _hasMessages,
              'showInHistory': _hasMessages || _callDurationSeconds > 10,
              'threadId': _threadId,
              'characterType': 'guider',
              'type': 'video',
              'updatedAt': DateTime.now(),
            }, SetOptions(merge: true));

            print("✅ Session ended via fallback");
          }
        } catch (fallbackError) {
          print("❌ Fallback update failed: $fallbackError");
        }
      }

      _httpClient?.close();
      DebugTimer.printSummary();

      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  Future<void> _sendSessionSummary(User user) async {
    try {
      final url = Uri.parse("$_voiceAppBaseUrl$_guiderSessionSummaryEndpoint");

      final requestBody = {
        'uid': user.uid,
        'characterId': widget.characterId,
        'sessionId': _sessionId,
        'duration': _callDurationSeconds,
        'messages': _conversationHistory,
        'hasMessages': _hasMessages,
      };

      await _httpClient!.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 5));

      print("✅ Summary sent to backend");
    } catch (e) {
      print("Error sending summary: $e");
    }
  }

  void _toggleMute() {
    if (_isMuted) {
      if (mounted) {
        setState(() {
          _isMuted = false;
          _status = "LIVE";
        });
      }
      if (_audioReady && !_isProcessing) {
        _startVoiceLoop();
      }
    } else {
      _stopAll();
      if (mounted) {
        setState(() {
          _isMuted = true;
          _status = "MUTED";
        });
      }
    }
  }

  void _toggleVideo() async {
    if (_isVideoEnabled) {
      await _disposeCamera();
      if (mounted) {
        setState(() {
          _isVideoEnabled = false;
          _isCameraInitialized = false;
        });
      }
    } else {
      _isCameraDisposed = false;
      if (mounted) {
        setState(() {
          _isVideoEnabled = true;
        });
      }
      await _initializeCamera();
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _getStatusText() {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    switch (_status) {
      case "LIVE": return isArabic ? "مباشر" : "LIVE";
      case "LISTENING": return isArabic ? "بيسمع" : "LISTENING";
      case "THINKING": return isArabic ? "مفكّر" : "THINKING";
      case "SPEAKING": return isArabic ? "بيتكلم" : "SPEAKING";
      case "PROCESSING": return isArabic ? "بيجهّز" : "PROCESSING";
      case "TRANSCRIBING": return isArabic ? "بيعمل نسخ" : "TRANSCRIBING";
      case "MUTED": return isArabic ? "كتم الصوت" : "MUTED";
      default: return _status;
    }
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
          gradient: const LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
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
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: iconSize),
      );
    }

    return Container(
      width: buttonSize,
      height: buttonSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
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
    _recorderSubscription?.cancel();
    _continuousTranscribeTimer?.cancel();
    _stopAll();
    _disposeCamera();
    _httpClient?.close();
    try {
      _recorder.closeRecorder();
      _tts.stop();
    } catch (e) {
      print("Error disposing: $e");
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isLandscape = screenWidth > screenHeight;

    final guiderSize = isTablet ? screenWidth * 0.5 : screenWidth * 0.7;
    final videoWidth = isSmallScreen ? 100.0 : 120.0;
    final videoHeight = isSmallScreen ? 140.0 : 160.0;
    final chatContainerWidth = isLandscape ? screenWidth * 0.7 : screenWidth * 0.9;
    final double nameFontSize = isSmallScreen ? 22.0 : 26.0;
    final double quoteFontSize = isSmallScreen ? 14.0 : 16.0;
    final double statusFontSize = isSmallScreen ? 12.0 : 16.0;

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
                // Top Bar - matches VideoCallScreen style
                Padding(
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
                              backgroundColor: _isRecording ? Colors.green :
                              _isProcessing ? Colors.orange :
                              _isSpeaking ? Colors.purple :
                              Colors.red,
                            ),
                            SizedBox(width: isSmallScreen ? 4 : 6),
                            Text(
                              _getStatusText(),
                              style: TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                                fontSize: statusFontSize,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Guider Area
                Expanded(
                  flex: isLandscape ? 6 : 4,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Guider GIF
                      Positioned(
                        top: screenHeight * 0.02,
                        child: SizedBox(
                          height: screenHeight * 0.7,
                          width: screenWidth * 0.9,
                          child: Image.asset(
                            _guiderGifPath,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                      // User camera preview - matches VideoCallScreen position
                      Positioned(
                        top: 5,
                        right: isSmallScreen ? 10 : -35,
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
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.3),
                                  blurRadius: 15,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: _isVideoEnabled && _isCameraInitialized && _cameraController != null && !_isCameraDisposed
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
                                        widget.userName,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: isSmallScreen ? 12 : 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (!_isVideoEnabled)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF4A2B7A).withValues(alpha: 0.8),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(
                                            isArabic ? 'مطفية' : 'OFF',
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
                // Bottom Section - matches VideoCallScreen style
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
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 10,
                              offset: const Offset(0, -2),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isArabic ? 'المُرشد' : 'The Guider',
                              style: TextStyle(
                                fontSize: nameFontSize,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF2A1E3B),
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            if (_lastUserTranscript.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  '"$_lastUserTranscript"',
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
                              _visibleGuiderText.isNotEmpty
                                  ? _visibleGuiderText
                                  : (isArabic ? "تحدث... أنا أستمع" : "Speak... I'm listening"),
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: quoteFontSize,
                                height: 1.4,
                              ),
                            ),
                            if (_isProcessing && _visibleGuiderText.isEmpty)
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
                            onTap: _endCallAndSaveSummary,
                            child: _circleButton(Icons.call_end, isEndCall: true),
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
        ],
      ),
    );
  }
}