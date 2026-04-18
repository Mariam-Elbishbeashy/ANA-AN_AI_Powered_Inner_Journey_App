import 'package:firebase_auth/firebase_auth.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/core/localization/app_language_provider.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/features/admin/presentation/screens/admin_collection_screen.dart';
import 'package:ana_ifs_app/features/onboarding/presentation/screens/welcome_screen.dart';
import 'package:ana_ifs_app/core/widgets/shared_widgets.dart';
import 'package:ana_ifs_app/features/profile/presentation/screens/profile_screen.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/initial_motivation_screen.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/admin/presentation/screens/admin_inner_characters_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final TextEditingController _emailController = TextEditingController();
  bool _checkingAccess = true;
  bool _isAdmin = false;
  bool _loadingStats = true;
  bool _updatingAdmin = false;
  bool _loadingProfile = true;
  int _innerCharactersCount = 0;
  String? _firstName;
  String? _lastName;
  String? _birthdate;
  Map<String, int> _stats = const {
    'users': 0,
    'questions': 0,
    'answers': 0,
    'characters': 0,
    'admins': 0,
    'completedQuestionnaire': 0,
  };

  @override
  void initState() {
    super.initState();
    _loadAccess();
    _loadInnerCharactersCount();
  }

  Future<void> _loadAccess() async {
    final isAdmin = await _firestoreService.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = isAdmin;
      _checkingAccess = false;
    });
    if (isAdmin) {
      await _loadStats();
      await _loadProfile();
    }
  }

  Future<void> _loadStats() async {
    setState(() => _loadingStats = true);
    final stats = await _firestoreService.getAdminOverviewCounts();
    if (!mounted) return;
    setState(() {
      _stats = stats;
      _loadingStats = false;
    });
  }

  Future<void> _loadInnerCharactersCount() async {
    try {
      final raw = await rootBundle
          .loadString('assets/data/inner_characters_data.json');
      final decoded = jsonDecode(raw);
      final count = decoded is List ? decoded.length : 0;
      if (!mounted) return;
      setState(() => _innerCharactersCount = count > 18 ? 18 : count);
    } catch (_) {
      if (!mounted) return;
      setState(() => _innerCharactersCount = 18);
    }
  }

  Future<void> _loadProfile() async {
    setState(() => _loadingProfile = true);
    final profile = await _firestoreService.getCurrentUserProfile();
    if (!mounted) return;
    setState(() {
      _firstName = profile['firstName']?.toString();
      _lastName = profile['lastName']?.toString();
      _birthdate = profile['birthdate']?.toString();
      _loadingProfile = false;
    });
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AnaWelcomeScreen()),
      (route) => false,
    );
  }

  Future<void> _retakeQuestionnaire() async {
    await _firestoreService.clearQuestionnaireData();
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
    );
  }

  Future<void> _switchLanguage() async {
    final provider = context.read<AppLanguageProvider>();
    await provider.toggleLanguage();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(
            context,
            'Language updated',
            'تم تغيير اللغة',
          ),
        ),
      ),
    );
  }

  String _getFriendlyName(User? user) {
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      final beforeAt = email.split('@').first;
      if (beforeAt.isNotEmpty) return beforeAt;
    }
    return 'there';
  }

  Future<void> _setAdminByEmail(bool isAdmin) async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      _showSnack(
        tr(context, 'Enter an email address first.', 'أدخل البريد الإلكتروني أولاً.'),
      );
      return;
    }
    setState(() => _updatingAdmin = true);
    try {
      await _firestoreService.setAdminByEmail(email, isAdmin);
      if (!mounted) return;
      _showSnack(
        isAdmin
            ? tr(context, 'Admin granted successfully.', 'تم منح صلاحية الإدارة.')
            : tr(context, 'Admin removed successfully.', 'تم إزالة صلاحية الإدارة.'),
      );
      _emailController.clear();
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        tr(context, 'Failed to update admin user.', 'فشل تحديث صلاحية الإدارة.'),
      );
    } finally {
      if (mounted) setState(() => _updatingAdmin = false);
    }
  }

  Future<void> _toggleSelfAdmin(bool nextValue) async {
    setState(() => _updatingAdmin = true);
    try {
      await _firestoreService.setCurrentUserAdmin(nextValue);
      if (!mounted) return;
      setState(() => _isAdmin = nextValue);
      _showSnack(
        nextValue
            ? tr(context, 'You are now an admin.', 'أنت الآن مسؤول.')
            : tr(context, 'Admin role removed.', 'تمت إزالة صلاحية الإدارة.'),
      );
    } catch (e) {
      if (!mounted) return;
      _showSnack(
        tr(context, 'Failed to update your role.', 'فشل تحديث صلاحيتك.'),
      );
    } finally {
      if (mounted) setState(() => _updatingAdmin = false);
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openScreen(Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  void _openUserCharacters(String userId, Map<String, dynamic> data) {
    final displayName = data['firstName']?.toString().trim();
    final email = data['email']?.toString() ?? userId;
    final label = tr(
      context,
      'Characters for',
      'شخصيات',
      listen: false,
    );
    final title = (displayName != null && displayName.isNotEmpty)
        ? '$label $displayName'
        : '$label $email';
    _openScreen(
      AdminCollectionScreen(
        title: title,
        collection: _firestoreService.userCharactersCollection
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        ),
        listQuery: _firestoreService.userCharactersCollection
            .where('userId', isEqualTo: userId)
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        ),
        type: AdminCollectionType.characters,
        summaryBuilder: _characterSummary,
        emptyMessage: tr(
          context,
          'No characters yet.',
          'لا توجد شخصيات بعد.',
          listen: false,
        ),
      ),
    );
  }

  void _openUserAnswers(String userId, Map<String, dynamic> data) {
    final displayName = data['firstName']?.toString().trim();
    final email = data['email']?.toString() ?? userId;
    final label = tr(
      context,
      'Answers for',
      'إجابات',
      listen: false,
    );
    final title = (displayName != null && displayName.isNotEmpty)
        ? '$label $displayName'
        : '$label $email';
    _openScreen(
      AdminCollectionScreen(
        title: title,
        collection: _firestoreService.userAnswersCollection
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        ),
        listQuery: _firestoreService.userAnswersCollection
            .where('userId', isEqualTo: userId)
            .orderBy('questionNumber')
            .withConverter<Map<String, dynamic>>(
          fromFirestore: (snap, _) => snap.data() ?? {},
          toFirestore: (data, _) => data,
        ),
        type: AdminCollectionType.answers,
        summaryBuilder: _answerSummary,
        emptyMessage: tr(
          context,
          'No answers yet.',
          'لا توجد إجابات بعد.',
          listen: false,
        ),
      ),
    );
  }


  String _userSummary(Map<String, dynamic> data, String docId) {
    final email = data['email']?.toString() ?? docId;
    final first = data['firstName']?.toString().trim() ?? '';
    final last = data['lastName']?.toString().trim() ?? '';
    final name = [first, last].where((part) => part.isNotEmpty).join(' ');
    final isAdmin = data['isAdmin'] == true;
    final role = isAdmin ? tr(context, 'Admin', 'مسؤول') : tr(context, 'User', 'مستخدم');
    if (name.isEmpty) return '$email • $role';
    return '$name • $email • $role';
  }

  String _questionSummary(Map<String, dynamic> data, String docId) {
    final number = data['questionNumber']?.toString() ?? docId;
    final lang = data['language']?.toString() ?? 'en';
    return 'Q$number • $lang';
  }

  String _answerSummary(Map<String, dynamic> data, String docId) {
    final userId = data['userId']?.toString() ?? 'unknown';
    final number = data['questionNumber']?.toString() ?? '?';
    return 'User $userId • Q$number';
  }

  String _characterSummary(Map<String, dynamic> data, String docId) {
    final name = data['displayName']?.toString() ??
        data['characterName']?.toString() ??
        docId;
    final userId = data['userId']?.toString();
    final rank = data['rank']?.toString();
    final pieces = <String>[name];
    if (rank != null) pieces.add('#$rank');
    if (userId != null) pieces.add(userId);
    return pieces.join(' • ');
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = _getFriendlyName(user);

    if (_checkingAccess) {
      return const Scaffold(
        backgroundColor: Color(0xFFF9F6FF),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
        ),
      );
    }

    if (!_isAdmin) {
      return Scaffold(
        backgroundColor: const Color(0xFFF9F6FF),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF6A5CFF)),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE5DEFF)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_rounded,
                    color: Color(0xFF8E7CFF),
                    size: 44,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    tr(context, 'Admin access required', 'يتطلب صلاحية الإدارة'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'Ask an admin to grant you access.',
                      'اطلب من مسؤول منحك الصلاحية.',
                    ),
                    style: const TextStyle(color: Color(0xFF7A6A5A)),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          tr(context, 'Admin Dashboard', 'لوحة الإدارة'),
          style: const TextStyle(
            color: Color(0xFF2A1E3B),
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded, color: Color(0xFF6A5CFF)),
            onPressed: () {
              showModalBottomSheet(
                context: context,
                builder: (context) => SettingsBottomSheet(
                  onRetakeQuestionnaire: _retakeQuestionnaire,
                  onSwitchLanguage: _switchLanguage,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.person_rounded, color: Color(0xFF6A5CFF)),
            onPressed: () {
              final user = FirebaseAuth.instance.currentUser;
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    user: user,
                    onLogout: _logout,
                    initialUserCharacters: const [],
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _HeaderCard(name: name),
            const SizedBox(height: 20),
            _SectionTitle(
              title: tr(context, 'App Overview', 'نظرة عامة'),
              action: TextButton(
                onPressed: _loadingStats ? null : _loadStats,
                child: Text(tr(context, 'Refresh', 'تحديث')),
              ),
            ),
            const SizedBox(height: 12),
            _loadingStats
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF8E7CFF)),
                  )
                : Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _StatCard(
                        icon: Icons.person_rounded,
                        label: tr(context, 'Users', 'المستخدمون'),
                        value: _stats['users'] ?? 0,
                        onTap: () => _openScreen(
                          AdminCollectionScreen(
                            title: tr(
                              context,
                              'Users',
                              'المستخدمون',
                              listen: false,
                            ),
                            collection: _firestoreService.usersCollection
                                .withConverter<Map<String, dynamic>>(
                              fromFirestore: (snap, _) =>
                                  snap.data() ?? {},
                              toFirestore: (data, _) => data,
                            ),
                            type: AdminCollectionType.users,
                            summaryBuilder: _userSummary,
                            onUserTap: _openUserCharacters,
                            onUserAnswersTap: _openUserAnswers,
                          ),
                        ),
                      ),
                      _StatCard(
                        icon: Icons.help_center_rounded,
                        label: tr(context, 'Questions', 'الأسئلة'),
                        value: _stats['questions'] ?? 0,
                        onTap: () => _openScreen(
                          AdminCollectionScreen(
                            title: tr(
                              context,
                              'Questions',
                              'الأسئلة',
                              listen: false,
                            ),
                            collection: _firestoreService.questionsCollection
                                .withConverter<Map<String, dynamic>>(
                              fromFirestore: (snap, _) =>
                                  snap.data() ?? {},
                              toFirestore: (data, _) => data,
                            ),
                            type: AdminCollectionType.questions,
                            summaryBuilder: _questionSummary,
                          ),
                        ),
                      ),
                      _StatCard(
                        icon: Icons.groups_rounded,
                        label:
                            tr(context, 'User Characters', 'شخصيات المستخدمين'),
                        value: _stats['characters'] ?? 0,
                        onTap: () => _openScreen(
                          AdminCollectionScreen(
                            title: tr(
                              context,
                              'User Characters',
                              'شخصيات المستخدمين',
                              listen: false,
                            ),
                            collection: _firestoreService.userCharactersCollection
                                .withConverter<Map<String, dynamic>>(
                              fromFirestore: (snap, _) =>
                                  snap.data() ?? {},
                              toFirestore: (data, _) => data,
                            ),
                            type: AdminCollectionType.characters,
                            summaryBuilder: _characterSummary,
                          ),
                        ),
                      ),
                      _StatCard(
                        icon: Icons.psychology_rounded,
                        label: tr(
                          context,
                          'Inner Characters',
                          'الشخصيات الداخلية',
                        ),
                        value: _innerCharactersCount,
                        onTap: () =>
                            _openScreen(const AdminInnerCharactersScreen()),
                      ),
                      _StatCard(
                        icon: Icons.admin_panel_settings_rounded,
                        label: tr(context, 'Admins', 'المسؤولون'),
                        value: _stats['admins'] ?? 0,
                        onTap: () => _openScreen(
                          AdminCollectionScreen(
                            title: tr(
                              context,
                              'Admins',
                              'المسؤولون',
                              listen: false,
                            ),
                            collection: _firestoreService.usersCollection
                                .withConverter<Map<String, dynamic>>(
                              fromFirestore: (snap, _) =>
                                  snap.data() ?? {},
                              toFirestore: (data, _) => data,
                            ),
                            listQuery: _firestoreService.usersCollection
                                .where('isAdmin', isEqualTo: true)
                                .withConverter<Map<String, dynamic>>(
                                  fromFirestore: (snap, _) =>
                                      snap.data() ?? {},
                                  toFirestore: (data, _) => data,
                                ),
                            type: AdminCollectionType.users,
                            summaryBuilder: _userSummary,
                          ),
                        ),
                      ),
                      _StatCard(
                        icon: Icons.check_circle_rounded,
                        label:
                            tr(context, 'Completed Questionnaire', 'أكملوا الاستبيان'),
                        value: _stats['completedQuestionnaire'] ?? 0,
                        onTap: () => _openScreen(
                          AdminCollectionScreen(
                            title: tr(
                              context,
                              'Users',
                              'المستخدمون',
                              listen: false,
                            ),
                            collection: _firestoreService.usersCollection
                                .withConverter<Map<String, dynamic>>(
                              fromFirestore: (snap, _) =>
                                  snap.data() ?? {},
                              toFirestore: (data, _) => data,
                            ),
                            listQuery: _firestoreService.usersCollection
                                .where('hasCompletedQuestionnaire',
                                    isEqualTo: true)
                                .withConverter<Map<String, dynamic>>(
                                  fromFirestore: (snap, _) =>
                                      snap.data() ?? {},
                                  toFirestore: (data, _) => data,
                                ),
                            type: AdminCollectionType.users,
                            summaryBuilder: _userSummary,
                          ),
                        ),
                      ),
                    ],
                  ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: tr(context, 'Admin Tools', 'أدوات الإدارة'),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(context, 'Profile data', 'بيانات الملف الشخصي'),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _loadingProfile ? null : _loadProfile,
                        icon: const Icon(Icons.refresh_rounded),
                        color: const Color(0xFF8E7CFF),
                        tooltip: tr(context, 'Refresh', 'تحديث'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ProfileRow(
                    label: tr(context, 'First name', 'الاسم الأول'),
                    value: _firstName ?? tr(context, 'Not set', 'غير محدد'),
                    isLoading: _loadingProfile,
                  ),
                  _ProfileRow(
                    label: tr(context, 'Last name', 'اسم العائلة'),
                    value: (_lastName == null || _lastName!.trim().isEmpty)
                        ? tr(context, 'Not set', 'غير محدد')
                        : _lastName!,
                    isLoading: _loadingProfile,
                  ),
                  _ProfileRow(
                    label: tr(context, 'Birthdate', 'تاريخ الميلاد'),
                    value: (_birthdate == null || _birthdate!.trim().isEmpty)
                        ? tr(context, 'Not set', 'غير محدد')
                        : _birthdate!,
                    isLoading: _loadingProfile,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: _cardDecoration(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(context, 'Your admin status', 'صلاحيتك الحالية'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tr(
                            context,
                            'Toggle to grant or remove admin access for this account.',
                            'فعّل أو ألغِ صلاحية الإدارة لهذا الحساب.',
                          ),
                          style: const TextStyle(
                            color: Color(0xFF7A6A5A),
                            fontSize: 12,
                          ),
                        ),
                      ),
                      Switch(
                        value: _isAdmin,
                        onChanged: _updatingAdmin ? null : _toggleSelfAdmin,
                        activeColor: const Color(0xFF8E7CFF),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: Color(0xFFE5DEFF)),
                  Text(
                    tr(context, 'Grant admin by email', 'منح صلاحية الإدارة'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    tr(
                      context,
                      'The user must have signed up at least once.',
                      'يجب أن يكون المستخدم قد سجل مرة واحدة على الأقل.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF7A6A5A)),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: tr(context, 'user@email.com', 'user@email.com'),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5DEFF)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFFE5DEFF)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(color: Color(0xFF8E7CFF)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _updatingAdmin
                              ? null
                              : () => _setAdminByEmail(true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF8E7CFF),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(tr(context, 'Grant', 'منح')),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _updatingAdmin
                              ? null
                              : () => _setAdminByEmail(false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF6A5CFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: const BorderSide(color: Color(0xFF8E7CFF)),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(tr(context, 'Remove', 'إزالة')),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final String name;

  const _HeaderCard({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF8E7CFF), Color(0xFFB79CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'Welcome, $name', 'مرحباً، $name'),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr(
              context,
              'Manage features, content, and access in one place.',
              'تحكم في الميزات والمحتوى والصلاحيات من مكان واحد.',
            ),
            style: const TextStyle(
              color: Colors.white,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const _SectionTitle({required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2A1E3B),
            ),
          ),
        ),
        if (action != null) action!,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final int value;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: (MediaQuery.of(context).size.width - 52) / 2,
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF8E7CFF).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: const Color(0xFF8E7CFF), size: 18),
            ),
            const SizedBox(height: 10),
            Text(
              value.toString(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF2A1E3B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A6A5A)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLoading;

  const _ProfileRow({
    required this.label,
    required this.value,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF7A6A5A),
              ),
            ),
          ),
          if (isLoading)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF8E7CFF),
              ),
            )
          else
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: Color(0xFF2A1E3B),
              ),
            ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    border: Border.all(color: const Color(0xFFE5DEFF)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}
