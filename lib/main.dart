import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'screens/welcome_screen.dart';
import 'screens/shell_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
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
      ),

      // 🔑 THIS IS WHERE authStateChanges() GOES
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          // while Firebase checks auth state
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          // user is logged in
          if (snapshot.hasData) {
            return const AnaShell();
          }

          // user is NOT logged in
          return const AnaWelcomeScreen();
        },
      ),
    );
  }
}
