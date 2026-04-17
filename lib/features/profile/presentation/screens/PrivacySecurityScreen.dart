// privacy_security_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/services/auth_service.dart';
import 'package:ana_ifs_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ana_ifs_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ana_ifs_app/features/auth/domain/usecases/change_password.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  bool _dataCollection = true;
  bool _analytics = true;
  bool _secureSession = true;
  late final _authRepository =
      AuthRepositoryImpl(AuthRemoteDataSource(AuthService()));
  late final _changePassword = ChangePassword(_authRepository);

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Column(
        children: [
          // App Bar
          Container(
            padding: const EdgeInsets.only(top: 40, bottom: 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_rounded,
                        color: Color(0xFF2A1E3B), size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isArabicValue ? 'الخصوصية والأمان' : 'Privacy & Security',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Privacy Settings
                  Text(
                    isArabicValue ? 'إعدادات الخصوصية' : 'Privacy Settings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _PrivacyItem(
                          icon: Icons.security_rounded,
                          title: isArabicValue ? 'تشفير البيانات' : 'Data Encryption',
                          subtitle: isArabicValue
                              ? 'جميع بياناتك مشفرة باستخدام تشفير من طرف إلى طرف'
                              : 'All your data is encrypted using end-to-end encryption',
                        ),
                        const Divider(height: 24),
                        _PrivacySwitch(
                          title: isArabicValue ? 'جمع البيانات' : 'Data Collection',
                          subtitle: isArabicValue
                              ? 'السماح بجمع البيانات المجهولة لتحسين التطبيق'
                              : 'Allow anonymous data collection to improve the app',
                          value: _dataCollection,
                          onChanged: (value) => setState(() => _dataCollection = value),
                        ),
                        const Divider(height: 24),
                        _PrivacySwitch(
                          title: isArabicValue ? 'التحليلات' : 'Analytics',
                          subtitle: isArabicValue
                              ? 'مشاركة بيانات الاستخدام لتحليل الأنماط'
                              : 'Share usage data for pattern analysis',
                          value: _analytics,
                          onChanged: (value) => setState(() => _analytics = value),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Security Settings
                  Text(
                    isArabicValue ? 'إعدادات الأمان' : 'Security Settings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _PrivacySwitch(
                          title: isArabicValue ? 'جلسة آمنة' : 'Secure Session',
                          subtitle: isArabicValue
                              ? 'تسجيل الخروج التلقائي بعد فترة من عدم النشاط'
                              : 'Automatically log out after period of inactivity',
                          value: _secureSession,
                          onChanged: (value) => setState(() => _secureSession = value),
                        ),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E7CFF).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.lock_clock_rounded,
                                color: Color(0xFF8E7CFF), size: 20),
                          ),
                          title: Text(
                            isArabicValue ? 'تغيير كلمة المرور' : 'Change Password',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          subtitle: Text(
                            isArabicValue
                                ? 'تحديث كلمة المرور لحسابك'
                                : 'Update your account password',
                            style: const TextStyle(fontSize: 13,
                                color: Color(0xFF7A6A5A)),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: Color(0xFFD0C6E8)),
                          onTap: () {
                            _showChangePasswordDialog(context, isArabicValue);
                          },
                        ),
                        const Divider(height: 24),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E7CFF).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.delete_rounded,
                                color: Colors.red, size: 20),
                          ),
                          title: Text(
                            isArabicValue ? 'حذف البيانات' : 'Delete Data',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF2A1E3B),
                            ),
                          ),
                          subtitle: Text(
                            isArabicValue
                                ? 'حذف جميع بيانات حسابك نهائياً'
                                : 'Permanently delete all your account data',
                            style: const TextStyle(fontSize: 13,
                                color: Color(0xFF7A6A5A)),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: Color(0xFFD0C6E8)),
                          onTap: () {
                            _showDeleteDialog(context, isArabicValue);
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Data Export
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8E7CFF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.download_rounded,
                            color: Color(0xFF8E7CFF), size: 20),
                      ),
                      title: Text(
                        isArabicValue ? 'تصدير البيانات' : 'Export Data',
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                      subtitle: Text(
                        isArabicValue
                            ? 'تنزيل جميع بياناتك في ملف PDF'
                            : 'Download all your data as PDF file',
                        style: const TextStyle(fontSize: 13, color: Color(0xFF7A6A5A)),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded,
                          size: 16, color: Color(0xFFD0C6E8)),
                      onTap: () {
                        // Export data functionality
                      },
                    ),
                  ),

                  const SizedBox(height: 40), // Extra padding at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    bool isArabicValue,
  ) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? serverError;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title:
                  Text(isArabicValue ? 'تغيير كلمة المرور' : 'Change password'),
              content: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: currentController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText:
                            isArabicValue ? 'كلمة المرور الحالية' : 'Current password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return isArabicValue
                              ? 'يرجى إدخال كلمة المرور الحالية'
                              : 'Enter your current password';
                        }
                        return null;
                      },
                      onChanged: (_) {
                        if (serverError != null) {
                          setState(() => serverError = null);
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: newController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText:
                            isArabicValue ? 'كلمة المرور الجديدة' : 'New password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return isArabicValue
                              ? 'يرجى إدخال كلمة المرور الجديدة'
                              : 'Enter a new password';
                        }
                        if ((value ?? '').length < 6) {
                          return isArabicValue
                              ? 'يجب أن تكون كلمة المرور 6 أحرف على الأقل'
                              : 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: confirmController,
                      obscureText: true,
                      decoration: InputDecoration(
                        labelText:
                            isArabicValue ? 'تأكيد كلمة المرور' : 'Confirm password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return isArabicValue
                              ? 'يرجى تأكيد كلمة المرور'
                              : 'Confirm your new password';
                        }
                        if (value != newController.text) {
                          return isArabicValue
                              ? 'كلمتا المرور غير متطابقتين'
                              : 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    if (serverError != null)
                      Padding(
                        padding:
                            const EdgeInsets.only(top: 8, left: 4, right: 4),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            serverError!,
                            style: const TextStyle(
                              color: Color(0xFFD9534F),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(isArabicValue ? 'إلغاء' : 'Cancel'),
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
                            await _changePassword(
                              currentPassword: currentController.text,
                              newPassword: newController.text,
                            );
                            if (!mounted) return;
                            Navigator.of(dialogContext).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isArabicValue
                                      ? 'تم تغيير كلمة المرور بنجاح'
                                      : 'Password updated successfully',
                                ),
                                backgroundColor: const Color(0xFF8E7CFF),
                              ),
                            );
                          } on FirebaseAuthException catch (e) {
                            if (!mounted) return;
                            switch (e.code) {
                              case 'wrong-password':
                                serverError = isArabicValue
                                    ? 'كلمة المرور الحالية غير صحيحة'
                                    : 'Current password is incorrect';
                                break;
                              case 'weak-password':
                                serverError = isArabicValue
                                    ? 'كلمة المرور الجديدة ضعيفة'
                                    : 'New password is too weak';
                                break;
                              case 'requires-recent-login':
                                serverError = isArabicValue
                                    ? 'يرجى تسجيل الدخول مرة أخرى ثم المحاولة'
                                    : 'Please log in again and retry';
                                break;
                              default:
                                serverError = isArabicValue
                                    ? 'فشل تحديث كلمة المرور'
                                    : 'Failed to update password';
                            }
                          } catch (_) {
                            if (!mounted) return;
                            serverError = isArabicValue
                                ? 'فشل تحديث كلمة المرور'
                                : 'Failed to update password';
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
                      : Text(isArabicValue ? 'تحديث' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showDeleteDialog(BuildContext context, bool isArabicValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabicValue ? 'حذف البيانات' : 'Delete Data'),
        content: Text(
          isArabicValue
              ? 'هل أنت متأكد أنك تريد حذف جميع بياناتك؟ هذا الإجراء لا يمكن التراجع عنه.'
              : 'Are you sure you want to delete all your data? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabicValue ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Delete data logic
            },
            child: Text(
              isArabicValue ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrivacyItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PrivacyItem({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF8E7CFF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF8E7CFF), size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A6A5A),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PrivacySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _PrivacySwitch({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2A1E3B),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A6A5A),
                ),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: const Color(0xFF8E7CFF),
        ),
      ],
    );
  }
}