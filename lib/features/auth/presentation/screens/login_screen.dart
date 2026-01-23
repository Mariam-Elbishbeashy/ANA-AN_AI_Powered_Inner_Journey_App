import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:sign_in_button/sign_in_button.dart';

import 'package:ana_ifs_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/initial_motivation_screen.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/questionnaire_screen.dart';
import 'package:ana_ifs_app/core/services/auth_service.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ana_ifs_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ana_ifs_app/features/auth/domain/usecases/reset_password.dart';

import 'package:ana_ifs_app/app/shell/ana_shell.dart';
import 'package:ana_ifs_app/features/auth/presentation/screens/signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Services for authentication and questionnaire status checks.
  final _auth = AuthService();
  final _firestoreService = FirestoreService();
  // Use case for password reset (clean-architecture flow).
  late final _authRepository = AuthRepositoryImpl(AuthRemoteDataSource(_auth));
  late final _resetPassword = ResetPassword(_authRepository);
  // Form key and controllers manage validation + inputs.
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  // UI state flags and server-side field errors.
  bool _loading = false;
  bool _obscure = true;
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

  Future<void> _login() async {
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

    // Start loading and attempt Firebase sign-in (with timeout).
    setState(() => _loading = true);
    var navigated = false;
    try {
      await _auth
          .signIn(email: email, password: pass)
          .timeout(const Duration(seconds: 20));

      // After login, route based on questionnaire status.
      await _navigateAfterLogin();
      navigated = true;
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      // Map Firebase error codes to field-level messages.
      String? emailError;
      String? passError;
      switch (e.code) {
        case "user-not-found":
          emailError = tr(
            context,
            "No account found for this email.",
            "لا يوجد حساب بهذا البريد الإلكتروني.",
            listen: false,
          );
          break;
        case "invalid-credential":
          passError = tr(
            context,
            "Incorrect email or password.",
            "البريد الإلكتروني أو كلمة المرور غير صحيحة.",
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
        case "wrong-password":
          passError = tr(
            context,
            "Incorrect password.",
            "كلمة المرور غير صحيحة.",
            listen: false,
          );
          break;
        case "user-disabled":
          _snack(
            tr(
              context,
              "This account has been disabled.",
              "تم تعطيل هذا الحساب.",
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
              "Login failed. Please try again.",
              "فشل تسجيل الدخول. حاول مرة أخرى.",
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
          "Login failed. Please try again.",
          "فشل تسجيل الدخول. حاول مرة أخرى.",
          listen: false,
        ),
      );
    } finally {
      // Stop loading unless we already navigated away.
      if (!mounted || navigated) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _navigateAfterLogin() async {
    // Decide next screen based on questionnaire completion.
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
      // If status check fails, show message and stop loading.
      _snack(
        tr(
          context,
          "Error checking your status. Please try again.",
          "حدث خطأ أثناء التحقق. حاول مرة أخرى.",
          listen: false,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _googleLogin() async {
    // Google sign-in uses Firebase Auth then same routing logic.
    setState(() => _loading = true);
    try {
      await _auth.signInWithGoogle();
      await _navigateAfterLogin();
    } catch (e) {
      if (!mounted) return;
      _snack(
        tr(
          context,
          "Google sign-in cancelled or failed.",
          "تم إلغاء تسجيل الدخول عبر جوجل أو فشل.",
          listen: false,
        ),
      );
      setState(() => _loading = false);
    }
  }

  Future<void> _showResetPasswordDialog() async {
    // Dialog-scoped controller and form for resetting password.
    final emailController = TextEditingController(text: _email.text.trim());
    final formKey = GlobalKey<FormState>();
    String? serverError;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                tr(context, "Reset password", "إعادة تعيين كلمة المرور"),
              ),
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(
                        context,
                        "Enter your email and we'll send a reset link.",
                        "أدخل بريدك الإلكتروني وسنرسل لك رابط إعادة التعيين.",
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
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
                      onChanged: (_) {
                        if (serverError != null) {
                          setState(() => serverError = null);
                        }
                      },
                      decoration: InputDecoration(
                        hintText: tr(
                          context,
                          "Email address",
                          "البريد الإلكتروني",
                        ),
                      ),
                    ),
                    if (serverError != null) _buildFieldError(serverError!),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(tr(context, "Cancel", "إلغاء")),
                ),
                ElevatedButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          if (!(formKey.currentState?.validate() ?? false)) {
                            return;
                          }
                          setState(() => submitting = true);
                          try {
                            await _resetPassword(
                              emailController.text.trim(),
                            ).timeout(const Duration(seconds: 20));
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            _snack(
                              tr(
                                context,
                                "Password reset email sent.",
                                "تم إرسال بريد إعادة تعيين كلمة المرور.",
                                listen: false,
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            if (!mounted) return;
                            switch (e.code) {
                              case "user-not-found":
                                serverError = tr(
                                  context,
                                  "No account found for this email.",
                                  "لا يوجد حساب بهذا البريد الإلكتروني.",
                                  listen: false,
                                );
                                break;
                              case "invalid-email":
                                serverError = tr(
                                  context,
                                  "Enter a valid email address.",
                                  "يرجى إدخال بريد إلكتروني صحيح.",
                                  listen: false,
                                );
                                break;
                              default:
                                _snack(
                                  tr(
                                    context,
                                    "Failed to send reset email.",
                                    "فشل إرسال بريد إعادة التعيين.",
                                    listen: false,
                                  ),
                                );
                            }
                          } on TimeoutException {
                            if (!mounted) return;
                            _snack(
                              tr(
                                context,
                                "Request timed out. Check your connection.",
                                "انتهت مهلة الطلب. تحقق من الاتصال.",
                                listen: false,
                              ),
                            );
                          } catch (_) {
                            if (!mounted) return;
                            _snack(
                              tr(
                                context,
                                "Failed to send reset email.",
                                "فشل إرسال بريد إعادة التعيين.",
                                listen: false,
                              ),
                            );
                          } finally {
                            if (mounted) {
                              setState(() => submitting = false);
                            }
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(tr(context, "Send", "إرسال")),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
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

                        // Form handles validation + inline errors.
                        Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: Column(
                            children: [
                              // Email
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
                              if (_emailServerError != null)
                                _buildFieldError(_emailServerError!),
                              const SizedBox(height: 12),

                              // Password
                              _buildTextField(
                                _pass,
                                tr(context, "Password", "كلمة المرور"),
                                Icons.lock_outline_rounded,
                                _obscure,
                                validator: (value) {
                                  if ((value ?? "").isEmpty) {
                                    return tr(
                                      context,
                                      "Password is required.",
                                      "كلمة المرور مطلوبة.",
                                    );
                                  }
                                  return null;
                                },
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
                                autofillHints: const [AutofillHints.password],
                                onChanged: (_) {
                                  if (_passServerError != null) {
                                    setState(() => _passServerError = null);
                                  }
                                },
                              ),
                              if (_passServerError != null)
                                _buildFieldError(_passServerError!),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _loading ? null : _showResetPasswordDialog,
                                  child: Text(
                                    tr(context, "Forgot password?", "نسيت كلمة المرور؟"),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const SizedBox(height: 4),

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
                              text: tr(
                                context,
                                "Continue with Google",
                                "تابع عبر جوجل",
                              ),
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