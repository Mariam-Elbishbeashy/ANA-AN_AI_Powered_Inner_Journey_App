// privacy_security_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';

class PrivacySecurityScreen extends StatefulWidget {
  const PrivacySecurityScreen({super.key});

  @override
  State<PrivacySecurityScreen> createState() => _PrivacySecurityScreenState();
}

class _PrivacySecurityScreenState extends State<PrivacySecurityScreen> {
  late final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  late final FirebaseFirestore _firestore = FirebaseFirestore.instance;

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
                  color: Colors.black.withValues(alpha: 0.05),
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
                          color: Colors.black.withValues(alpha: 0.05),
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
                              ? 'بيانات حسابك وجلساتك محفوظة بشكل آمن داخل التطبيق'
                              : 'Your account data and sessions are kept securely inside the app',
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Account Settings
                  Text(
                    isArabicValue ? 'إعدادات الحساب' : 'Account Settings',
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: _buildEditNameTile(context, isArabicValue),
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
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
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
                              color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
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

                  const SizedBox(height: 40), // Extra padding at bottom
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditNameTile(BuildContext context, bool isArabicValue) {
    final user = _firebaseAuth.currentUser;

    Widget buildTile(String subtitle) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_rounded,
            color: Color(0xFF8E7CFF),
            size: 20,
          ),
        ),
        title: Text(
          isArabicValue ? 'تعديل الاسم' : 'Edit Name',
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2A1E3B),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 13, color: Color(0xFF7A6A5A)),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 16,
          color: Color(0xFFD0C6E8),
        ),
        onTap: () {
          _showEditNameDialog(context, isArabicValue);
        },
      );
    }

    if (user == null) {
      return buildTile(
        isArabicValue
            ? 'سجّلي الدخول عشان تقدري تعدّلي اسم الحساب'
            : 'Sign in to edit your account name',
      );
    }

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('users').doc(user.uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final savedName = (data?['displayName'] ??
            data?['firstName'] ??
            user.displayName ??
            '')
            .toString()
            .trim();

        return buildTile(
          savedName.isEmpty
              ? (isArabicValue
              ? 'اضغطي هنا لإضافة اسمك'
              : 'Tap here to add your name')
              : savedName,
        );
      },
    );
  }

  Future<void> _showEditNameDialog(
      BuildContext context,
      bool isArabicValue,
      ) async {
    final screenContext = context;
    final nameController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? serverError;
    bool submitting = false;
    bool dialogClosed = false;

    Future<void> submitName(
        StateSetter dialogSetState,
        BuildContext dialogContext,
        ) async {
      if (submitting) return;
      if (!(formKey.currentState?.validate() ?? false)) return;

      dialogSetState(() {
        submitting = true;
        serverError = null;
      });

      try {
        await _updateUserName(nameController.text);
        if (!dialogContext.mounted) return;

        dialogClosed = true;
        Navigator.of(dialogContext).pop();

        if (!mounted) return;
        ScaffoldMessenger.of(screenContext).showSnackBar(
          SnackBar(
            content: Text(
              isArabicValue
                  ? 'تم تحديث الاسم بنجاح'
                  : 'Name updated successfully',
            ),
            backgroundColor: const Color(0xFF8E7CFF),
          ),
        );
      } catch (_) {
        if (!dialogContext.mounted || dialogClosed) return;
        dialogSetState(() {
          serverError = isArabicValue
              ? 'فشل تحديث الاسم'
              : 'Failed to update name';
          submitting = false;
        });
      } finally {
        // Do not call the dialog setState after Navigator.pop().
        // Calling it after the dialog is closed can rebuild TextFormField
        // with a controller that has already been disposed.
        if (dialogContext.mounted && !dialogClosed && submitting) {
          dialogSetState(() => submitting = false);
        }
      }
    }

    final user = _firebaseAuth.currentUser;
    if (user != null) {
      try {
        final userDoc = await _firestore.collection('users').doc(user.uid).get();
        final data = userDoc.data();
        final currentName = (data?['displayName'] ??
            data?['firstName'] ??
            user.displayName ??
            '')
            .toString()
            .trim();
        nameController.text = currentName;
      } catch (_) {
        nameController.text = (user.displayName ?? '').trim();
      }
    }

    await showDialog<void>(
      context: screenContext,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (dialogContext, dialogSetState) {
            return Directionality(
              textDirection:
              isArabicValue ? TextDirection.rtl : TextDirection.ltr,
              child: AlertDialog(
                title: Text(isArabicValue ? 'تعديل الاسم' : 'Edit name'),
                content: Form(
                  key: formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        enabled: !submitting,
                        textInputAction: TextInputAction.done,
                        textAlign:
                        isArabicValue ? TextAlign.right : TextAlign.left,
                        textDirection: isArabicValue
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        decoration: InputDecoration(
                          labelText: isArabicValue ? 'اسمك' : 'Your name',
                          hintText: isArabicValue
                              ? 'اكتبي الاسم اللي تحبي يظهر'
                              : 'Enter the name you want to display',
                        ),
                        validator: (value) {
                          final trimmed = (value ?? '').trim();
                          if (trimmed.isEmpty) {
                            return isArabicValue
                                ? 'يرجى إدخال الاسم'
                                : 'Enter your name';
                          }
                          if (trimmed.length < 2) {
                            return isArabicValue
                                ? 'الاسم قصير جداً'
                                : 'Name is too short';
                          }
                          return null;
                        },
                        onChanged: (_) {
                          if (serverError != null) {
                            dialogSetState(() => serverError = null);
                          }
                        },
                        onFieldSubmitted: (_) =>
                            submitName(dialogSetState, dialogContext),
                      ),
                      if (serverError != null)
                        Padding(
                          padding:
                          const EdgeInsets.only(top: 8, left: 4, right: 4),
                          child: Align(
                            alignment: isArabicValue
                                ? Alignment.centerRight
                                : Alignment.centerLeft,
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
                        : () {
                      dialogClosed = true;
                      Navigator.of(dialogContext).pop();
                    },
                    child: Text(isArabicValue ? 'إلغاء' : 'Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: submitting
                        ? null
                        : () => submitName(dialogSetState, dialogContext),
                    child: submitting
                        ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                        : Text(isArabicValue ? 'حفظ' : 'Save'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      dialogClosed = true;
      nameController.dispose();
    });
  }

  Future<void> _updateUserName(String name) async {
    final trimmedName = name.trim();
    final user = _firebaseAuth.currentUser;

    if (user == null) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    final firstName = trimmedName.split(RegExp(r'\s+')).first;

    await user.updateDisplayName(trimmedName);

    await _firestore.collection('users').doc(user.uid).set(
      {
        'displayName': trimmedName,
        'firstName': firstName,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _changeCurrentUserPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _firebaseAuth.currentUser;
    final email = user?.email;

    if (user == null || email == null || email.trim().isEmpty) {
      throw FirebaseAuthException(code: 'no-current-user');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword,
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword);
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
    bool dialogClosed = false;

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
                      : () {
                    dialogClosed = true;
                    Navigator.of(dialogContext).pop();
                  },
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
                      await _changeCurrentUserPassword(
                        currentPassword: currentController.text,
                        newPassword: newController.text,
                      );
                      if (!mounted || dialogClosed) return;
                      dialogClosed = true;
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
                      if (!mounted || dialogClosed) return;
                      switch (e.code) {
                        case 'wrong-password':
                        case 'invalid-credential':
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
                      if (!mounted || dialogClosed) return;
                      serverError = isArabicValue
                          ? 'فشل تحديث كلمة المرور'
                          : 'Failed to update password';
                    } finally {
                      if (mounted && !dialogClosed) {
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
    ).whenComplete(() {
      dialogClosed = true;
      currentController.dispose();
      newController.dispose();
      confirmController.dispose();
    });
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
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
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
