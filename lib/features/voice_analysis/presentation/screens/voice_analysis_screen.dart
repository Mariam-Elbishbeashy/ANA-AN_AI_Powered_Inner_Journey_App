import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gif/gif.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';

import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/chat/data/datasources/chat_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/chat_ai_remote_data_source.dart';
import 'package:ana_ifs_app/features/chat/data/datasources/inner_character_local_data_source.dart';

import '../../data/datasources/voice_ai_remote_data_source.dart';
import '../../data/repositories/voice_ai_repository_impl.dart';
import '../state/voice_analysis_cubit.dart';

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

  VoiceAnalysisCubit? cubit;

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

  // If your environment is noisy, increase threshold (less negative).
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
  // Backend (Flask)
  // ==========================
  static String get _baseUrl {
    // Android Emulator -> PC
    if (Platform.isAndroid) return "http://10.0.2.2:5001";

    // iPhone Simulator OR real iPhone -> must use PC IP on same WiFi
    return "http://192.168.1.108:5001";
  }

  // IMPORTANT: These must exist in Flask
  static const String _transcribeEndpoint = "/voice/transcribe";
  static const String _ttsEndpoint = "/voice/tts";

  // ==========================
  // Chat pipeline (Firestore + /chat)
  // ==========================
  final ChatRemoteDataSource _chatRemote = ChatRemoteDataSource();
  late final ChatAiRemoteDataSource _chatAi =
  ChatAiRemoteDataSource(baseUrl: _baseUrl);
  final InnerCharacterLocalDataSource _characterLocal =
  InnerCharacterLocalDataSource();

  String? _threadId;
  String? _sessionId;
  Map<String, dynamic>? _characterProfilePrompt;

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);

    // Keep your cubit init (won’t break)
    try {
      final remote = VoiceAiRemoteDataSource(baseUrl: _baseUrl);
      final repo = VoiceAiRepositoryImpl(remote);
      cubit = VoiceAnalysisCubit(repo: repo);
      cubit!.addListener(_onCubitChanged);
      cubit!.init();
    } catch (e) {
      debugPrint("VoiceAnalysis init error: $e");
    }

    _initAudio();
    _initVoiceChatThread();
  }

  void _onCubitChanged() {
    if (!mounted) return;
    setState(() => _gifKey = UniqueKey());
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

  Future<void> _initVoiceChatThread() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final characterId = widget.character.id;
      const characterType = "inner_character";

      final profile = await _characterLocal.getCharacterById(characterId);

      _characterProfilePrompt = profile?.toPromptMap(useArabic: false) ??
          {
            "id": characterId,
            "displayName": widget.character.displayName,
            "role": "Inner Part",
            "shortDescription": "",
            "whyIExist": "",
            "triggers": [],
            "coreBelief": "",
            "intention": "",
            "fear": "",
            "whatINeed": [],
          };

      final thread = await _chatRemote.ensureChatThread(
        uid: user.uid,
        characterId: characterId,
        characterType: characterType,
        title: widget.character.displayName,
      );

      _threadId = thread.id;
      _sessionId = thread.sessionId;

      debugPrint("✅ Voice thread ready: threadId=$_threadId sessionId=$_sessionId");
    } catch (e) {
      debugPrint("❌ _initVoiceChatThread error: $e");
    }
  }

  // ✅ We create our OWN stable path. NO actualPath.
  Future<String> _makeWavPath() async {
    final dir = await getTemporaryDirectory();
    return "${dir.path}/ana_user_${DateTime.now().millisecondsSinceEpoch}.wav";
  }

  // ==========================
  // Main flow: tap mic
  // ==========================
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

      // ✅ IMPORTANT: We don't use actualPath at all.
      await _recorder.startRecorder(
        toFile: _wavPath,
        codec: Codec.pcm16WAV,
        sampleRate: _sampleRate,
        numChannels: _channels,
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
            if (_silenceAccum >= _silenceStop) {
              if (!_stopQueued) {
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

  // ==========================
  // Flask helpers
  // ==========================
  Future<String> _transcribeWav(String wavPath) async {
    final uri = Uri.parse("$_baseUrl$_transcribeEndpoint");
    final req = http.MultipartRequest("POST", uri);

    req.files.add(
      await http.MultipartFile.fromPath("file", wavPath, filename: "user.wav"),
    );

    final streamed = await req.send();
    final body = await streamed.stream.bytesToString();

    if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
      throw Exception("TRANSCRIBE HTTP ${streamed.statusCode}: $body");
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    if (decoded["success"] != true) {
      throw Exception(decoded["error"] ?? "Transcribe failed");
    }

    return (decoded["transcript"] ?? "").toString().trim();
  }

  Future<Uint8List> _ttsWavBytes(String text, {String voice = "alloy"}) async {
    final uri = Uri.parse("$_baseUrl$_ttsEndpoint");
    final res = await http.post(
      uri,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"text": text, "voice": voice}),
    );

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("TTS HTTP ${res.statusCode}: ${res.body}");
    }

    final decoded = jsonDecode(res.body) as Map<String, dynamic>;
    if (decoded["success"] != true) {
      throw Exception(decoded["error"] ?? "TTS failed");
    }

    final b64 = (decoded["wav_base64"] ?? "").toString();
    if (b64.isEmpty) throw Exception("TTS returned empty audio");

    return base64Decode(b64);
  }

  // ==========================
  // SAFE STOP (prevents crash)
  // ==========================
  Future<String?> _safeStopRecorder() async {
    try {
      final p = await _recorder.stopRecorder(); // IMPORTANT: capture returned path
      return p;
    } catch (_) {
      return null;
    }
  }


  // ==========================
  // Stop -> Transcribe -> Firestore -> /chat -> Firestore -> TTS play
  // ==========================
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
        final stoppedPath = await _safeStopRecorder();
        await Future.delayed(const Duration(milliseconds: 300)); // give it a bit more

// IMPORTANT: update path to the real one
        if (stoppedPath != null && stoppedPath.toString().isNotEmpty) {
          _wavPath = stoppedPath;
        }

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
      if (path == null) {
        setState(() {
          _status = "❌ No audio path";
          _isBusy = false;
        });
        _stopping = false;
        return;
      }

      final f = File(path);
      if (!await f.exists()) {
        setState(() {
          _status = "❌ Audio file missing";
          _isBusy = false;
        });
        _stopping = false;
        return;
      }

      final len = await f.length();
      // ✅ DEBUG (3): Print wav size + header bytes
      final bytes = await File(path).readAsBytes();
      debugPrint("🎙 WAV path: $path");
      debugPrint("🎙 WAV size: ${bytes.length}");
      debugPrint("🎙 WAV header (first 16 bytes): ${bytes.take(16).toList()}");

      if (len < 5000) {
        setState(() {
          _status = "⚠️ Empty/very small file. Try again.";
          _isBusy = false;
        });
        _stopping = false;
        return;
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("Not signed in");

      if (_threadId == null || _sessionId == null || _characterProfilePrompt == null) {
        await _initVoiceChatThread();
      }

      final threadId = _threadId;
      final sessionId = _sessionId;
      final characterProfile = _characterProfilePrompt;

      if (threadId == null || sessionId == null || characterProfile == null) {
        throw Exception("Voice chat thread not initialized yet");
      }

      // ✅ DEBUG (2): play the recorded audio to confirm it contains your voice
      setState(() => _status = "🔎 Debug: playing your recording...");
      await _player.stopPlayer();

      await _player.startPlayer(
        fromURI: path,
        codec: Codec.pcm16WAV,
      );

      await Future.delayed(const Duration(seconds: 2));
      await _player.stopPlayer();

      // 1) Transcribe
      setState(() => _status = "📝 Transcribing...");
      final transcript = await _transcribeWav(path);

      if (transcript.isEmpty) {
        setState(() {
          _status = "⚠️ I didn’t catch that. Try again.";
          _isBusy = false;
        });
        _stopping = false;
        return;
      }

      setState(() => _lastUserText = transcript);

      // 2) Save user text as normal chat message
      await _chatRemote.sendMessage(
        uid: user.uid,
        threadId: threadId,
        role: "user",
        content: transcript,
        metadata: {
          "inputType": "voice_transcribed",
          "sessionId": sessionId,
          "characterId": widget.character.id,
        },
      );

      // 3) Fetch recent messages
      final recent = await _chatRemote.getRecentMessages(
        uid: user.uid,
        threadId: threadId,
        limit: 20,
      );

      final List<Map<String, String>> messagesPayload = recent
          .map((m) => <String, String>{
        "role": m.role.toString(),
        "content": m.content.toString(),
      })
          .toList();

      // 4) Ask AI (/chat)
      setState(() => _status = "🧠 Thinking...");
      final assistantText = await _chatAi.fetchAssistantMessage(
        uid: user.uid,
        threadId: threadId,
        sessionId: sessionId,
        characterId: widget.character.id,
        characterProfile: characterProfile,
        messages: messagesPayload,
      );

      setState(() => _lastAiText = assistantText);

      // 5) Save assistant text
      await _chatRemote.sendMessage(
        uid: user.uid,
        threadId: threadId,
        role: "assistant",
        content: assistantText,
        metadata: {
          "outputType": "voice_reply",
          "sessionId": sessionId,
          "characterId": widget.character.id,
          "voice": "alloy",
        },
      );

      // 6) TTS + play
      setState(() => _status = "🔊 Speaking...");
      final wavBytes = await _ttsWavBytes(assistantText, voice: "alloy");

      if (wavBytes.length < 1000) {
        throw Exception("Invalid TTS audio bytes: ${wavBytes.length}");
      }

      await _player.stopPlayer();
      final dir = await getTemporaryDirectory();
      final outPath = "${dir.path}/ana_tts_${DateTime.now().millisecondsSinceEpoch}.wav";
      final outFile = File(outPath);
      await outFile.writeAsBytes(wavBytes, flush: true);

      await _player.startPlayer(
        fromURI: outPath,
        codec: Codec.pcm16WAV, // still fine since it's WAV file path
        whenFinished: () {
          if (!mounted) return;
          setState(() => _status = "Ready");
        },
      );


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
    cubit?.removeListener(_onCubitChanged);
    cubit?.disposeCubit();

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
    final normalized = name.toLowerCase().startsWith('the ')
        ? name.substring(4)
        : name;
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
                    ? tr(context, 'Tap the mic to speak.', 'اضغط الميكروفون للتحدث.')
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
              if (_lastUserText.isNotEmpty || _lastAiText.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_lastUserText.isNotEmpty)
                        Text(
                          "You: $_lastUserText",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2A1E3B),
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_lastAiText.isNotEmpty)
                        Text(
                          "AI: $_lastAiText",
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF2A1E3B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 18),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 290,
                    height: 290,
                    child: _showListeningAnim
                        ? Gif(
                      key: _gifKey,
                      image: const AssetImage('assets/animations/voice_sphere.gif'),
                      controller: _gifController!,
                      autostart: Autostart.loop,
                      fit: BoxFit.contain,
                    )
                        : Image.asset('assets/animations/voice_sphere.gif', fit: BoxFit.contain),
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
