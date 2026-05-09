import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';

// Guider Intervention Model
class GuiderInterventionModel {
  final bool shouldIntervene;
  final String reason;
  final String severity;
  final String? guiderMessage;

  const GuiderInterventionModel({
    required this.shouldIntervene,
    required this.reason,
    required this.severity,
    this.guiderMessage,
  });

  static const none = GuiderInterventionModel(
    shouldIntervene: false,
    reason: '',
    severity: '',
    guiderMessage: null,
  );
}

class VoiceAnalysisScreen extends StatefulWidget {
  final UserCharacter character;
  const VoiceAnalysisScreen({super.key, required this.character});

  @override
  State<VoiceAnalysisScreen> createState() => _VoiceAnalysisScreenState();
}

class _VoiceAnalysisScreenState extends State<VoiceAnalysisScreen>
    with SingleTickerProviderStateMixin {
  GifController? _gifController;
  Key _gifKey = UniqueKey();

  // ==========================
  // Audio (record + play)
  // ==========================
  final FlutterTts _tts = FlutterTts();
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _audioReady = false;
  static const String _guiderGifPath = 'assets/animations/guider.gif';

  // Silence auto-stop config
  static const int _sampleRate = 44100;
  static const int _channels = 1;
  static const Duration _progressEvery = Duration(milliseconds: 80);
  static const double _silenceDbThreshold = -65.0;

  static const Duration _minRecord = Duration(milliseconds: 800);
  static const Duration _silenceStop = Duration(milliseconds: 2500);
  static const Duration _maxRecord = Duration(seconds: 30);

  DateTime? _recordStartAt;
  bool _heardSpeech = false;
  Duration _silenceAccum = Duration.zero;

  StreamSubscription? _recSub;
  Timer? _maxTimer;
  Timer? _nextTurnTimer;

  // ==========================
  // Guider Intervention Variables
  // ==========================
  bool _guiderActive = false;
  bool _guiderSpeaking = false;
  String _guiderMessage = "";
  GuiderInterventionModel _intervention = GuiderInterventionModel.none;
  bool _showingIntervention = false;

  // Emotion detection keywords
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

  // UI state
  bool _isRecording = false;
  bool _isBusy = false;
  bool _voiceLoopActive = false;
  bool _isSpeaking = false;  // ADD THIS LINE
  String _status = "";
  String _lastUserText = "";
  String _lastAiText = "";
  String _visibleAiText = "";
  String _error = "";
  Timer? _typingTimer;
  String? _wavPath;
  String? _currentSessionId;
  String? _currentThreadId;
  String? _emotionSessionId;
  int _callDurationSeconds = 0;
  Timer? _durationTimer;
  List<Map<String, String>> _conversationHistory = [];
  String _characterIdForBackend = "";

  // Prevent stop crash
  bool _stopping = false;
  bool _stopQueued = false;

  // ==========================
  // Backend (Flask) - EMULATOR ONLY
  // ==========================
  static const String _baseUrl = "http://10.0.2.2:5004";
  static const String _voiceChatEndpoint = "/voice/chat";

  // ==========================
  // AI big text styles (photo-like)
  // ==========================
  TextStyle get _aiPrefixStyle => const TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: Color(0xFFB9B0C9),
    height: 1.18,
  );

  TextStyle get _aiTextStyle => const TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w900,
    color: Color(0xFF2A1E3B),
    height: 1,
  );

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    _initAudio();
    _initializeSession();
    _startDurationTracking();
  }

  Future<void> _initAudio() async {
    try {
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        setState(() {
          _error = "Microphone permission denied";
          _status = "❌ Permission denied";
        });
        return;
      }

      await _recorder.openRecorder();
      await _player.openPlayer();
      _recorder.setSubscriptionDuration(_progressEvery);

      setState(() {
        _audioReady = true;
        _status = "Ready";
      });
    } catch (e) {
      setState(() {
        _error = "Audio init error: $e";
        _status = "❌ Audio init failed";
      });
    }
  }
  String _getCharacterIdForBackend(String characterName) {
    final idMap = {
      'Inner Critic': 'inner_critic',
      'People Pleaser': 'people_pleaser',
      'Lonely Part': 'lonely',
      'Jealous Part': 'jealous',
      'Ashamed Part': 'ashamed',
      'Workaholic': 'workaholic',
      'Perfectionist': 'perfectionist',
      'Procrastinator': 'procrastinator',
      'Excessive Gamer': 'excessive_gamer',
      'Confused Part': 'confused',
      'Dependent Part': 'dependent',
      'Fearful Part': 'fearful',
      'Neglected Part': 'neglected',
      'Overeater': 'overater_binger',
      'Overeater/Binger': 'overater_binger',
      'Overwhelmed Part': 'overwhelmed',
      'Stoic Part': 'stoic',
      'Wounded Child': 'wounded_child',
      'Controller': 'controller',
      'Controller Part': 'controller',
    };
    return idMap[characterName] ?? characterName.toLowerCase().replaceAll(' ', '_');
  }

  Future<void> _initializeSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      _characterIdForBackend = _getCharacterIdForBackend(widget.character.characterName);
      _emotionSessionId = "emotion_${DateTime.now().millisecondsSinceEpoch}";

      // Try to get active session first
      final response = await http.get(
        Uri.parse("$_baseUrl/voice/get_active_session?uid=${user.uid}&characterId=$_characterIdForBackend"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['session'] != null) {
          setState(() {
            _currentSessionId = data['session']['id'];
            _currentThreadId = data['session']['threadId'];
          });
          print("✅ Found active session: $_currentSessionId");
          return;
        }
      }

      // Create new session if no active session
      final createResponse = await http.post(
        Uri.parse("$_baseUrl/voice/create_session"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': user.uid,
          'characterId': _characterIdForBackend,
          'characterType': 'inner_character',
          'title': 'Voice call with ${widget.character.displayNameEn}',
        }),
      );

      if (createResponse.statusCode == 200) {
        final data = json.decode(createResponse.body);
        setState(() {
          _currentSessionId = data['sessionId'];
          _currentThreadId = data['threadId'];
        });
        print("✅ Created new session: $_currentSessionId");
      }
    } catch (e) {
      print("❌ Session initialization error: $e");
    }
  }

  void _startDurationTracking() {
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_voiceLoopActive || _isBusy || _isSpeaking) {
        setState(() => _callDurationSeconds++);
      }
    });
  }

  void _stopDurationTracking() {
    _durationTimer?.cancel();
  }

  Future<void> _endCall() async {
    print("===== _endCall CALLED =====");

    // Stop audio tracking
    _stopDurationTracking();

    // Call _stopAll but don't await - let it run in background
    _stopAll();

    // Small delay to let audio stop
    await Future.delayed(const Duration(milliseconds: 100));

    // Navigate back IMMEDIATELY
    if (mounted) {
      print("Navigating back...");
      Navigator.of(context).pop();
    }

    // Then do cleanup in the background (fire and forget)
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _currentSessionId != null) {
      // Build messages for summary
      final messagesForSummary = _conversationHistory.map((msg) {
        return {
          'role': msg['role'],
          'content': msg['content'],
        };
      }).toList();

      // Fire and forget - don't await
      http.post(
        Uri.parse("$_baseUrl/voice/session_summary"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': user.uid,
          'sessionId': _currentSessionId,
          'threadId': _currentThreadId,
          'characterId': _characterIdForBackend,
          'duration': _callDurationSeconds,
          'messages': messagesForSummary,
        }),
      ).then((response) {
        if (response.statusCode == 200) {
          print("✅ Session summary saved");
        }
      }).catchError((e) => print("Error saving summary: $e"));

      // Also call end_session
      http.post(
        Uri.parse("$_baseUrl/voice/end_session"),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'uid': user.uid,
          'sessionId': _currentSessionId,
          'emotionSessionId': _emotionSessionId,
        }),
      ).catchError((e) => print("Error ending session: $e"));
    }
  }

  Future<String> _makeWavPath() async {
    final dir = await getTemporaryDirectory();
    return "${dir.path}/ana_user_${DateTime.now().millisecondsSinceEpoch}.wav";
  }

  Future<void> _startOrStop() async {
    if (!_audioReady) {
      await _initAudio();
      if (!_audioReady) return;
    }

    // START LOOP
    if (!_voiceLoopActive) {
      print("VOICE LOOP STARTED");
      _voiceLoopActive = true;
      await _startRecordingWithAutoStop();
      return;
    }

    // STOP LOOP
    print("VOICE LOOP STOPPED");
    _voiceLoopActive = false;
    _stopAll();
  }

  Future<void> _startRecordingWithAutoStop() async {
    if (!_voiceLoopActive) return;
    if (_guiderSpeaking) return; // Don't record while Guider is speaking

    _stopping = false;

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
      } catch (_) {}

      try {
        await _recorder.closeRecorder();
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 300));
      await _recorder.openRecorder();
      await Future.delayed(const Duration(milliseconds: 400));

      try {
        if (_recorder.isRecording) {
          await _recorder.stopRecorder();
        }
      } catch (_) {}

      await Future.delayed(const Duration(milliseconds: 250));

      if (!_recorder.isStopped) {
        await _recorder.closeRecorder();
        await _recorder.openRecorder();
      }

      setState(() {
        _isRecording = true;
        _status = "🎙️ Recording";
        _error = "";
        _gifKey = UniqueKey();
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
        numChannels: _channels,
        audioSource: AudioSource.microphone,
      );

      _maxTimer?.cancel();
      _maxTimer = Timer(const Duration(seconds: 6), () async {
        if (!_voiceLoopActive) return;
        if (!_isRecording) return;
        print("VOICE LOOP → AUTO STOP TRIGGERED");
        await _stopRecordingAndSend();
      });

    } catch (e) {
      print("START RECORD ERROR: $e");
      setState(() {
        _isRecording = false;
        _status = "❌ Recording failed";
        _error = "$e";
      });
    }
  }

  Future<Map<String, dynamic>> _sendVoiceTurn({
    required String uid,
    required String characterId,
    required String wavPath,
  }) async {
    final uri = Uri.parse("$_baseUrl$_voiceChatEndpoint");
    final req = http.MultipartRequest("POST", uri);

    req.fields["uid"] = uid;
    req.fields["characterId"] = characterId;
    req.fields["guided"] = "true";

    // Add session info
    if (_currentSessionId != null) {
      req.fields["sessionId"] = _currentSessionId!;
    }
    if (_currentThreadId != null) {
      req.fields["threadId"] = _currentThreadId!;
    }

    // Add guider context if active
    if (_guiderActive) {
      req.fields["guiderActive"] = "true";
    }

    req.files.add(
      await http.MultipartFile.fromPath("audio", wavPath, filename: "user.wav"),
    );

    final streamed = await req.send().timeout(
      const Duration(seconds: 60),
    );
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("VOICE CHAT HTTP ${streamed.statusCode}: $body");
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    print("VOICE RESPONSE: $decoded");
    if (decoded["success"] != true) {
      throw Exception(decoded["error"] ?? "Voice chat failed");
    }

    return decoded;
  }

  Future<String?> _safeStopRecorder() async {
    try {
      return await _recorder.stopRecorder();
    } catch (_) {
      return null;
    }
  }

  Future<void> _playFromBase64(String audioB64) async {
    final bytes = base64Decode(audioB64);
    if (bytes.length < 1000) {
      throw Exception("Invalid TTS audio bytes: ${bytes.length}");
    }

    final dir = await getTemporaryDirectory();
    final outPath =
        "${dir.path}/ana_tts_${DateTime.now().millisecondsSinceEpoch}.wav";
    final outFile = File(outPath);
    await outFile.writeAsBytes(bytes, flush: true);

    await _player.startPlayer(
      fromURI: outPath,
      codec: Codec.pcm16WAV,
      whenFinished: () async {
        if (!mounted) return;
        setState(() {
          _status = "Listening...";
          _isBusy = false;
        });
        await _scheduleNextRecording();
      },
    );
  }

  Future<void> _scheduleNextRecording() async {
    if (!_voiceLoopActive) return;
    if (!mounted) return;
    if (_isRecording) return;
    if (_isBusy) return;

    print("VOICE LOOP → NEXT TURN");
    await Future.delayed(const Duration(milliseconds: 300));
    if (!_voiceLoopActive) return;
    await _startRecordingWithAutoStop();
  }

  // ==========================
  // TTS METHODS
  // ==========================
  Future<void> _speakText(String text, {bool isGuider = false}) async {
    if (text.isEmpty) return;

    try {
      setState(() {
        if (isGuider) {
          _guiderSpeaking = true;
          _guiderMessage = text;
          _status = "Guider speaking...";
        } else {
          _isBusy = true;
          _status = "🔊 Speaking...";
        }
      });

      if (isGuider) {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.52);
        await _tts.setPitch(1.2);
      } else {
        await _tts.setLanguage("en-US");
        await _tts.setSpeechRate(0.45);
        await _tts.setPitch(1.0);
      }

      await _tts.speak(text);
      await _tts.awaitSpeakCompletion(true);

      setState(() {
        if (isGuider) {
          _guiderSpeaking = false;
          _guiderMessage = "";
          _status = "Ready";
        } else {
          _isBusy = false;
          _status = "Listening...";
        }
      });
    } catch (e) {
      print("TTS Error: $e");
      setState(() {
        if (isGuider) {
          _guiderSpeaking = false;
        } else {
          _isBusy = false;
        }
        _error = "TTS error: $e";
      });
    }
  }

  // ==========================
  // EMOTION DETECTION & INTERVENTION
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

      // Announce Guider joining
      await _speakText("Hello, I'm here to help. I'll be joining your conversation with ${widget.character.displayNameEn}.", isGuider: true);
      _guiderMessage = "I'm here to support you.";

      // Small delay before resuming
      await Future.delayed(const Duration(milliseconds: 500));
      _startVoiceLoop();
    } else {
      setState(() {
        _status = "Ready";
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
          title: Text(tr(context, 'End Guider Session', 'إنهاء جلسة المُرشد')),
          content: Text(tr(
            context,
            'Do you want The Guider to leave the conversation?',
            'هل تريد أن يغادر المُرشد المحادثة؟',
          )),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(tr(context, 'Cancel', 'إلغاء')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(tr(context, 'End', 'إنهاء')),
            ),
          ],
        ),
      );

      if (confirm == true && mounted) {
        setState(() {
          _guiderActive = false;
          _guiderMessage = "";
          _status = "Ready";
        });

        await _speakText("I'll step back now. You can continue your conversation.", isGuider: true);
      }
    } else {
      _showGuiderInvitation('manual', 'low',
          tr(context, 'Would you like The Guider to join and help guide your conversation?',
              'هل تريد أن ينضم المُرشد ليساعد في توجيه محادثتك؟'));
    }
  }

  void _startVoiceLoop() async {
    if (!_voiceLoopActive) {
      _voiceLoopActive = true;
      await _startRecordingWithAutoStop();
    }
  }

  Future<void> _stopRecordingAndSend() async {
    print("PROCESSING RECORDING PIPELINE");
    if (_stopping || !_isRecording) return;
    _stopping = true;

    try {
      setState(() {
        _isBusy = true;
        _status = "⏹ Processing...";
      });

      _maxTimer?.cancel();

      if (_isRecording) {
        await _safeStopRecorder();
        setState(() {
          _isRecording = false;
        });
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final path = _wavPath;
      if (path == null || !(await File(path).exists())) {
        throw Exception("Audio file missing");
      }

      final len = await File(path).length();
      if (len < 30000) {
        print("AUDIO TOO SMALL — restarting recording");
        if (mounted) {
          setState(() {
            _isBusy = false;
          });
        }
        if (_voiceLoopActive) {
          await _scheduleNextRecording();
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged");

      setState(() => _status = "🚀 Sending voice...");

      final result = await _sendVoiceTurn(
        uid: user.uid,
        characterId: widget.character.id,
        wavPath: path,
      );

// FIRST: Check if backend detected an intervention
      if (result["needsIntervention"] == true) {
        print("🎯 INTERVENTION DETECTED BY BACKEND");
        final interventionMessage = result["interventionMessage"] ??
            "I notice you're expressing difficult feelings. Would you like The Guider to join and help?";
        final interventionReason = result["interventionReason"] ?? "emotional";
        final interventionSeverity = result["interventionSeverity"] ?? "medium";

        // Show the intervention overlay
        _showGuiderInvitation(interventionReason, interventionSeverity, interventionMessage);

        setState(() {
          _isBusy = false;
        });
        return;
      }

      final transcript = (result["transcript"] ?? "").toString();
      final assistantText = (result["assistantText"] ?? "").toString();
      final audioB64 = (result["audioBase64"] ?? "").toString();
      final audioUrl = (result["audioUrl"] ?? "").toString();

// Only use local emotion detection if no backend intervention
// (This is a fallback)
      if (!_guiderActive && !_showingIntervention && transcript.isNotEmpty) {
        _checkEmotionAndIntervene(transcript);
        if (_showingIntervention) {
          setState(() {
            _isBusy = false;
          });
          return;
        }
      }
      // Save to conversation history
      _conversationHistory.add({'role': 'user', 'content': transcript});
      _conversationHistory.add({'role': 'assistant', 'content': assistantText});

      // Keep only last 20 messages
      if (_conversationHistory.length > 20) {
        _conversationHistory = _conversationHistory.sublist(_conversationHistory.length - 20);
      }

      setState(() {
        _lastUserText = transcript;
        _lastAiText = assistantText;
        _visibleAiText = "";
      });

      await _typeAiResponse(assistantText);
      await _speakText(assistantText);
      print("AI FINISHED SPEAKING");
      await _player.stopPlayer();

      if (mounted) {
        setState(() {
          _isBusy = false;
          _status = "Listening...";
        });
      }

      if (_voiceLoopActive) {
        await _scheduleNextRecording();
      }

    } catch (e) {
      setState(() {
        _status = "❌ Failed";
        _error = "$e";
        _isBusy = false;
      });
    }

    _stopping = false;
  }

  Future<void> _typeAiResponse(String text) async {
    _typingTimer?.cancel();
    setState(() {
      _visibleAiText = "";
    });

    final words = text.split(" ");
    int index = 0;

    _typingTimer = Timer.periodic(
      const Duration(milliseconds: 200),
          (timer) {
        if (index >= words.length) {
          timer.cancel();
          return;
        }
        if (!mounted) return;
        setState(() {
          _visibleAiText += "${words[index]} ";
        });
        index++;
      },
    );
  }

  void _stopAll() async {
    print("VOICE LOOP FORCE STOP");
    _voiceLoopActive = false;

    try {
      _nextTurnTimer?.cancel();
      _maxTimer?.cancel();
      await _recSub?.cancel();
      _recSub = null;

      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _player.stopPlayer();
      await _tts.stop();
    } catch (_) {}

    if (!mounted) return;

    setState(() {
      _isRecording = false;
      _isBusy = false;
      _status = "Paused";
    });

    _stopping = false;
  }

  @override
  void dispose() {
    _stopDurationTracking();
    _maxTimer?.cancel();
    _recSub?.cancel();
    try {
      _player.closePlayer();
      _recorder.closeRecorder();
      _tts.stop();
    } catch (_) {}
    _gifController?.dispose();
    super.dispose();
  }

  String _getTitle(BuildContext context) {
    final name = widget.character.displayNameEn.trim();
    final normalized =
    name.toLowerCase().startsWith('the ') ? name.substring(4) : name;
    return tr(context, 'Your $normalized', '$normalized الخاص بك');
  }

  bool get _showListeningAnim => _isRecording;

  // ==========================
  // INTERVENTION OVERLAY BUILDER
  // ==========================
  Widget _buildInterventionOverlay() {
    if (!_showingIntervention) return const SizedBox.shrink();

    final isArabic = Localizations.localeOf(context).languageCode == 'ar';
    final screenWidth = MediaQuery.of(context).size.width;

    final guiderMessage = _intervention.guiderMessage ?? '';

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Center(
          child: Container(
            width: screenWidth * 0.85,
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Guider Photo
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFB79CFF).withValues(alpha: 0.6),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      _guiderGifPath,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)],
                            ),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assistant_navigation,
                            color: Colors.white,
                            size: 40,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isArabic ? "المُرشد" : "The Guider",
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F0FF),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    guiderMessage,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Color(0xFF4B3A66),
                      height: 1.5,
                    ),
                  ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          isArabic ? "استمر بمفردي" : "Continue Alone",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
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
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                        ),
                        child: Text(
                          isArabic ? "انضم للمُرشد" : "Invite Guider",
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  isArabic ? "سيظهر المُرشد على الشاشة لتقديم الدعم" : "Guider will join to provide support",
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _gifController ??= GifController(vsync: this);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFF7F2FF),
              Color(0xFFF2ECFF),
              Color(0xFFEDE7FF),
            ],
          ),
        ),
        child: Stack(
          children: [
            SafeArea(
              child: Column(
                children: [
                  // Top Bar with Guider button
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                    child: Row(
                      children: [
                        _CircleIconButton(
                          icon: Icons.arrow_back_rounded,
                          onTap: _endCall,
                        ),
                        Expanded(
                          child: Center(
                            child: Text(
                              _getTitle(context),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ),
                        ),
                        // Guider Button
                        GestureDetector(
                          onTap: _toggleGuider,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _guiderActive
                                  ? const Color(0xFFB79CFF).withValues(alpha: 0.2)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: _guiderActive
                                    ? const Color(0xFFB79CFF)
                                    : Colors.grey.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  child: ClipOval(
                                    child: Image.asset(
                                      _guiderGifPath,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) {
                                        return Icon(
                                          Icons.assistant_navigation,
                                          size: 18,
                                          color: _guiderActive
                                              ? const Color(0xFFB79CFF)
                                              : Colors.grey,
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  _guiderActive
                                      ? (Localizations.localeOf(context).languageCode == 'ar' ? "المُرشد معك" : "Guider Active")
                                      : (Localizations.localeOf(context).languageCode == 'ar' ? "انضم للمُرشد" : "Invite Guider"),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: _guiderActive
                                        ? const Color(0xFFB79CFF)
                                        : const Color(0xFF4B3A66),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _status.isEmpty
                        ? tr(context, 'Tap the mic to speak.',
                        'اضغط الميكروفون للتحدث.')
                        : _status,
                    style: const TextStyle(
                      color: Color(0xFF7A6A5A),
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (_error.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
                      child: Text(
                        _error,
                        style: const TextStyle(
                          color: Colors.red,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 290,
                            height: 290,
                            child: _showListeningAnim
                                ? Gif(
                              key: _gifKey,
                              image: const AssetImage(
                                  'assets/animations/voice_sphere.gif'),
                              controller: _gifController!,
                              autostart: Autostart.loop,
                              fit: BoxFit.contain,
                            )
                                : Image.asset(
                              'assets/animations/voice_sphere.gif',
                              fit: BoxFit.contain,
                            ),
                          ),
                          const SizedBox(height: 22),
                          if (_visibleAiText.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 22),
                              child: RichText(
                                textAlign: TextAlign.center,
                                text: TextSpan(
                                  children: [
                                    TextSpan(text: _visibleAiText, style: _aiTextStyle),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _RoundCircleButton(
                          icon: Icons.pause_rounded,
                          onTap: _stopAll,
                          backgroundColor: Colors.white,
                          iconColor: const Color(0xFF2A1E3B),
                        ),
                        _RoundCircleButton(
                          icon: Icons.mic_rounded,
                          onTap: _startOrStop,
                          backgroundColor: const Color(0xFF8E7CFF),
                          iconColor: Colors.white,
                          size: 64,
                        ),
                        _RoundCircleButton(
                          icon: Icons.close_rounded,
                          onTap: _endCall,
                          backgroundColor: Colors.white,
                          iconColor: const Color(0xFF2A1E3B),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Guider Indicator (when active)
            if (_guiderActive)
              Positioned(
                top: 80,
                left: 16,
                child: GestureDetector(
                  onTap: _toggleGuider,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFB79CFF),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFB79CFF).withValues(alpha: 0.5),
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
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFB79CFF), Color(0xFF9B7BFF)],
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.assistant_navigation,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              "The Guider",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                            if (_guiderMessage.isNotEmpty)
                              Container(
                                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.5),
                                child: Text(
                                  _guiderMessage,
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _guiderSpeaking
                                        ? const Color(0xFFB79CFF)
                                        : const Color(0xFF4B3A66),
                                    fontStyle: FontStyle.italic,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        if (_guiderSpeaking)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFFB79CFF),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            // Intervention Overlay
            _buildInterventionOverlay(),
          ],
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _CircleIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: const Color(0xFF2A1E3B)),
      ),
    );
  }
}

class _RoundCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color backgroundColor;
  final Color iconColor;
  final double size;

  const _RoundCircleButton({
    required this.icon,
    required this.onTap,
    required this.backgroundColor,
    required this.iconColor,
    this.size = 52,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: backgroundColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Icon(icon, color: iconColor),
      ),
    );
  }
}