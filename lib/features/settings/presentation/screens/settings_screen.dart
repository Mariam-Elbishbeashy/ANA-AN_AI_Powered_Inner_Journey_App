// settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:ana_ifs_app/features/questionnaire/presentation/state/questionnaire_provider.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/core/services/auth_service.dart';
import 'package:ana_ifs_app/features/auth/data/datasources/auth_remote_data_source.dart';
import 'package:ana_ifs_app/features/auth/data/repositories/auth_repository_impl.dart';
import 'package:ana_ifs_app/features/auth/domain/usecases/change_password.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  late final _authRepository =
      AuthRepositoryImpl(AuthRemoteDataSource(AuthService()));
  late final _changePassword = ChangePassword(_authRepository);
  String _currentLanguage = 'en';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadCurrentLanguage();
  }

  Future<void> _loadCurrentLanguage() async {
    try {
      final language = await _firestoreService.getUserLanguage();
      setState(() {
        _currentLanguage = language;
      });
    } catch (e) {
      print('Error loading language: $e');
    }
  }

  Future<void> _switchLanguage(String newLanguage) async {
    if (_currentLanguage == newLanguage) return;

    setState(() {
      _isLoading = true;
    });

    try {
      await _firestoreService.setUserLanguage(newLanguage);

      // Notify other parts of the app about language change
      // (You might need to implement this based on your app structure)

      setState(() {
        _currentLanguage = newLanguage;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newLanguage == 'ar'
                ? 'تم تغيير اللغة إلى العربية'
                : 'Language changed to English',
          ),
          backgroundColor: const Color(0xFF8E7CFF),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _currentLanguage == 'ar'
                ? 'خطأ في تغيير اللغة'
                : 'Error changing language',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showChangePasswordDialog(bool isArabic) async {
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
              title: Text(isArabic ? 'تغيير كلمة المرور' : 'Change password'),
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
                            isArabic ? 'كلمة المرور الحالية' : 'Current password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return isArabic
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
                            isArabic ? 'كلمة المرور الجديدة' : 'New password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return isArabic
                              ? 'يرجى إدخال كلمة المرور الجديدة'
                              : 'Enter a new password';
                        }
                        if ((value ?? '').length < 6) {
                          return isArabic
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
                            isArabic ? 'تأكيد كلمة المرور' : 'Confirm password',
                      ),
                      validator: (value) {
                        if ((value ?? '').isEmpty) {
                          return isArabic
                              ? 'يرجى تأكيد كلمة المرور'
                              : 'Confirm your new password';
                        }
                        if (value != newController.text) {
                          return isArabic
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
                  child: Text(isArabic ? 'إلغاء' : 'Cancel'),
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
                                  isArabic
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
                                serverError = isArabic
                                    ? 'كلمة المرور الحالية غير صحيحة'
                                    : 'Current password is incorrect';
                                break;
                              case 'weak-password':
                                serverError = isArabic
                                    ? 'كلمة المرور الجديدة ضعيفة'
                                    : 'New password is too weak';
                                break;
                              case 'requires-recent-login':
                                serverError = isArabic
                                    ? 'يرجى تسجيل الدخول مرة أخرى ثم المحاولة'
                                    : 'Please log in again and retry';
                                break;
                              default:
                                serverError = isArabic
                                    ? 'فشل تحديث كلمة المرور'
                                    : 'Failed to update password';
                            }
                          } catch (_) {
                            if (!mounted) return;
                            serverError = isArabic
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
                      : Text(isArabic ? 'تحديث' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = _currentLanguage == 'ar';

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            isArabic ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
            color: const Color(0xFF6A5CFF),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isArabic ? 'الإعدادات' : 'Settings',
          style: const TextStyle(
            color: Color(0xFF2A1E3B),
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Color(0xFF8E7CFF)),
                  const SizedBox(height: 20),
                  Text(
                    isArabic ? 'جاري التحديث...' : 'Updating...',
                    style: const TextStyle(
                      color: Color(0xFF4B3A66),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Language Settings
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DEFF)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                color: const Color(0xFF8E7CFF).withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.language_rounded,
                                color: Color(0xFF8E7CFF),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Text(
                              isArabic ? 'اللغة' : 'Language',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _switchLanguage('en'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentLanguage == 'en'
                                      ? const Color(0xFF8E7CFF)
                                      : Colors.white,
                                  foregroundColor: _currentLanguage == 'en'
                                      ? Colors.white
                                      : const Color(0xFF2A1E3B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: _currentLanguage == 'en'
                                          ? const Color(0xFF8E7CFF)
                                          : const Color(0xFFE5DEFF),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('English'),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () => _switchLanguage('ar'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _currentLanguage == 'ar'
                                      ? const Color(0xFF8E7CFF)
                                      : Colors.white,
                                  foregroundColor: _currentLanguage == 'ar'
                                      ? Colors.white
                                      : const Color(0xFF2A1E3B),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(
                                      color: _currentLanguage == 'ar'
                                          ? const Color(0xFF8E7CFF)
                                          : const Color(0xFFE5DEFF),
                                    ),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                                child: const Text('العربية'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isArabic
                              ? 'سيتم تطبيق تغييرات اللغة على جميع أجزاء التطبيق'
                              : 'Language changes will apply to all parts of the app',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9C90B3),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // App Settings
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DEFF)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'إعدادات التطبيق' : 'App Settings',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsItem(
                          icon: Icons.notifications_rounded,
                          title: isArabic ? 'الإشعارات' : 'Notifications',
                          subtitle: isArabic
                              ? 'إدارة الإشعارات اليومية والتذكيرات'
                              : 'Manage daily notifications and reminders',
                          trailing: Switch(
                            value: true,
                            onChanged: (value) {},
                            activeColor: const Color(0xFF8E7CFF),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.palette_rounded,
                          title: isArabic ? 'المظهر' : 'Appearance',
                          subtitle: isArabic
                              ? 'تخصيص مظهر التطبيق'
                              : 'Customize app appearance',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.volume_up_rounded,
                          title: isArabic
                              ? 'الصوت والتأثيرات'
                              : 'Sound & Effects',
                          subtitle: isArabic
                              ? 'تعديل إعدادات الصوت والتأثيرات'
                              : 'Adjust sound and effects settings',
                          trailing: Switch(
                            value: false,
                            onChanged: (value) {},
                            activeColor: const Color(0xFF8E7CFF),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  // Data & Privacy
                  Container(
                    padding: const EdgeInsets.all(20),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DEFF)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'البيانات والخصوصية' : 'Data & Privacy',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsItem(
                          icon: Icons.security_rounded,
                          title: isArabic ? 'الأمان' : 'Security',
                          subtitle: isArabic
                              ? 'إعدادات أمان الحساب'
                              : 'Account security settings',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () => _showChangePasswordDialog(isArabic),
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.privacy_tip_rounded,
                          title: isArabic ? 'سياسة الخصوصية' : 'Privacy Policy',
                          subtitle: isArabic
                              ? 'قراءة سياسة الخصوصية'
                              : 'Read privacy policy',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.description_rounded,
                          title: isArabic ? 'شروط الخدمة' : 'Terms of Service',
                          subtitle: isArabic
                              ? 'قراءة شروط الاستخدام'
                              : 'Read terms of service',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.delete_outline_rounded,
                          title: isArabic ? 'حذف البيانات' : 'Delete Data',
                          subtitle: isArabic
                              ? 'حذف جميع البيانات الشخصية'
                              : 'Delete all personal data',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {
                            _showDeleteDataDialog(isArabic);
                          },
                        ),
                      ],
                    ),
                  ),

                  // About & Support
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE5DEFF)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isArabic ? 'عن التطبيق والدعم' : 'About & Support',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _SettingsItem(
                          icon: Icons.info_rounded,
                          title: isArabic ? 'عن ANA' : 'About ANA',
                          subtitle: isArabic
                              ? 'تعرف على تطبيق ANA'
                              : 'Learn about ANA app',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.help_rounded,
                          title: isArabic ? 'المساعدة' : 'Help',
                          subtitle: isArabic
                              ? 'الدعم والأسئلة الشائعة'
                              : 'Support and FAQs',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.contact_support_rounded,
                          title: isArabic ? 'اتصل بنا' : 'Contact Us',
                          subtitle: isArabic
                              ? 'تواصل مع فريق الدعم'
                              : 'Contact support team',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                        const Divider(height: 20, color: Color(0xFFE5DEFF)),
                        _SettingsItem(
                          icon: Icons.star_rounded,
                          title: isArabic ? 'قيم التطبيق' : 'Rate App',
                          subtitle: isArabic
                              ? 'شارك تجربتك معنا'
                              : 'Share your experience',
                          trailing: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: const Color(0xFF9C90B3),
                          ),
                          onTap: () {},
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // App Version
                  Center(
                    child: Text(
                      isArabic ? 'الإصدار 1.0.0' : 'Version 1.0.0',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9C90B3),
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  void _showDeleteDataDialog(bool isArabic) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isArabic ? 'حذف البيانات' : 'Delete Data'),
        content: Text(
          isArabic
              ? 'هل أنت متأكد أنك تريد حذف جميع بياناتك؟\n\nهذا الإجراء لا يمكن التراجع عنه وسيتم حذف:\n• جميع الإجابات على الاستبيان\n• جميع الشخصيات المحددة\n• تقدمك الحالي'
              : 'Are you sure you want to delete all your data?\n\nThis action cannot be undone and will delete:\n• All questionnaire answers\n• All identified characters\n• Your current progress',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isArabic ? 'إلغاء' : 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _firestoreService.clearQuestionnaireData();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic
                          ? 'تم حذف جميع البيانات بنجاح'
                          : 'All data deleted successfully',
                    ),
                    backgroundColor: const Color(0xFF8E7CFF),
                    duration: const Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isArabic ? 'خطأ في حذف البيانات' : 'Error deleting data',
                    ),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            child: Text(
              isArabic ? 'حذف' : 'Delete',
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
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
          const SizedBox(width: 16),
          trailing,
        ],
      ),
    );
  }
}
