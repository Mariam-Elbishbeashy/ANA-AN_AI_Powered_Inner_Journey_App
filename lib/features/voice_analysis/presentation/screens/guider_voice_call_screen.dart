// lib/features/guider/presentation/screens/guider_voice_call_screen.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:flutter_tts/flutter_tts.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';

class GuiderVoiceCallScreen extends StatefulWidget {
  final String userName;
  final String? characterId;
  final String? existingSessionId;
  final String? existingThreadId;

  const GuiderVoiceCallScreen({
    super.key,
    required this.userName,
    this.characterId,
    this.existingSessionId,
    this.existingThreadId,
  });

  @override
  State<GuiderVoiceCallScreen> createState() => _GuiderVoiceCallScreenState();
}

class _GuiderVoiceCallScreenState extends State<GuiderVoiceCallScreen>
    with SingleTickerProviderStateMixin {
  bool _disposed = false;
  GifController? _gifController;
  Key _gifKey = UniqueKey();

  // ==========================
  // AUDIO VARIABLES
  // ==========================
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final FlutterTts _tts = FlutterTts();

  bool _audioReady = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isSpeaking = false;
  bool _voiceLoopActive = false;
  bool _stopping = false;

  // Silence auto-stop config
  static const int _sampleRate = 44100;
  static const int _channels = 1;
  static const Duration _progressEvery = Duration(milliseconds: 80);
  static const double _silenceDbThreshold = -65.0;
  static const Duration _silenceStop = Duration(milliseconds: 2500);
  static const Duration _maxRecord = Duration(seconds: 30);

  bool _hasDetectedSpeech = false;
  Timer? _silenceTimer;
  Timer? _maxTimer;
  StreamSubscription? _recSub;

  // UI State
  String _status = "";
  double _currentDbLevel = -100.0;
  String _lastUserTranscript = "";
  String _visibleGuiderText = "";
  String _error = "";
  String? _wavPath;
  final List<String> _textBuffer = [];
  Timer? _typingTimer;

  // Session data
  String _sessionId = "";
  String _threadId = "";
  int _sessionStartTime = 0;
  List<Map<String, String>> _conversationHistory = [];

  // TTS Settings
  static const double _guiderSpeechRate = 0.52;
  static const double _guiderPitch = 1.2;

  // Backend URLs - USING EXISTING VOICE ENDPOINTS
  static const String _baseUrl = "http://10.0.2.2:5003";
  static const String _voiceChatEndpoint = "/voice/chat";

  // Guider GIF path
  static const String _guiderGifPath = 'assets/animations/guider.gif';

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
    _initializeSession();
    _initAudio();
    _initTts();
    _sessionStartTime = DateTime.now().millisecondsSinceEpoch;
  }

  void _initializeSession() {
    if (widget.existingSessionId != null && widget.existingThreadId != null) {
      _sessionId = widget.existingSessionId!;
      _threadId = widget.existingThreadId!;
      print("📱 Resuming Guider session: $_sessionId");
      print("📱 Thread ID: $_threadId");
    } else {
      _sessionId = "guider_${DateTime.now().millisecondsSinceEpoch}";
      _threadId = "guider_${DateTime.now().millisecondsSinceEpoch}_thread";
      print("📱 New Guider session: $_sessionId");
      print("📱 Thread ID: $_threadId");
    }
  }

  Future<void> _initAudio() async {
    try {
      print("🎤 Initializing audio...");
      final mic = await Permission.microphone.request();
      if (!mic.isGranted) {
        if (mounted) {
          setState(() {
            _error = "Microphone permission denied";
            _status = "❌ Permission denied";
          });
        }
        return;
      }

      await _recorder.openRecorder();
      await _player.openPlayer();
      _recorder.setSubscriptionDuration(_progressEvery);

      if (mounted) {
        setState(() {
          _audioReady = true;
          _status = "Ready";
        });
      }

      print("✅ Audio initialized");
    } catch (e) {
      print("❌ Audio init error: $e");
      if (mounted) {
        setState(() {
          _error = "Audio init error: $e";
          _status = "❌ Audio init failed";
        });
      }
    }
  }

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
            _status = "Listening...";
          });
        }

        if (_voiceLoopActive && mounted) {
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_voiceLoopActive && mounted) {
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
            _error = "TTS error: $msg";
          });
        }
      });

      print("✅ TTS initialized");
    } catch (e) {
      print("❌ TTS init error: $e");
    }
  }

  Future<String> _makeWavPath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return "${dir.path}/guider_voice_$timestamp.wav";
  }

  void _setupVoiceDetection() {
    _recSub?.cancel();
    _recSub = _recorder.onProgress!.listen((event) {
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
        _silenceTimer = Timer(_silenceStop, () {
          if (_hasDetectedSpeech && _isRecording && !_stopping) {
            print("🔇 Silence reached - processing");
            _stopRecordingAndSend();
          }
        });
      }
    });
  }

  void _startVoiceLoop() async {
    if (!_audioReady) {
      await _initAudio();
      if (!_audioReady) return;
    }

    if (!_voiceLoopActive) {
      setState(() {
        _voiceLoopActive = true;
      });
      await _startRecordingWithAutoStop();
    }
  }

  Future<void> _startRecordingWithAutoStop() async {
    if (_disposed || !_voiceLoopActive) return;
    if (!_voiceLoopActive) return;
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
          _status = "🎙️ Recording";
          _error = "";
          _gifKey = UniqueKey();
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
        numChannels: _channels,
        audioSource: AudioSource.microphone,
      );

      _setupVoiceDetection();

      _maxTimer?.cancel();
      _maxTimer = Timer(_maxRecord, () async {
        if (!_voiceLoopActive || !_isRecording) return;
        print("⏰ Max recording time reached");
        await _stopRecordingAndSend();
      });

      print("✅ Recording started");
    } catch (e) {
      print("❌ Record error: $e");
      if (mounted) {
        setState(() {
          _isRecording = false;
          _status = "❌ Recording failed";
          _error = "$e";
        });
      }
    }
  }

  Future<Map<String, dynamic>> _sendVoiceTurn({
    required String uid,
    required String wavPath,
  }) async {
    final uri = Uri.parse("$_baseUrl$_voiceChatEndpoint");
    final req = http.MultipartRequest("POST", uri);

    req.fields["uid"] = uid;
    req.fields["characterId"] = widget.characterId ?? 'guider';
    req.fields["characterType"] = 'guider';
    req.fields["guided"] = "true";
    req.fields["guiderActive"] = "true";  // Force Guider to be active

    if (_sessionId.isNotEmpty) {
      req.fields["sessionId"] = _sessionId;
    }
    if (_threadId.isNotEmpty) {
      req.fields["threadId"] = _threadId;
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

    _typingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
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
    if (_disposed || !_voiceLoopActive) return;
    print("PROCESSING RECORDING PIPELINE");
    if (_stopping || !_isRecording) return;
    _stopping = true;

    try {
      if (mounted) {
        setState(() {
          _isProcessing = true;
          _status = "⏹ Processing...";
          _isRecording = false;
        });
      }

      _maxTimer?.cancel();
      _silenceTimer?.cancel();
      _recSub?.cancel();

      if (_recorder.isRecording) {
        await _safeStopRecorder();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final path = _wavPath;
      if (path == null || !(await File(path).exists())) {
        throw Exception("Audio file missing");
      }

      final len = await File(path).length();
      print("📁 Audio file size: $len bytes");

      if (len < 20000 || !_hasDetectedSpeech) {
        print("⚠️ Audio too short ($len bytes)");
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
        if (_voiceLoopActive) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (_voiceLoopActive && mounted && !_disposed) {
              _startRecordingWithAutoStop();
            }
          });
        }
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      setState(() => _status = "🚀 Sending to Guider...");

      final result = await _sendVoiceTurn(
        uid: user.uid,
        wavPath: path,
      );

      final transcript = (result["transcript"] ?? "").toString();
      final guiderText = (result["assistantText"] ?? "").toString();

      print("✅ Transcription: $transcript");
      print("✅ Guider response: $guiderText");

      if (mounted) {
        setState(() {
          _lastUserTranscript = transcript;
        });
      }

      // Save to conversation history
      if (transcript.isNotEmpty) {
        _conversationHistory.add({'role': 'user', 'content': transcript});
      }
      if (guiderText.isNotEmpty) {
        _conversationHistory.add({'role': 'assistant', 'content': guiderText});
      }

      if (_conversationHistory.length > 20) {
        _conversationHistory = _conversationHistory.sublist(_conversationHistory.length - 20);
      }

      _startTypingAnimation(guiderText);

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      await _speakGuiderText(guiderText);

      if (mounted) {
        setState(() {
          _textBuffer.clear();
          _visibleGuiderText = "";
        });
      }

      if (_voiceLoopActive) {
        await Future.delayed(const Duration(milliseconds: 500));
        if (_voiceLoopActive && mounted) {
          await _startRecordingWithAutoStop();
        }
      }

    } catch (e) {
      print("❌ Error: $e");
      setState(() {
        _status = "❌ Failed";
        _error = "$e";
        _isProcessing = false;
      });
      if (_voiceLoopActive) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (_voiceLoopActive && mounted && !_disposed) {
            _startRecordingWithAutoStop();
          }
        });
      }
    } finally {
      _stopping = false;
    }
  }

  Future<void> _speakGuiderText(String text) async {
    if (text.isEmpty) return;

    try {
      if (mounted) {
        setState(() {
          _isSpeaking = true;
          _status = "🔊 Speaking...";
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

  void _stopAll() async {
    print("🛑 Stopping all audio activities");
    _voiceLoopActive = false;

    _maxTimer?.cancel();
    _silenceTimer?.cancel();
    _typingTimer?.cancel();
    _recSub?.cancel();

    try {
      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }
      await _player.stopPlayer();
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
        _status = "Paused";
      });
    }
    _stopping = false;
  }

  Future<void> _endCall() async {
    _disposed = true;

    _stopAll();

    await Future.delayed(const Duration(milliseconds: 100));

    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _maxTimer?.cancel();
    _silenceTimer?.cancel();
    _typingTimer?.cancel();
    _recSub?.cancel();
    _stopAll();
    try {
      _player.closePlayer();
      _recorder.closeRecorder();
      _tts.stop();
    } catch (e) {
      print("Error disposing: $e");
    }
    _gifController?.dispose();
    super.dispose();
  }

  bool get _showListeningAnim => _isRecording && !_isProcessing && !_isSpeaking;

  @override
  Widget build(BuildContext context) {
    _gifController ??= GifController(vsync: this);
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

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
        child: SafeArea(
          child: Column(
            children: [
              // Top Bar
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
                          tr(context, 'The Guider', 'المرشد'),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.06),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _voiceLoopActive
                                  ? Colors.green
                                  : Colors.grey,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _voiceLoopActive ? (isArabic ? "مباشر" : "LIVE") : (isArabic ? "متوقف" : "PAUSED"),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF6B5C82),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Status Text
              Text(
                _status.isEmpty
                    ? (isArabic ? "اضغط الميكروفون للتحدث" : "Tap the mic to speak")
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

              // Guider Animation Area
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
                          image: const AssetImage(_guiderGifPath),
                          controller: _gifController!,
                          autostart: Autostart.loop,
                          fit: BoxFit.contain,
                        )
                            : Image.asset(
                          _guiderGifPath,
                          fit: BoxFit.contain,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Guider Text Bubble
                      if (_visibleGuiderText.isNotEmpty || _isProcessing)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(28),
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
                            children: [
                              if (_lastUserTranscript.isNotEmpty && _visibleGuiderText.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '"$_lastUserTranscript"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFFB79CFF),
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ),
                              Text(
                                _visibleGuiderText.isNotEmpty
                                    ? _visibleGuiderText
                                    : (isArabic ? "..." : "..."),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF2A1E3B),
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

                      // Audio Level Indicator (when recording)
                      if (_isRecording && !_isProcessing && !_isSpeaking)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _currentDbLevel > -25
                                        ? Colors.green
                                        : (_currentDbLevel > -35 ? Colors.yellow : Colors.red),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isArabic ? "تتحدث..." : "Speaking...",
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
                                        color: _currentDbLevel > -25
                                            ? Colors.green
                                            : (_currentDbLevel > -35 ? Colors.yellow : Colors.red),
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Bottom Buttons
              Padding(
                padding: EdgeInsets.fromLTRB(24, 8, 24, 24 + MediaQuery.of(context).padding.bottom),
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
                      onTap: () {
                        if (!_voiceLoopActive) {
                          _startVoiceLoop();
                        } else if (_isRecording) {
                          _stopRecordingAndSend();
                        }
                      },
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
              color: Colors.black.withOpacity(0.06),
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
              color: Colors.black.withOpacity(0.08),
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