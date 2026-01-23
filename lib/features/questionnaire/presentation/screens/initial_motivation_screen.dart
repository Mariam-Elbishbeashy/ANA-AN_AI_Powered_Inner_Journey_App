import 'package:flutter/material.dart';

import 'package:ana_ifs_app/features/questionnaire/presentation/screens/questionnaire_screen.dart';

class InitialMotivationScreen extends StatefulWidget {
  const InitialMotivationScreen({super.key});

  @override
  State<InitialMotivationScreen> createState() =>
      _InitialMotivationScreenState();
}

class _InitialMotivationScreenState extends State<InitialMotivationScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _showStartButton = false;
  bool _gifLoaded = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeInOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.elasticOut),
      ),
    );

    // Simulate GIF loading (you can adjust this delay)
    Future.delayed(const Duration(milliseconds: 800), () {
      setState(() => _gifLoaded = true);
      // Start animation sequence after GIF is loaded
      Future.delayed(const Duration(milliseconds: 200), () {
        _controller.forward().then((_) {
          setState(() => _showStartButton = true);
        });
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startQuestionnaire() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFFFFFFFF),
                      Color(0xFFF4F0FF),
                      Color(0xFFEDE7FF),
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 32,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Top spacing
                        const SizedBox(height: 40),

                        // GIF Animation/Illustration
                        Container(
                          height: 200,
                          width: 200,
                          margin: const EdgeInsets.only(bottom: 40),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Placeholder/loading while GIF loads
                              if (!_gifLoaded)
                                Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE5DEFF),
                                    borderRadius: BorderRadius.circular(75),
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(
                                      color: Color(0xFF8E7CFF),
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),

                              // GIF Animation
                              if (_gifLoaded)
                                FadeTransition(
                                  opacity: _fadeAnimation,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: Container(
                                      width: 200,
                                      height: 200,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF8E7CFF,
                                            ).withOpacity(0.1),
                                            blurRadius: 15,
                                            spreadRadius: 2,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(20),
                                        child: Image.asset(
                                          'assets/animations/meditation.gif',
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          errorBuilder:
                                              (context, error, stackTrace) {
                                                return Container(
                                                  decoration: BoxDecoration(
                                                    color: const Color(
                                                      0xFFE5DEFF,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          20,
                                                        ),
                                                  ),
                                                  child: const Center(
                                                    child: Icon(
                                                      Icons
                                                          .self_improvement_rounded,
                                                      size: 80,
                                                      color: Color(0xFF8E7CFF),
                                                    ),
                                                  ),
                                                );
                                              },
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),

                        // Main message
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: ScaleTransition(
                            scale: _scaleAnimation,
                            child: Column(
                              children: [
                                Text(
                                  "Beginning Your Journey",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: const Color(0xFF2A1E3B),
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  "This is a safe space to explore your inner world.\n"
                                  "We'll begin with 13 questions to understand\n"
                                  "your unique inner landscape.",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18,
                                    color: const Color(0xFF4B3A66),
                                    height: 1.6,
                                  ),
                                ),
                                const SizedBox(height: 30),
                                // Motivational quote
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF8E7CFF,
                                      ).withOpacity(0.2),
                                    ),
                                  ),
                                  child: Text(
                                    '"The journey inward is the most important journey of all. '
                                    'Take your time, be gentle with yourself."',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontStyle: FontStyle.italic,
                                      color: const Color(0xFF6A5CFF),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Flexible spacer to push content to proper position
                        const SizedBox(height: 40),

                        // Progress indicator
                        Column(
                          children: [
                            Text(
                              "Estimated time: 5-7 minutes",
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF9C90B3),
                              ),
                            ),
                            const SizedBox(height: 10),
                            LinearProgressIndicator(
                              value: 0.1,
                              backgroundColor: const Color(0xFFE5DEFF),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                const Color(0xFF8E7CFF),
                              ),
                              minHeight: 4,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ],
                        ),

                        const SizedBox(height: 30),

                        // Start button
                        if (_showStartButton)
                          AnimatedOpacity(
                            duration: const Duration(milliseconds: 500),
                            opacity: _showStartButton ? 1.0 : 0.0,
                            child: SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: _startQuestionnaire,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF8E7CFF),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  elevation: 0,
                                  shadowColor: const Color(
                                    0xFF8E7CFF,
                                  ).withOpacity(0.3),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Begin Questionnaire",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
