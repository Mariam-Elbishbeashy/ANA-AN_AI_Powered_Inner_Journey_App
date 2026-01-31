import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../domain/repositories/voice_ai_repository.dart';

enum VoiceUiStatus { idle, listening, thinking, speaking, error }

class VoiceAnalysisState {
  final VoiceUiStatus status;
  final String sessionId;
  final String lastUserText;
  final String lastAiText;
  final String? error;

  const VoiceAnalysisState({
    required this.status,
    required this.sessionId,
    required this.lastUserText,
    required this.lastAiText,
    this.error,
  });

  factory VoiceAnalysisState.initial() => const VoiceAnalysisState(
    status: VoiceUiStatus.idle,
    sessionId: "default",
    lastUserText: "",
    lastAiText: "",
  );

  VoiceAnalysisState copyWith({
    VoiceUiStatus? status,
    String? sessionId,
    String? lastUserText,
    String? lastAiText,
    String? error,
  }) {
    return VoiceAnalysisState(
      status: status ?? this.status,
      sessionId: sessionId ?? this.sessionId,
      lastUserText: lastUserText ?? this.lastUserText,
      lastAiText: lastAiText ?? this.lastAiText,
      error: error,
    );
  }
}

class VoiceAnalysisCubit extends ChangeNotifier {
  final VoiceAiRepository repo;

  VoiceAnalysisState _state = VoiceAnalysisState.initial();
  VoiceAnalysisState get state => _state;

  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final AudioPlayer _player = AudioPlayer();

  bool _ready = false;

  NoiseMeter? _noiseMeter;
  StreamSubscription<NoiseReading>? _noiseSub;

  File? _wavFile;

  // Silence detection (tune if needed)
  final double startSpeechDb = 55.0;
  final double silenceDb = 45.0;
  final Duration minRecord = const Duration(milliseconds: 800);
  final Duration stopAfterSilence = const Duration(milliseconds: 900);
  final Duration hardMax = const Duration(seconds: 30);

  DateTime? _recordStart;
  DateTime? _speechStart;
  DateTime? _lastLoud;

  VoiceAnalysisCubit({required this.repo});

  void _emit(VoiceAnalysisState s) {
    _state = s;
    notifyListeners();
  }

  Future<void> init() async {
    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _emit(state.copyWith(status: VoiceUiStatus.error, error: "Microphone permission denied"));
      return;
    }
    await _recorder.openRecorder();
    _ready = true;
  }

  Future<void> disposeCubit() async {
    await stop();
    await _player.dispose();
    await _recorder.closeRecorder();
  }

  Future<void> startOrStop() async {
    if (state.status == VoiceUiStatus.listening) {
      await stop();
    } else {
      await startListening();
    }
  }

  Future<void> stop() async {
    try {
      await _noiseSub?.cancel();
      _noiseSub = null;

      if (_recorder.isRecording) {
        await _recorder.stopRecorder();
      }

      _emit(state.copyWith(status: VoiceUiStatus.idle));
    } catch (_) {
      _emit(state.copyWith(status: VoiceUiStatus.idle));
    }
  }

  Future<void> startListening() async {
    if (!_ready) await init();
    if (!_ready) return;

    final dir = await getTemporaryDirectory();
    final path = "${dir.path}/user.wav";
    _wavFile = File(path);
    if (await _wavFile!.exists()) await _wavFile!.delete();

    _recordStart = DateTime.now();
    _speechStart = null;
    _lastLoud = null;

    _emit(state.copyWith(status: VoiceUiStatus.listening, error: null));

    await _recorder.startRecorder(
      toFile: path,
      codec: Codec.pcm16WAV,
      sampleRate: 16000,
      numChannels: 1,
    );

    _noiseMeter = NoiseMeter();
    _noiseSub = _noiseMeter!.noise.listen((NoiseReading r) async {
      final now = DateTime.now();

      if (_recordStart != null && now.difference(_recordStart!) > hardMax) {
        await _finishAndSend();
        return;
      }

      final db = r.meanDecibel;
      final loud = db >= startSpeechDb;
      final silent = db <= silenceDb;

      if (loud && _speechStart == null) _speechStart = now;
      if (!silent) _lastLoud = now;

      if (_speechStart != null && _recordStart != null) {
        final recordedEnough = now.difference(_recordStart!) >= minRecord;
        if (recordedEnough) {
          final last = _lastLoud ?? _speechStart!;
          if (silent && now.difference(last) >= stopAfterSilence) {
            await _finishAndSend();
            return;
          }
        }
      }
    }, onError: (e) {
      _emit(state.copyWith(status: VoiceUiStatus.error, error: e.toString()));
    });
  }

  Future<void> _finishAndSend() async {
    if (state.status != VoiceUiStatus.listening) return;

    await _noiseSub?.cancel();
    _noiseSub = null;

    await _recorder.stopRecorder();

    final file = _wavFile;
    if (file == null || !(await file.exists())) {
      _emit(state.copyWith(status: VoiceUiStatus.error, error: "No audio recorded"));
      return;
    }

    // too-short protection
    final len = await file.length();
    if (len < 5000) {
      _emit(state.copyWith(status: VoiceUiStatus.idle));
      return;
    }

    _emit(state.copyWith(status: VoiceUiStatus.thinking));

    try {
      final res = await repo.doVoiceTurn(wavFile: file, sessionId: state.sessionId);

      _emit(state.copyWith(
        status: VoiceUiStatus.speaking,
        sessionId: res.sessionId,
        lastUserText: res.transcript,
        lastAiText: res.replyText,
      ));

      if (res.replyAudioWavBase64.isNotEmpty) {
        final dir = await getTemporaryDirectory();
        final aiPath = "${dir.path}/ai.wav";
        final aiFile = File(aiPath);
        await aiFile.writeAsBytes(base64Decode(res.replyAudioWavBase64), flush: true);

        await _player.setFilePath(aiFile.path);
        await _player.play();
      }

      _emit(state.copyWith(status: VoiceUiStatus.idle));
    } catch (e) {
      _emit(state.copyWith(status: VoiceUiStatus.error, error: e.toString()));
    }
  }
}
