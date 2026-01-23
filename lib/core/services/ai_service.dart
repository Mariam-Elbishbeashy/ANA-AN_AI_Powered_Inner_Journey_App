import 'dart:convert';

import 'package:http/http.dart' as http;

class AIService {
  // For Android Emulator:
  static const String _baseUrl = 'http://10.0.2.2:5000';

  // For physical device testing (use your computer's IP):
  // static const String _baseUrl = 'http://192.168.1.103:5000';

  Future<Map<String, dynamic>> predictCharacters(
    Map<String, dynamic> answers,
  ) async {
    try {
      print('🌐 Sending request to AI server...');
      print('   URL: $_baseUrl/predict');
      print('   Answers count: ${answers.length}');

      final response = await http.post(
        Uri.parse('$_baseUrl/predict'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'answers': answers}),
      );

      print('📥 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final result = json.decode(response.body);
        print('✅ AI prediction successful');
        print('   Predictions received: ${result['predictions']?.length ?? 0}');
        return result;
      } else {
        print('❌ Server error: ${response.statusCode}');
        print('   Body: ${response.body}');
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      print('❌ AI Service Error: $e');
      print('Stack trace: $stackTrace');
      rethrow;
    }
  }

  Future<bool> checkServerHealth() async {
    try {
      print('🔍 Checking server health at $_baseUrl/health');
      final response = await http.get(Uri.parse('$_baseUrl/health'));

      final healthy = response.statusCode == 200;
      print('   Server health: ${healthy ? '✅ Healthy' : '❌ Unhealthy'}');
      return healthy;
    } catch (e) {
      print('❌ Cannot reach server: $e');
      return false;
    }
  }
}
