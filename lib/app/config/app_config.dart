import 'package:flutter/foundation.dart';

// App-level configuration and environment constants.
// Update AI base URL to match your local server or hosted endpoint.
class AppConfig {
  // Optional override:
  // flutter run --dart-define=AI_BASE_URL=http://127.0.0.1:5001
  static const String _aiBaseUrlFromEnv =
      String.fromEnvironment('AI_BASE_URL');

  static String get aiBaseUrl {
    if (_aiBaseUrlFromEnv.isNotEmpty) {
      return _aiBaseUrlFromEnv;
    }

    if (kIsWeb) {
      return 'http://localhost:5001';
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        // Android emulator -> host machine loopback.
        return 'http://10.0.2.2:5001';
      case TargetPlatform.iOS:
        // iOS simulator -> host machine loopback.
        return 'http://127.0.0.1:5001';
      default:
        return 'http://localhost:5001';
    }
  }
}