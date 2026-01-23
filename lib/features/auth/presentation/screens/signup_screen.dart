import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/auth/presentation/screens/login_screen.dart';
import 'package:ana_ifs_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/initial_motivation_screen.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/core/services/auth_service.dart';
import 'package:ana_ifs_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ana_ifs_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ana_ifs_app/features/auth/domain/usecases/sign_up.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  // Services used for signup + questionnaire routing.
  final _firestoreService = FirestoreService();
  late final _authRepository =
      AuthRepositoryImpl(AuthRemoteDataSource(AuthService()));
  late final _signUp = SignUp(_authRepository);
  // Form key and controllers manage validation + inputs.
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();

  // UI state flags and server-side field errors.
  bool _loading = false;
  bool _obscurePass = true;
  bool _obscureConfirm = true;
  String? _emailServerError;
  String? _passServerError;

  // Backward-compatible getters for hot reload.
  String? get _emailError => _emailServerError;
  set _emailError(String? value) => _emailServerError = value;
  String? get _passError => _passServerError;
  set _passError(String? value) => _passServerError = value;

  void _snack(String msg) {
    // Lightweight feedback for non-field errors.
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _signup() async {
    // Hide keyboard to make loading state clear.
    FocusScope.of(context).unfocus();
    // Clear previous server-side errors before new attempt.
    if (_emailServerError != null || _passServerError != null) {
      setState(() {
        _emailServerError = null;
        _passServerError = null;
      });
    }
    // Local validation (empty/invalid inputs).
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final email = _email.text.trim();
    final pass = _pass.text;
    final confirm = _confirm.text;

    // Start loading and attempt Firebase sign-up (with timeout).
    setState(() => _loading = true);
    var navigated = false;
    try {
      await _signUp(email: email, password: pass)
          .timeout(const Duration(seconds: 20));

      // After signup, start the questionnaire flow.
      if (!mounted) return;
      navigated = true;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
        (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Map Firebase error codes to field-level messages.
      String? emailError;
      String? passError;
      switch (e.code) {
        case "email-already-in-use":
          emailError = tr(
            context,
            "This email is already registered.",
            "هذا البريد الإلكتروني مسجل بالفعل.",
            listen: false,
          );
          break;
        case "invalid-email":
          emailError = tr(
            context,
            "Enter a valid email address.",
            "يرجى إدخال بريد إلكتروني صحيح.",
            listen: false,
          );
          break;
        case "weak-password":
          passError = tr(
            context,
            "Password is too weak.",
            "كلمة المرور ضعيفة جداً.",
            listen: false,
          );
          break;
        case "operation-not-allowed":
          _snack(
            tr(
              context,
              "Sign up is currently disabled.",
              "إنشاء الحساب معطل حالياً.",
              listen: false,
            ),
          );
          break;
        case "too-many-requests":
          _snack(
            tr(
              context,
              "Too many attempts. Please try again later.",
              "محاولات كثيرة جداً. يرجى المحاولة لاحقاً.",
              listen: false,
            ),
          );
          break;
        default:
          _snack(
            tr(
              context,
              "Sign up failed. Please try again.",
              "فشل إنشاء الحساب. حاول مرة أخرى.",
              listen: false,
            ),
          );
      }
      setState(() {
        _emailServerError = emailError;
        _passServerError = passError;
      });
    } on TimeoutException {
      if (!mounted) return;
      // Network/recaptcha timeouts should not lock the UI.
      _snack(
        tr(
          context,
          "Request timed out. Check your connection and try again.",
          "انتهت مهلة الطلب. تحقق من الاتصال وحاول مرة أخرى.",
          listen: false,
        ),
      );
    } catch (e) {
      // Catch-all for unexpected errors.
      _snack(
        tr(
          context,
          "Sign up failed. Please try again.",
          "فشل إنشاء الحساب. حاول مرة أخرى.",
          listen: false,
        ),
      );
    } finally {
      // Stop loading unless we already navigated away.
      if (!mounted || navigated) return;
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
    // Local gradient colors for the CTA button.
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

                        // Form handles validation + inline errors.
                        Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: [
                              _buildTextField(
                                _email,
                                tr(context, "Email address", "البريد الإلكتروني"),
                                Icons.mail_outline_rounded,
                                false,
                                validator: (value) {
                                  final text = value?.trim() ?? "";
                                  if (text.isEmpty) {
                                    return tr(
                                      context,
                                      "Email is required.",
                                      "البريد الإلكتروني مطلوب.",
                                    );
                                  }
                                  final emailRegex =
                                      RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");
                                  if (!emailRegex.hasMatch(text)) {
                                    return tr(
                                      context,
                                      "Enter a valid email address.",
                                      "يرجى إدخال بريد إلكتروني صحيح.",
                                    );
                                  }
                                  return null;
                                },
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [AutofillHints.email],
                                onChanged: (_) {
                                  if (_emailServerError != null) {
                                    setState(() => _emailServerError = null);
                                  }
                                },
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.only(top: 6, left: 12, right: 12),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    tr(
                                      context,
                                      "Use a valid email like name@example.com",
                                      "استخدم بريداً إلكترونياً صحيحاً مثل name@example.com",
                                    ),
                                    style: const TextStyle(
                                      color: Color(0xFF9C90B3),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              if (_emailServerError != null)
                                _buildFieldError(_emailServerError!),
                              const SizedBox(height: 12),

                              _buildTextField(
                                _pass,
                                tr(context, "Password", "كلمة المرور"),
                                Icons.lock_outline_rounded,
                                _obscurePass,
                                validator: (value) {
                                  if ((value ?? "").isEmpty) {
                                    return tr(
                                      context,
                                      "Password is required.",
                                      "كلمة المرور مطلوبة.",
                                    );
                                  }
                                  if ((value ?? "").length < 6) {
                                    return tr(
                                      context,
                                      "Password must be at least 6 characters.",
                                      "كلمة المرور يجب أن تكون 6 أحرف على الأقل.",
                                    );
                                  }
                                  return null;
                                },
                                suffix: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscurePass = !_obscurePass),
                                  icon: Icon(
                                    _obscurePass
                                        ? Icons.visibility_off_outlined
                                        : Icons.visibility_outlined,
                                  ),
                                ),
                                autofillHints: const [AutofillHints.newPassword],
                                onChanged: (_) {
                                  if (_passServerError != null) {
                                    setState(() => _passServerError = null);
                                  }
                                },
                              ),
                              if (_passServerError != null)
                                _buildFieldError(_passServerError!),
                              const SizedBox(height: 12),

                              _buildTextField(
                                _confirm,
                                tr(
                                  context,
                                  "Confirm password",
                                  "تأكيد كلمة المرور",
                                ),
                                Icons.lock_outline_rounded,
                                _obscureConfirm,
                                validator: (value) {
                                  if ((value ?? "").isEmpty) {
                                    return tr(
                                      context,
                                      "Please confirm your password.",
                                      "يرجى تأكيد كلمة المرور.",
                                    );
                                  }
                                  if (value != _pass.text) {
                                    return tr(
                                      context,
                                      "Passwords do not match.",
                                      "كلمتا المرور غير متطابقتين.",
                                    );
                                  }
                                  return null;
                                },
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
                                autofillHints: const [AutofillHints.newPassword],
                              ),
                            ],
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
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    List<String>? autofillHints,
    ValueChanged<String>? onChanged,
  }) {
    // Shared styling for auth text fields.
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType ??
          (hint.toLowerCase().contains("email")
              ? TextInputType.emailAddress
              : TextInputType.text),
      autofillHints: autofillHints,
      validator: validator,
      enableSuggestions: !obscure,
      autocorrect: !obscure,
      onChanged: onChanged,
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

  Widget _buildFieldError(String message) {
    // Inline server-side error text under a field.
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12, right: 12),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: const TextStyle(
            color: Color(0xFFD9534F),
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
