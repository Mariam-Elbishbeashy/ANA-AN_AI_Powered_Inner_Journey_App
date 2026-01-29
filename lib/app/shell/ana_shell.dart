// In ana_shell.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:o3d/o3d.dart';
import 'package:provider/provider.dart';

import 'package:ana_ifs_app/core/localization/app_language_provider.dart';
import 'package:ana_ifs_app/l10n/app_strings.dart';
import 'package:ana_ifs_app/features/questionnaire/presentation/screens/initial_motivation_screen.dart';
import 'package:ana_ifs_app/core/services/firestore_service.dart';
import 'package:ana_ifs_app/features/chat/presentation/screens/chat_screen.dart';
import 'package:ana_ifs_app/features/home/presentation/screens/home_screen.dart';
import 'package:ana_ifs_app/features/map_3d/presentation/screens/map_3d_screen.dart';
import 'package:ana_ifs_app/features/progress/presentation/screens/progress_screen.dart';
import 'package:ana_ifs_app/features/reframe/presentation/screens/reframe_screen.dart';

import 'package:ana_ifs_app/app/shell/ana_bottom_nav.dart';
import 'package:ana_ifs_app/features/onboarding/presentation/screens/welcome_screen.dart';

import '../../features/character/domain/entities/user_character.dart';
import 'package:ana_ifs_app/glb_cache_manager.dart';

class AnaShell extends StatefulWidget {
  const AnaShell({super.key});

  @override
  State<AnaShell> createState() => _AnaShellState();
}

class _AnaShellState extends State<AnaShell> {
  int _index = 0; // 0=Home, 1=3D Map, 2=Chat, 3=Reframe, 4=Progress
  final FirestoreService _firestoreService = FirestoreService();
  List<UserCharacter> _userCharacters = []; // Store user characters
  bool _charactersLoaded = false; // Flag to track if characters are loaded

  @override
  void initState() {
    super.initState();
    _loadUserCharacters();
  }

  Future<void> _loadUserCharacters() async {
    try {
      // Only load characters once
      if (!_charactersLoaded) {
        final characters = await _firestoreService.getUserCharacters();
        setState(() {
          _userCharacters = characters;
          _charactersLoaded = true;
        });
        print('✅ Loaded ${_userCharacters.length} user characters');

        // Pre-cache all GLB models in the background
        _precacheGLBModels();
      }
    } catch (e) {
      print('❌ Error loading user characters: $e');
      _userCharacters = [];
      _charactersLoaded = true; // Still mark as loaded to avoid retries
    }
  }

  void _precacheGLBModels() {
    // Pre-create controllers for all GLB models in background
    for (final character in _userCharacters) {
      if (character.glbFileName.isNotEmpty) {
        final glbPath = "assets/models/${character.glbFileName}";
        final cacheManager = GLBCacheManager();

        // Only create if not already cached
        if (cacheManager.getController(glbPath) == null) {
          final controller = O3DController();
          cacheManager.cacheController(glbPath, controller);
          print('🔄 Pre-cached GLB: ${character.glbFileName}');
        }
      }
    }
  }

  void _selectTab(int i) {
    setState(() {
      _index = i;
    });
  }

  String _getFriendlyName(User? user) {
    final display = user?.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;

    final email = user?.email?.trim();
    if (email != null && email.contains('@')) {
      final beforeAt = email.split('@').first;
      if (beforeAt.isNotEmpty) return beforeAt;
    }

    return "there";
  }

  Future<void> _logout() async {
    try {
      await FirebaseAuth.instance.signOut();

      // Clear the GLB cache on logout
      GLBCacheManager().clearCache();

      if (!mounted) return;

      // ✅ Clear all routes and go to Welcome
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AnaWelcomeScreen()),
            (route) => false,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Logout failed.")));
    }
  }

  Future<void> _retakeQuestionnaire() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Retake Questionnaire'),
        content: const Text(
          'This will clear your current character assessment and start a new questionnaire. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Retake'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Clear existing data
        await _firestoreService.clearQuestionnaireData();

        // Clear local state AND GLB cache
        setState(() {
          _userCharacters = [];
          _charactersLoaded = false;
        });

        // Clear the GLB cache
        GLBCacheManager().clearCache();

        // Navigate to motivation screen
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const InitialMotivationScreen()),
              (route) => false,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
      }
    }
  }

  Future<void> _switchLanguage() async {
    try {
      final provider = context.read<AppLanguageProvider>();
      await provider.toggleLanguage();
      final next = provider.language;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(
              context,
              'Language set to English',
              'تم تغيير اللغة للعربية',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr(context, 'Failed to change language', 'فشل تغيير اللغة'),
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    // Clear cache when shell is disposed (optional)
    // GLBCacheManager().clearCache();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final name = _getFriendlyName(user);

    final pages = <Widget>[
      HomeScreen(
        name: name,
        onLogout: _logout,
        onRetakeQuestionnaire: _retakeQuestionnaire,
        onSwitchLanguage: _switchLanguage,
      ),
      Map3DScreen(
        key: ValueKey('map3d_${_userCharacters.hashCode}'), // Add key for proper state management
        name: name,
        userCharacters: _userCharacters,
        onLogout: _logout,
        onRetakeQuestionnaire: _retakeQuestionnaire,
        onSwitchLanguage: _switchLanguage,
      ),
      ChatScreen(
        name: name,
        onLogout: _logout,
        onRetakeQuestionnaire: _retakeQuestionnaire,
        onSwitchLanguage: _switchLanguage,
      ),
      ReframeScreen(
        name: name,
        onLogout: _logout,
        onRetakeQuestionnaire: _retakeQuestionnaire,
        onSwitchLanguage: _switchLanguage,
      ),
      ProgressScreen(
        name: name,
        onLogout: _logout,
        onRetakeQuestionnaire: _retakeQuestionnaire,
        onSwitchLanguage: _switchLanguage,
      ),
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF9F6FF),
      body: Stack(
        children: [
          // Current page - Use IndexedStack to keep pages alive
          Positioned.fill(
            child: IndexedStack(
              index: _index,
              children: pages,
            ),
          ),

          // Bottom nav bar
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: AnaBottomNav(
              currentIndex: _index,
              onHome: () => _selectTab(0),
              onMap3D: () => _selectTab(1),
              onChat: () => _selectTab(2),
              onReframe: () => _selectTab(3),
              onProgress: () => _selectTab(4),
            ),
          ),
        ],
      ),
    );
  }
}