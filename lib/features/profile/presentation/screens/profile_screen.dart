import 'dart:async';
import 'dart:convert';

import 'package:ana_ifs_app/features/profile/presentation/screens/AboutANAScreen.dart';
import 'package:ana_ifs_app/features/profile/presentation/screens/HelpSupportScreen.dart';
import 'package:ana_ifs_app/features/profile/presentation/screens/NotificationsScreen.dart';
import 'package:ana_ifs_app/features/profile/presentation/screens/PrivacySecurityScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/core/localization/app_language_provider.dart';
import 'package:ana_ifs_app/features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/initial_motivation_screen.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';

import '../../../questionnaire/presentation/state/questionnaire_provider.dart';

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
  bool _isRetaking = false;
  bool _hasQuestionnaireResults = false;
  int _questionCount = 0;
  String? _profilePhotoUrl;
  String? _profilePhotoPath;
  bool _isProfilePhotoSaving = false;

  final FirestoreService _firestoreService = FirestoreService();
  final ImagePicker _imagePicker = ImagePicker();
  StreamSubscription<List<UserCharacter>>? _charactersSubscription;
  StreamSubscription<int>? _questionCountSubscription;
  StreamSubscription<Map<String, dynamic>>? _profileSubscription;

  @override
  void initState() {
    super.initState();

    // Use already available data first, so opening Profile is instant.
    final cachedCharacters = _firestoreService.getCachedUserCharacters();
    final initialCharacters = cachedCharacters ?? widget.initialUserCharacters;
    final cachedQuestionCount =
    _firestoreService.getCachedUserQuestionnaireQuestionCount();

    _setCharactersFromList(initialCharacters, notify: false);
    if (cachedQuestionCount != null) {
      _questionCount = cachedQuestionCount;
    }
    _profilePhotoUrl = _profilePhotoUrlFromValue(widget.user?.photoURL);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startRealtimeCacheUpdates();
      _startProfilePhotoListener();
      _updateLastActivitySilently();
    });
  }

  void _setCharactersFromList(
      List<UserCharacter> allCharacters, {
        bool notify = true,
      }) {
    final activeCharacters = allCharacters
        .where((c) => c.currentState.toLowerCase() == 'active')
        .toList();

    if (!notify) {
      _hasQuestionnaireResults = allCharacters.isNotEmpty;
      _userCharacters = activeCharacters;
      return;
    }

    if (!mounted) return;
    setState(() {
      _hasQuestionnaireResults = allCharacters.isNotEmpty;
      _userCharacters = activeCharacters;
    });
  }

  Future<void> _startRealtimeCacheUpdates() async {
    await _charactersSubscription?.cancel();
    _charactersSubscription = _firestoreService.watchUserCharacters().listen(
          (characters) {
        _setCharactersFromList(characters);
      },
      onError: (error) {
        print('👤 ProfileScreen: character watch error: $error');
      },
    );

    try {
      final selectedLanguage = await _firestoreService.getUserLanguage();

      final cachedQuestionCount =
      _firestoreService.getCachedUserQuestionnaireQuestionCount();

      if (cachedQuestionCount != null && mounted) {
        setState(() {
          _questionCount = cachedQuestionCount;
        });
      } else {
        final count = await _firestoreService.getUserQuestionnaireQuestionCount(
          language: selectedLanguage,
          forceRefresh: false,
        );

        if (mounted) {
          setState(() {
            _questionCount = count;
          });
        }
      }

      await _questionCountSubscription?.cancel();
      _questionCountSubscription = _firestoreService
          .watchUserQuestionnaireQuestionCount(language: selectedLanguage)
          .listen(
            (count) {
          if (!mounted) return;
          setState(() {
            _questionCount = count;
          });
        },
        onError: (error) {
          print('👤 ProfileScreen: saved question count watch error: $error');
        },
      );
    } catch (e) {
      print('👤 ProfileScreen: Error starting cached updates: $e');
    }
  }

  Future<void> _updateLastActivitySilently() async {
    try {
      await _firestoreService.updateUserLastActivity();
    } catch (e) {
      print('👤 ProfileScreen: last activity update skipped: $e');
    }
  }

  Future<void> _loadQuestionCount({String? language}) async {
    try {
      final selectedLanguage =
          language ?? await _firestoreService.getUserLanguage();

      final cachedQuestionCount =
      _firestoreService.getCachedUserQuestionnaireQuestionCount();

      if (cachedQuestionCount != null && mounted) {
        setState(() {
          _questionCount = cachedQuestionCount;
        });
      } else {
        final count = await _firestoreService.getUserQuestionnaireQuestionCount(
          language: selectedLanguage,
          forceRefresh: false,
        );

        if (!mounted) return;
        setState(() {
          _questionCount = count;
        });
      }

      await _questionCountSubscription?.cancel();
      _questionCountSubscription = _firestoreService
          .watchUserQuestionnaireQuestionCount(language: selectedLanguage)
          .listen(
            (count) {
          if (!mounted) return;
          setState(() {
            _questionCount = count;
          });
        },
      );
    } catch (e) {
      print('👤 ProfileScreen: Error loading saved question count: $e');
    }
  }

  @override
  void dispose() {
    _charactersSubscription?.cancel();
    _questionCountSubscription?.cancel();
    _profileSubscription?.cancel();
    super.dispose();
  }


  String? _profilePhotoUrlFromValue(dynamic value) {
    final url = value?.toString().trim();
    return url == null || url.isEmpty ? null : url;
  }

  String? _profilePhotoPathFromValue(dynamic value) {
    final path = value?.toString().trim();
    return path == null || path.isEmpty ? null : path;
  }

  void _startProfilePhotoListener() {
    _profileSubscription?.cancel();
    _profileSubscription = _firestoreService.watchCurrentUserProfile().listen(
          (profileData) {
        if (!mounted) return;

        setState(() {
          _profilePhotoUrl = _profilePhotoUrlFromValue(
            profileData['profilePhotoUrl'] ?? profileData['photoURL'],
          );
          _profilePhotoPath = _profilePhotoPathFromValue(
            profileData['profilePhotoPath'],
          );
        });
      },
      onError: (error) {
        print('👤 ProfileScreen: profile photo watch error: $error');
      },
    );
  }


  bool _isArabicWithoutListening() {
    try {
      return context.read<AppLanguageProvider>().isArabic;
    } catch (_) {
      return false;
    }
  }

  String _profilePhotoText(String english, String arabic) {
    return _isArabicWithoutListening() ? arabic : english;
  }

  Future<void> _handleProfilePhotoTap() async {
    if (_isProfilePhotoSaving) return;

    final isArabicValue = _isArabicWithoutListening();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Directionality(
          textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD0C6E8),
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    _profilePhotoText('Profile picture', 'صورة الملف الشخصي'),
                    textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _ProfilePhotoActionTile(
                    icon: Icons.photo_library_rounded,
                    title: _profilePhotoText('Choose a photo', 'اختار صورة'),
                    subtitle: _profilePhotoText('Save it and show it across the app', 'احفظها واعرضها في كل التطبيق'),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _pickAndSaveProfilePhoto();
                    },
                  ),
                  if (_profilePhotoUrl != null)
                    _ProfilePhotoActionTile(
                      icon: Icons.delete_outline_rounded,
                      title: _profilePhotoText('Remove photo', 'امسح الصورة'),
                      subtitle: _profilePhotoText('Return to the initial purple circle', 'ارجع للدائرة البنفسجي بحرف اسمك'),
                      isDestructive: true,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _removeProfilePhoto();
                      },
                    ),
                  _ProfilePhotoActionTile(
                    icon: Icons.close_rounded,
                    title: _profilePhotoText('Cancel', 'إلغاء'),
                    subtitle: _profilePhotoText('Keep current photo', 'خلي الصورة الحالية'),
                    onTap: () => Navigator.pop(sheetContext),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _mimeTypeForPickedImage(XFile pickedImage) {
    final name = pickedImage.name.toLowerCase();
    final path = pickedImage.path.toLowerCase();

    if (name.endsWith('.png') || path.endsWith('.png')) {
      return 'image/png';
    }
    if (name.endsWith('.webp') || path.endsWith('.webp')) {
      return 'image/webp';
    }
    return 'image/jpeg';
  }

  Future<void> _pickAndSaveProfilePhoto() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isProfilePhotoSaving) return;

    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600,
        maxHeight: 600,
        imageQuality: 72,
      );

      if (pickedImage == null) return;

      if (mounted) {
        setState(() {
          _isProfilePhotoSaving = true;
        });
      }

      final imageBytes = await pickedImage.readAsBytes();
      final mimeType = _mimeTypeForPickedImage(pickedImage);
      final photoDataUrl = 'data:$mimeType;base64,${base64Encode(imageBytes)}';

      // Firestore documents have a 1 MiB limit. Keep the selected photo small
      // so the profile document can stay the single real-time source for all pages.
      if (photoDataUrl.length > 850000) {
        throw Exception('Selected profile picture is too large after compression.');
      }

      await _firestoreService.updateCurrentUserProfilePhoto(
        profilePhotoUrl: photoDataUrl,
        profilePhotoPath: null,
      );

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = photoDataUrl;
        _profilePhotoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profilePhotoText('Profile picture updated', 'تم تحديث صورة الملف الشخصي'),
          ),
        ),
      );
    } catch (e) {
      print('👤 ProfileScreen: Error saving profile photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profilePhotoText('Could not update profile picture. Please choose a smaller image and try again.', 'ماقدرناش نحدّث صورة الملف الشخصي. اختار صورة أصغر وحاول تاني.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProfilePhotoSaving = false;
        });
      }
    }
  }

  Future<void> _removeProfilePhoto() async {
    if (_isProfilePhotoSaving) return;

    final oldPath = _profilePhotoPath;

    if (mounted) {
      setState(() {
        _isProfilePhotoSaving = true;
      });
    }

    try {
      await _firestoreService.removeCurrentUserProfilePhoto();

      if (!mounted) return;
      setState(() {
        _profilePhotoUrl = null;
        _profilePhotoPath = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profilePhotoText('Profile picture removed', 'تم مسح صورة الملف الشخصي'),
          ),
        ),
      );
    } catch (e) {
      print('👤 ProfileScreen: Error removing profile photo: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _profilePhotoText('Could not remove profile picture. Please try again.', 'ماقدرناش نمسح صورة الملف الشخصي. حاول تاني.'),
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProfilePhotoSaving = false;
        });
      }
    }
  }

  String _currentAppLanguage() {
    try {
      final appLanguage = context.read<AppLanguageProvider>().language;
      return appLanguage.trim().toLowerCase().startsWith('ar') ? 'ar' : 'en';
    } catch (e) {
      return isArabic(context) ? 'ar' : 'en';
    }
  }

  String _toArabicDigits(Object value) {
    var text = value.toString();
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishDigits.length; i++) {
      text = text.replaceAll(englishDigits[i], arabicDigits[i]);
    }

    return text;
  }

  String _localizedNumber(Object value) {
    return isArabic(context) ? _toArabicDigits(value) : value.toString();
  }

  Future<void> _handleRetakeQuestionnaire(bool isArabicValue) async {
    if (_isRetaking) return;

    setState(() {
      _isRetaking = true;
      _hasQuestionnaireResults = false;
      _userCharacters = [];
    });

    final appLanguage = _currentAppLanguage();

    QuestionnaireProvider? questionnaireProvider;
    try {
      questionnaireProvider = context.read<QuestionnaireProvider>();
    } catch (e) {
      print('QuestionnaireProvider not found before retake: $e');
    }

    try {
      // The app UI language is the source of truth. If Firestore still has
      // preferredLanguage='ar' while the app is currently English, this line
      // prevents the retaken questionnaire from being saved as Arabic.
      await _firestoreService.setUserLanguage(appLanguage);
      await questionnaireProvider?.syncLanguageFromApp(
        appLanguage,
        forceReload: false,
      );

      // Delete only the current answers/characters before opening the questionnaire.
      // This prevents old answers from appearing, but avoids waiting for slower
      // progress/history cleanup.
      await _firestoreService.clearQuestionnaireStartData(
        language: appLanguage,
      );
      questionnaireProvider?.clearAnswers();
    } catch (e) {
      print('Fast retake cleanup failed: $e');
    }

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
    );

    unawaited(() async {
      try {
        await questionnaireProvider?.resetForRetake(appLanguage: appLanguage);
        await _firestoreService.clearQuestionnaireProgressData();
      } catch (e) {
        print('Background retake cleanup failed: $e');
      }
    }());
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


  Future<void> _showLanguageDialog() async {
    final languageProvider = context.read<AppLanguageProvider>();
    final currentLanguage = languageProvider.language;
    final isArabicValue = languageProvider.isArabic;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        String selectedLanguage = currentLanguage;
        bool isSaving = false;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveLanguage(String language) async {
              if (isSaving) return;
              setSheetState(() {
                selectedLanguage = language;
                isSaving = true;
              });

              await languageProvider.setLanguage(language);
              await _firestoreService.setUserLanguage(language);
              try {
                await context.read<QuestionnaireProvider>().syncLanguageFromApp(
                  language,
                  forceReload: true,
                );
              } catch (e) {
                print('QuestionnaireProvider language sync skipped: $e');
              }
              await _loadQuestionCount(language: language);

              if (!mounted) return;
              Navigator.pop(sheetContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    language == 'ar'
                        ? 'تم تغيير اللغة إلى العربية'
                        : 'Language changed to English',
                  ),
                  backgroundColor: const Color(0xFF8E7CFF),
                  duration: const Duration(seconds: 2),
                ),
              );
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Directionality(
                textDirection:
                isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 48,
                        height: 5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD0C6E8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      isArabicValue ? 'اختيار اللغة' : 'Choose Language',
                      textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isArabicValue
                          ? 'سيتم تطبيق اللغة مباشرة على التطبيق.'
                          : 'The language will be applied immediately across the app.',
                      textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF7A6A5A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    _LanguageOption(
                      title: 'English',
                      subtitle: 'Use ANA in English',
                      selected: selectedLanguage == 'en',
                      isSaving: isSaving && selectedLanguage == 'en',
                      onTap: () => saveLanguage('en'),
                    ),
                    const SizedBox(height: 12),
                    _LanguageOption(
                      title: 'العربية',
                      subtitle: 'استخدم ANA باللغة العربية',
                      selected: selectedLanguage == 'ar',
                      isSaving: isSaving && selectedLanguage == 'ar',
                      onTap: () => saveLanguage('ar'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
                      const Color(0xFF8E7CFF).withValues(alpha: 0.8),
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
                      GestureDetector(
                        onTap: _handleProfilePhotoTap,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.white,
                              child: ClipOval(
                                child: _buildProfilePhotoImage(),
                              ),
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: const Color(0xFFE5DEFF),
                                    width: 2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: _isProfilePhotoSaving
                                    ? const Padding(
                                  padding: EdgeInsets.all(7),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Color(0xFF8E7CFF),
                                  ),
                                )
                                    : const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 16,
                                  color: Color(0xFF8E7CFF),
                                ),
                              ),
                            ),
                          ],
                        ),
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
                              color: Colors.white.withValues(alpha: 0.9),
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
                              color: Colors.white.withValues(alpha: 0.3),
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
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(
                            value: _localizedNumber(_userCharacters.length),
                            label: isArabicValue ? 'شخصيات نشطة' : 'Active Characters',
                            icon: Icons.psychology_rounded,
                          ),
                          _StatItem(
                            value: _localizedNumber(_questionCount),
                            label: isArabicValue ? 'أسئلة' : 'Questions',
                            icon: Icons.help_outline_rounded,
                          ),
                          _StatItem(
                            value: _localizedNumber(_getDaysActive()),
                            label: isArabicValue ? 'أيام نشاط' : 'Days Active',
                            icon: Icons.calendar_today_rounded,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // My Characters Section
                    Align(
                      alignment: isArabicValue
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        isArabicValue ? 'شخصياتي النشطة' : 'My Active Characters',
                        textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_userCharacters.isEmpty && !_isLoading)
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0ECF7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Directionality(
                          textDirection:
                          isArabicValue ? TextDirection.rtl : TextDirection.ltr,
                          child: Column(
                            crossAxisAlignment: isArabicValue
                                ? CrossAxisAlignment.end
                                : CrossAxisAlignment.center,
                            children: [
                              const Center(
                                child: Icon(
                                  Icons.psychology_outlined,
                                  size: 40,
                                  color: Color(0xFF8E7CFF),
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                isArabicValue
                                    ? 'لا توجد شخصيات نشطة'
                                    : 'No active characters',
                                textAlign:
                                isArabicValue ? TextAlign.right : TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2A1E3B),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                isArabicValue
                                    ? 'الشخصيات النشطة هي التي تؤثر حالياً على حياتك اليومية'
                                    : 'Active characters are the ones currently influencing your daily life',
                                textAlign:
                                isArabicValue ? TextAlign.right : TextAlign.center,
                                style: const TextStyle(color: Color(0xFF7A6A5A)),
                              ),
                              const SizedBox(height: 16),
                              Center(
                                child: ElevatedButton(
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
                              ),
                            ],
                          ),
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
                    Align(
                      alignment: isArabicValue
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Text(
                        isArabicValue ? 'إعدادات الحساب' : 'Account Settings',
                        textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF2A1E3B),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _SettingsItem(
                      icon: Icons.language_rounded,
                      title: isArabicValue ? 'اللغة' : 'Language',
                      subtitle: isArabicValue
                          ? 'تغيير لغة التطبيق'
                          : 'Change app language',
                      onTap: _showLanguageDialog,
                    ),

                    _SettingsItem(
                      icon: Icons.notifications_rounded,
                      title: isArabicValue ? 'الإشعارات' : 'Notifications',
                      subtitle: isArabicValue
                          ? 'إدارة تفضيلات الإشعارات الخاصة بك'
                          : 'Manage your notification preferences',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const NotificationsScreen(),
                          ),
                        );
                      },
                    ),

                    _SettingsItem(
                      icon: Icons.privacy_tip_rounded,
                      title: isArabicValue ? 'الخصوصية والأمان' : 'Privacy & Security',
                      subtitle: isArabicValue
                          ? 'التحكم في بياناتك وإعدادات الأمان'
                          : 'Control your data and security settings',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const PrivacySecurityScreen(),
                          ),
                        );
                      },
                    ),

                    _SettingsItem(
                      icon: Icons.help_rounded,
                      title: isArabicValue ? 'المساعدة والدعم' : 'Help & Support',
                      subtitle: isArabicValue
                          ? 'احصل على المساعدة أو اتصل بالدعم'
                          : 'Get help or contact support',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const HelpSupportScreen(),
                          ),
                        );
                      },
                    ),

                    _SettingsItem(
                      icon: Icons.info_rounded,
                      title: isArabicValue ? 'عن تطبيق ANA' : 'About ANA',
                      subtitle: isArabicValue
                          ? 'تعرف على المزيد حول التطبيق'
                          : 'Learn more about the app',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AboutANAScreen(),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 30),

                    // Retake Questionnaire Button
                    if (_hasQuestionnaireResults)
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) => Directionality(
                                textDirection: isArabicValue
                                    ? TextDirection.rtl
                                    : TextDirection.ltr,
                                child: AlertDialog(
                                  title: Text(
                                    isArabicValue
                                        ? 'إعادة الاستبيان'
                                        : 'Retake Questionnaire',
                                    textAlign: isArabicValue
                                        ? TextAlign.right
                                        : TextAlign.left,
                                  ),
                                  content: Text(
                                    isArabicValue
                                        ? 'إعادة الاستبيان ستقوم بحذف الشخصيات الحالية وإزالة تقدمك الحالي. هل تريد المتابعة؟'
                                        : 'Retaking the questionnaire will remove your current characters and clear your current progress. Do you want to continue?',
                                    textAlign: isArabicValue
                                        ? TextAlign.right
                                        : TextAlign.left,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child:
                                      Text(isArabicValue ? 'إلغاء' : 'Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: _isRetaking
                                          ? null
                                          : () async {
                                        Navigator.pop(context);
                                        await _handleRetakeQuestionnaire(
                                          isArabicValue,
                                        );
                                      },
                                      child: Text(
                                        _isRetaking
                                            ? (isArabicValue
                                            ? 'جاري الإعادة...'
                                            : 'Resetting...')
                                            : (isArabicValue ? 'إعادة' : 'Retake'),
                                      ),
                                    ),
                                  ],
                                ),
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
                          child: Directionality(
                            textDirection: isArabicValue
                                ? TextDirection.rtl
                                : TextDirection.ltr,
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
                      ),

                    // Logout Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => Directionality(
                              textDirection: isArabicValue
                                  ? TextDirection.rtl
                                  : TextDirection.ltr,
                              child: AlertDialog(
                                title: Text(
                                  isArabicValue ? 'تسجيل الخروج' : 'Logout',
                                  textAlign: isArabicValue
                                      ? TextAlign.right
                                      : TextAlign.left,
                                ),
                                content: Text(
                                  isArabicValue
                                      ? 'هل أنت متأكد أنك تريد تسجيل الخروج؟'
                                      : 'Are you sure you want to logout?',
                                  textAlign: isArabicValue
                                      ? TextAlign.right
                                      : TextAlign.left,
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
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.red.withValues(alpha: 0.2),
                            ),
                          ),
                        ),
                        child: Directionality(
                          textDirection: isArabicValue
                              ? TextDirection.rtl
                              : TextDirection.ltr,
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

  Widget _buildProfilePhotoImage() {
    final photoValue = _profilePhotoUrl?.trim();

    if (photoValue == null || photoValue.isEmpty) {
      return _buildDefaultAvatar();
    }

    if (photoValue.startsWith('data:image/')) {
      try {
        final commaIndex = photoValue.indexOf(',');
        if (commaIndex <= 0 || commaIndex >= photoValue.length - 1) {
          return _buildDefaultAvatar();
        }

        final imageBytes = base64Decode(photoValue.substring(commaIndex + 1));
        return Image.memory(
          imageBytes,
          width: 96,
          height: 96,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
        );
      } catch (e) {
        return _buildDefaultAvatar();
      }
    }

    return Image.network(
      photoValue,
      width: 96,
      height: 96,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    final formattedName = _getFormattedName().trim();
    final initial = formattedName.isNotEmpty
        ? formattedName.substring(0, 1).toUpperCase()
        : 'U';

    return Container(
      width: 96,
      height: 96,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Color(0xFF8E7CFF), Color(0xFF6A5CFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}


class _ProfilePhotoActionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDestructive;

  const _ProfilePhotoActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);
    final color = isDestructive
        ? const Color(0xFFE84A5F)
        : const Color(0xFF8E7CFF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF9F6FF),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5DEFF)),
        ),
        child: Row(
          textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                isArabicValue ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: isDestructive
                          ? const Color(0xFFE84A5F)
                          : const Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF7A6A5A),
                    ),
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
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
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

  String _toArabicDigits(Object value) {
    var text = value.toString();
    const englishDigits = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < englishDigits.length; i++) {
      text = text.replaceAll(englishDigits[i], arabicDigits[i]);
    }

    return text;
  }

  String _localizedNumber(BuildContext context, Object value) {
    return isArabic(context) ? _toArabicDigits(value) : value.toString();
  }

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
    final isArabicValue = isArabic(context);
    final color = _getArchetypeColor(character.archetype);
    final imagePath = _getImagePathForCharacter(character.characterName);
    final displayName = isArabicValue && character.displayNameAr.isNotEmpty
        ? character.displayNameAr
        : character.displayNameEn;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5DEFF)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Directionality(
        textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
        child: Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withValues(alpha: 0.1),
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
                    displayName,
                    textAlign:
                    isArabicValue ? TextAlign.right : TextAlign.left,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2A1E3B),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getLocalizedArchetype(context, character.archetype),
                          textAlign:
                          isArabicValue ? TextAlign.right : TextAlign.left,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFAB47BC).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isArabicValue ? 'نشط' : 'ACTIVE',
                          textAlign:
                          isArabicValue ? TextAlign.right : TextAlign.left,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFAB47BC),
                          ),
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


class _LanguageOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool selected;
  final bool isSaving;
  final VoidCallback onTap;

  const _LanguageOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.isSaving,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isArabicValue = isArabic(context);

    return Directionality(
      textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
      child: InkWell(
        onTap: isSaving ? null : onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFF8E7CFF).withValues(alpha: 0.10)
                : const Color(0xFFF9F6FF),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color:
              selected ? const Color(0xFF8E7CFF) : const Color(0xFFE5DEFF),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: selected ? const Color(0xFF8E7CFF) : Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  selected ? Icons.check_rounded : Icons.language_rounded,
                  color: selected ? Colors.white : const Color(0xFF8E7CFF),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2A1E3B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7A6A5A),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSaving)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        ),
      ),
    );
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
    final isArabicValue = isArabic(context);

    return Directionality(
      textDirection: isArabicValue ? TextDirection.rtl : TextDirection.ltr,
      child: ListTile(
        onTap: onTap,
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF8E7CFF).withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: const Color(0xFF8E7CFF), size: 20),
        ),
        title: Text(
          title,
          textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF2A1E3B),
          ),
        ),
        subtitle: Text(
          subtitle,
          textAlign: isArabicValue ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontSize: 13, color: Color(0xFF7A6A5A)),
        ),
        trailing: Icon(
          isArabicValue
              ? Icons.chevron_right_rounded
              : Icons.chevron_right_rounded,
          size: 22,
          color: const Color(0xFFD0C6E8),
        ),
      ),
    );
  }
}