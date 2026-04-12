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

import 'package:ana_ifs_app/l10n/app_strings.dart';

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

  // Session and Thread IDs for database saving
  String _sessionId = "";
  String _threadId = "";

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
  // VOICE VARIABLES
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
  StreamSubscription? _recorderSubscription;

  static const int _sampleRate = 16000;
  static const int _numChannels = 1;
  static const Duration _maxRecord = Duration(seconds: 20);
  static const Duration _silenceThreshold = Duration(seconds: 1);
  static const double _silenceDbThreshold = -38.0;

  String? _wavPath;

  // TTS Settings
  double _guiderSpeechRate = 0.65;
  double _guiderPitch = 1.45;

  // Backend
  static const String _voiceAppBaseUrl = "http://192.168.100.7:5003";
  static const String _guiderRespondEndpoint = "/guider/respond";
  static const String _guiderUpdateEmotionsEndpoint = "/guider/update_emotions";
  static const String _guiderSessionSummaryEndpoint = "/guider/session_summary";
  static const String _transcribeEndpoint = "/video/transcribe";

  int _sessionStartTime = DateTime.now().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    _generateSessionAndThread();
    _startVideoSession();
    _initializeEmotionSession();
    _initializeCamera();
    _initAudio();
    _initTts();
  }

  void _generateSessionAndThread() {
    _sessionId = DateTime.now().millisecondsSinceEpoch.toString();
    _threadId = DateTime.now().millisecondsSinceEpoch.toString();
    _emotionSessionId = "emotion_${DateTime.now().millisecondsSinceEpoch}";
    print("📱 Session ID: $_sessionId");
    print("📱 Thread ID: $_threadId");
  }

  Future<void> _startVideoSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.post(
        Uri.parse("$_voiceAppBaseUrl/guider/start_session"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': user.uid,
          'sessionId': _sessionId,
          'threadId': _threadId,  // ✅ THIS IS THE ONLY CHANGE NEEDED
          'userName': widget.userName,
          'characterId': widget.characterId,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        print("✅ Video session started on server with threadId: $_threadId");
      }
    } catch (e) {
      print("⚠️ Could not start video session: $e");
    }
  }

  // ==========================
  // EMOTION METHODS WITH BACKEND SYNC
  // ==========================

  Future<void> _initializeEmotionSession() async {
    try {
      final response = await http.post(
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

          // Start periodic emotion sending to backend (every 2 seconds)
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
      // Silent fail
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
          }
        }
      }
    } catch (e) {
      print("⚠️ Voice emotion analysis error: $e");
    }
  }

  // CRITICAL: Send emotions to backend to save to Firestore
  Future<void> _sendPendingEmotions() async {
    if (!_hasPendingEmotionUpdate) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final response = await http.post(
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
  }

  Future<void> _endEmotionSession() async {
    _emotionActive = false;
    _emotionFrameTimer?.cancel();
    _emotionSendTimer?.cancel();

    // Send final emotions before ending
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
  // TTS METHODS
  // ==========================
  Future<void> _initTts() async {
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
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_voiceLoopActive && !_isMuted && mounted) {
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
  }

  Future<void> _speakGuiderText(String text) async {
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
  }

  // ==========================
  // AUDIO METHODS
  // ==========================
  Future<void> _initAudio() async {
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
      _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
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

  Future<void> _startRecordingWithAutoStop() async {
    if (!_voiceLoopActive || _isMuted) return;
    if (_isSpeaking || _isProcessing || _isRecording) return;

    _stopping = false;
    _hasDetectedSpeech = false;

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
        await Future.delayed(const Duration(milliseconds: 300));
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

      await _recorder.startRecorder(
        toFile: _wavPath!,
        codec: Codec.pcm16WAV,
        sampleRate: _sampleRate,
        numChannels: _numChannels,
        bitRate: 256000,
      );

      _setupVoiceDetection();
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
  }

  Future<String> _transcribeAudio(String wavPath) async {
    try {
      final uri = Uri.parse("$_voiceAppBaseUrl$_transcribeEndpoint");
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
        return data['transcript'] ?? '';
      }
      return '';
    } catch (e) {
      print("❌ Transcription error: $e");
      return '';
    }
  }

  Future<String> _getGuiderResponse(String uid, String userMessage) async {
    try {
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

      final httpResponse = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 30));

      if (httpResponse.statusCode == 200) {
        final data = json.decode(httpResponse.body);
        return data['guiderMessage'] ?? _getRandomFallbackMessage();
      }
      return _getRandomFallbackMessage();
    } catch (e) {
      print("Network error: $e");
      return _getRandomFallbackMessage();
    }
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

    _typingTimer = Timer.periodic(const Duration(milliseconds: 370), (timer) {
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
    if (_stopping || !_isRecording) return;
    _stopping = true;

    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _status = "THINKING";
          _isRecording = false;
        });
      }

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
      print("📁 Audio file size: $len bytes");

      if (len < 5000 || !_hasDetectedSpeech) {
        print("⚠️ Audio too short ($len bytes)");
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        if (_voiceLoopActive && !_isMuted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_voiceLoopActive && !_isMuted && mounted) {
              _startRecordingWithAutoStop();
            }
          });
        }
        return;
      }

      // Analyze audio for emotion (updates _lastVoiceEmotion)
      await _analyzeAudioEmotion(path);

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final transcript = await _transcribeAudio(path);
      if (transcript.isEmpty) {
        print("⚠️ Empty transcription");
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        if (_voiceLoopActive && !_isMuted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_voiceLoopActive && !_isMuted && mounted) {
              _startRecordingWithAutoStop();
            }
          });
        }
        return;
      }

      print("✅ Transcription: $transcript");

      if (mounted) {
        setState(() {
          _lastUserTranscript = transcript;
        });
      }

      _conversationHistory.add({'role': 'user', 'content': transcript});

      final guiderResponse = await _getGuiderResponse(user.uid, transcript);

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
    } catch (e) {
      print("❌ Error: $e");
      if (mounted) {
        setState(() {
          _status = "LIVE";
          _isProcessing = false;
        });
      }
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

  Future<void> _startVoiceLoop() async {
    if (!_audioReady) {
      await Future.delayed(const Duration(seconds: 1));
      if (!_audioReady) return;
    }
    if (mounted) {
      setState(() {
        _voiceLoopActive = true;
      });
    }
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
  }

  Future<void> _endCallAndSaveSummary() async {
    _stopAll();
    await _endEmotionSession();
    await _disposeCamera();

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _conversationHistory.isNotEmpty) {
        final url = Uri.parse("$_voiceAppBaseUrl$_guiderSessionSummaryEndpoint");

        final requestBody = {
          'uid': user.uid,
          'characterId': widget.characterId,
          'sessionId': _sessionId,
          'duration': DateTime.now().millisecondsSinceEpoch - _sessionStartTime,
          'messages': _conversationHistory,
        };

        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(requestBody),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          print("✅ Summary saved to Firestore");
          print("   - Face dominant: ${data['faceEmotion']['dominant']}");
          print("   - Voice dominant: ${data['voiceTone']['dominant']}");
          print("   - Face detections: ${data['faceEmotion']['totalDetections']}");
          print("   - Voice detections: ${data['voiceTone']['totalDetections']}");
        }
      }
    } catch (e) {
      print("Error saving summary: $e");
    }

    if (mounted) {
      Navigator.pop(context);
    }
  }

  void _toggleMute() {
    if (_isMuted) {
      if (mounted) {
        setState(() {
          _isMuted = false;
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
      if (mounted) {
        setState(() {
          _isVideoEnabled = true;
        });
      }
      await _initializeCamera();
    }
  }

  Widget _circleButton(IconData icon, {bool isActive = true, bool isEndCall = false}) {
    if (isEndCall) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      );
    }

    if (!isActive) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF4A2B7A),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 30),
      );
    }

    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          colors: [Color(0xFF7B61FF), Color(0xFF9C8CFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: 30),
    );
  }

  @override
  void dispose() {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
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
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: _endCallAndSaveSummary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _status,
                              style: const TextStyle(
                                color: Color(0xFF7B61FF),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                // Guider Area
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
                      // Audio Level Indicator
                      if (_isRecording && !_isMuted)
                        Positioned(
                          bottom: 80,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentDbLevel > -25 ? Colors.green :
                                    _currentDbLevel > -35 ? Colors.yellow : Colors.red,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "تحدث..." : "Speaking...",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 50,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                  child: FractionallySizedBox(
                                    widthFactor: ((_currentDbLevel + 50) / 35).clamp(0.0, 1.0),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: _currentDbLevel > -25 ? Colors.green :
                                        _currentDbLevel > -35 ? Colors.yellow : Colors.red,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isRecording && !_isMuted && !_isProcessing)
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.green,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "يستمع..." : "Listening...",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isProcessing)
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(
                                  width: 12,
                                  height: 12,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "تفكير..." : "Thinking...",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      if (_isSpeaking)
                        Positioned(
                          bottom: 20,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Color(0xFFB79CFF),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "يتحدث..." : "Speaking...",
                                  style: const TextStyle(color: Colors.white, fontSize: 12),
                                ),
                              ],
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
                                color: _isVideoEnabled
                                    ? const Color(0xFF7B61FF)
                                    : const Color(0xFF4A2B7A),
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
                              child: _isVideoEnabled && _isCameraInitialized && _cameraController != null && !_isCameraDisposed
                                  ? CameraPreview(_cameraController!)
                                  : Container(
                                color: _isVideoEnabled
                                    ? const Color(0xFF7B61FF).withOpacity(0.3)
                                    : const Color(0xFF4A2B7A).withOpacity(0.3),
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _isVideoEnabled ? Icons.videocam : Icons.videocam_off,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        widget.userName,
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
                                          child: const Text(
                                            'OFF',
                                            style: TextStyle(
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
                // Bottom Section
                Transform.translate(
                  offset: const Offset(0, -80),
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
                              tr(context, 'The Guider', 'المُرشد'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2A1E3B),
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
                                  style: const TextStyle(
                                    color: Color(0xFFB79CFF),
                                    fontSize: 14,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                            Text(
                              _visibleGuiderText.isNotEmpty
                                  ? _visibleGuiderText
                                  : (isArabic ? "تحدث... أنا أستمع" : "Speak... I'm listening"),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF4B3A66),
                                fontSize: 16,
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
                                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFB79CFF)),
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
                            onTap: _endCallAndSaveSummary,
                            child: _circleButton(Icons.call_end, isEndCall: true),
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
        ],
      ),
    );
  }
}