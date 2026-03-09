import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

/// Screen for video call with The Guider - using GIF animation instead of 3D model
class GuiderVideoCallScreen extends StatefulWidget {
  final String userName; // User's name for personalized interaction

  const GuiderVideoCallScreen({
    super.key,
    required this.userName,
  });

  @override
  State<GuiderVideoCallScreen> createState() => _GuiderVideoCallScreenState();
}

class _GuiderVideoCallScreenState extends State<GuiderVideoCallScreen> {
  bool _isMuted = false;
  bool _isVideoEnabled = true;

  // Guider-specific properties
  static const String _guiderGifPath = 'assets/animations/guider.gif';
  static const List<String> _guiderMessages = [
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

  // Camera related variables
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;

  @override
  void initState() {
    super.initState();
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

  String _getGuiderQuote() {
    final random = DateTime.now().millisecondsSinceEpoch % _guiderMessages.length;
    return _guiderMessages[random];
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
          // Background - Same as VideoCallScreen
          Positioned.fill(
            child: Image.asset(
              "assets/images/call_background.jpeg",
              fit: BoxFit.cover,
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top Bar - Same as VideoCallScreen
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
                              "LIVE",
                              style: const TextStyle(
                                color: Color(0xFF7B61FF), // Changed to match Guider's purple
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

                // Guider Area - Replaced 3D model with GIF
                Expanded(
                  flex: 3,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Glow circle - Same as VideoCallScreen
                      Container(
                        width: screenWidth * 0.6,
                        height: screenWidth * 0.6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFE6DBFF).withOpacity(0.5),
                        ),
                      ),

                      // Guider GIF Animation - Replacing the 3D model
                      Positioned(
                        top: screenHeight * 0.02,
                        child: SizedBox(
                          height: screenHeight * 0.7,
                          width: screenWidth * 0.9,
                          child: Image.asset(
                            _guiderGifPath,
                            fit: BoxFit.contain,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFB79CFF), Color(0xFF9C8CFF)],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  size: 60,
                                  color: Colors.white,
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // User Camera Preview - Same position as VideoCallScreen
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
                                    ? const Color(0xFF7B61FF) // Purple when active
                                    : const Color(0xFF4A2B7A), // Dark purple when inactive
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
                                    ? const Color(0xFF7B61FF).withOpacity(0.3)
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

                // BOTTOM SECTION - Same positioning as VideoCallScreen
                Transform.translate(
                  offset: const Offset(0, -75),
                  child: Column(
                    children: [
                      // Guider Card - Similar to Character Card but for Guider
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
                            Text(
                              isArabic
                                  ? _getArabicGuiderMessage(_getGuiderQuote())
                                  : _getGuiderQuote(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF4B3A66),
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 15),

                      // Control Buttons - Exactly the same as VideoCallScreen
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

  // Exactly the same _circleButton as VideoCallScreen
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

  // Arabic translations for Guider messages
  String _getArabicGuiderMessage(String englishMessage) {
    final Map<String, String> translations = {
      "Take a deep breath. I'm here with you.": "خذ نفسًا عميقًا. أنا هنا معك.",
      "Notice how you're feeling right now.": "لاحظ ما تشعر به الآن.",
      "There's no rush. We have all the time you need.": "لا داعي للعجلة. لدينا كل الوقت الذي تحتاجه.",
      "Whatever you're experiencing is valid.": "كل ما تمر به هو شعور صحيح.",
      "You're doing important work by being here.": "أنت تقوم بعمل مهم بوجودك هنا.",
      "Let's explore this together, gently.": "دعنا نستكشف هذا معًا بلطف.",
      "Your inner parts are welcome here.": "أجزاؤك الداخلية مرحب بها هنا.",
      "This is a safe space for all of you.": "هذه مساحة آمنة لكم جميعًا.",
      "Breathe. Feel. Be present.": "تنفس. اشعر. كن حاضرًا.",
      "I'm listening - not just to your words, but to you.": "أنا أستمع - ليس فقط لكلماتك، بل لك.",
    };

    return translations[englishMessage] ?? englishMessage;
  }
}