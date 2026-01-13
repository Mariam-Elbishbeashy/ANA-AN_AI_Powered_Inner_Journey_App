import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';


class AnaWelcomeScreen extends StatelessWidget {
  const AnaWelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFFFFFFFF),
              Color(0xFFF9F6FF),
              Color(0xFFF4F0FF),
            ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Top-left logo
              const Positioned(
                top: 18,
                left: 18,
                child: _LogoMark(),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 80),

                    const Text(
                      "Hi there, I’m ANA.",
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.3,
                        color: Color(0xFF2E2442),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),

                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 38,
                          height: 1.18,
                          color: Color(0xFF2A1E3B),
                        ),
                        children: [
                          TextSpan(text: "I’m here to support your\n"),
                          TextSpan(
                            text: "inner journey.",
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Text(
                      "You’re safe here. Let’s begin — one gentle step at a time.",
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.5,
                        color: Color(0xFF3B2E55),
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const Spacer(),

                    // Character illustration area (pure Flutter shapes)
                    Center(
                      child: SizedBox(
                        height: size.height * 0.26,
                        width: size.width,
                        child: const _CuteCharacter(),
                      ),
                    ),

                    const SizedBox(height: 16),

                    SizedBox(
                      width: double.infinity,
                      height: 58,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8E7CFF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          "Get started",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    Center(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                          );
                        },
                        child: RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF4B3A66),
                              height: 1.4,
                            ),
                            children: [
                              TextSpan(text: "Already have an account? "),
                              TextSpan(
                                text: "Log in",
                                style: TextStyle(
                                  color: Color(0xFF8E7CFF),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),

                    const Center(
                      child: Text(
                        "v0.1.0",
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF9C90B3),
                        ),
                      ),
                    ),

                    const SizedBox(height: 18),
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

class _LogoMark extends StatelessWidget {
  const _LogoMark();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.favorite_rounded,
            color: Color(0xFF8E7CFF),
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        const Text(
          "ANA",
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A1E3B),
            letterSpacing: 0.4,
          ),
        ),
      ],
    );
  }
}

class _CuteCharacter extends StatelessWidget {
  const _CuteCharacter();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        Positioned(
          bottom: 8,
          child: Container(
            width: 280,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
        ),
        Positioned(
          bottom: 22,
          child: Container(
            width: 320,
            height: 190,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.88),
              borderRadius: BorderRadius.circular(42),
              border: Border.all(
                color: const Color(0xFF8E7CFF).withValues(alpha: 0.18),
                width: 1.2,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: 56,
          child: Container(
            width: 250,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F6FF),
              borderRadius: BorderRadius.circular(34),
            ),
          ),
        ),
        Positioned(
          bottom: 150,
          child: Column(
            children: [
              Container(
                width: 10,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFFB8AED6),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFF2E2442).withValues(alpha: 0.6),
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          bottom: 100,
          child: Row(
            children: const [
              _Eye(),
              SizedBox(width: 40),
              _Eye(),
            ],
          ),
        ),
        Positioned(
          bottom: 78,
          child: Row(
            children: [
              Container(
                width: 26,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB3D9).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              const SizedBox(width: 150),
              Container(
                width: 26,
                height: 14,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFB3D9).withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ],
          ),
        ),
        const Positioned(bottom: 30, left: 24, child: _Hand()),
        const Positioned(bottom: 30, right: 24, child: _Hand()),
      ],
    );
  }
}

class _Eye extends StatelessWidget {
  const _Eye();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 26,
      decoration: BoxDecoration(
        color: const Color(0xFF2E2442).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(40),
      ),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Container(
          width: 56,
          height: 14,
          decoration: BoxDecoration(
            color: const Color(0xFFF8F6FF),
            borderRadius: BorderRadius.circular(40),
          ),
        ),
      ),
    );
  }
}

class _Hand extends StatelessWidget {
  const _Hand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 90,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
        ),
      ),
    );
  }
}
