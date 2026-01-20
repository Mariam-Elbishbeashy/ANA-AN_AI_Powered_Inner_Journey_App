import 'package:ana_ifs_app/screens/questionnaire/initial_motivation_screen.dart';
import 'package:ana_ifs_app/screens/questionnaire/questionnaire_screen.dart';
import 'package:ana_ifs_app/screens/shell_screen.dart';
import 'package:ana_ifs_app/screens/signup_screen.dart';
import 'package:ana_ifs_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:sign_in_button/sign_in_button.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../l10n/app_strings.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _auth = AuthService();
  final _firestoreService = FirestoreService();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  bool _obscure = true;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _login() async {
    final email = _email.text.trim();
    final pass = _pass.text;

    if (email.isEmpty || pass.isEmpty) {
      _snack(tr(context, "Please enter email and password.", "يرجى إدخال البريد الإلكتروني وكلمة المرور."));
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.signIn(email: email, password: pass);

      // After successful login, check if user needs to complete questionnaire
      await _navigateAfterLogin();
    } catch (e) {
      _snack(tr(context, "Login failed: ${e.toString()}", "فشل تسجيل الدخول: ${e.toString()}"));
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateAfterLogin() async {
    try {
      // Check if user has completed questionnaire
      final hasCompleted = await _firestoreService.hasCompletedQuestionnaire();

      if (!mounted) return;

      if (hasCompleted) {
        // Go directly to home
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AnaShell()),
          (route) => false,
        );
      } else {
        // Check if user has started questionnaire
        final userAnswers = await _firestoreService.getAllUserAnswers();
        if (userAnswers.isNotEmpty) {
          // User has started but not completed - go to questionnaire
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const QuestionnaireScreen()),
            (route) => false,
          );
        } else {
          // User hasn't started - go to motivation screen
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
            (route) => false,
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      _snack(tr(context, "Error checking your status. Please try again.", "حدث خطأ أثناء التحقق. حاول مرة أخرى."));
      setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
      await _navigateAfterLogin();
    } catch (e) {
      if (!mounted) return;
      _snack(tr(context, "Google sign-in cancelled or failed.", "تم إلغاء تسجيل الدخول عبر جوجل أو فشل."));
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const purple1 = Color(0xFF9B7BFF);
    const purple2 = Color(0xFF6A5CFF);

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFF4F0FF), Color(0xFFEDE7FF), Color(0xFFFFFFFF)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Back button
              Positioned(
                top: 8,
                left: 8,
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Color(0xFF6A5CFF),
                  ),
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(builder: (_) => const AnaWelcomeScreen()),
                    );
                  },
                ),
              ),

              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 22),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.80),
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                        color: const Color(0xFF6A5CFF).withOpacity(0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: purple2.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: purple2,
                          ),
                        ),

                        const SizedBox(height: 12),

                        const Text(
                          "Welcome!",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Email
                        _buildTextField(
                          _email,
                          tr(context, "Email address", "البريد الإلكتروني"),
                          Icons.mail_outline_rounded,
                          false,
                        ),
                        const SizedBox(height: 12),

                        // Password
                        _buildTextField(
                          _pass,
                          tr(context, "Password", "كلمة المرور"),
                          Icons.lock_outline_rounded,
                          _obscure,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6A5CFF),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Log In button
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            minWidth: double.infinity,
                          ),
                          child: ElevatedButton(
                            onPressed: _loading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(double.infinity, 54),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [purple1, purple2],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Container(
                                height: 50,
                                alignment: Alignment.center,
                                child: _loading
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.4,
                                      )
                                    : Text(
                                        tr(context, "Log In", "تسجيل الدخول"),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ),

                        // Divider
                        Center(child: const SizedBox(height: 16)),
                        Row(
                          children: [
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.black.withOpacity(0.12),
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                "OR",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7A6A5A),
                                ),
                              ),
                            ),
                            Expanded(
                              child: Divider(
                                thickness: 1,
                                color: Colors.black.withOpacity(0.12),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Google Sign-In
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: SizedBox(
                            width: double.infinity,
                            height: 58,
                            child: SignInButton(
                              Buttons.google,
                              text: tr(context, "Continue with Google", "تابع عبر جوجل"),
                              onPressed: () {
                                if (_loading) return;
                                _googleLogin();
                              },
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tr(context, "No account? ", "لا تملك حساباً؟ ")),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const SignUpScreen(),
                                        ),
                                      );
                                    },
                              child: Text(tr(context, "Sign up", "إنشاء حساب")),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint,
    IconData icon,
    bool obscure, {
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      keyboardType: hint.toLowerCase().contains("email")
          ? TextInputType.emailAddress
          : TextInputType.text,
      decoration: InputDecoration(
        prefixIcon: Icon(icon),
        suffixIcon: suffix,
        hintText: hint,
        filled: true,
        fillColor: Colors.white.withOpacity(0.70),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF6A5CFF).withOpacity(0.18),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFF6A5CFF), width: 1.4),
        ),
      ),
    );
  }
}

