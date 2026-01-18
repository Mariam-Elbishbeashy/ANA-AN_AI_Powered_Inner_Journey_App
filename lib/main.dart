import 'package:ana_ifs_app/screens/shell_screen.dart';
import 'package:ana_ifs_app/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const AnaApp());
}

class AnaApp extends StatelessWidget {
  const AnaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ANA',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF8E7CFF)),
        scaffoldBackgroundColor: const Color(0xFFF9F6FF),
      ),
      home: const WelcomeScreenWrapper(),
    );
  }
}

class WelcomeScreenWrapper extends StatelessWidget {
  const WelcomeScreenWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // Show welcome screen immediately while checking auth
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildWelcomeScreenWithLoading();
        }
        // if (snapshot.hasData) {
        //   return const AnaShell();
        // }

        // If user is logged in, show main app wrapper
        if (snapshot.hasData && snapshot.data != null) {
          return const MainAppWrapper();
        }

        // User is not logged in - show welcome screen
        return const AnaWelcomeScreen();
      },
    );
  }

  Widget _buildWelcomeScreenWithLoading() {
    return const AnaWelcomeScreen();
  }
}

class MainAppWrapper extends StatefulWidget {
  const MainAppWrapper({super.key});

  @override
  State<MainAppWrapper> createState() => _MainAppWrapperState();
}

class _MainAppWrapperState extends State<MainAppWrapper> {
  bool _checkingStatus = true;
  String? _destinationRoute;
  Map<String, dynamic>? _routeArguments;

  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }

  Future<void> _checkUserStatus() async {
    // Simulate a delay for checking user status
    await Future.delayed(const Duration(milliseconds: 500));

    // For now, just go back to welcome screen
    // In a real app, you would check Firestore for user questionnaire status
    setState(() {
      _checkingStatus = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingStatus) {
      return _buildLoadingScreen();
    }

    // If we have a destination route, navigate there
    if (_destinationRoute != null) {
      // Handle different routes
      return const AnaWelcomeScreen(); // Fallback
    }

    // Default fallback
    return const AnaWelcomeScreen();
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0xFFF9F6FF), Color(0xFFF4F0FF)],
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF8E7CFF)),
              SizedBox(height: 20),
              Text(
                'Loading your journey...',
                style: TextStyle(color: Color(0xFF4B3A66), fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
