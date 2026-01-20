import 'package:ana_ifs_app/screens/questionnaire/initial_motivation_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_character_model.dart';
import '../services/firestore_service.dart';
import '../l10n/app_strings.dart';

class ProfileScreen extends StatefulWidget {
  final User? user;
  final VoidCallback onLogout;
  final List<UserCharacter> initialUserCharacters;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onLogout,
    required this.initialUserCharacters,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late List<UserCharacter> _userCharacters;
  bool _isLoading = false;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _userCharacters = widget.initialUserCharacters;
    // Refresh characters if needed
    if (_userCharacters.isEmpty) {
      _refreshCharacters();
    }
  }

  Future<void> _refreshCharacters() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final characters = await _firestoreService.getUserCharacters();
      setState(() {
        _userCharacters = characters;
        _isLoading = false;
      });
    } catch (e) {
      print('Error refreshing characters: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getFormattedName() {
    if (widget.user?.displayName != null &&
        widget.user!.displayName!.isNotEmpty) {
      return widget.user!.displayName!;
    }
    if (widget.user?.email != null) {
      final email = widget.user!.email!;
      final namePart = email.split('@').first;
      // Capitalize first letter
      return namePart[0].toUpperCase() + namePart.substring(1);
    }
    return 'User';
  }

  String _getDaysActive() {
    if (widget.user?.metadata?.creationTime != null) {
      final createdDate = widget.user!.metadata!.creationTime!;
      final now = DateTime.now();
      final difference = now.difference(createdDate);
      return '${difference.inDays}';
    }
    return '7'; // Fallback
  }

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            expandedHeight: 240,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF8E7CFF).withOpacity(0.8),
                      const Color(0xFFF9F6FF),
                    ],
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 8),
                      CircleAvatar(
                        radius: 48,
                        backgroundColor: Colors.white,
                        child: widget.user?.photoURL != null
                            ? ClipOval(
                          child: Image.network(
                            widget.user!.photoURL!,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildDefaultAvatar();
                            },
                          ),
                        )
                            : _buildDefaultAvatar(),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _getFormattedName(),
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      if (widget.user?.email != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            widget.user!.email!,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      // Language indicator
                    if (true)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                            isArabicValue ? 'العربية' : 'English',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Stats
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
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            value: _userCharacters.length.toString(),
                            label: isArabicValue ? 'شخصيات' : 'Characters',
                            icon: Icons.psychology_rounded,
                          ),
                          _StatItem(
                            value: '13',
                            label: isArabicValue ? 'أسئلة' : 'Questions',
                            icon: Icons.help_outline_rounded,
                          ),
                          _StatItem(
                            value: _getDaysActive(),
                            label: isArabicValue ? 'أيام نشاط' : 'Days Active',
                            icon: Icons.calendar_today_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // My Characters Section
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isArabicValue ? 'شخصياتي الداخلية' : 'My Inner Characters',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF2A1E3B),
                          ),
                        ),
                        if (_isLoading)
                          const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Color(0xFF8E7CFF),
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: const Icon(
                              Icons.refresh_rounded,
                              size: 20,
                              color: Color(0xFF8E7CFF),
                            ),
                            onPressed: _refreshCharacters,
                            tooltip: isArabicValue ? 'تحديث' : 'Refresh',
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_userCharacters.isEmpty && !_isLoading)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECF7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.psychology_outlined,
                              size: 40,
                              color: Color(0xFF8E7CFF),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              isArabicValue
                                  ? 'لم يتم تحديد شخصيات بعد'
                                  : 'No characters identified yet',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2A1E3B),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isArabicValue
                                  ? 'أكمل الاستبيان لاكتشاف شخصياتك الداخلية'
                                  : 'Complete the questionnaire to discover your inner characters',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Color(0xFF7A6A5A)),
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                // Navigate to questionnaire
                                Navigator.of(context).pushReplacement(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                    const InitialMotivationScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF8E7CFF),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                isArabicValue
                                    ? 'بدء الاستبيان'
                                    : 'Take Questionnaire',
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_isLoading)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECF7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF8E7CFF),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: _userCharacters.map((character) {
                          return _CharacterCard(character: character);
                        }).toList(),
                      ),

                    const SizedBox(height: 30),

                    // Account Settings
                    Text(
                      isArabicValue ? 'إعدادات الحساب' : 'Account Settings',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SettingsItem(
                      icon: Icons.notifications_rounded,
                      title: isArabicValue ? 'الإشعارات' : 'Notifications',
                      subtitle: isArabicValue
                          ? 'إدارة تفضيلات الإشعارات الخاصة بك'
                          : 'Manage your notification preferences',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.privacy_tip_rounded,
                      title: isArabicValue
                          ? 'الخصوصية والأمان'
                          : 'Privacy & Security',
                      subtitle: isArabicValue
                          ? 'التحكم في بياناتك وإعدادات الأمان'
                          : 'Control your data and security settings',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.help_rounded,
                      title: isArabicValue ? 'المساعدة والدعم' : 'Help & Support',
                      subtitle: isArabicValue
                          ? 'احصل على المساعدة أو اتصل بالدعم'
                          : 'Get help or contact support',
                      onTap: () {},
                    ),
                    _SettingsItem(
                      icon: Icons.info_rounded,
                      title: isArabicValue ? 'عن تطبيق ANA' : 'About ANA',
                      subtitle: isArabicValue
                          ? 'تعرف على المزيد حول التطبيق'
                          : 'Learn more about the app',
                      onTap: () {},
                    ),

                    const SizedBox(height: 30),

                    // Retake Questionnaire Button
                    if (_userCharacters.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => AlertDialog(
                                title: Text(
                                  isArabicValue
                                      ? 'إعادة الاستبيان'
                                      : 'Retake Questionnaire',
                                ),
                                content: Text(
                                  isArabicValue
                                      ? 'هل تريد إعادة الاستبيان؟ سيتم حذف النتائج الحالية.'
                                      : 'Do you want to retake the questionnaire? Your current results will be deleted.',
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: Text(isArabicValue ? 'إلغاء' : 'Cancel'),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      Navigator.pop(context);
                                      // Clear existing data and navigate to questionnaire
                                      try {
                                        await _firestoreService
                                            .clearQuestionnaireData();
                                        Navigator.of(context).pushReplacement(
                                          MaterialPageRoute(
                                            builder: (_) =>
                                            const InitialMotivationScreen(),
                                          ),
                                        );
                                      } catch (e) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              isArabicValue
                                                  ? 'خطأ في إعادة الاستبيان'
                                                  : 'Error retaking questionnaire',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    },
                                    child:
                                        Text(isArabicValue ? 'إعادة' : 'Retake'),
                                  ),
                                ],
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFF0ECF7),
                            foregroundColor: const Color(0xFF8E7CFF),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.replay_rounded, size: 20),
                              const SizedBox(width: 12),
                              Text(
                                isArabicValue
                                    ? 'إعادة الاستبيان'
                                    : 'Retake Questionnaire',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: Text(
                                isArabicValue ? 'تسجيل الخروج' : 'Logout',
                              ),
                              content: Text(
                                isArabicValue
                                    ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                                    : 'Are you sure you want to logout?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child:
                                      Text(isArabicValue ? 'إلغاء' : 'Cancel'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context);
                                    widget.onLogout();
                                  },
                                  child: Text(
                                    isArabicValue ? 'تسجيل الخروج' : 'Logout',
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.red.withOpacity(0.2),
                            ),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.logout_rounded, size: 20),
                            const SizedBox(width: 12),
                            Text(
                              isArabicValue ? 'تسجيل الخروج' : 'Logout',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Center(
      child: Text(
        _getFormattedName().substring(0, 1).toUpperCase(),
        style: const TextStyle(
          fontSize: 36,
          fontWeight: FontWeight.w800,
          color: Color(0xFF8E7CFF),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatItem({
    required this.value,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF8E7CFF).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF8E7CFF), size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Color(0xFF2A1E3B),
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF7A6A5A), fontSize: 12),
        ),
      ],
    );
  }
}

class _CharacterCard extends StatelessWidget {
  final UserCharacter character;

  const _CharacterCard({required this.character});

  String _getImagePathForCharacter(String characterName) {
    final imageMap = {
      'Inner Critic': 'inner_critic.png',
      'People Pleaser': 'people_pleaser.png',
      'Lonely Part': 'lonely.png',
      'Jealous Part': 'jealous.png',
      'Ashamed Part': 'ashamed.png',
      'Workaholic': 'workaholic.png',
      'Perfectionist': 'perfictionist.png',
      'Procrastinator': 'procrastinator.png',
      'Excessive Gamer': 'excessive_gamer.png',
      'Confused Part': 'confused.png',
      'Dependent Part': 'dependant.png',
      'Fearful Part': 'fearful.png',
      'Neglected Part': 'neglected.png',
      'Overeater': 'overeater_binger.png',
      'Binger': 'overeater_binger.png',
      'Overeater/Binger': 'overeater_binger.png',
      'Overwhelmed Part': 'overwhelmed.png',
      'Stoic Part': 'stoic.png',
      'Wounded Child': 'wounded_child.png',
      'Controller': 'controller.png',
      'Controller Part': 'controller.png',
    };

    if (imageMap.containsKey(characterName)) {
      return 'assets/images/${imageMap[characterName]}';
    }

    final lowerName = characterName.toLowerCase();
    for (final entry in imageMap.entries) {
      if (lowerName.contains(entry.key.toLowerCase()) ||
          entry.key.toLowerCase().contains(lowerName)) {
        return 'assets/images/${entry.value}';
      }
    }

    return 'assets/images/inner_critic.png';
  }

  Color _getArchetypeColor(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return const Color(0xFF4A6FA5);
      case 'firefighter':
        return const Color(0xFFD9534F);
      case 'exile':
        return const Color(0xFF5CB85C);
      default:
        return const Color(0xFF8E7CFF);
    }
  }

  String _getLocalizedArchetype(BuildContext context, String archetype) {
    // Add language detection logic if needed
    switch (archetype.toLowerCase()) {
      case 'manager':
        return tr(context, 'MANAGER', 'مدير');
      case 'firefighter':
        return tr(context, 'FIREFIGHTER', 'إطفائي');
      case 'exile':
        return tr(context, 'EXILE', 'منفى');
      default:
        return archetype.toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getArchetypeColor(character.archetype);
    final imagePath = _getImagePathForCharacter(character.characterName);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundColor: color.withOpacity(0.1),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: ClipOval(
                child: Image.asset(
                  imagePath,
                  width: 50,
                  height: 50,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  character.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2A1E3B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Confidence: ${(character.confidence * 100).toStringAsFixed(1)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: const Color(0xFF7A6A5A),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '#${character.rank}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _getLocalizedArchetype(context, character.archetype),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getCharacterIcon(String archetype) {
    switch (archetype.toLowerCase()) {
      case 'manager':
        return Icons.gavel_rounded;
      case 'firefighter':
        return Icons.local_fire_department_rounded;
      case 'exile':
        return Icons.self_improvement_rounded;
      default:
        return Icons.psychology_rounded;
    }
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: const Color(0xFF8E7CFF).withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: const Color(0xFF8E7CFF), size: 20),
      ),
      title: Text(
        title,
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
    );
  }
}
