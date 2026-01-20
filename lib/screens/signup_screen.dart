import 'package:ana_ifs_app/screens/questionnaire/initial_motivation_screen.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import 'login_screen.dart';
import 'welcome_screen.dart';
import '../l10n/app_strings.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _auth = AuthService();
  final _firestoreService = FirestoreService();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signup() async {
    final email = _email.text.trim();
    final pass = _pass.text;
    final confirm = _confirm.text;

    if (email.isEmpty || pass.isEmpty || confirm.isEmpty) {
      _snack(tr(context, "Please fill all fields.", "يرجى تعبئة جميع الحقول."));
      return;
    }
    if (pass.length < 6) {
      _snack(tr(context, "Password must be at least 6 characters.", "كلمة المرور يجب أن تكون 6 أحرف على الأقل."));
      return;
    }
    if (pass != confirm) {
      _snack(tr(context, "Passwords do not match.", "كلمتا المرور غير متطابقتين."));
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.signUp(email: email, password: pass);

      // After successful signup, navigate to motivation screen
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
        (route) => false,
      );
    } catch (e) {
      _snack(tr(context, "Sign up failed: ${e.toString()}", "فشل إنشاء الحساب: ${e.toString()}"));
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    _confirm.dispose();
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
                            Icons.waves_outlined,
                            color: purple2,
                          ),
                        ),
                        const SizedBox(height: 12),

                        Text(
                          tr(
                            context,
                            "Take a deep breath,\n Reset your mind",
                            "خذ نفساً عميقاً،\n وأعد ضبط ذهنك",
                          ),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 26,
                            height: 1.3,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF2E2442),
                          ),
                        ),
                        const SizedBox(height: 18),

                        _buildTextField(
                          _email,
                          tr(context, "Email address", "البريد الإلكتروني"),
                          Icons.mail_outline_rounded,
                          false,
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          _pass,
                          tr(context, "Password", "كلمة المرور"),
                          Icons.lock_outline_rounded,
                          _obscurePass,
                          suffix: IconButton(
                            onPressed: () =>
                                setState(() => _obscurePass = !_obscurePass),
                            icon: Icon(
                              _obscurePass
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        _buildTextField(
                          _confirm,
                          tr(context, "Confirm password", "تأكيد كلمة المرور"),
                          Icons.lock_outline_rounded,
                          _obscureConfirm,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        // Sign Up button
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _signup,
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Ink(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [purple1, purple2],
                                ),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: _loading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                          color: Colors.white,
                                        ),
                                      )
                                    : Text(
                                        tr(context, "Sign Up", "إنشاء حساب"),
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

                        const SizedBox(height: 12),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(tr(context, "Already have an account? ", "هل لديك حساب؟ ")),
                            TextButton(
                              onPressed: _loading
                                  ? null
                                  : () {
                                      Navigator.of(context).pushReplacement(
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      );
                                    },
                              child: Text(tr(context, "Log in", "تسجيل الدخول")),
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
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF6A5CFF).withOpacity(0.18),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide(
            color: const Color(0xFF6A5CFF).withOpacity(0.18),
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
