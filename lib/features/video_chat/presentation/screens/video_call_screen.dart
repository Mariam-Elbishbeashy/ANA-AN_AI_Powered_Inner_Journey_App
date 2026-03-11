import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:o3d/o3d.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';

class VideoCallScreen extends StatefulWidget {
  final UserCharacter character;

  const VideoCallScreen({super.key, required this.character});

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoEnabled = true;
  late final String _characterModelPath;
  final O3DController _o3dController = O3DController();

  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
    _characterModelPath = _getModelPathForCharacter(widget.character.characterName);
    _initializeCamera();
  }

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
        if (mounted) {
          setState(() {
            _isCameraInitialized = true;
          });
        }
      }
    } catch (e) {
      print("Error initializing camera: $e");
      if (mounted) {
        setState(() {
          _isVideoEnabled = false;
        });
      }
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

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
  }

  void _toggleVideo() async {
    if (_isVideoEnabled) {
      await _cameraController?.dispose();
      _cameraController = null;
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

  void _endCall() {
    _cameraController?.dispose();
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _cameraController?.dispose();
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
          // Background
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
                          onPressed: () => Navigator.pop(context),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: const [
                            CircleAvatar(
                              radius: 4,
                              backgroundColor: Colors.red,
                            ),
                            SizedBox(width: 6),
                            Text(
                              "LIVE",
                              style: TextStyle(
                                color: Colors.purple,
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

                // Character Area - Optimized like dialog
                Expanded(
                  flex: 3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Glow circle
                      Container(
                        width: screenWidth * 0.6,
                        height: screenWidth * 0.6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE6DBFF).withOpacity(0.5),
                        ),
                      ),

                      // 3D Character Model - Exactly like dialog implementation
                      Positioned(
                        top: screenHeight * 0.12,
                        child: SizedBox(
                          height: screenHeight * 0.45,
                          width: screenWidth * 0.65,
                          child: O3D(
                            controller: _o3dController,
                            src: _characterModelPath,
                            autoPlay: true,
                            cameraControls: false, // Disabled for performance
                            backgroundColor: Colors.transparent,
                            autoRotate: false,
                            loading: Loading.eager, // Eager loading for speed - same as dialog
                          ),
                        ),
                      ),

                      // User Camera Preview
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
                                      const Text(
                                        'You',
                                        style: TextStyle(
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

                // BOTTOM SECTION
                Transform.translate(
                  offset: const Offset(0, -75),
                  child: Column(
                    children: [
                      // Character Card
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
                              widget.character.getDisplayName(isArabic ? 'ar' : 'en'),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getCharacterQuote(widget.character.characterName),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.black54,
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Control Buttons
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
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, {bool isActive = true, bool isEndCall = false}) {
    if (isEndCall) {
      return Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [
              Color(0xFF7B61FF),
              Color(0xFF9C8CFF),
            ],
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
          colors: [
            Color(0xFF7B61FF),
            Color(0xFF9C8CFF),
          ],
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
}