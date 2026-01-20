import 'package:flutter/material.dart';
import 'package:gif/gif.dart';
import '../models/user_character_model.dart';
import '../l10n/app_strings.dart';

class VoiceAnalysisScreen extends StatefulWidget {
  final UserCharacter character;

  const VoiceAnalysisScreen({super.key, required this.character});

  @override
  State<VoiceAnalysisScreen> createState() => _VoiceAnalysisScreenState();
}

class _VoiceAnalysisScreenState extends State<VoiceAnalysisScreen>
    with SingleTickerProviderStateMixin {
  bool _isListening = false;
  GifController? _gifController;
  Key _gifKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    _gifController = GifController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _gifController ??= GifController(vsync: this);
  }

  @override
  void dispose() {
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

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      _gifKey = UniqueKey();
    });
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
              const SizedBox(height: 12),
              Text(
                _isListening
                    ? tr(context, 'Listening...', 'جارٍ الاستماع...')
                    : tr(
                        context,
                        'Tap the mic to speak freely and unburden.',
                        'اضغط الميكروفون لتتحدث بحرية وتخفف عن نفسك.',
                      ),
                style: const TextStyle(
                  color: Color(0xFF7A6A5A),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: Center(
                  child: SizedBox(
                    width: 290,
                    height: 290,
                    child: _isListening
                        ? Gif(
                            key: _gifKey,
                            image: const AssetImage(
                              'assets/animations/voice_sphere.gif',
                            ),
                            controller: _gifController!,
                            autostart: Autostart.loop,
                            fit: BoxFit.contain,
                          )
                        : Image.asset(
                            'assets/animations/voice_sphere.gif',
                            fit: BoxFit.contain,
                          ),
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
                      onTap: () {},
                      backgroundColor: Colors.white,
                      iconColor: const Color(0xFF2A1E3B),
                    ),
                    _RoundCircleButton(
                      icon: Icons.mic_rounded,
                      onTap: _toggleListening,
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