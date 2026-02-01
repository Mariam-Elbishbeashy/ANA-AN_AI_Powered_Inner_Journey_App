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

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';

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
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _audioReady = false;

  // Silence auto-stop config
  static const int _sampleRate = 16000;
  static const int _channels = 1;
  static const Duration _progressEvery = Duration(milliseconds: 80);
  static const double _silenceDbThreshold = -35.0;

  static const Duration _minRecord = Duration(milliseconds: 800);
  static const Duration _silenceStop = Duration(milliseconds: 900);
  static const Duration _maxRecord = Duration(seconds: 30);

  DateTime? _recordStartAt;
  bool _heardSpeech = false;
  Duration _silenceAccum = Duration.zero;

  StreamSubscription? _recSub;
  Timer? _maxTimer;

  // UI state
  bool _isRecording = false;
  bool _isBusy = false;
  String _status = "";
  String _lastUserText = "";
  String _lastAiText = "";
  String _error = "";

  String? _wavPath;

  // Prevent stop crash
  bool _stopping = false;
  bool _stopQueued = false;

  // ==========================
  // Backend (Flask) - EMULATOR ONLY
  // ==========================
  static const String _baseUrl = "http://10.0.2.2:5003";
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

  Future<String> _makeWavPath() async {
    final dir = await getTemporaryDirectory();
    return "${dir.path}/ana_user_${DateTime.now().millisecondsSinceEpoch}.wav";
  }

  Future<void> _startOrStop() async {
    if (_isBusy) return;

    if (!_audioReady) {
      await _initAudio();
      if (!_audioReady) return;
    }

    if (_isRecording) {
      await _stopRecordingAndSend();
    } else {
      await _startRecordingWithAutoStop();
    }
  }

  Future<void> _startRecordingWithAutoStop() async {
    try {
      setState(() {
        _error = "";
        _status = "🎙️ Listening...";
        _isRecording = true;
        _lastUserText = "";
        _lastAiText = "";
        _gifKey = UniqueKey();
      });

      _stopping = false;
      _stopQueued = false;

      _wavPath = await _makeWavPath();
      final f = File(_wavPath!);
      if (await f.exists()) await f.delete();

      _recordStartAt = DateTime.now();
      _heardSpeech = false;
      _silenceAccum = Duration.zero;

      await _player.stopPlayer();

      await _recorder.startRecorder(
        toFile: _wavPath,
        codec: Codec.pcm16WAV,
        sampleRate: _sampleRate,
        numChannels: _channels,
        audioSource: AudioSource.microphone,
      );

      _maxTimer?.cancel();
      _maxTimer = Timer(_maxRecord, () async {
        if (_isRecording) {
          await _stopRecordingAndSend();
        }
      });

      _recSub?.cancel();
      _recSub = _recorder.onProgress?.listen((e) {
        if (!_isRecording) return;
        if (_stopping) return;

        final db = e.decibels ?? -120.0;

        if (db > _silenceDbThreshold) {
          _heardSpeech = true;
          _silenceAccum = Duration.zero;
        } else {
          if (_heardSpeech) {
            _silenceAccum += _progressEvery;
            if (_silenceAccum >= _silenceStop && !_stopQueued) {
              _stopQueued = true;
              Future.microtask(() async {
                if (!mounted) return;
                if (_isRecording && !_stopping) {
                  await _stopRecordingAndSend();
                }
              });
            }
          }
        }
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        _status = "❌ Record start failed";
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

    req.files.add(
      await http.MultipartFile.fromPath("audio", wavPath, filename: "user.wav"),
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("VOICE CHAT HTTP ${streamed.statusCode}: $body");
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
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
      whenFinished: () {
        if (!mounted) return;
        setState(() => _status = "Ready");
      },
    );
  }

  Future<void> _stopRecordingAndSend() async {
    if (_isBusy) return;
    if (_stopping) return;
    _stopping = true;

    setState(() {
      _isBusy = true;
      _status = "⏹ Processing...";
    });

    try {
      _maxTimer?.cancel();
      await _recSub?.cancel();
      _recSub = null;

      if (_isRecording) {
        await _safeStopRecorder();
        await Future.delayed(const Duration(milliseconds: 250));
      }

      final startedAt = _recordStartAt;
      final elapsed = (startedAt == null)
          ? Duration.zero
          : DateTime.now().difference(startedAt);

      setState(() => _isRecording = false);

      if (elapsed < _minRecord) {
        setState(() {
          _status = "⚠️ Too short. Try again.";
          _isBusy = false;
        });
        _stopping = false;
        return;
      }

      final path = _wavPath;
      if (path == null) throw Exception("No audio path");

      final f = File(path);
      if (!await f.exists()) throw Exception("Audio file missing");

      final len = await f.length();
      if (len < 5000) throw Exception("Empty/very small file. Try again.");

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not signed in");

      setState(() => _status = "Crafting a reply with care..");
      final result = await _sendVoiceTurn(
        uid: user.uid,
        characterId: widget.character.id,
        wavPath: path,
      );

      final transcript = (result["transcript"] ?? "").toString().trim();
      final assistantText = (result["assistantText"] ?? "").toString().trim();
      final audioUrl = (result["audioUrl"] ?? "").toString().trim();
      final audioB64 = (result["audioBase64"] ?? "").toString().trim();

      setState(() {
        _lastUserText = transcript;
        _lastAiText = assistantText;
      });

      // 3) Play AI voice
      setState(() => _status = " Speaking...");
      await _player.stopPlayer();

      // First try URL (best)
      if (audioUrl.isNotEmpty) {
        try {
          await _player.startPlayer(
            fromURI: audioUrl,
            codec: Codec.pcm16WAV,
            whenFinished: () {
              if (!mounted) return;
              setState(() => _status = "Ready");
            },
          );
        } catch (_) {
          // If URL playback fails, fallback to base64
          if (audioB64.isEmpty) rethrow;
          await _playFromBase64(audioB64);
        }
      } else {
        // No URL -> base64 fallback
        if (audioB64.isEmpty) {
          throw Exception("No audioUrl and no audioBase64 returned from server");
        }
        await _playFromBase64(audioB64);
      }

      setState(() => _isBusy = false);
      _stopping = false;
    } catch (e) {
      setState(() {
        _status = "❌ Failed";
        _error = "$e";
        _isBusy = false;
        _isRecording = false;
      });
      _stopping = false;
    }
  }

  void _stopAll() async {
    try {
      _maxTimer?.cancel();
      await _recSub?.cancel();
      _recSub = null;

      if (_isRecording) {
        await _safeStopRecorder();
      }
      await _player.stopPlayer();

      setState(() {
        _isRecording = false;
        _isBusy = false;
        _status = "Stopped";
      });

      _stopping = false;
      _stopQueued = false;
    } catch (_) {}
  }

  @override
  void dispose() {
    _maxTimer?.cancel();
    _recSub?.cancel();
    try {
      _player.closePlayer();
      _recorder.closeRecorder();
    } catch (_) {}

    _gifController?.dispose();
    super.dispose();
  }

  String _getTitle(BuildContext context) {
    final name = widget.character.displayName.trim();
    final normalized =
    name.toLowerCase().startsWith('the ') ? name.substring(4) : name;
    return tr(context, 'Your $normalized', '$normalized الخاص بك');
  }

  bool get _showListeningAnim => _isRecording;

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
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
                child: Row(
                  children: [
                    _CircleIconButton(
                      icon: Icons.arrow_back_rounded,
                      onTap: () => Navigator.pop(context),
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
                    _CircleIconButton(
                      icon: Icons.menu_rounded,
                      onTap: () {},
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

              // ✅ Sphere ABOVE + big AI text (photo-like)
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
                      if (_lastAiText.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              children: [
                                TextSpan(text: _lastAiText, style: _aiTextStyle),
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
                      onTap: () => Navigator.pop(context),
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
